part of '../dashboard_screen.dart';

// ─── Drawer ───────────────────────────────────────────────────────────────────

class _DashboardDrawer extends ConsumerWidget {
  final VoidCallback onRelatorio;
  const _DashboardDrawer({required this.onRelatorio});

  void _navegar(BuildContext context, String route) {
    Navigator.pop(context); // fecha o drawer
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.maybeWhen(data: (u) => u, orElse: () => null);
    final isGestao = user != null && user.role.isDirector;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Foco Pedagógico',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // ── Demandas ──────────────────────────────────────────────────────
            _DrawerSection(titulo: 'Demandas'),
            _DrawerItem(
              icon: Icons.inbox_rounded,
              label: 'Minhas demandas recebidas',
              onTap: () => _navegar(context, AppRoutes.minhasDemandas),
            ),
            _DrawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Mural de Demandas',
              onTap: () => _navegar(context, AppRoutes.muralDemandas),
            ),
            _DrawerItem(
              icon: Icons.summarize_rounded,
              label: 'Relatório de pendências',
              onTap: () {
                Navigator.pop(context);
                onRelatorio();
              },
            ),

            // ── Escola ────────────────────────────────────────────────────────
            const Divider(),
            _DrawerSection(titulo: 'Escola'),
            _DrawerItem(
              icon: Icons.people_rounded,
              label: 'Equipe',
              onTap: () => _navegar(context, AppRoutes.professores),
            ),
            if (isGestao) ...[
              _DrawerItem(
                icon: Icons.class_rounded,
                label: 'Gerenciar Turmas',
                onTap: () => _navegar(context, AppRoutes.gerenciarTurmas),
              ),
              _DrawerItem(
                icon: Icons.engineering_rounded,
                label: 'Cursos Técnicos',
                onTap: () => _navegar(context, AppRoutes.gerenciarCursosTecnicos),
              ),
            ],

            // ── App ───────────────────────────────────────────────────────────
            const Divider(),
            _DrawerSection(titulo: 'App'),
            _DrawerItem(
              icon: Icons.qr_code_rounded,
              label: 'QR Code de instalação',
              onTap: () {
                Navigator.pop(context);
                showQrInstallDialog(context);
              },
            ),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Sair',
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(context);
                await AuthService.logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String titulo;
  const _DrawerSection({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _DrawerItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: TextStyle(
              color: c, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 8,
    );
  }
}
