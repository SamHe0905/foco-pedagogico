import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/solicitacao.dart';
import '../../coordenacao/domain/turma.dart';
import '../../coordenacao/services/cursos_tecnicos_service.dart';

class SolicitacoesService {
  static final _db   = Supabase.instance.client;
  static final _auth = Supabase.instance.client.auth;

  static String get _userId => _auth.currentUser!.id;

  static const _bucket = 'solicitacao-anexos';

  // ── Professor: criar solicitação ──────────────────────────────────────────

  /// Encontra o coordenador responsável pela etapa+turno informados.
  static Future<String?> _findCoordenador(String etapa, String turno) async {
    final rows = await _db
        .from('coordenador_etapas')
        .select('coordenador_id')
        .eq('etapa', etapa)
        .eq('turno', turno)
        .limit(1);

    final list = rows as List;
    if (list.isEmpty) return null;
    return list.first['coordenador_id'] as String;
  }

  static Future<String> criarSolicitacao({
    required String titulo,
    required String descricao,
    String? turmaId,
    String? turmaNome,
    String? turmaEtapa,
    String? turmaTurno,
    String? turmaCursoTecnicoId,
  }) async {
    // Resolve o coordenador pela etapa+turno da turma
    String? coordenadorId;
    if (turmaEtapa != null && turmaTurno != null) {
      coordenadorId = await _findCoordenador(turmaEtapa, turmaTurno);
    }
    if (coordenadorId == null) {
      throw Exception(
        'Nenhum coordenador encontrado para essa etapa/turno. '
        'Solicite ao administrador que configure as etapas do coordenador.',
      );
    }

    // Resolve supervisor pelo curso técnico da turma (opcional)
    String? supervisorId;
    if (turmaCursoTecnicoId != null) {
      supervisorId = await CursosTecnicosService.findSupervisorByCurso(
          turmaCursoTecnicoId);
    }

    final res = await _db.from('solicitacoes').insert({
      'titulo':         titulo.trim(),
      'descricao':      descricao.trim(),
      'professor_id':   _userId,
      'coordenador_id': coordenadorId,
      'supervisor_id':  supervisorId,
      'turma_id':       turmaId,
      'status':         'pendente',
    }).select('id').single();

    return res['id'] as String;
  }

  // ── Professor: listar suas solicitações ───────────────────────────────────

  static Future<List<Solicitacao>> getMinhaSolicitacoes() async {
    final rows = await _db
        .from('solicitacoes')
        .select('*, solicitacao_anexos(*)')
        .eq('professor_id', _userId)
        .order('criada_em', ascending: false);

    return _enrichWithNames(rows as List);
  }

  // ── Coordenador: listar solicitações recebidas ────────────────────────────

  static Future<List<Solicitacao>> getSolicitacoesRecebidas() async {
    final rows = await _db
        .from('solicitacoes')
        .select('*, solicitacao_anexos(*)')
        .or('coordenador_id.eq.$_userId,supervisor_id.eq.$_userId')
        .order('criada_em', ascending: false);

    return _enrichWithNames(rows as List);
  }

  // ── Contagem de pendentes (para badge in-app) ─────────────────────────────

  static Future<int> countSolicitacoesPendentes() async {
    final rows = await _db
        .from('solicitacoes')
        .select('id')
        .or('coordenador_id.eq.$_userId,supervisor_id.eq.$_userId')
        .eq('status', 'pendente');
    return (rows as List).length;
  }

  // ── Coordenador: atualizar status ─────────────────────────────────────────

  static Future<void> atualizarStatus(
      String id, StatusSolicitacao status) async {
    await _db.from('solicitacoes').update({
      'status':        status.dbValue,
      'atualizada_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Anexos ────────────────────────────────────────────────────────────────

  static Future<void> uploadAnexo(
      String solicitacaoId, String nome, Uint8List bytes) async {
    final safeName = _sanitize(nome);
    final path =
        '$solicitacaoId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentType(nome)),
        );

    final url = _db.storage.from(_bucket).getPublicUrl(path);

    await _db.from('solicitacao_anexos').insert({
      'solicitacao_id': solicitacaoId,
      'nome':           nome,
      'url':            url,
      'storage_path':   path,
      'tamanho':        bytes.length,
    });
  }

  static Future<void> deleteAnexo(String anexoId, String storagePath) async {
    await _db.storage.from(_bucket).remove([storagePath]);
    await _db.from('solicitacao_anexos').delete().eq('id', anexoId);
  }

  // ── Coordenador: etapas cobertas ─────────────────────────────────────────

  static Future<List<EtapaTurno>> getEtapasCoordenador(
      String coordenadorId) async {
    final rows = await _db
        .from('coordenador_etapas')
        .select('etapa, turno')
        .eq('coordenador_id', coordenadorId);

    return (rows as List).map((r) {
      final etapa = EtapaX.fromString(r['etapa'] as String);
      final turno = TurnoX.fromString(r['turno'] as String? ?? '');
      if (etapa == null) return null;
      return EtapaTurno(etapa: etapa, turno: turno);
    }).whereType<EtapaTurno>().toList();
  }

  static Future<void> salvarEtapasCoordenador(
      String coordenadorId, List<EtapaTurno> etapas) async {
    // Substitui completamente
    await _db
        .from('coordenador_etapas')
        .delete()
        .eq('coordenador_id', coordenadorId);

    if (etapas.isEmpty) return;

    await _db.from('coordenador_etapas').insert(
      etapas
          .map((e) => {
                'coordenador_id': coordenadorId,
                'etapa':          e.dbEtapa,
                'turno':          e.dbTurno,
              })
          .toList(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Busca nomes de professores e turmas para enriquecer a lista.
  static Future<List<Solicitacao>> _enrichWithNames(List rows) async {
    if (rows.isEmpty) return [];

    final profIds   = rows.map((r) => r['professor_id'] as String).toSet().toList();
    final turmaIds  = rows
        .map((r) => r['turma_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final perfis = await _db
        .from('profiles')
        .select('id, nome')
        .inFilter('id', profIds);

    final nomeMap = {
      for (final p in perfis as List) p['id'] as String: p['nome'] as String,
    };

    Map<String, String> turmaMap = {};
    if (turmaIds.isNotEmpty) {
      final turmas = await _db
          .from('turmas')
          .select('id, nome')
          .inFilter('id', turmaIds);
      turmaMap = {
        for (final t in turmas as List) t['id'] as String: t['nome'] as String,
      };
    }

    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      map['professor_nome'] = nomeMap[map['professor_id']] ?? 'Professor';
      map['turma_nome']     = map['turma_id'] != null
          ? turmaMap[map['turma_id']]
          : null;
      return Solicitacao.fromMap(map);
    }).toList();
  }

  static String _sanitize(String nome) {
    const acentos = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a',
      'é': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o',
      'õ': 'o', 'ô': 'o', 'ú': 'u', 'ç': 'c',
    };
    var r = nome.toLowerCase();
    acentos.forEach((k, v) => r = r.replaceAll(k, v));
    return r.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w\-.]'), '');
  }

  static String _contentType(String nome) {
    final ext = nome.toLowerCase().split('.').last;
    return switch (ext) {
      'pdf'  => 'application/pdf',
      'doc'  => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      _               => 'application/octet-stream',
    };
  }
}
