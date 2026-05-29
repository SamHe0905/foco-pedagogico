import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/professor_perfil.dart';
import '../domain/turma.dart'; // ProfessorItem, Turno e TurnoX

/// Gestão da equipe: lista de professores, perfis, cargos, status ativo e
/// vínculo de turmas.
class EquipeService {
  static final _db = Supabase.instance.client;
  static String get _userId => _db.auth.currentUser!.id;

  // Sentinela para distinguir "parâmetro não passado" de "parâmetro = null"
  static const _sentinel = Object();

  // ── Lista de professores ──────────────────────────────────────────────────

  static Future<List<ProfessorItem>> getProfessores() async {
    final data = await _db
        .from('profiles')
        .select('id, nome')
        .inFilter('role', ['professor', 'professor_aee'])
        .order('nome');

    return (data as List)
        .map((m) => ProfessorItem(id: m['id'] as String, nome: m['nome'] as String))
        .toList();
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
        myRole == 'diretor' || myRole == 'diretor-adjunto' || myRole == 'secretaria';

    final rolesVisiveis = isDirector
        ? ['professor', 'supervisor', 'coordenacao', 'diretor', 'diretor-adjunto', 'pcsa', 'professor_aee', 'secretaria']
        : ['professor', 'supervisor', 'coordenacao', 'pcsa', 'professor_aee'];

    // 2. Perfis
    final profiles = await _db
        .from('profiles')
        .select('id, nome, role, role_secundario')
        .inFilter('role', rolesVisiveis)
        .neq('id', _userId)
        .order('nome');

    // 3. Turmas por professor (agora inclui turno)
    final links = await _db
        .from('professor_turmas')
        .select('professor_id, turmas(id, nome, turno)');

    // 4. Status ativo
    final statuses = await _db
        .from('professor_status')
        .select('professor_id, ativo');

    final turmasMap = <String, List<TurmaSimples>>{};
    for (final l in links as List) {
      final pid = l['professor_id'] as String;
      final t   = l['turmas'] as Map<String, dynamic>;
      turmasMap.putIfAbsent(pid, () => [])
          .add(TurmaSimples(
            id:    t['id']    as String,
            nome:  t['nome']  as String,
            turno: TurnoX.fromString(t['turno'] as String? ?? 'matutino'),
          ));
    }

    final statusMap = <String, bool>{
      for (final s in statuses as List)
        s['professor_id'] as String: s['ativo'] as bool,
    };

    return (profiles as List)
        .map((p) => ProfessorPerfil(
              id:             p['id']             as String,
              nome:           p['nome']           as String,
              role:           p['role']           as String,
              roleSecundario: p['role_secundario'] as String?,
              ativo:          statusMap[p['id']] ?? true,
              turmas:         turmasMap[p['id']] ?? [],
            ))
        .toList();
  }

  // Altera o cargo (role) de um membro da equipe via Edge Function (service role).
  //
  // [novoRoleSecundario]:
  //   - omitido → não mexe no role_secundario atual
  //   - null    → limpa o role_secundario (remove duplo acesso)
  //   - string  → define o role_secundario (deve ser diferente do principal)
  static Future<void> alterarCargo(
    String userId,
    String novoRole, {
    Object? novoRoleSecundario = _sentinel,
  }) async {
    final body = <String, dynamic>{
      'userId':   userId,
      'novoRole': novoRole,
    };
    if (!identical(novoRoleSecundario, _sentinel)) {
      body['novoRoleSecundario'] = novoRoleSecundario; // pode ser null
    }

    final res = await _db.functions.invoke('alterar-cargo', body: body);
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Erro ao alterar cargo.');
    }
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
}
