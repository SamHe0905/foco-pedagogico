import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/curso_tecnico.dart';
import '../domain/demanda_anexo.dart';
import '../domain/demanda_resumo.dart';
import '../domain/professor_pendencias.dart';
import '../domain/professor_perfil.dart';
import '../domain/status_professor.dart';
import '../domain/turma.dart';
import '../services/coordenacao_service.dart';
import '../services/cursos_tecnicos_service.dart';

final coordenacaoDemandasProvider = FutureProvider<List<DemandaResumo>>((ref) {
  return CoordenacaoService.getDemandas();
});

final todasDemandasProvider = FutureProvider<List<DemandaResumo>>((ref) {
  return CoordenacaoService.getTodasDemandas();
});

final turmasProvider = FutureProvider<List<Turma>>((ref) {
  return CoordenacaoService.getTurmas();
});

final professoresProvider = FutureProvider<List<ProfessorItem>>((ref) {
  return CoordenacaoService.getProfessores();
});

final detalhesProfessoresProvider =
    FutureProvider.family<List<StatusProfessor>, String>((ref, demandaId) {
  return CoordenacaoService.getDetalhesProfessores(demandaId);
});

final professoresPerfisProvider = FutureProvider<List<ProfessorPerfil>>((ref) {
  return CoordenacaoService.getProfessoresPerfis();
});

final professoresPendentesProvider =
    FutureProvider<List<ProfessorComPendencias>>((ref) {
  return CoordenacaoService.getProfessoresPendentes();
});

final anexosProvider =
    FutureProvider.family<List<DemandaAnexo>, String>((ref, demandaId) {
  return CoordenacaoService.getAnexos(demandaId);
});

/// Categoria de demanda selecionada no dashboard (null = home com cards)
final categoriaDashboardProvider = StateProvider<String?>((ref) => null);

final cursosTecnicosProvider = FutureProvider<List<CursoTecnico>>((ref) {
  return CursosTecnicosService.getCursos();
});
