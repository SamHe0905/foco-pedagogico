import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/pwa_install_banner.dart';
import '../../../shared/widgets/saudacao_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/services/auth_service.dart';
import '../services/coordenacao_service.dart';
import '../../demandas/domain/demanda.dart';
import '../domain/demanda_resumo.dart';
import '../domain/professor_pendencias.dart';
import 'coordenacao_providers.dart';

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
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coordenacaoDemandasProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                      if (user == null || !user.temDuploAcesso) {
                        return const SizedBox.shrink();
                      }
                      final isSecundary = ref.watch(viewAsSecundaryProvider);
                      return IconButton(
                        icon: Icon(
                          isSecundary
                              ? Icons.swap_horiz_rounded
                              : Icons.school_rounded,
                          color: isSecundary ? AppColors.secondary : null,
                        ),
                        tooltip: isSecundary
                            ? 'Voltar para Coordenação'
                            : 'Ver como Professor',
                        onPressed: () {
                          final novo = !isSecundary;
                          ref.read(viewAsSecundaryProvider.notifier).state = novo;
                          if (novo && user.roleSecundario != null) {
                            context.go(homeRouteFor(user.roleSecundario!));
                          }
                        },
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }),
                // Mural de demandas gerais
                IconButton(
                  icon: const Icon(Icons.dashboard_rounded),
                  tooltip: 'Mural de Demandas',
                  onPressed: () => context.push(AppRoutes.muralDemandas),
                ),
                IconButton(
                  icon: const Icon(Icons.class_rounded),
                  tooltip: 'Gerenciar Turmas',
                  onPressed: () => context.push(AppRoutes.gerenciarTurmas),
                ),
                IconButton(
                  icon: const Icon(Icons.people_rounded),
                  tooltip: 'Equipe',
                  onPressed: () => context.push(AppRoutes.professores),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Sair',
                  onPressed: () async => await AuthService.logout(),
                ),
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
      floatingActionButton: _emModoSelecao
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.criarDemanda);
                ref.invalidate(coordenacaoDemandasProvider);
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova Demanda'),
            ),
    );
  }
}

// ─── Conteúdo principal ───────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final List<DemandaResumo> demandas;
  final Set<String> selectedIds;
  final bool emModoSelecao;
  final void Function(String id) onLongPress;
  final void Function(String id) onToggle;

  const _DashboardContent({
    required this.demandas,
    required this.selectedIds,
    required this.emModoSelecao,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final atrasadas       = demandas.where((d) => d.atrasada).toList();
    final concluidas      = demandas.where((d) => d.todosConcluidam).length;
    final naoFinalizadas  = demandas.where((d) => !d.todosConcluidam).length;
    final profPendentes   = demandas.fold(0, (s, d) => s + d.pendentes);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // ── Saudação ──────────────────────────────────────────────────────
        const SaudacaoHeader(),
        const Divider(height: 1),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Resumo 2×2 ──────────────────────────────────────────────
              _ResumoGrid(
                pendentes:    naoFinalizadas,
                concluidas:   concluidas,
                atrasadas:    atrasadas.length,
                profPendentes: profPendentes,
              ),

              // ── Pendências importantes ───────────────────────────────────
              if (atrasadas.isNotEmpty) ...[
                const SizedBox(height: 24),
                _PendenciasSection(atrasadas: atrasadas),
              ],

              // ── Lista de demandas ────────────────────────────────────────
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Demandas Enviadas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (!emModoSelecao) ...[
                    const Spacer(),
                    Text(
                      'Segure para selecionar',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ...demandas.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DemandaCard(
                      demanda: d,
                      isSelected: selectedIds.contains(d.id),
                      emModoSelecao: emModoSelecao,
                      onLongPress: () => onLongPress(d.id),
                      onToggle: () => onToggle(d.id),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Resumo 2×2 ──────────────────────────────────────────────────────────────

class _ResumoGrid extends StatelessWidget {
  final int pendentes;
  final int concluidas;
  final int atrasadas;
  final int profPendentes;

  const _ResumoGrid({
    required this.pendentes,
    required this.concluidas,
    required this.atrasadas,
    required this.profPendentes,
  });

  void _mostrarProfsPendentes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProfsPendentesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _ResumoCard(
            icon:  Icons.schedule_rounded,
            value: '$pendentes',
            label: 'Em andamento',
            color: AppColors.primary,
          )),
          const SizedBox(width: 10),
          Expanded(child: _ResumoCard(
            icon:  Icons.check_circle_rounded,
            value: '$concluidas',
            label: 'Concluídas',
            color: AppColors.statusConcluida,
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ResumoCard(
            icon:  Icons.warning_amber_rounded,
            value: '$atrasadas',
            label: 'Atrasadas',
            color: atrasadas > 0 ? AppColors.error : AppColors.textHint,
            destaque: atrasadas > 0,
          )),
          const SizedBox(width: 10),
          Expanded(child: _ResumoCard(
            icon:  Icons.hourglass_top_rounded,
            value: '$profPendentes',
            label: 'Prof. pendentes',
            color: profPendentes > 0 ? AppColors.warning : AppColors.textHint,
            onTap: profPendentes > 0
                ? () => _mostrarProfsPendentes(context)
                : null,
          )),
        ]),
      ],
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool destaque;
  final VoidCallback? onTap;

  const _ResumoCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.destaque = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded,
              size: 14, color: color.withValues(alpha: 0.55)),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: color.withValues(alpha: destaque ? 0.1 : 0.06),
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: destaque ? 0.35 : 0.15),
                width: destaque ? 1.5 : 1,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

// ─── Pendências importantes ───────────────────────────────────────────────────

class _PendenciasSection extends ConsumerStatefulWidget {
  final List<DemandaResumo> atrasadas;
  const _PendenciasSection({required this.atrasadas});

  @override
  ConsumerState<_PendenciasSection> createState() => _PendenciasSectionState();
}

class _PendenciasSectionState extends ConsumerState<_PendenciasSection> {
  bool _notificando = false;

  Future<void> _notificarTodos() async {
    setState(() => _notificando = true);
    try {
      final ids = widget.atrasadas.map((d) => d.id).toList();
      await CoordenacaoService.notificarAtrasados(ids);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lembrete enviado para ${widget.atrasadas.length} demanda(s) atrasada(s).',
          ),
          backgroundColor: AppColors.statusConcluida,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao enviar lembretes.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _notificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 18),
            const SizedBox(width: 6),
            Text(
              'Atenção necessária',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
            const Spacer(),
            _notificando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
                    ),
                  )
                : TextButton.icon(
                    onPressed: _notificarTodos,
                    icon: const Icon(Icons.notifications_active_rounded, size: 15),
                    label: const Text('Notificar todos'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 10),
        ...widget.atrasadas.map((d) => _PendenciaItem(demanda: d)),
      ],
    );
  }
}

class _PendenciaItem extends StatelessWidget {
  final DemandaResumo demanda;
  const _PendenciaItem({required this.demanda});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/coordenacao/demanda/${demanda.id}', extra: demanda),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    demanda.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${demanda.prazoLabel} · ${demanda.pendentes} prof. pendentes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.error),
          ],
        ),
      ),
    );
  }
}

// ─── Card de demanda ──────────────────────────────────────────────────────────

class _DemandaCard extends StatelessWidget {
  final DemandaResumo demanda;
  final bool isSelected;
  final bool emModoSelecao;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;

  const _DemandaCard({
    required this.demanda,
    required this.isSelected,
    required this.emModoSelecao,
    required this.onLongPress,
    required this.onToggle,
  });

  Color get _priorCor => switch (demanda.prioridade) {
        PrioridadeDemanda.alta  => AppColors.error,
        PrioridadeDemanda.media => AppColors.warning,
        PrioridadeDemanda.baixa => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: AppColors.divider),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
      ),
      child: InkWell(
        onTap: emModoSelecao
            ? onToggle
            : () => context.push(
                  '/coordenacao/demanda/${demanda.id}',
                  extra: demanda,
                ),
        onLongPress: emModoSelecao ? null : onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de prioridade
                Container(width: 4, color: _priorCor),

                // Conteúdo
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título + checkbox/ícone concluída
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                demanda.titulo,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: demanda.todosConcluidam
                                          ? AppColors.textHint
                                          : AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (emModoSelecao)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        key: ValueKey('checked'),
                                        color: AppColors.primary,
                                        size: 20,
                                      )
                                    : const Icon(
                                        Icons.radio_button_unchecked_rounded,
                                        key: ValueKey('unchecked'),
                                        color: AppColors.textHint,
                                        size: 20,
                                      ),
                              )
                            else if (demanda.todosConcluidam)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.statusConcluida, size: 16),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Chips de info
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (demanda.criadoPorNome != null)
                              _InfoChip(
                                label: demanda.criadoPorNome!,
                                icon: Icons.person_outline_rounded,
                                color: AppColors.secondary,
                              ),
                            if (demanda.turma.isNotEmpty)
                              _InfoChip(
                                label: demanda.turma,
                                icon: Icons.class_rounded,
                                color: AppColors.textSecondary,
                              ),
                            _InfoChip(
                              label: demanda.prazoLabel,
                              icon: demanda.atrasada
                                  ? Icons.warning_amber_rounded
                                  : Icons.calendar_today_rounded,
                              color: demanda.atrasada
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              bold: demanda.atrasada,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Barra de progresso
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: demanda.progresso,
                            minHeight: 5,
                            backgroundColor: AppColors.divider,
                            color: demanda.todosConcluidam
                                ? AppColors.statusConcluida
                                : demanda.atrasada
                                    ? AppColors.error
                                    : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Progresso texto
                        Row(
                          children: [
                            Text(
                              '${demanda.concluidas}/${demanda.total} concluíram',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (demanda.pendentes > 0 && !demanda.todosConcluidam)
                              Text(
                                '${demanda.pendentes} pendentes',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: demanda.atrasada
                                      ? AppColors.error
                                      : AppColors.statusPendente,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool bold;

  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Bottom sheet — professores pendentes ─────────────────────────────────────

class _ProfsPendentesSheet extends ConsumerWidget {
  const _ProfsPendentesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(professoresPendentesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Cabeçalho
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.hourglass_top_rounded,
                          color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Professores pendentes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Conteúdo
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.warning, strokeWidth: 2.5),
                  ),
                  error: (_, __) => const Center(
                    child: Text('Erro ao carregar pendências.'),
                  ),
                  data: (professores) {
                    if (professores.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhum professor pendente. 🎉',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: professores.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 20, endIndent: 20),
                      itemBuilder: (context, i) =>
                          _ProfPendenteTile(prof: professores[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfPendenteTile extends StatelessWidget {
  final ProfessorComPendencias prof;
  const _ProfPendenteTile({required this.prof});

  @override
  Widget build(BuildContext context) {
    final qtd = prof.demandas.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome + badge de quantidade
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  prof.nome.isNotEmpty ? prof.nome[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prof.nome,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$qtd pendente${qtd > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),

          // Lista de demandas pendentes
          const SizedBox(height: 8),
          ...prof.demandas.map(
            (label) => Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.fiber_manual_record,
                        size: 6, color: AppColors.textHint),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estados ──────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2.5),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const SaudacaoHeader(),
          const Divider(height: 1),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_rounded,
                    size: 56, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma demanda enviada.\nToque em + para criar a primeira.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar demandas.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}
