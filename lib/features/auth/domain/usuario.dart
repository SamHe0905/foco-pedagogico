enum RoleUsuario {
  professor,
  coordenacao,
  supervisor,
  diretor,
  diretorAdjunto,
  /// Professor Coordenador de Suporte à Aprendizagem
  pcsa,
  /// Professor de Atendimento Educacional Especializado
  professorAee,
  /// Secretaria da escola — membro da gestão
  secretaria,
}

extension RoleUsuarioX on RoleUsuario {
  static RoleUsuario fromString(String value) => switch (value) {
        'coordenacao'     => RoleUsuario.coordenacao,
        'supervisor'      => RoleUsuario.supervisor,
        'diretor'         => RoleUsuario.diretor,
        'diretor-adjunto' => RoleUsuario.diretorAdjunto,
        'pcsa'            => RoleUsuario.pcsa,
        'professor_aee'   => RoleUsuario.professorAee,
        'secretaria'      => RoleUsuario.secretaria,
        _                 => RoleUsuario.professor,
      };

  String get dbValue => switch (this) {
        RoleUsuario.professor     => 'professor',
        RoleUsuario.coordenacao   => 'coordenacao',
        RoleUsuario.supervisor    => 'supervisor',
        RoleUsuario.diretor       => 'diretor',
        RoleUsuario.diretorAdjunto => 'diretor-adjunto',
        RoleUsuario.pcsa          => 'pcsa',
        RoleUsuario.professorAee  => 'professor_aee',
        RoleUsuario.secretaria    => 'secretaria',
      };

  /// Prefixo usado na saudação: "Prof. Samuel", "Coord. Samuel", etc.
  String get prefixo => switch (this) {
        RoleUsuario.professor     => 'Prof.',
        RoleUsuario.coordenacao   => 'Coord.',
        RoleUsuario.supervisor    => 'Sup.',
        RoleUsuario.diretor       => 'Dir.',
        RoleUsuario.diretorAdjunto => 'Dir. Adj.',
        RoleUsuario.pcsa          => 'PCSA',
        RoleUsuario.professorAee  => 'Prof. AEE',
        RoleUsuario.secretaria    => 'Sec.',
      };

  /// Rótulo exibido abaixo da saudação.
  String get cargo => switch (this) {
        RoleUsuario.professor     => 'Professor',
        RoleUsuario.coordenacao   => 'Coordenação Pedagógica',
        RoleUsuario.supervisor    => 'Supervisão Pedagógica',
        RoleUsuario.diretor       => 'Direção',
        RoleUsuario.diretorAdjunto => 'Direção Adjunta',
        RoleUsuario.pcsa          => 'Prof. Coord. de Suporte à Aprendizagem',
        RoleUsuario.professorAee  => 'Educação Especial (AEE)',
        RoleUsuario.secretaria    => 'Secretaria',
      };

  /// True para diretores e secretaria (gestão — acesso total ao app).
  bool get isDirector =>
      this == RoleUsuario.diretor ||
      this == RoleUsuario.diretorAdjunto ||
      this == RoleUsuario.secretaria;

  /// True para quem acessa o painel da coordenação.
  bool get isDashboard =>
      this == RoleUsuario.coordenacao ||
      this == RoleUsuario.supervisor   ||
      this == RoleUsuario.pcsa         ||
      isDirector;

  /// True para quem tem acesso a demandas de todos os turnos.
  bool get verTodosOsTurnos =>
      isDashboard || this == RoleUsuario.professorAee;
}

class Usuario {
  final String id;
  final String email;
  final String nome;
  final RoleUsuario role;

  /// Cargo secundário para usuários com duplo acesso
  /// (ex: coordenador em um turno, professor em outro).
  final RoleUsuario? roleSecundario;

  const Usuario({
    required this.id,
    required this.email,
    required this.nome,
    required this.role,
    this.roleSecundario,
  });

  /// True se este usuário tem acesso duplo (professor + coordenação ou vice-versa).
  bool get temDuploAcesso => roleSecundario != null;
}
