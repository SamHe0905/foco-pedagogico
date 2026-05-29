import 'package:flutter_test/flutter_test.dart';
import 'package:foco_pedagogico/features/demandas/domain/demanda.dart';

void main() {
  Map<String, dynamic> _row({
    String tipo = 'turma',
    String status = 'pendente',
    String prioridade = 'media',
    String? criadoPorRole,
    String? observacao,
  }) {
    return {
      'status': status,
      'observacao': observacao,
      'demandas': {
        'id': 'd1',
        'titulo': 'Plano semanal',
        'descricao': 'Detalhes',
        'turma': '7A',
        'tipo': tipo,
        'turno': 'matutino',
        'prazo': '2030-06-15',
        'prioridade': prioridade,
        'criada_em': '2030-06-01T10:00:00Z',
        'criada_por_role': criadoPorRole,
      },
    };
  }

  group('Demanda.fromSupabaseRow - mapeamento de tipo', () {
    test('reconhece todos os tipos validos', () {
      expect(Demanda.fromSupabaseRow(_row(tipo: 'individual')).tipo,
          TipoDemanda.individual);
      expect(Demanda.fromSupabaseRow(_row(tipo: 'turma')).tipo,
          TipoDemanda.turma);
      expect(Demanda.fromSupabaseRow(_row(tipo: 'coordenacao')).tipo,
          TipoDemanda.coordenacao);
      expect(Demanda.fromSupabaseRow(_row(tipo: 'gestao')).tipo,
          TipoDemanda.gestao);
      expect(Demanda.fromSupabaseRow(_row(tipo: 'geral')).tipo,
          TipoDemanda.geral);
    });

    test('tipo desconhecido cai em geral', () {
      expect(Demanda.fromSupabaseRow(_row(tipo: 'xyz')).tipo,
          TipoDemanda.geral);
    });
  });

  group('Demanda.fromSupabaseRow - mapeamento de status', () {
    test('reconhece os tres status', () {
      expect(Demanda.fromSupabaseRow(_row(status: 'pendente')).status,
          StatusDemanda.pendente);
      expect(Demanda.fromSupabaseRow(_row(status: 'visualizada')).status,
          StatusDemanda.visualizada);
      expect(Demanda.fromSupabaseRow(_row(status: 'concluida')).status,
          StatusDemanda.concluida);
    });

    test('status desconhecido cai em pendente', () {
      expect(Demanda.fromSupabaseRow(_row(status: 'invalido')).status,
          StatusDemanda.pendente);
    });
  });

  group('Demanda.fromSupabaseRow - mapeamento de prioridade', () {
    test('reconhece alta, media e baixa', () {
      expect(Demanda.fromSupabaseRow(_row(prioridade: 'alta')).prioridade,
          PrioridadeDemanda.alta);
      expect(Demanda.fromSupabaseRow(_row(prioridade: 'media')).prioridade,
          PrioridadeDemanda.media);
      expect(Demanda.fromSupabaseRow(_row(prioridade: 'baixa')).prioridade,
          PrioridadeDemanda.baixa);
    });

    test('prioridade desconhecida cai em media', () {
      expect(Demanda.fromSupabaseRow(_row(prioridade: 'xx')).prioridade,
          PrioridadeDemanda.media);
    });
  });

  group('Demanda.fromSupabaseRow - campos opcionais', () {
    test('criadoPorRole eh preenchido quando presente', () {
      final demanda = Demanda.fromSupabaseRow(_row(criadoPorRole: 'diretor'));
      expect(demanda.criadoPorRole, 'diretor');
    });

    test('criadoPorRole nulo quando ausente', () {
      final demanda = Demanda.fromSupabaseRow(_row(criadoPorRole: null));
      expect(demanda.criadoPorRole, isNull);
    });

    test('observacao eh preenchida quando presente', () {
      final demanda = Demanda.fromSupabaseRow(_row(observacao: 'Feito.'));
      expect(demanda.observacao, 'Feito.');
    });
  });
}
