import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/demanda.dart';
import '../services/demandas_service.dart';

final demandasProvider = FutureProvider<List<Demanda>>((ref) {
  return DemandasService.getDemandas();
});

final filtroProvider = StateProvider<StatusDemanda?>((ref) => null);

/// Stream de mensagens FCM com o app em foreground.
/// Usado pela DemandasListScreen para atualizar a lista automaticamente.
final fcmForegroundProvider = StreamProvider<RemoteMessage>((ref) {
  return FirebaseMessaging.onMessage;
});
