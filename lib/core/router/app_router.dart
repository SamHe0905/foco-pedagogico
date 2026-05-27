import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/usuario.dart';
import '../../features/auth/presentation/auth_callback_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/cadastro_screen.dart';
import '../../features/auth/presentation/criar_senha_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/demandas/domain/demanda.dart';
import '../../features/demandas/presentation/demandas_list_screen.dart';
import '../../features/demandas/presentation/demanda_detail_screen.dart';
import '../../features/coordenacao/domain/demanda_resumo.dart';
import '../../features/coordenacao/presentation/dashboard_screen.dart';
import '../../features/coordenacao/presentation/criar_demanda_screen.dart';
import '../../features/coordenacao/presentation/detalhe_demanda_coordenacao_screen.dart';
import '../../features/coordenacao/presentation/editar_demanda_screen.dart';
import '../../features/coordenacao/presentation/mural_demandas_screen.dart';
import '../../features/coordenacao/presentation/professores_screen.dart';
import '../../features/coordenacao/presentation/gerenciar_turmas_screen.dart';

abstract class AppRoutes {
  static const login                     = '/login';
  static const cadastro                  = '/cadastro';
  static const authCallback              = '/auth/callback';
  static const criarSenha               = '/criar-senha';
  static const professorHome             = '/professor';
  static const coordenacaoDashboard      = '/coordenacao';
  static const criarDemanda              = '/coordenacao/criar';
  static const detalheDemandaCoordenacao = '/coordenacao/demanda/:id';
  static const professores               = '/coordenacao/professores';
  static const muralDemandas             = '/coordenacao/mural';
  static const gerenciarTurmas           = '/coordenacao/turmas';
  static const minhasDemandas            = '/coordenacao/recebidas';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: goRouterAuthNotifier,
    onException: (_, __, router) => router.go(AppRoutes.login),
    errorBuilder: (context, state) => const LoginScreen(),
    redirect: (context, state) {
      final autenticado  = goRouterAuthNotifier.isAuthenticated;
      final loc          = state.matchedLocation;
      final rotas_livres = {AppRoutes.login, AppRoutes.cadastro, AppRoutes.authCallback, AppRoutes.criarSenha};

      // Evento passwordRecovery capturado pelo notifier → vai direto para criar-senha
      if (goRouterAuthNotifier.pendingRecovery &&
          autenticado &&
          loc != AppRoutes.criarSenha) {
        return AppRoutes.criarSenha;
      }

      if (!autenticado && !rotas_livres.contains(loc)) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.cadastro,
        builder: (context, state) => const CadastroScreen(),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (context, state) => const AuthCallbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.criarSenha,
        builder: (context, state) => const CriarSenhaScreen(),
      ),
      GoRoute(
        path: AppRoutes.professorHome,
        builder: (context, state) => const DemandasListScreen(useTurnoCards: true),
        routes: [
          GoRoute(
            path: 'demanda/:id',
            builder: (context, state) => DemandaDetailScreen(
              demandaId: state.pathParameters['id']!,
              demanda: state.extra as Demanda?,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.coordenacaoDashboard,
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'criar',
            builder: (context, state) => const CriarDemandaScreen(),
          ),
          GoRoute(
            path: 'professores',
            builder: (context, state) => const ProfessoresScreen(),
          ),
          GoRoute(
            path: 'mural',
            builder: (context, state) => const MuralDemandasScreen(),
          ),
          GoRoute(
            path: 'turmas',
            builder: (context, state) => const GerenciarTurmasScreen(),
          ),
          GoRoute(
            path: 'recebidas',
            builder: (context, state) => const DemandasListScreen(),
            routes: [
              GoRoute(
                path: 'demanda/:id',
                builder: (context, state) => DemandaDetailScreen(
                  demandaId: state.pathParameters['id']!,
                  demanda: state.extra as Demanda?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'demanda/:id',
            builder: (context, state) => DetalheDemandaCoordenacaoScreen(
              demandaId: state.pathParameters['id']!,
              demanda:   state.extra as DemandaResumo?,
            ),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) => EditarDemandaScreen(
                  demanda: state.extra as DemandaResumo,
                ),
              ),
            ],
          ),
        ],
      ),

      // Rota catch-all: qualquer path desconhecido (ex: token do Supabase no
      // fragment) redireciona para login — o SDK já processou o token da URL.
      GoRoute(
        path: '/:rest(.*)',
        redirect: (_, __) => AppRoutes.login,
      ),
    ],
  );
});

// Retorna a rota home correta para cada role
String homeRouteFor(RoleUsuario role) =>
    role.isDashboard ? AppRoutes.coordenacaoDashboard : AppRoutes.professorHome;

// Retorna a rota home considerando o modo de visão atual (duplo acesso)
String homeRouteForMode(RoleUsuario primaryRole, {bool viewAsSecundary = false, RoleUsuario? secundaryRole}) {
  if (viewAsSecundary && secundaryRole != null) {
    return homeRouteFor(secundaryRole);
  }
  return homeRouteFor(primaryRole);
}
