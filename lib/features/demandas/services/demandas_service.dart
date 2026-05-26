import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/demanda.dart';

class DemandasService {
  static final _db = Supabase.instance.client;
  static final _auth = Supabase.instance.client.auth;

  static String get _userId => _auth.currentUser!.id;

  static const _select =
      'status, demandas(id, titulo, descricao, turma, tipo, turno, prazo, prioridade, criada_em)';

  /// Retorna os turnos distintos das turmas deste professor.
  static Future<List<String>> getTurnosDoProfessor() async {
    final data = await _db
        .from('professor_turmas')
        .select('turmas(turno)')
        .eq('professor_id', _userId);

    final turnos = <String>{};
    for (final row in data as List) {
      final t = (row['turmas'] as Map<String, dynamic>?)?['turno'] as String?;
      if (t != null) turnos.add(t);
    }
    return turnos.toList();
  }

  // ── Lista todas as demandas do professor logado ───────────────────────────

  static Future<List<Demanda>> getDemandas() async {
    final data = await _db
        .from('demanda_professor')
        .select(_select)
        .eq('professor_id', _userId);

    final demandas = (data as List)
        .map((row) => Demanda.fromSupabaseRow(row as Map<String, dynamic>))
        .toList();

    return _sorted(demandas);
  }

  // ── Busca demanda por ID (usado como fallback no detalhe) ─────────────────

  static Future<Demanda?> getDemandaById(String id) async {
    try {
      final data = await _db
          .from('demanda_professor')
          .select(_select)
          .eq('professor_id', _userId)
          .eq('demanda_id', id)
          .single();

      return Demanda.fromSupabaseRow(data);
    } catch (_) {
      return null;
    }
  }

  // ── Atualiza status da demanda para o professor logado ────────────────────

  static Future<void> atualizarStatus(String id, StatusDemanda novoStatus) async {
    await _db
        .from('demanda_professor')
        .update({
          'status': novoStatus.name,
          'atualizado_em': DateTime.now().toIso8601String(),
        })
        .eq('demanda_id', id)
        .eq('professor_id', _userId);
  }

  // ── Conta demandas pendentes (para badge no ícone da gestão) ─────────────

  static Future<int> getContadorPendentes() async {
    final data = await _db
        .from('demanda_professor')
        .select('status')
        .eq('professor_id', _userId)
        .eq('status', 'pendente');

    return (data as List).length;
  }

  // ── Ordenação: prioridade alta → média → baixa, depois prazo ─────────────

  static List<Demanda> _sorted(List<Demanda> lista) {
    const ordem = {
      PrioridadeDemanda.alta: 0,
      PrioridadeDemanda.media: 1,
      PrioridadeDemanda.baixa: 2,
    };
    final copy = [...lista];
    copy.sort((a, b) {
      final p = ordem[a.prioridade]!.compareTo(ordem[b.prioridade]!);
      if (p != 0) return p;
      return a.prazo.compareTo(b.prazo);
    });
    return copy;
  }
}
