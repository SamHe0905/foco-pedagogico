enum StatusDemanda { pendente, visualizada, concluida }

enum PrioridadeDemanda { alta, media, baixa }

class Demanda {
  final String id;
  final String titulo;
  final String descricao;
  final String turma;
  final DateTime prazo;
  final StatusDemanda status;
  final PrioridadeDemanda prioridade;
  final DateTime criadaEm;

  const Demanda({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.turma,
    required this.prazo,
    required this.status,
    required this.prioridade,
    required this.criadaEm,
  });

  // Mapeia uma linha de demanda_professor com demandas embutido
  factory Demanda.fromSupabaseRow(Map<String, dynamic> row) {
    final d = row['demandas'] as Map<String, dynamic>;
    return Demanda(
      id: d['id'] as String,
      titulo: d['titulo'] as String,
      descricao: d['descricao'] as String? ?? '',
      turma: d['turma'] as String,
      prazo: DateTime.parse(d['prazo'] as String),
      prioridade: switch (d['prioridade'] as String) {
        'alta'  => PrioridadeDemanda.alta,
        'baixa' => PrioridadeDemanda.baixa,
        _       => PrioridadeDemanda.media,
      },
      status: switch (row['status'] as String) {
        'visualizada' => StatusDemanda.visualizada,
        'concluida'   => StatusDemanda.concluida,
        _             => StatusDemanda.pendente,
      },
      criadaEm: DateTime.parse(d['criada_em'] as String),
    );
  }

  Demanda copyWith({StatusDemanda? status}) {
    return Demanda(
      id: id,
      titulo: titulo,
      descricao: descricao,
      turma: turma,
      prazo: prazo,
      status: status ?? this.status,
      prioridade: prioridade,
      criadaEm: criadaEm,
    );
  }

  bool get atrasada =>
      prazo.isBefore(DateTime.now()) && status != StatusDemanda.concluida;

  String get prazoLabel {
    final hoje = DateTime.now();
    final diaHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final diaPrazo = DateTime(prazo.year, prazo.month, prazo.day);
    final diff = diaPrazo.difference(diaHoje).inDays;

    if (diff < 0) return 'Atrasada ${-diff}d';
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    if (diff < 7) return 'Em ${diff}d';
    return '${prazo.day.toString().padLeft(2, '0')}/${prazo.month.toString().padLeft(2, '0')}';
  }
}
