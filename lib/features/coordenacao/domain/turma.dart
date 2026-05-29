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

// ─── Etapa de ensino ──────────────────────────────────────────────────────────

enum Etapa { fundamentalIntegral, fundamentalParcial, medioParcial }

extension EtapaX on Etapa {
  static Etapa? fromString(String? v) => switch (v) {
        'fundamental_integral' => Etapa.fundamentalIntegral,
        'fundamental_parcial'  => Etapa.fundamentalParcial,
        'medio_parcial'        => Etapa.medioParcial,
        _                      => null,
      };

  String get dbValue => switch (this) {
        Etapa.fundamentalIntegral => 'fundamental_integral',
        Etapa.fundamentalParcial  => 'fundamental_parcial',
        Etapa.medioParcial        => 'medio_parcial',
      };

  String get label => switch (this) {
        Etapa.fundamentalIntegral => 'Fund. Integral',
        Etapa.fundamentalParcial  => 'Fund. Parcial',
        Etapa.medioParcial        => 'Médio Parcial',
      };

  /// Turnos válidos para cada etapa
  List<Turno> get turnosValidos => switch (this) {
        Etapa.fundamentalIntegral => [Turno.integral],
        Etapa.fundamentalParcial  => [Turno.matutino, Turno.vespertino],
        Etapa.medioParcial        => [Turno.matutino, Turno.vespertino, Turno.noturno],
      };
}

// ─── Combinação etapa + turno (usada no vínculo coordenador ↔ etapa) ──────────

class EtapaTurno {
  final Etapa etapa;
  final Turno turno;

  const EtapaTurno({required this.etapa, required this.turno});

  String get label => '${etapa.label} — ${turno.label}';

  String get dbTurno => turno.dbValue;
  String get dbEtapa => etapa.dbValue;

  @override
  bool operator ==(Object other) =>
      other is EtapaTurno && other.etapa == etapa && other.turno == turno;

  @override
  int get hashCode => Object.hash(etapa, turno);

  /// Todas as combinações possíveis (exibidas no cadastro do coordenador)
  static List<EtapaTurno> get todas => [
        EtapaTurno(etapa: Etapa.fundamentalIntegral, turno: Turno.integral),
        EtapaTurno(etapa: Etapa.fundamentalParcial,  turno: Turno.matutino),
        EtapaTurno(etapa: Etapa.fundamentalParcial,  turno: Turno.vespertino),
        EtapaTurno(etapa: Etapa.medioParcial,        turno: Turno.matutino),
        EtapaTurno(etapa: Etapa.medioParcial,        turno: Turno.vespertino),
        EtapaTurno(etapa: Etapa.medioParcial,        turno: Turno.noturno),
      ];
}

// ─── Turma ────────────────────────────────────────────────────────────────────

class Turma {
  final String  id;
  final String  nome;
  final String  serie;
  final Turno   turno;
  final Etapa?  etapa;
  final String? cursoTecnicoId;
  final String? cursoTecnicoNome;

  const Turma({
    required this.id,
    required this.nome,
    required this.serie,
    required this.turno,
    this.etapa,
    this.cursoTecnicoId,
    this.cursoTecnicoNome,
  });

  /// Rótulo completo: "9A · Integral"
  String get nomeCompleto => '$nome · ${turno.label}';
}

class ProfessorItem {
  final String id;
  final String nome;

  const ProfessorItem({required this.id, required this.nome});
}
