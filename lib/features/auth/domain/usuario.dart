enum RoleUsuario {
  professor,
  coordenacao,
  supervisor,
  diretor,
  diretorAdjunto,
}

extension RoleUsuarioX on RoleUsuario {
  static RoleUsuario fromString(String value) => switch (value) {
        'coordenacao'     => RoleUsuario.coordenacao,
        'supervisor'      => RoleUsuario.supervisor,
        'diretor'         => RoleUsuario.diretor,
        'diretor-adjunto' => RoleUsuario.diretorAdjunto,
        _                 => RoleUsuario.professor,
      };

  /// Prefixo usado na saudação: "Prof. Samuel", "Coord. Samuel", etc.
  String get prefixo => switch (this) {
        RoleUsuario.professor     => 'Prof.',
        RoleUsuario.coordenacao   => 'Coord.',
        RoleUsuario.supervisor    => 'Sup.',
        RoleUsuario.diretor       => 'Dir.',
        RoleUsuario.diretorAdjunto => 'Dir. Adj.',
      };

  /// Rótulo exibido abaixo da saudação.
  String get cargo => switch (this) {
        RoleUsuario.professor     => 'Professor',
        RoleUsuario.coordenacao   => 'Coordenação Pedagógica',
        RoleUsuario.supervisor    => 'Supervisão Pedagógica',
        RoleUsuario.diretor       => 'Direção',
        RoleUsuario.diretorAdjunto => 'Direção Adjunta',
      };

  /// True para diretores (acesso total ao app).
  bool get isDirector =>
      this == RoleUsuario.diretor || this == RoleUsuario.diretorAdjunto;

  /// True para quem acessa o painel da coordenação.
  bool get isDashboard =>
      this == RoleUsuario.coordenacao ||
      this == RoleUsuario.supervisor   ||
      isDirector;
}

class Usuario {
  final String id;
  final String email;
  final String nome;
  final RoleUsuario role;

  const Usuario({
    required this.id,
    required this.email,
    required this.nome,
    required this.role,
  });
}
