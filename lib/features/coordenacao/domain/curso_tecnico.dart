class CursoTecnico {
  final String id;
  final String nome;
  final bool   ativo;

  const CursoTecnico({
    required this.id,
    required this.nome,
    this.ativo = true,
  });

  factory CursoTecnico.fromMap(Map<String, dynamic> m) => CursoTecnico(
        id:    m['id']    as String,
        nome:  m['nome']  as String,
        ativo: m['ativo'] as bool? ?? true,
      );
}
