import 'package:flutter_test/flutter_test.dart';
import 'package:foco_pedagogico/features/coordenacao/domain/turma.dart';

void main() {
  group('TurnoX.fromString', () {
    test('reconhece os 4 turnos', () {
      expect(TurnoX.fromString('matutino'),   Turno.matutino);
      expect(TurnoX.fromString('vespertino'), Turno.vespertino);
      expect(TurnoX.fromString('integral'),   Turno.integral);
      expect(TurnoX.fromString('noturno'),    Turno.noturno);
    });

    test('valor desconhecido cai em matutino', () {
      expect(TurnoX.fromString('xyz'), Turno.matutino);
      expect(TurnoX.fromString(''),    Turno.matutino);
    });
  });

  group('TurnoX roundtrip', () {
    test('fromString -> dbValue preserva o valor', () {
      const valores = ['matutino', 'vespertino', 'integral', 'noturno'];
      for (final v in valores) {
        expect(TurnoX.fromString(v).dbValue, v);
      }
    });
  });

  group('TurnoX.label', () {
    test('cada turno tem label distinto e legivel', () {
      expect(Turno.matutino.label,   'Matutino');
      expect(Turno.vespertino.label, 'Vespertino');
      expect(Turno.integral.label,   'Integral');
      expect(Turno.noturno.label,    'Noturno');
    });
  });

  group('EtapaX.fromString', () {
    test('reconhece as 3 etapas', () {
      expect(EtapaX.fromString('fundamental_integral'), Etapa.fundamentalIntegral);
      expect(EtapaX.fromString('fundamental_parcial'),  Etapa.fundamentalParcial);
      expect(EtapaX.fromString('medio_parcial'),        Etapa.medioParcial);
    });

    test('valor nulo ou desconhecido retorna null', () {
      expect(EtapaX.fromString(null),     isNull);
      expect(EtapaX.fromString('xyz'),    isNull);
      expect(EtapaX.fromString(''),       isNull);
    });
  });

  group('EtapaX.turnosValidos', () {
    test('fundamental integral so aceita integral', () {
      expect(Etapa.fundamentalIntegral.turnosValidos, [Turno.integral]);
    });

    test('fundamental parcial aceita matutino e vespertino', () {
      expect(
        Etapa.fundamentalParcial.turnosValidos,
        [Turno.matutino, Turno.vespertino],
      );
    });

    test('medio parcial aceita matutino, vespertino e noturno', () {
      expect(
        Etapa.medioParcial.turnosValidos,
        [Turno.matutino, Turno.vespertino, Turno.noturno],
      );
    });
  });

  group('EtapaTurno', () {
    test('label combina etapa e turno', () {
      const et = EtapaTurno(
        etapa: Etapa.medioParcial,
        turno: Turno.vespertino,
      );
      expect(et.label, 'Médio Parcial — Vespertino');
    });

    test('igualdade baseada em etapa + turno', () {
      const a = EtapaTurno(etapa: Etapa.fundamentalParcial, turno: Turno.matutino);
      const b = EtapaTurno(etapa: Etapa.fundamentalParcial, turno: Turno.matutino);
      const c = EtapaTurno(etapa: Etapa.fundamentalParcial, turno: Turno.vespertino);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('dbValues estao corretos', () {
      const et = EtapaTurno(etapa: Etapa.medioParcial, turno: Turno.noturno);
      expect(et.dbEtapa, 'medio_parcial');
      expect(et.dbTurno, 'noturno');
    });
  });
}
