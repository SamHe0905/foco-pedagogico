import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/demanda_anexo.dart';
import '../domain/demanda_resumo.dart';
import '../domain/professor_pendencias.dart';
import '../domain/professor_perfil.dart';
import '../domain/status_professor.dart';
import '../domain/turma.dart';

class CoordenacaoService {
  static final _db   = Supabase.instance.client;
  static final _auth = Supabase.instance.client.auth;

  static String get _userId => _auth.currentUser!.id;

  // ── Demandas criadas por esta coordenação ─────────────────────────────────

  static Future<List<DemandaResumo>> getDemandas() async {
    final data = await _db
        .from('demandas')
        .select('id, titulo, descricao, turma, tipo, prazo, prioridade, demanda_professor(status)')
        .eq('criada_por', _userId)
        .order('criada_em', ascending: false);

    return (data as List)
        .map((m) => DemandaResumo.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ── Todas as demandas (todos os coordenadores) — somente leitura ──────────

  static Future<List<DemandaResumo>> getTodasDemandas() async {
    final data = await _db
        .from('demandas')
        .select(
          'id, titulo, descricao, turma, tipo, prazo, prioridade, '
          'criador:profiles!criada_por(nome), '
          'demanda_professor(status)',
        )
        .order('criada_em', ascending: false);

    return (data as List)
        .map((m) => DemandaResumo.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ── Lista de turmas cadastradas ───────────────────────────────────────────

  static Future<List<Turma>> getTurmas() async {
    final data = await _db
        .from('turmas')
        .select('id, nome')
        .order('nome');

    return (data as List)
        .map((m) => Turma(id: m['id'] as String, nome: m['nome'] as String))
        .toList();
  }

  // ── Lista de professores ──────────────────────────────────────────────────

  static Future<List<ProfessorItem>> getProfessores() async {
    final data = await _db
        .from('profiles')
        .select('id, nome')
        .eq('role', 'professor')
        .order('nome');

    return (data as List)
        .map((m) => ProfessorItem(id: m['id'] as String, nome: m['nome'] as String))
        .toList();
  }

  // ── Criar nova demanda ────────────────────────────────────────────────────
  //
  // tipo = 'geral'      → atribui a todos os professores
  // tipo = 'turma'      → atribui aos professores da turma selecionada
  // tipo = 'individual' → atribui a um professor específico

  static Future<String> criarDemanda({
    required String   titulo,
    required String   descricao,
    required String   tipo,
    required DateTime prazo,
    required String   prioridade,
    String? turmaId,       // obrigatório quando tipo == 'turma'
    String? turmaNome,     // nome legível da turma (para display)
    String? professorId,   // obrigatório quando tipo == 'individual'
  }) async {
    // Texto de destino exibido nos cards
    final turmaDisplay = switch (tipo) {
      'geral'      => 'Geral',
      'turma'      => turmaNome ?? '',
      'individual' => 'Individual',
      _            => '',
    };

    // 1. Insere a demanda
    final res = await _db.from('demandas').insert({
      'titulo':     titulo.trim(),
      'descricao':  descricao.trim(),
      'tipo':       tipo,
      'turma':      turmaDisplay,
      'turma_id':   turmaId,
      'prazo':      _formatDate(prazo),
      'prioridade': prioridade,
      'criada_por': _userId,
    }).select('id').single();

    final demandaId = res['id'] as String;

    // 2. Determina quais professores recebem a demanda
    final List<String> professorIds;

    switch (tipo) {
      case 'geral':
        final rows = await _db
            .from('profiles')
            .select('id')
            .eq('role', 'professor');
        professorIds = (rows as List).map((r) => r['id'] as String).toList();

      case 'turma':
        final rows = await _db
            .from('professor_turmas')
            .select('professor_id')
            .eq('turma_id', turmaId!);
        professorIds = (rows as List).map((r) => r['professor_id'] as String).toList();

      case 'individual':
        professorIds = [professorId!];

      default:
        professorIds = [];
    }

    if (professorIds.isEmpty) return demandaId;

    // 3. Atribui a demanda a cada professor
    await _db.from('demanda_professor').insert(
      professorIds
          .map((pid) => {
                'demanda_id':   demandaId,
                'professor_id': pid,
                'status':       'pendente',
              })
          .toList(),
    );

    // Notifica professores em background — não bloqueia nem propaga erros
    Future.microtask(() async {
      try {
        await _db.functions.invoke(
          'notify-professores',
          body: {'demanda_id': demandaId},
        );
      } catch (e) {
        debugPrint('[Notify] Erro ao enviar notificações: $e');
      }
    });

    return demandaId;
  }

  // ── Gestão de professores ─────────────────────────────────────────────────

  static Future<List<ProfessorPerfil>> getProfessoresPerfis() async {
    // 1. Verifica role do usuário logado para filtrar quem ele pode gerenciar
    final meData = await _db
        .from('profiles')
        .select('role')
        .eq('id', _userId)
        .single();
    final myRole = meData['role'] as String;
    final isDirector =
        myRole == 'diretor' || myRole == 'diretor-adjunto';

    final rolesVisiveis = isDirector
        ? ['professor', 'supervisor', 'coordenacao', 'diretor', 'diretor-adjunto']
        : ['professor', 'supervisor', 'coordenacao']; // coordenador e supervisor veem todos exceto diretores

    // 2. Perfis
    final profiles = await _db
        .from('profiles')
        .select('id, nome, role')
        .inFilter('role', rolesVisiveis)
        .neq('id', _userId) // não lista a si mesmo
        .order('nome');

    // 2. Turmas por professor
    final links = await _db
        .from('professor_turmas')
        .select('professor_id, turmas(id, nome)');

    // 3. Status ativo
    final statuses = await _db
        .from('professor_status')
        .select('professor_id, ativo');

    final turmasMap = <String, List<TurmaSimples>>{};
    for (final l in links as List) {
      final pid = l['professor_id'] as String;
      final t   = l['turmas'] as Map<String, dynamic>;
      turmasMap.putIfAbsent(pid, () => [])
          .add(TurmaSimples(id: t['id'], nome: t['nome']));
    }

    final statusMap = <String, bool>{
      for (final s in statuses as List)
        s['professor_id'] as String: s['ativo'] as bool,
    };

    return (profiles as List)
        .map((p) => ProfessorPerfil(
              id:     p['id'] as String,
              nome:   p['nome'] as String,
              role:   p['role'] as String,
              ativo:  statusMap[p['id']] ?? true,
              turmas: turmasMap[p['id']] ?? [],
            ))
        .toList();
  }

  static Future<void> toggleAtivoProfessor(String professorId, {required bool ativo}) async {
    await _db.from('professor_status').upsert({
      'professor_id': professorId,
      'ativo':        ativo,
    });
  }

  static Future<void> atualizarTurmasProfessor(
      String professorId, List<String> turmaIds) async {
    await _db
        .from('professor_turmas')
        .delete()
        .eq('professor_id', professorId);

    if (turmaIds.isNotEmpty) {
      await _db.from('professor_turmas').insert(
        turmaIds
            .map((tid) => {'professor_id': professorId, 'turma_id': tid})
            .toList(),
      );
    }
  }

  // Integra novo membro via Edge Function
  static Future<void> integrarDocente(String email, String nome, String role) async {
    final res = await _db.functions.invoke(
      'invite-professor',
      body: {'email': email.trim(), 'nome': nome.trim(), 'role': role},
    );
    if (res.status != 200) {
      final erro = res.data?['error'] as String? ?? 'Erro ao enviar convite.';
      if (erro.toLowerCase().contains('already been registered') ||
          erro.toLowerCase().contains('already registered')) {
        throw Exception('Este e-mail já está cadastrado. Exclua o usuário antes de reenviar o convite.');
      }
      throw Exception(erro);
    }
  }

  // Exclui usuário do sistema via Edge Function
  static Future<void> deletarUsuario(String userId) async {
    final res = await _db.functions.invoke(
      'deletar-usuario',
      body: {'userId': userId},
    );
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Erro ao excluir usuário.');
    }
  }

  // ── Editar demanda (campos simples — tipo/turma não mudam) ───────────────

  static Future<void> editarDemanda({
    required String   demandaId,
    required String   titulo,
    required String   descricao,
    required DateTime prazo,
    required String   prioridade,
  }) async {
    await _db.from('demandas').update({
      'titulo':     titulo.trim(),
      'descricao':  descricao.trim(),
      'prazo':      _formatDate(prazo),
      'prioridade': prioridade,
    }).eq('id', demandaId).eq('criada_por', _userId);
  }

  // ── Notificar professores com demandas atrasadas ─────────────────────────

  static Future<void> notificarAtrasados(List<String> demandaIds) async {
    for (final id in demandaIds) {
      try {
        await _db.functions.invoke(
          'notify-professores',
          body: {'demanda_id': id, 'tipo': 'lembrete'},
        );
      } catch (e) {
        debugPrint('[Notify] Erro ao notificar atrasada $id: $e');
      }
    }
  }

  // ── Excluir demanda ───────────────────────────────────────────────────────

  static Future<void> excluirDemanda(String demandaId) async {
    // 1. Busca os storage_paths dos anexos para remover do bucket
    final anexosRaw = await _db
        .from('demanda_anexos')
        .select('storage_path')
        .eq('demanda_id', demandaId);

    final paths = (anexosRaw as List)
        .map((r) => r['storage_path'] as String)
        .toList();

    if (paths.isNotEmpty) {
      await _db.storage.from(_bucket).remove(paths);
    }

    // 2. Remove os registros da tabela (independente de CASCADE no FK)
    await _db.from('demanda_anexos').delete().eq('demanda_id', demandaId);

    // 3. Exclui a demanda
    await _db
        .from('demandas')
        .delete()
        .eq('id', demandaId)
        .eq('criada_por', _userId);
  }

  // ── Professores com pendências (visão agregada para o dashboard) ─────────
  //
  // Retorna, para cada professor que ainda tem status 'pendente' em qualquer
  // demanda desta coordenação, o nome dele e a lista de demandas pendentes.

  static Future<List<ProfessorComPendencias>> getProfessoresPendentes() async {
    // 1. Busca todas as demandas com os status por professor
    final demandasRaw = await _db
        .from('demandas')
        .select('titulo, turma, tipo, demanda_professor(professor_id, status)')
        .eq('criada_por', _userId);

    // 2. Agrupa por professor_id → labels das demandas pendentes
    final Map<String, List<String>> porProfessor = {};
    for (final d in demandasRaw as List) {
      final titulo = d['titulo'] as String;
      final turma  = (d['turma'] as String?) ?? '';
      final tipo   = (d['tipo'] as String?) ?? '';
      final label  = (tipo == 'geral' || turma.isEmpty)
          ? titulo
          : '$titulo · $turma';

      for (final dp in d['demanda_professor'] as List) {
        if (dp['status'] == 'pendente') {
          final pid = dp['professor_id'] as String;
          porProfessor.putIfAbsent(pid, () => []).add(label);
        }
      }
    }

    if (porProfessor.isEmpty) return [];

    // 3. Busca nomes dos professores
    final perfis = await _db
        .from('profiles')
        .select('id, nome')
        .inFilter('id', porProfessor.keys.toList());

    // 4. Monta lista ordenada por nome
    final lista = (perfis as List).map<ProfessorComPendencias>((p) {
      final pid = p['id'] as String;
      return ProfessorComPendencias(
        nome:     p['nome'] as String,
        demandas: porProfessor[pid] ?? [],
      );
    }).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    return lista;
  }

  // ── Detalhes por professor de uma demanda ─────────────────────────────────
  // Usa embedded select via tabela demandas (mesmo caminho que já funciona
  // no dashboard) — sem precisar de policy extra em demanda_professor.

  static Future<List<StatusProfessor>> getDetalhesProfessores(String demandaId) async {
    // 1. Busca status via demandas (coordenador já tem acesso à própria demanda)
    final data = await _db
        .from('demandas')
        .select('demanda_professor(professor_id, status)')
        .eq('id', demandaId)
        .eq('criada_por', _userId)
        .single();

    final rows = data['demanda_professor'] as List;
    if (rows.isEmpty) return [];

    // 2. Busca nomes (profiles acessível para todos autenticados)
    final ids = rows.map((r) => r['professor_id'] as String).toList();
    final perfis = await _db
        .from('profiles')
        .select('id, nome')
        .inFilter('id', ids);

    final nomeMap = {
      for (final p in perfis as List) p['id'] as String: p['nome'] as String,
    };

    // 3. Monta e ordena: concluída → visualizada → pendente
    final lista = rows.map((r) => StatusProfessor(
          nome:   nomeMap[r['professor_id']] ?? 'Professor',
          status: r['status'] as String,
        )).toList();

    const ordem = {'concluida': 0, 'visualizada': 1, 'pendente': 2};
    lista.sort((a, b) =>
        (ordem[a.status] ?? 3).compareTo(ordem[b.status] ?? 3));

    return lista;
  }

  // ── Anexos de PDF ─────────────────────────────────────────────────────────

  static const _bucket = 'demanda-anexos';

  static Future<List<DemandaAnexo>> getAnexos(String demandaId) async {
    final data = await _db
        .from('demanda_anexos')
        .select()
        .eq('demanda_id', demandaId)
        .order('criado_em');
    return (data as List)
        .map((m) => DemandaAnexo.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<void> uploadAnexo(
      String demandaId, String nome, Uint8List bytes) async {
    final path =
        '$demandaId/${DateTime.now().millisecondsSinceEpoch}_$nome';

    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );

    final url = _db.storage.from(_bucket).getPublicUrl(path);

    await _db.from('demanda_anexos').insert({
      'demanda_id':   demandaId,
      'nome':         nome,
      'url':          url,
      'storage_path': path,
      'tamanho':      bytes.length,
    });
  }

  static Future<void> deleteAnexo(String anexoId, String storagePath) async {
    await _db.storage.from(_bucket).remove([storagePath]);
    await _db.from('demanda_anexos').delete().eq('id', anexoId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
