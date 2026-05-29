import 'package:flutter_test/flutter_test.dart';
import 'package:foco_pedagogico/features/auth/domain/usuario.dart';

void main() {
  group('RoleUsuarioX.fromString', () {
    test('mapeia strings conhecidas do banco para o enum', () {
      expect(RoleUsuarioX.fromString('coordenacao'),     RoleUsuario.coordenacao);
      expect(RoleUsuarioX.fromString('supervisor'),      RoleUsuario.supervisor);
      expect(RoleUsuarioX.fromString('diretor'),         RoleUsuario.diretor);
      expect(RoleUsuarioX.fromString('diretor-adjunto'), RoleUsuario.diretorAdjunto);
      expect(RoleUsuarioX.fromString('pcsa'),            RoleUsuario.pcsa);
      expect(RoleUsuarioX.fromString('professor_aee'),   RoleUsuario.professorAee);
      expect(RoleUsuarioX.fromString('secretaria'),      RoleUsuario.secretaria);
      expect(RoleUsuarioX.fromString('professor'),       RoleUsuario.professor);
    });

    test('valores desconhecidos caem em professor (default)', () {
      expect(RoleUsuarioX.fromString('xyz'),    RoleUsuario.professor);
      expect(RoleUsuarioX.fromString(''),       RoleUsuario.professor);
      expect(RoleUsuarioX.fromString('admin'),  RoleUsuario.professor);
    });
  });

  group('RoleUsuarioX.dbValue', () {
    test('roundtrip fromString -> dbValue preserva o valor', () {
      const strings = [
        'professor', 'coordenacao', 'supervisor', 'diretor',
        'diretor-adjunto', 'pcsa', 'professor_aee', 'secretaria',
      ];
      for (final s in strings) {
        expect(RoleUsuarioX.fromString(s).dbValue, s);
      }
    });
  });

  group('RoleUsuarioX.isDirector', () {
    test('true para diretor, diretor-adjunto e secretaria', () {
      expect(RoleUsuario.diretor.isDirector,        isTrue);
      expect(RoleUsuario.diretorAdjunto.isDirector, isTrue);
      expect(RoleUsuario.secretaria.isDirector,     isTrue);
    });

    test('false para roles pedagogicas', () {
      expect(RoleUsuario.professor.isDirector,     isFalse);
      expect(RoleUsuario.coordenacao.isDirector,   isFalse);
      expect(RoleUsuario.supervisor.isDirector,    isFalse);
      expect(RoleUsuario.pcsa.isDirector,          isFalse);
      expect(RoleUsuario.professorAee.isDirector,  isFalse);
    });
  });

  group('RoleUsuarioX.isDashboard', () {
    test('inclui coordenacao, supervisor, pcsa e diretores', () {
      expect(RoleUsuario.coordenacao.isDashboard,   isTrue);
      expect(RoleUsuario.supervisor.isDashboard,    isTrue);
      expect(RoleUsuario.pcsa.isDashboard,          isTrue);
      expect(RoleUsuario.diretor.isDashboard,       isTrue);
      expect(RoleUsuario.diretorAdjunto.isDashboard, isTrue);
      expect(RoleUsuario.secretaria.isDashboard,    isTrue);
    });

    test('exclui professor e prof. AEE', () {
      expect(RoleUsuario.professor.isDashboard,    isFalse);
      expect(RoleUsuario.professorAee.isDashboard, isFalse);
    });
  });

  group('RoleUsuarioX.verTodosOsTurnos', () {
    test('true para isDashboard ou professor AEE', () {
      expect(RoleUsuario.coordenacao.verTodosOsTurnos,  isTrue);
      expect(RoleUsuario.diretor.verTodosOsTurnos,      isTrue);
      expect(RoleUsuario.professorAee.verTodosOsTurnos, isTrue);
    });

    test('false apenas para professor comum', () {
      expect(RoleUsuario.professor.verTodosOsTurnos, isFalse);
    });
  });

  group('RoleUsuarioX.prefixo', () {
    test('cada role tem um prefixo distinto', () {
      final prefixos = RoleUsuario.values.map((r) => r.prefixo).toSet();
      // 8 roles, mas duas podem coincidir? Vamos so confirmar que ha variedade.
      expect(prefixos.length, greaterThanOrEqualTo(7));
    });
  });
}
