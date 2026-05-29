import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/demanda_resumo.dart';
import '../domain/professor_pendencias.dart';
import '../domain/status_professor.dart';

/// Demandas criadas/geridas pela coordenação: CRUD, criação com atribuição,
/// pendências agregadas, detalhes por professor e notificações de atraso.
class DemandasCoordenacaoService {
  static final _db = Supabase.instance.client;
  static String get _userId => _db.auth.currentUser!.id;

  static const _bucket = 'demanda-anexos';

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    // Busca demandas sem join de FK (evita erro quando criada_por → auth.users)
    final data = await _db
        .from('demandas')
        .select(
          'id, titulo, descricao, turma, tipo, prazo, prioridade, '
          'criada_por, demanda_professor(status)',
        )
        .order('criada_em', ascending: false);

    final rows = data as List;
    if (rows.isEmpty) return [];

    // Busca nomes dos criadores separadamente
    final ids = rows.map((d) => d['criada_por'] as String).toSet().toList();
    final perfis = await _db
        .from('profiles')
        .select('id, nome')
        .inFilter('id', ids);

    final nomeMap = {
      for (final p in perfis as List) p['id'] as String: p['nome'] as String,
    };

    return rows.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      final nomeCriador = nomeMap[map['criada_por'] as String];
      map['criador'] = nomeCriador != null ? {'nome': nomeCriador} : null;
      return DemandaResumo.fromMap(map);
    }).toList();
  }

  // ── Criar nova demanda ────────────────────────────────────────────────────
  //
  // tipo = 'geral'       → atribui a todos os professores
  // tipo = 'turma'       → atribui aos professores da turma selecionada
  // tipo = 'individual'  → atribui a um professor específico
  // tipo = 'coordenacao' → atribui à coordenação (coordenacao + supervisor + pcsa)

  static Future<String> criarDemanda({
    required String   titulo,
    required String   descricao,
    required String   tipo,
    required DateTime prazo,
    required String   prioridade,
    String?       turmaId,          // obrigatório quando tipo == 'turma'
    String?       turmaNome,        // nome legível da turma (para display)
    String?       turnoFiltro,      // turno da turma (para indexar nas demandas)
    String?       professorId,      // compatibilidade — individual simples
    List<String>? professorIds,     // individual multi-select
  }) async {
    // Texto de destino exibido nos cards
    final turmaDisplay = switch (tipo) {
      'geral'       => 'Geral',
      'turma'       => turmaNome ?? '',
      'individual'  => 'Individual',
      'coordenacao' => 'Coordenação',
      'gestao'      => 'Gestão',
      _             => '',
    };

    // 1. Insere a demanda
    final res = await _db.from('demandas').insert({
      'titulo':     titulo.trim(),
      'descricao':  descricao.trim(),
      'tipo':       tipo,
      'turma':      turmaDisplay,
      'turma_id':   turmaId,
      'turno':      turnoFiltro,
      'prazo':      _formatDate(prazo),
      'prioridade': prioridade,
      'criada_por': _userId,
    }).select('id').single();

    final demandaId = res['id'] as String;

    // 2. Determina quais professores recebem a demanda
    final List<String> destinos;

    switch (tipo) {
      case 'geral':
        final rows = await _db
            .from('profiles')
            .select('id')
            .inFilter('role', ['professor', 'professor_aee']);
        destinos = (rows as List).map((r) => r['id'] as String).toList();

      case 'turma':
        final rows = await _db
            .from('professor_turmas')
            .select('professor_id')
            .eq('turma_id', turmaId!);
        destinos = (rows as List).map((r) => r['professor_id'] as String).toList();

      case 'individual':
        // Suporta multi-select: usa professorIds se fornecido, senão professorId
        destinos = professorIds ?? (professorId != null ? [professorId] : []);

      case 'coordenacao':
        // Comunicação interna da coordenação pedagógica
        final rows = await _db
            .from('profiles')
            .select('id')
            .inFilter('role', ['coordenacao', 'supervisor', 'pcsa', 'pcpi']);
        // Não envia para si mesmo
        destinos = (rows as List)
            .map((r) => r['id'] as String)
            .where((id) => id != _userId)
            .toList();

      case 'gestao':
        // Comunicação da gestão: direção, direção adjunta e secretaria
        final rows = await _db
            .from('profiles')
            .select('id')
            .inFilter('role', ['diretor', 'diretor-adjunto', 'secretaria']);
        // Não envia para si mesmo
        destinos = (rows as List)
            .map((r) => r['id'] as String)
            .where((id) => id != _userId)
            .toList();

      default:
        destinos = [];
    }

    final professorIdsLocal = destinos;

    if (professorIdsLocal.isEmpty) return demandaId;

    // 3. Atribui a demanda a cada professor
    await _db.from('demanda_professor').insert(
      professorIdsLocal
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
    // 1. Valida permissão: criador OU roles de gestão/direção podem apagar
    final demanda = await _db
        .from('demandas')
        .select('criada_por')
        .eq('id', demandaId)
        .maybeSingle();

    if (demanda == null) {
      throw Exception('Demanda não encontrada.');
    }

    // Verifica role do usuário para permitir que gestão apague qualquer demanda
    if (demanda['criada_por'] != _userId) {
      final perfil = await _db
          .from('profiles')
          .select('role')
          .eq('id', _userId)
          .single();
      final role = perfil['role'] as String;
      const rolesGestao = {
        'diretor', 'diretor-adjunto', 'secretaria', 'supervisor', 'pcsa'
      };
      if (!rolesGestao.contains(role)) {
        throw Exception('Apenas o criador da demanda pode removê-la.');
      }
    }

    // 2. Anexos do storage
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

    // 3. Remove atribuições aos professores
    //    (sem isso, a demanda continua aparecendo na lista deles)
    await _db.from('demanda_professor').delete().eq('demanda_id', demandaId);

    // 4. Remove registros de anexos
    await _db.from('demanda_anexos').delete().eq('demanda_id', demandaId);

    // 5. Exclui a demanda em si
    await _db.from('demandas').delete().eq('id', demandaId);
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
        .select('demanda_professor(professor_id, status, observacao)')
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
          nome:      nomeMap[r['professor_id']] ?? 'Professor',
          status:    r['status'] as String,
          observacao: r['observacao'] as String?,
        )).toList();

    const ordem = {'concluida': 0, 'visualizada': 1, 'pendente': 2};
    lista.sort((a, b) =>
        (ordem[a.status] ?? 3).compareTo(ordem[b.status] ?? 3));

    return lista;
  }
}
