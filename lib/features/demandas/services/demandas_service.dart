import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/demanda.dart';

class DemandasService {
  static final _db = Supabase.instance.client;
  static final _auth = Supabase.instance.client.auth;

  static String get _userId => _auth.currentUser!.id;

  static const _select =
      'status, demandas(id, titulo, descricao, turma, tipo, turno, prazo, prioridade, criada_em, criada_por)';

  // ── Lista todas as demandas do professor logado ───────────────────────────

  static Future<List<Demanda>> getDemandas() async {
    final data = await _db
        .from('demanda_professor')
        .select(_select)
        .eq('professor_id', _userId);

    final rows = data as List;

    // Coleta IDs únicos dos criadores para buscar seus roles (badge "Da Gestão")
    final creatorIds = rows
        .map((r) => ((r as Map)['demandas'] as Map)['criada_por'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    // Busca roles dos criadores em lote (silenciosamente ignora erros de permissão)
    final roleMap = <String, String>{};
    if (creatorIds.isNotEmpty) {
      try {
        final perfis = await _db
            .from('profiles')
            .select('id, role')
            .inFilter('id', creatorIds);
        for (final p in perfis as List) {
          roleMap[p['id'] as String] = p['role'] as String;
        }
      } catch (_) {
        // Sem permissão para ler roles: badge não será exibido
      }
    }

    // Injeta criada_por_role em cada linha antes de parsear
    final demandas = rows.map((row) {
      final map        = Map<String, dynamic>.from(row as Map);
      final demandaMap = Map<String, dynamic>.from(map['demandas'] as Map);
      final criadoPor  = demandaMap['criada_por'] as String?;
      if (criadoPor != null && roleMap.containsKey(criadoPor)) {
        demandaMap['criada_por_role'] = roleMap[criadoPor];
      }
      map['demandas'] = demandaMap;
      return Demanda.fromSupabaseRow(map);
    }).toList();

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
