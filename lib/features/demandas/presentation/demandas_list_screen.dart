import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/saudacao_header.dart';
import '../../auth/services/auth_service.dart';
import '../domain/demanda.dart';
import 'demandas_providers.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class DemandasListScreen extends ConsumerWidget {
  const DemandasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Recebe nova demanda com app aberto → atualiza lista automaticamente
    ref.listen(fcmForegroundProvider, (_, next) {
      next.whenData((_) => ref.invalidate(demandasProvider));
    });

    final async = ref.watch(demandasProvider);
    final filtro = ref.watch(filtroProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 36,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
            onPressed: () async {
              await AuthService.logout();
              // GoRouterAuthNotifier notifica o router → redirect para /login
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              const SaudacaoHeader(),
              const Divider(height: 1),
          async.when(
            data: (demandas) => _FilterBar(demandas: demandas),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: async.when(
              loading: () => const _LoadingState(),
              error: (e, _) => _ErrorState(
                onRetry: () => ref.invalidate(demandasProvider),
              ),
              data: (demandas) {
                final filtradas = filtro == null
                    ? demandas
                    : demandas.where((d) => d.status == filtro).toList();

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.refresh(demandasProvider.future),
                  child: filtradas.isEmpty
                      ? _EmptyState(filtro: filtro)
                      : _DemandaList(demandas: filtradas),
                );
              },
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final List<Demanda> demandas;
  const _FilterBar({required this.demandas});

  int _count(StatusDemanda? status) => status == null
      ? demandas.length
      : demandas.where((d) => d.status == status).length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroProvider);

    final filtros = <(String, StatusDemanda?)>[
      ('Todas', null),
      ('Pendentes', StatusDemanda.pendente),
      ('Visualizadas', StatusDemanda.visualizada),
      ('Concluídas', StatusDemanda.concluida),
    ];

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: filtros.map((entry) {
                final (label, status) = entry;
                final active = filtro == status;
                final count = _count(status);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('$label  $count'),
                    selected: active,
                    onSelected: (_) =>
                        ref.read(filtroProvider.notifier).state = status,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceVariant,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color:
                          active ? AppColors.surface : AppColors.textSecondary,
                    ),
                    showCheckmark: false,
                    side: BorderSide(
                      color: active ? AppColors.primary : Colors.transparent,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ─── List ────────────────────────────────────────────────────────────────────

class _DemandaList extends StatelessWidget {
  final List<Demanda> demandas;
  const _DemandaList({required this.demandas});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: demandas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _DemandaCard(demanda: demandas[i]),
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _DemandaCard extends StatelessWidget {
  final Demanda demanda;
  const _DemandaCard({required this.demanda});

  @override
  Widget build(BuildContext context) {
    final concluida = demanda.status == StatusDemanda.concluida;

    return Card(
      child: InkWell(
        onTap: () => context.push('/professor/demanda/${demanda.id}', extra: demanda),
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PriorityBar(prioridade: demanda.prioridade),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                      decoration: concluida
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: concluida
                                          ? AppColors.textHint
                                          : AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(status: demanda.status),
                          ],
                        ),
                        if (demanda.descricao.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            demanda.descricao,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _TurmaChip(turma: demanda.turma),
                            const Spacer(),
                            _PrazoLabel(demanda: demanda),
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

class _PriorityBar extends StatelessWidget {
  final PrioridadeDemanda prioridade;
  const _PriorityBar({required this.prioridade});

  Color get _color => switch (prioridade) {
        PrioridadeDemanda.alta => AppColors.error,
        PrioridadeDemanda.media => AppColors.warning,
        PrioridadeDemanda.baixa => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(width: 4, color: _color);
  }
}

class _StatusBadge extends StatelessWidget {
  final StatusDemanda status;
  const _StatusBadge({required this.status});

  (Color, String, IconData) get _config => switch (status) {
        StatusDemanda.pendente =>
          (AppColors.statusPendente, 'Pendente', Icons.schedule_rounded),
        StatusDemanda.visualizada =>
          (AppColors.statusVisualizada, 'Visualizada', Icons.visibility_rounded),
        StatusDemanda.concluida =>
          (AppColors.statusConcluida, 'Concluída', Icons.check_circle_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurmaChip extends StatelessWidget {
  final String turma;
  const _TurmaChip({required this.turma});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        turma,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _PrazoLabel extends StatelessWidget {
  final Demanda demanda;
  const _PrazoLabel({required this.demanda});

  @override
  Widget build(BuildContext context) {
    final atrasada = demanda.atrasada;
    final concluida = demanda.status == StatusDemanda.concluida;
    final color = concluida
        ? AppColors.textHint
        : atrasada
            ? AppColors.error
            : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          atrasada && !concluida
              ? Icons.warning_amber_rounded
              : Icons.calendar_today_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          demanda.prazoLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: atrasada && !concluida ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── States ──────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final StatusDemanda? filtro;
  const _EmptyState({this.filtro});

  String get _mensagem => switch (filtro) {
        StatusDemanda.pendente => 'Nenhuma demanda pendente.\nTudo em dia!',
        StatusDemanda.visualizada => 'Nenhuma demanda visualizada.',
        StatusDemanda.concluida => 'Nenhuma demanda concluída ainda.',
        null => 'Nenhuma demanda no momento.\nPuxe para atualizar.',
      };

  IconData get _icon => switch (filtro) {
        StatusDemanda.pendente => Icons.check_circle_outline_rounded,
        StatusDemanda.concluida => Icons.hourglass_empty_rounded,
        _ => Icons.inbox_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 56, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(
                _mensagem,
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
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar\nas demandas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
