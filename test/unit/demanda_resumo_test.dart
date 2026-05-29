import 'package:flutter_test/flutter_test.dart';
import 'package:foco_pedagogico/features/coordenacao/domain/demanda_resumo.dart';
import 'package:foco_pedagogico/features/demandas/domain/demanda.dart';

DemandaResumo _build({
  String id = 'd1',
  DateTime? prazo,
  int total = 3,
  int concluidas = 0,
  int pendentes = 3,
  PrioridadeDemanda prioridade = PrioridadeDemanda.media,
}) {
  return DemandaResumo(
    id: id,
    titulo: 'Teste',
    descricao: 'Desc',
    turma: '7A',
    tipo: 'turma',
    prazo: prazo ?? DateTime.now().add(const Duration(days: 5)),
    prioridade: prioridade,
    total: total,
    concluidas: concluidas,
    pendentes: pendentes,
  );
}

void main() {
  group('DemandaResumo.progresso', () {
    test('zero quando total = 0', () {
      expect(_build(total: 0, concluidas: 0).progresso, 0.0);
    });

    test('proporcao concluidas/total', () {
      expect(_build(total: 4, concluidas: 1).progresso, 0.25);
      expect(_build(total: 4, concluidas: 2).progresso, 0.5);
      expect(_build(total: 4, concluidas: 4).progresso, 1.0);
    });
  });

  group('DemandaResumo.todosConcluidam', () {
    test('true apenas quando total > 0 E concluidas == total', () {
      expect(_build(total: 3, concluidas: 3).todosConcluidam, isTrue);
      expect(_build(total: 3, concluidas: 2).todosConcluidam, isFalse);
      expect(_build(total: 0, concluidas: 0).todosConcluidam, isFalse);
    });
  });

  group('DemandaResumo.atrasada', () {
    test('true quando prazo eh anterior a hoje e nem todos concluiram', () {
      final ontem = DateTime.now().subtract(const Duration(days: 1));
      expect(_build(prazo: ontem, concluidas: 0).atrasada, isTrue);
    });

    test('false quando todos concluiram, mesmo com prazo passado', () {
      final ontem = DateTime.now().subtract(const Duration(days: 1));
      expect(_build(prazo: ontem, total: 3, concluidas: 3).atrasada, isFalse);
    });

    test('false quando prazo eh hoje (nao conta como atrasada)', () {
      final hoje = DateTime.now();
      expect(_build(prazo: hoje).atrasada, isFalse);
    });

    test('false quando prazo eh futuro', () {
      final amanha = DateTime.now().add(const Duration(days: 1));
      expect(_build(prazo: amanha).atrasada, isFalse);
    });
  });

  group('DemandaResumo.diffDias', () {
    test('0 para hoje', () {
      expect(_build(prazo: DateTime.now()).diffDias, 0);
    });

    test('positivo para datas futuras', () {
      final em5 = DateTime.now().add(const Duration(days: 5));
      expect(_build(prazo: em5).diffDias, 5);
    });

    test('negativo para datas passadas', () {
      final ha2 = DateTime.now().subtract(const Duration(days: 2));
      expect(_build(prazo: ha2).diffDias, -2);
    });
  });

  group('DemandaResumo.prazoLabel', () {
    test('"Atrasada Nd" para prazos passados', () {
      final ha3 = DateTime.now().subtract(const Duration(days: 3));
      expect(_build(prazo: ha3).prazoLabel, 'Atrasada 3d');
    });

    test('"Hoje" para prazo de hoje', () {
      expect(_build(prazo: DateTime.now()).prazoLabel, 'Hoje');
    });

    test('"Amanha" para prazo de amanha', () {
      final amanha = DateTime.now().add(const Duration(days: 1));
      expect(_build(prazo: amanha).prazoLabel, 'Amanhã');
    });

    test('"Em Nd" para prazos dentro de uma semana', () {
      final em3 = DateTime.now().add(const Duration(days: 3));
      expect(_build(prazo: em3).prazoLabel, 'Em 3d');
    });

    test('data formatada dd/MM para prazos alem de uma semana', () {
      // Usa data fixa pra teste deterministico
      final futuro = DateTime(2030, 3, 15);
      final demanda = _build(prazo: futuro);
      expect(demanda.prazoLabel, '15/03');
    });
  });

  group('DemandaResumo.fromMap', () {
    test('mapeia campos basicos corretamente', () {
      final demanda = DemandaResumo.fromMap({
        'id': 'abc',
        'titulo': 'Entregar plano',
        'descricao': 'Detalhes...',
        'turma': '8B',
        'tipo': 'turma',
        'prazo': '2030-01-15',
        'prioridade': 'alta',
        'demanda_professor': [
          {'status': 'concluida'},
          {'status': 'pendente'},
          {'status': 'pendente'},
        ],
      });

      expect(demanda.id, 'abc');
      expect(demanda.titulo, 'Entregar plano');
      expect(demanda.turma, '8B');
      expect(demanda.tipo, 'turma');
      expect(demanda.prioridade, PrioridadeDemanda.alta);
      expect(demanda.total, 3);
      expect(demanda.concluidas, 1);
      expect(demanda.pendentes, 2);
    });

    test('prioridade desconhecida cai em media', () {
      final demanda = DemandaResumo.fromMap({
        'id': 'x', 'titulo': 't', 'turma': '', 'tipo': 'geral',
        'prazo': '2030-01-01', 'prioridade': 'invalida',
        'demanda_professor': [],
      });
      expect(demanda.prioridade, PrioridadeDemanda.media);
    });

    test('descricao e turma nulas viram string vazia', () {
      final demanda = DemandaResumo.fromMap({
        'id': 'x', 'titulo': 't', 'tipo': 'geral',
        'prazo': '2030-01-01', 'prioridade': 'media',
        'demanda_professor': [],
      });
      expect(demanda.descricao, '');
      expect(demanda.turma, '');
    });

    test('criador presente preenche criadoPorNome', () {
      final demanda = DemandaResumo.fromMap({
        'id': 'x', 'titulo': 't', 'tipo': 'geral',
        'prazo': '2030-01-01', 'prioridade': 'media',
        'demanda_professor': [],
        'criador': {'nome': 'Maria'},
      });
      expect(demanda.criadoPorNome, 'Maria');
    });

    test('criador ausente deixa criadoPorNome nulo', () {
      final demanda = DemandaResumo.fromMap({
        'id': 'x', 'titulo': 't', 'tipo': 'geral',
        'prazo': '2030-01-01', 'prioridade': 'media',
        'demanda_professor': [],
      });
      expect(demanda.criadoPorNome, isNull);
    });
  });
}
