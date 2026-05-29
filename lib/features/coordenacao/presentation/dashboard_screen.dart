import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/pwa_install_banner.dart';
import '../../../shared/widgets/saudacao_header.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/services/auth_service.dart';
import '../services/coordenacao_service.dart';
import '../../demandas/domain/demanda.dart';
import '../domain/demanda_resumo.dart';
import '../domain/professor_pendencias.dart';
import '../../solicitacoes/presentation/solicitacoes_providers.dart';
import '../../install/qr_install_dialog.dart';
import 'coordenacao_providers.dart';

// Widgets e helpers da tela, separados em arquivos-parte desta mesma biblioteca.
part 'dashboard/dashboard_relatorio.dart';
part 'dashboard/dashboard_content.dart';
part 'dashboard/categoria_demandas_view.dart';
part 'dashboard/resumo_grid.dart';
part 'dashboard/pendencias_section.dart';
part 'dashboard/demanda_card.dart';
part 'dashboard/profs_pendentes_sheet.dart';
part 'dashboard/dashboard_states.dart';
part 'dashboard/dashboard_drawer.dart';

// ─── Categoria constants ─────────────────────────────────────────────────────

const _categoriaLabels = {
  'geral': 'Geral',
  'turma': 'Por Turma',
  'individual': 'Individual',
  'coordenacao': 'Coordenação',
  'gestao': 'Gestão',
};

const _categoriaIcons = {
  'geral': Icons.campaign_rounded,
  'turma': Icons.class_rounded,
  'individual': Icons.person_rounded,
  'coordenacao': Icons.supervisor_account_rounded,
  'gestao': Icons.account_balance_rounded,
};

const _categoriaOrdem = [
  'geral', 'turma', 'individual', 'coordenacao', 'gestao'
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Set<String> _selectedIds = {};
  bool _excluindo = false;

  bool get _emModoSelecao => _selectedIds.isNotEmpty;

  void _iniciarSelecao(String id) => setState(() => _selectedIds.add(id));

  void _toggleSelecao(String id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });

  void _cancelarSelecao() => setState(() => _selectedIds.clear());

  Future<void> _excluirSelecionadas(List<DemandaResumo> demandas) async {
    final selecionadas =
        demandas.where((d) => _selectedIds.contains(d.id)).toList();
    final qtd = selecionadas.length;
    final naoConcluidas = selecionadas.where((d) => !d.todosConcluidam).length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          naoConcluidas > 0 ? Icons.warning_amber_rounded : Icons.delete_rounded,
          color: naoConcluidas > 0 ? AppColors.warning : AppColors.error,
          size: 32,
        ),
        title: Text('Excluir $qtd demanda${qtd > 1 ? 's' : ''}?'),
        content: Text(
          naoConcluidas > 0
              ? '$naoConcluidas demanda${naoConcluidas > 1 ? 's' : ''} ainda '
                  '${naoConcluidas > 1 ? 'não foram concluídas' : 'não foi concluída'}. '
                  'Deseja excluir mesmo assim?'
              : 'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _excluindo = true);
    try {
      for (final d in selecionadas) {
        await CoordenacaoService.excluirDemanda(d.id);
      }
      if (!mounted) return;
      _cancelarSelecao();
      ref.invalidate(coordenacaoDemandasProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coordenacaoDemandasProvider);
    final categoriaAtual = ref.watch(categoriaDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _DashboardDrawer(onRelatorio: () => _mostrarRelatorio(context, ref)),
      appBar: _emModoSelecao
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _cancelarSelecao,
              ),
              title: Text(
                '${_selectedIds.length} selecionada${_selectedIds.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              actions: [
                _excluindo
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        tooltip: 'Excluir selecionadas',
                        onPressed: () => async.whenData(_excluirSelecionadas),
                      ),
              ],
            )
          : categoriaAtual != null
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  ref.read(categoriaDashboardProvider.notifier).state = null;
                  _cancelarSelecao();
                },
              ),
              title: Text(_categoriaLabels[categoriaAtual] ?? categoriaAtual),
            )
          : AppBar(
              title: Image.asset(
                'assets/images/logo.png',
                height: 36,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
              actions: [
                // Toggle duplo acesso
                Consumer(builder: (context, ref, _) {
                  final userAsync = ref.watch(currentUserProvider);
                  return userAsync.maybeWhen(
                    data: (user) {
                      if (user == null ||
                          !user.temDuploAcesso ||
                          user.roleSecundario == null) {
                        return const SizedBox.shrink();
                      }
                      final isSecundary = ref.watch(viewAsSecundaryProvider);
                      final outroRole =
                          isSecundary ? user.role : user.roleSecundario!;
                      return IconButton(
                        icon: Icon(
                          outroRole.isDashboard
                              ? Icons.admin_panel_settings_rounded
                              : Icons.school_rounded,
                          color: isSecundary ? AppColors.secondary : null,
                        ),
                        tooltip: 'Ver como ${outroRole.cargo}',
                        onPressed: () {
                          final novo = !isSecundary;
                          ref.read(viewAsSecundaryProvider.notifier).state = novo;
                          context.go(homeRouteFor(
                              novo ? user.roleSecundario! : user.role));
                        },
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }),
                // Badge de solicitações pendentes
                Consumer(builder: (context, ref, _) {
                  final count = ref
                      .watch(solicitacoesPendentesCountProvider)
                      .maybeWhen(data: (n) => n, orElse: () => 0);
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: IconButton(
                      icon: const Icon(Icons.assignment_outlined),
                      tooltip: 'Solicitações recebidas',
                      onPressed: () {
                        context.push(AppRoutes.solicitacoesCoordenador);
                        ref.invalidate(solicitacoesPendentesCountProvider);
                      },
                    ),
                  );
                }),
              ],
            ),
      body: PwaInstallBanner(
        child: async.when(
        loading: () => const _LoadingState(),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(coordenacaoDemandasProvider),
        ),
        data: (demandas) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (_emModoSelecao) _cancelarSelecao();
            // ignore: unused_result
            ref.refresh(coordenacaoDemandasProvider);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: demandas.isEmpty
                  ? const _EmptyState()
                  : _DashboardContent(
                      demandas: demandas,
                      selectedIds: _selectedIds,
                      emModoSelecao: _emModoSelecao,
                      onLongPress: _iniciarSelecao,
                      onToggle: _toggleSelecao,
                    ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
