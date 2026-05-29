import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/curso_tecnico.dart';

class CursosTecnicosService {
  static final _db = Supabase.instance.client;

  // ── CRUD de cursos ────────────────────────────────────────────────────────

  static Future<List<CursoTecnico>> getCursos() async {
    final data = await _db
        .from('cursos_tecnicos')
        .select()
        .order('nome');
    return (data as List)
        .map((m) => CursoTecnico.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<void> criarCurso(String nome) async {
    await _db.from('cursos_tecnicos').insert({'nome': nome.trim()});
  }

  static Future<void> editarCurso(String id, String nome) async {
    await _db
        .from('cursos_tecnicos')
        .update({'nome': nome.trim()})
        .eq('id', id);
  }

  static Future<void> excluirCurso(String id) async {
    await _db.from('cursos_tecnicos').delete().eq('id', id);
  }

  // ── Vínculo supervisor ↔ cursos ───────────────────────────────────────────

  /// IDs dos cursos pelos quais este supervisor é responsável.
  static Future<List<String>> getCursoIdsSupervisor(
      String supervisorId) async {
    final rows = await _db
        .from('supervisor_cursos')
        .select('curso_tecnico_id')
        .eq('supervisor_id', supervisorId);
    return (rows as List)
        .map((r) => r['curso_tecnico_id'] as String)
        .toList();
  }

  /// Substitui todos os cursos vinculados ao supervisor.
  static Future<void> salvarCursosSupervisor(
      String supervisorId, List<String> cursoIds) async {
    await _db
        .from('supervisor_cursos')
        .delete()
        .eq('supervisor_id', supervisorId);

    if (cursoIds.isNotEmpty) {
      await _db.from('supervisor_cursos').insert(
        cursoIds
            .map((cid) => {
                  'supervisor_id':    supervisorId,
                  'curso_tecnico_id': cid,
                })
            .toList(),
      );
    }
  }

  /// Retorna o supervisor_id responsável pelo curso, ou null.
  static Future<String?> findSupervisorByCurso(
      String cursoTecnicoId) async {
    final rows = await _db
        .from('supervisor_cursos')
        .select('supervisor_id')
        .eq('curso_tecnico_id', cursoTecnicoId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return list.first['supervisor_id'] as String;
  }
}
