/// Professor com suas demandas ainda pendentes (status == 'pendente').
class ProfessorComPendencias {
  final String nome;

  /// Cada item é um label "Título da demanda · Turma" (ou só o título se geral).
  final List<String> demandas;

  const ProfessorComPendencias({
    required this.nome,
    required this.demandas,
  });
}
