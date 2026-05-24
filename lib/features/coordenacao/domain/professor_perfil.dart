class TurmaSimples {
  final String id;
  final String nome;
  const TurmaSimples({required this.id, required this.nome});
}

class ProfessorPerfil {
  final String id;
  final String nome;
  final String role; // 'professor' | 'supervisor' | 'coordenacao' | 'diretor' | 'diretor-adjunto'
  final bool ativo;
  final List<TurmaSimples> turmas;

  const ProfessorPerfil({
    required this.id,
    required this.nome,
    required this.role,
    required this.ativo,
    required this.turmas,
  });

  String get cargoLabel => switch (role) {
        'coordenacao'     => 'Coordenação',
        'supervisor'      => 'Supervisor',
        'diretor'         => 'Diretor',
        'diretor-adjunto' => 'Dir. Adjunto',
        _                 => 'Professor',
      };

  ProfessorPerfil copyWith({bool? ativo, List<TurmaSimples>? turmas}) =>
      ProfessorPerfil(
        id:     id,
        nome:   nome,
        role:   role,
        ativo:  ativo ?? this.ativo,
        turmas: turmas ?? this.turmas,
      );
}
