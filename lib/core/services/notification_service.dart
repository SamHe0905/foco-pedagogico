import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';

/// Handler de mensagens em background/terminated — precisa ser top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM exibe automaticamente a notificação quando o app está em background.
  // Nenhuma ação adicional é necessária aqui.
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db        = Supabase.instance.client;

  /// Router para navegação ao tocar na notificação.
  static GoRouter? _router;

  /// demandaId pendente quando o app abre via notificação antes do router estar pronto.
  static String? _pendingDemandaId;

  /// Chamado pelo app.dart após o router ser construído.
  static void setRouter(GoRouter router) {
    _router = router;
    if (_pendingDemandaId != null) {
      _navigateToDemanda(_pendingDemandaId!);
      _pendingDemandaId = null;
    }
  }

  static Future<void> initialize() async {
    // No web, onBackgroundMessage não é suportado — o SW (firebase-messaging-sw.js) cuida disso
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Pede permissão (Android 13+ / iOS / Web)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Salva token ao fazer login
    _db.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        _saveToken();
      }
    });

    // Salva token agora se já estiver autenticado
    await _saveToken();

    // Atualiza token quando ele mudar
    _messaging.onTokenRefresh.listen(_updateToken);

    // App em background → usuário tocou na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final demandaId = message.data['demanda_id'] as String?;
      if (demandaId != null) _navigateToDemanda(demandaId);
    });

    // App encerrado → abre via toque na notificação (não suportado no web)
    if (!kIsWeb) {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final demandaId = initial.data['demanda_id'] as String?;
        if (demandaId != null) {
          if (_router != null) {
            _navigateToDemanda(demandaId);
          } else {
            _pendingDemandaId = demandaId;
          }
        }
      }
    }
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  static Future<void> _saveToken() async {
    try {
      final userId = _db.auth.currentUser?.id;
      debugPrint('[FCM] _saveToken → userId: $userId');
      if (userId == null) return;

      // No web, getToken() exige a VAPID key para Web Push
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? DefaultFirebaseOptions.vapidKey : null,
      );
      debugPrint('[FCM] getToken → ${token == null ? 'NULL' : token.substring(0, 20)}...');
      if (token == null) return;

      await _db
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('[FCM] ✓ Token salvo para $userId');
    } catch (e) {
      debugPrint('[FCM] ✗ Erro ao salvar token: $e');
    }
  }

  static Future<void> _updateToken(String token) async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return;
      await _db
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (e) {
      debugPrint('[FCM] Erro ao atualizar token: $e');
    }
  }

  // ── Navegação ──────────────────────────────────────────────────────────────

  static void _navigateToDemanda(String demandaId) {
    _router?.push('/professor/demanda/$demandaId');
  }
}
