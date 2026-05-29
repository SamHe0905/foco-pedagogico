class StatusProfessor {
  final String nome;
  final String status; // 'pendente' | 'visualizada' | 'concluida'
  final String? observacao;

  const StatusProfessor({
    required this.nome,
    required this.status,
    this.observacao,
  });
}
