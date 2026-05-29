import 'package:flutter_test/flutter_test.dart';
import 'package:foco_pedagogico/core/utils/saudacao_helper.dart';
import 'package:foco_pedagogico/features/auth/domain/usuario.dart';

void main() {
  group('SaudacaoHelper.saudacaoAtual', () {
    // Nota: depende de DateTime.now() — testa o intervalo, nao um momento exato.
    test('retorna uma das tres saudacoes validas', () {
      final saudacao = SaudacaoHelper.saudacaoAtual();
      expect(saudacao, isIn(['Bom dia', 'Boa tarde', 'Boa noite']));
    });
  });

  group('SaudacaoHelper.primeiroNome', () {
    test('extrai o primeiro nome de um nome completo', () {
      expect(SaudacaoHelper.primeiroNome('Samuel Heimbach'), 'Samuel');
      expect(SaudacaoHelper.primeiroNome('Maria da Silva'), 'Maria');
    });

    test('lida com nome unico', () {
      expect(SaudacaoHelper.primeiroNome('Samuel'), 'Samuel');
    });

    test('remove espacos em branco no inicio e fim', () {
      expect(SaudacaoHelper.primeiroNome('  Samuel Heimbach  '), 'Samuel');
    });
  });

  group('SaudacaoHelper.nomeFormatado', () {
    test('formata professor com prefixo Prof.', () {
      expect(
        SaudacaoHelper.nomeFormatado('Maria Silva', RoleUsuario.professor),
        'Prof. Maria',
      );
    });

    test('formata coordenacao com prefixo Coord.', () {
      expect(
        SaudacaoHelper.nomeFormatado('Joao Souza', RoleUsuario.coordenacao),
        'Coord. Joao',
      );
    });

    test('formata diretor com prefixo Dir.', () {
      expect(
        SaudacaoHelper.nomeFormatado('Ana Santos', RoleUsuario.diretor),
        'Dir. Ana',
      );
    });
  });
}
