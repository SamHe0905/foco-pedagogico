import 'package:flutter_test/flutter_test.dart';
import 'package:foco_pedagogico/features/solicitacoes/domain/solicitacao.dart';

void main() {
  group('StatusSolicitacaoX.fromString', () {
    test('reconhece os 3 status', () {
      expect(StatusSolicitacaoX.fromString('pendente'),
          StatusSolicitacao.pendente);
      expect(StatusSolicitacaoX.fromString('em_andamento'),
          StatusSolicitacao.emAndamento);
      expect(StatusSolicitacaoX.fromString('resolvida'),
          StatusSolicitacao.resolvida);
    });

    test('valor desconhecido cai em pendente', () {
      expect(StatusSolicitacaoX.fromString('xyz'),
          StatusSolicitacao.pendente);
      expect(StatusSolicitacaoX.fromString(''),
          StatusSolicitacao.pendente);
    });
  });

  group('StatusSolicitacaoX roundtrip', () {
    test('fromString -> dbValue preserva o valor', () {
      const valores = ['pendente', 'em_andamento', 'resolvida'];
      for (final v in valores) {
        expect(StatusSolicitacaoX.fromString(v).dbValue, v);
      }
    });
  });

  group('StatusSolicitacaoX.label', () {
    test('cada status tem label legivel', () {
      expect(StatusSolicitacao.pendente.label,    'Pendente');
      expect(StatusSolicitacao.emAndamento.label, 'Em andamento');
      expect(StatusSolicitacao.resolvida.label,   'Resolvida');
    });
  });
}
