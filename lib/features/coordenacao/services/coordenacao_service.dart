// Barrel: este arquivo foi dividido em services focados por responsabilidade.
// Mantido como ponto de import único — re-exporta os novos services para não
// quebrar imports existentes. Use a classe específica em cada chamada:
//   - DemandasCoordenacaoService  (demandas, pendências, detalhes, notificações)
//   - TurmasService               (CRUD de turmas)
//   - EquipeService               (professores, cargos, status, vínculo de turmas)
//   - ConvitesService             (integrar/excluir usuários)
//   - AnexosService               (anexos das demandas)
export 'demandas_coordenacao_service.dart';
export 'turmas_service.dart';
export 'equipe_service.dart';
export 'convites_service.dart';
export 'anexos_service.dart';
