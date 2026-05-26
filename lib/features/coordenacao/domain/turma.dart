enum Turno { matutino, vespertino, integral, noturno }

extension TurnoX on Turno {
  static Turno fromString(String v) => switch (v) {
        'vespertino' => Turno.vespertino,
        'integral'   => Turno.integral,
        'noturno'    => Turno.noturno,
        _            => Turno.matutino,
      };

  String get dbValue => switch (this) {
        Turno.matutino   => 'matutino',
        Turno.vespertino => 'vespertino',
        Turno.integral   => 'integral',
        Turno.noturno    => 'noturno',
      };

  String get label => switch (this) {
        Turno.matutino   => 'Matutino',
        Turno.vespertino => 'Vespertino',
        Turno.integral   => 'Integral',
        Turno.noturno    => 'Noturno',
      };
}

class Turma {
  final String id;
  final String nome;
  final String serie;
  final Turno  turno;

  const Turma({
    required this.id,
    required this.nome,
    required this.serie,
    required this.turno,
  });

  /// Rótulo completo: "9A · Integral"
  String get nomeCompleto => '$nome · ${turno.label}';
}

class ProfessorItem {
  final String id;
  final String nome;

  const ProfessorItem({required this.id, required this.nome});
}
