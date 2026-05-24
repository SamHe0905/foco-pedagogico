import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/usuario.dart';
import '../../features/auth/presentation/auth_providers.dart';
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

abstract class AppRoutes {
  static const login                     = '/login';
  static const professorHome             = '/professor';
  static const coordenacaoDashboard      = '/coordenacao';
  static const criarDemanda              = '/coordenacao/criar';
  static const detalheDemandaCoordenacao = '/coordenacao/demanda/:id';
  static const professores               = '/coordenacao/professores';
  static const muralDemandas             = '/coordenacao/mural';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: goRouterAuthNotifier,
    redirect: (context, state) {
      final autenticado = goRouterAuthNotifier.isAuthenticated;
      final naLogin = state.matchedLocation == AppRoutes.login;

      // Não autenticado e tentando acessar rota protegida → login
      if (!autenticado && !naLogin) return AppRoutes.login;

      // Autenticado e na login → não redireciona aqui.
      // A tela de login navega para a rota correta após buscar o perfil.
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.professorHome,
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
    ],
  );
});

// Retorna a rota home correta para cada role
String homeRouteFor(RoleUsuario role) =>
    role.isDashboard ? AppRoutes.coordenacaoDashboard : AppRoutes.professorHome;
