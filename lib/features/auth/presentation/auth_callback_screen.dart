import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/app_router.dart';
import '../domain/usuario.dart';
import '../services/auth_service.dart';
import 'auth_providers.dart';

/// Tela intermediária usada pelo Supabase como redirectTo em fluxos de
/// confirmação de e-mail (signup/invite).
///
/// O fluxo PKCE de recovery (resetPasswordForEmail) é interceptado diretamente
/// pelo GoRouterAuthNotifier via AuthChangeEvent.passwordRecovery, então esta
/// tela não precisa mais lidar com ele.
class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String _status = 'Processando acesso...';

  @override
  void initState() {
    super.initState();
    _processar();
  }

  void _set(String s) {
    if (mounted) setState(() => _status = s);
  }

  Future<void> _processar() async {
    final client = Supabase.instance.client;

    // Erro vindo na URL (ex: otp_expired, access_denied)
    final fragment = Uri.base.fragment;
    final params   = Uri.splitQueryString(fragment);
    if (params.containsKey('error')) {
      final desc = (params['error_description'] ?? 'Link inválido ou expirado.')
          .replaceAll('+', ' ');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(desc), backgroundColor: Colors.red),
      );
      context.go(AppRoutes.login);
      return;
    }

    try {
      _set('Validando acesso...');

      // Troca o code (PKCE) ou token (implicit) por uma sessão.
      await client.auth.getSessionFromUrl(Uri.base, storeSession: true);

      // Cede o controle para que microtasks pendentes (inclusive o listener
      // do stream onAuthStateChange no GoRouterAuthNotifier) sejam executadas.
      await Future.delayed(Duration.zero);

      // Se era um link de recuperação de senha, o GoRouterAuthNotifier já
      // setou pendingRecovery = true. Navegamos explicitamente e paramos aqui.
      if (goRouterAuthNotifier.pendingRecovery) {
        goRouterAuthNotifier.clearRecovery();
        if (mounted) context.go(AppRoutes.criarSenha);
        return;
      }

      final session = client.auth.currentSession;
      if (session == null) {
        if (mounted) context.go(AppRoutes.login);
        return;
      }

      if (!mounted) return;

      // Auto-cria perfil para cadastros próprios (type == 'signup')
      final supaUser = client.auth.currentUser;
      if (supaUser != null) {
        try {
          final existing = await client
              .from('profiles')
              .select('id')
              .eq('id', supaUser.id)
              .maybeSingle();
          if (existing == null) {
            final nome =
                (supaUser.userMetadata?['nome'] as String?) ??
                supaUser.email ??
                'Usuário';
            await client.from('profiles').insert({
              'id':   supaUser.id,
              'nome': nome,
              'role': 'professor',
            });
          }
        } catch (_) {
          // Ignora — buscarUsuarioAtual abaixo lida com perfil ausente
        }
      }

      final usuario = await AuthService.buscarUsuarioAtual();
      if (!mounted) return;
      context.go(homeRouteFor(usuario?.role ?? RoleUsuario.professor));
    } catch (e) {
      _set('Erro: $e');
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
