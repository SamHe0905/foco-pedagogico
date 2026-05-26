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

  // Sinaliza que o próximo redirecionamento deve ir para CriarSenhaScreen
  bool _pendingRecovery = false;
  bool get pendingRecovery => _pendingRecovery;

  void clearRecovery() {
    _pendingRecovery = false;
    // não notifica — será chamado dentro do próprio CriarSenhaScreen
  }

  GoRouterAuthNotifier() {
    _sub = AuthService.onAuthStateChange.listen((authState) {
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        _pendingRecovery = true;
      }
      notifyListeners();
    });
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

/// Controla se o usuário com duplo acesso está vendo o papel secundário.
/// false = role principal, true = role secundário.
final viewAsSecundaryProvider = StateProvider<bool>((ref) => false);
