import 'turma.dart';

class TurmaSimples {
  final String id;
  final String nome;
  final Turno  turno;
  const TurmaSimples({required this.id, required this.nome, required this.turno});

  String get nomeCompleto => '$nome · ${turno.label}';
}

class ProfessorPerfil {
  final String id;
  final String nome;
  final String role;
  final String? roleSecundario;
  final bool ativo;
  final List<TurmaSimples> turmas;

  const ProfessorPerfil({
    required this.id,
    required this.nome,
    required this.role,
    this.roleSecundario,
    required this.ativo,
    required this.turmas,
  });

  String get cargoLabel => switch (role) {
        'coordenacao'     => 'Coordenação',
        'supervisor'      => 'Supervisor',
        'diretor'         => 'Diretor',
        'diretor-adjunto' => 'Dir. Adjunto',
        'pcsa'            => 'PCSA',
        'professor_aee'   => 'Prof. AEE',
        _                 => 'Professor',
      };

  /// Turnos únicos desta pessoa (derivados das turmas)
  List<Turno> get turnos =>
      turmas.map((t) => t.turno).toSet().toList();

  ProfessorPerfil copyWith({
    bool? ativo,
    List<TurmaSimples>? turmas,
    String? roleSecundario,
  }) =>
      ProfessorPerfil(
        id:             id,
        nome:           nome,
        role:           role,
        roleSecundario: roleSecundario ?? this.roleSecundario,
        ativo:          ativo ?? this.ativo,
        turmas:         turmas ?? this.turmas,
      );
}
