import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/demanda.dart';
import '../services/demandas_service.dart';

final demandasProvider = FutureProvider<List<Demanda>>((ref) {
  return DemandasService.getDemandas();
});

final filtroProvider = StateProvider<StatusDemanda?>((ref) => null);

/// Filtra as demandas do professor por turno (null = todos os turnos)
final filtroTurnoProvider = StateProvider<String?>((ref) => null);

/// Turnos do professor logado (derivados das suas turmas)
final turnosProfessorProvider = FutureProvider<List<String>>((ref) {
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) return Future.value([]);
  return DemandasService.getTurnosDoProfessor();
});

/// Conta quantas demandas estão pendentes para o usuário logado.
/// Usado para exibir o badge no ícone de "Minhas demandas recebidas" no dashboard.
final demandasPendentesCountProvider = FutureProvider<int>((ref) {
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) return Future.value(0);
  return DemandasService.getContadorPendentes();
});

/// Stream de mensagens FCM com o app em foreground.
/// Usado pela DemandasListScreen para atualizar a lista automaticamente.
final fcmForegroundProvider = StreamProvider<RemoteMessage>((ref) {
  return FirebaseMessaging.onMessage;
});
