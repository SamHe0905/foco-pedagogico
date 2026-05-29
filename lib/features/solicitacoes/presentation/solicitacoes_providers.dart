import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/solicitacao.dart';
import '../services/solicitacoes_service.dart';

final minhasSolicitacoesProvider = FutureProvider<List<Solicitacao>>((ref) {
  return SolicitacoesService.getMinhaSolicitacoes();
});

final solicitacoesRecebidasProvider = FutureProvider<List<Solicitacao>>((ref) {
  return SolicitacoesService.getSolicitacoesRecebidas();
});

/// Quantidade de solicitações pendentes recebidas (para badge no AppBar).
final solicitacoesPendentesCountProvider = FutureProvider<int>((ref) {
  return SolicitacoesService.countSolicitacoesPendentes();
});
