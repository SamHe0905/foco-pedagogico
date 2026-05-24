import '../../demandas/domain/demanda.dart';

class DemandaResumo {
  final String id;
  final String titulo;
  final String descricao;
  final String turma;   // "Geral", "7ºA", "Individual", etc.
  final String tipo;    // "geral" | "turma" | "individual"
  final DateTime prazo;
  final PrioridadeDemanda prioridade;
  final int total;
  final int concluidas;
  final int pendentes;

  /// Nome do coordenador que criou — preenchido apenas em "Demandas Gerais".
  final String? criadoPorNome;

  const DemandaResumo({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.turma,
    required this.tipo,
    required this.prazo,
    required this.prioridade,
    required this.total,
    required this.concluidas,
    required this.pendentes,
    this.criadoPorNome,
  });

  double get progresso => total > 0 ? concluidas / total : 0.0;
  bool get todosConcluidam => total > 0 && concluidas == total;

  bool get atrasada {
    final hoje     = DateTime.now();
    final diaHoje  = DateTime(hoje.year, hoje.month, hoje.day);
    final diaPrazo = DateTime(prazo.year, prazo.month, prazo.day);
    return diaPrazo.isBefore(diaHoje) && !todosConcluidam;
  }

  int get diffDias {
    final hoje     = DateTime.now();
    final diaHoje  = DateTime(hoje.year, hoje.month, hoje.day);
    final diaPrazo = DateTime(prazo.year, prazo.month, prazo.day);
    return diaPrazo.difference(diaHoje).inDays;
  }

  String get prazoLabel => switch (diffDias) {
        _ when diffDias < 0 => 'Atrasada ${-diffDias}d',
        0                   => 'Hoje',
        1                   => 'Amanhã',
        _ when diffDias < 7 => 'Em ${diffDias}d',
        _ => '${prazo.day.toString().padLeft(2, '0')}/${prazo.month.toString().padLeft(2, '0')}',
      };

  factory DemandaResumo.fromMap(Map<String, dynamic> map) {
    final respostas  = map['demanda_professor'] as List;
    final concluidas = respostas.where((r) => r['status'] == 'concluida').length;
    final pendentes  = respostas.where((r) => r['status'] == 'pendente').length;

    // Preenchido apenas quando a query faz join com profiles (Demandas Gerais)
    final criador = map['criador'] as Map<String, dynamic>?;

    return DemandaResumo(
      id:        map['id']        as String,
      titulo:    map['titulo']    as String,
      descricao: map['descricao'] as String? ?? '',
      turma:     map['turma']     as String? ?? '',
      tipo:      map['tipo']      as String? ?? 'turma',
      prazo:     DateTime.parse(map['prazo'] as String),
      prioridade: switch (map['prioridade'] as String) {
        'alta'  => PrioridadeDemanda.alta,
        'baixa' => PrioridadeDemanda.baixa,
        _       => PrioridadeDemanda.media,
      },
      total:         respostas.length,
      concluidas:    concluidas,
      pendentes:     pendentes,
      criadoPorNome: criador?['nome'] as String?,
    );
  }
}
