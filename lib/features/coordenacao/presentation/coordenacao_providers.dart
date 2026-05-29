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
  return DemandasCoordenacaoService.getDemandas();
});

final todasDemandasProvider = FutureProvider<List<DemandaResumo>>((ref) {
  return DemandasCoordenacaoService.getTodasDemandas();
});

final turmasProvider = FutureProvider<List<Turma>>((ref) {
  return TurmasService.getTurmas();
});

final professoresProvider = FutureProvider<List<ProfessorItem>>((ref) {
  return EquipeService.getProfessores();
});

final detalhesProfessoresProvider =
    FutureProvider.family<List<StatusProfessor>, String>((ref, demandaId) {
  return DemandasCoordenacaoService.getDetalhesProfessores(demandaId);
});

final professoresPerfisProvider = FutureProvider<List<ProfessorPerfil>>((ref) {
  return EquipeService.getProfessoresPerfis();
});

final professoresPendentesProvider =
    FutureProvider<List<ProfessorComPendencias>>((ref) {
  return DemandasCoordenacaoService.getProfessoresPendentes();
});

final anexosProvider =
    FutureProvider.family<List<DemandaAnexo>, String>((ref, demandaId) {
  return AnexosService.getAnexos(demandaId);
});

/// Categoria de demanda selecionada no dashboard (null = home com cards)
final categoriaDashboardProvider = StateProvider<String?>((ref) => null);

final cursosTecnicosProvider = FutureProvider<List<CursoTecnico>>((ref) {
  return CursosTecnicosService.getCursos();
});
