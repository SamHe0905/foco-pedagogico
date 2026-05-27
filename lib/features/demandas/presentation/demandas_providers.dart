import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/demanda.dart';
import '../services/demandas_service.dart';

final demandasProvider = FutureProvider<List<Demanda>>((ref) {
  return DemandasService.getDemandas();
});

final filtroProvider = StateProvider<StatusDemanda?>((ref) => null);

/// Seção de turno selecionada pelo professor ('gerais', 'matutino', etc.)
/// null = tela de cards (home)
final turnoSelecionadoProvider = StateProvider<String?>((ref) => null);

/// Stream de mensagens FCM com o app em foreground.
final fcmForegroundProvider = StreamProvider<RemoteMessage>((ref) {
  return FirebaseMessaging.onMessage;
});
