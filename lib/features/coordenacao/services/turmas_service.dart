import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/turma.dart'; // inclui Turno e TurnoX

/// CRUD de turmas (lista, criar, editar, excluir).
class TurmasService {
  static final _db = Supabase.instance.client;

  // ── Lista de turmas cadastradas ───────────────────────────────────────────

  static Future<List<Turma>> getTurmas() async {
    // Tenta com join; se a tabela cursos_tecnicos ainda não existir, cai no fallback.
    List rows;
    bool temCursoJoin = true;
    try {
      rows = await _db
          .from('turmas')
          .select('id, nome, serie, turno, etapa, curso_tecnico_id, cursos_tecnicos(nome)')
          .order('turno')
          .order('nome') as List;
    } catch (_) {
      temCursoJoin = false;
      rows = await _db
          .from('turmas')
          .select('id, nome, serie, turno, etapa')
          .order('turno')
          .order('nome') as List;
    }

    return rows.map((m) {
      final cursoMap = temCursoJoin
          ? m['cursos_tecnicos'] as Map<String, dynamic>?
          : null;
      return Turma(
        id:               m['id']    as String,
        nome:             m['nome']  as String,
        serie:            m['serie'] as String? ?? '',
        turno:            TurnoX.fromString(m['turno'] as String? ?? 'matutino'),
        etapa:            EtapaX.fromString(m['etapa'] as String?),
        cursoTecnicoId:   temCursoJoin ? m['curso_tecnico_id'] as String? : null,
        cursoTecnicoNome: cursoMap?['nome'] as String?,
      );
    }).toList();
  }

  // ── CRUD de turmas ────────────────────────────────────────────────────────

  static Future<void> criarTurma({
    required String nome,
    required String serie,
    required Turno  turno,
    Etapa?  etapa,
    String? cursoTecnicoId,
  }) async {
    final payload = <String, dynamic>{
      'nome':  nome.trim(),
      'serie': serie.trim(),
      'turno': turno.dbValue,
      'etapa': etapa?.dbValue,
    };
    if (cursoTecnicoId != null) payload['curso_tecnico_id'] = cursoTecnicoId;
    try {
      await _db.from('turmas').insert(payload);
    } catch (e) {
      // Se a coluna curso_tecnico_id ainda não existe, tenta sem ela
      if (e.toString().contains('curso_tecnico_id')) {
        payload.remove('curso_tecnico_id');
        await _db.from('turmas').insert(payload);
      } else {
        rethrow;
      }
    }
  }

  static Future<void> editarTurma({
    required String id,
    required String nome,
    required String serie,
    required Turno  turno,
    Etapa?  etapa,
    String? cursoTecnicoId,
  }) async {
    final payload = <String, dynamic>{
      'nome':  nome.trim(),
      'serie': serie.trim(),
      'turno': turno.dbValue,
      'etapa': etapa?.dbValue,
    };
    if (cursoTecnicoId != null) payload['curso_tecnico_id'] = cursoTecnicoId;
    try {
      await _db.from('turmas').update(payload).eq('id', id);
    } catch (e) {
      if (e.toString().contains('curso_tecnico_id')) {
        payload.remove('curso_tecnico_id');
        await _db.from('turmas').update(payload).eq('id', id);
      } else {
        rethrow;
      }
    }
  }

  static Future<void> excluirTurma(String turmaId) async {
    await _db.from('turmas').delete().eq('id', turmaId);
  }
}
