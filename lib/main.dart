import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, FlutterAuthClientOptions;
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/supabase/supabase_config.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URLs limpas (sem #) — necessário para links de auth do Supabase
  // (ex: /auth/callback?code=...) chegarem na rota correta.
  if (kIsWeb) usePathUrlStrategy();

  if (!kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUri: false, // AuthCallbackScreen processa manualmente
    ),
  );

  if (!kIsWeb) {
    await NotificationService.initialize();
  }

  runApp(
    const ProviderScope(
      child: FocoPedagogicoApp(),
    ),
  );
}
