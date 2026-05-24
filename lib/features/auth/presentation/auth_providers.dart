import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/usuario.dart';
import '../services/auth_service.dart';

// Sessão atual — atualiza em tempo real com o stream do Supabase
final sessionProvider = StreamProvider<Session?>((ref) {
  return AuthService.onAuthStateChange.map((state) => state.session);
});

// Atalho: está autenticado?
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).whenOrNull(data: (s) => s != null) ?? false;
});

// Notificador para o GoRouter reescolher rotas ao mudar o estado de auth
class GoRouterAuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  GoRouterAuthNotifier() {
    _sub = AuthService.onAuthStateChange.listen((_) => notifyListeners());
  }

  bool get isAuthenticated => AuthService.currentSession != null;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// Instância singleton — usada no routerProvider
final goRouterAuthNotifier = GoRouterAuthNotifier();

// Perfil completo do usuário logado — atualiza quando a sessão muda
final currentUserProvider = FutureProvider<Usuario?>((ref) {
  // Reexecuta sempre que a sessão mudar
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) return Future.value(null);
  return AuthService.buscarUsuarioAtual();
});
