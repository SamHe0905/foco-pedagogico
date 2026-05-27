import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/pwa_install_banner.dart';
import '../../../shared/widgets/saudacao_header.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/services/auth_service.dart';
import '../domain/demanda.dart';
import 'demandas_providers.dart';

const _turnoOrdem = ['matutino', 'vespertino', 'integral', 'noturno'];

const _turnoLabels = {
  'matutino':   'Matutino',
  'vespertino': 'Vespertino',
  'integral':   'Integral',
  'noturno':    'Noturno',
};

const _turnoIcons = {
  'matutino':   Icons.wb_sunny_rounded,
  'vespertino': Icons.wb_twilight_rounded,
  'integral':   Icons.brightness_5_rounded,
  'noturno':    Icons.nights_stay_rounded,
};

// ─── Screen ──────────────────────────────────────────────────────────────────

class DemandasListScreen extends ConsumerWidget {
  const DemandasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(fcmForegroundProvider, (_, next) {
      next.whenData((_) => ref.invalidate(demandasProvider));
    });

    final async  = ref.watch(demandasProvider);
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
          Consumer(builder: (ctx, r, _) {
            final userAsync = r.watch(currentUserProvider);
            return userAsync.maybeWhen(
              data: (user) {
                if (user == null ||
                    !user.temDuploAcesso ||
                    user.roleSecundario == null) {
                  return const SizedBox.shrink();
                }
                final isSecundary = r.watch(viewAsSecundaryProvider);
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
                    r.read(viewAsSecundaryProvider.notifier).state = novo;
                    final destinoRole =
                        novo ? user.roleSecundario! : user.role;
                    context.go(homeRouteFor(destinoRole));
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          }),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
            onPressed: () async => AuthService.logout(),
          ),
        ],
      ),
      body: PwaInstallBanner(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                const SaudacaoHeader(),
                const Divider(height: 1),

                // ── Filtro de status ───────────────────────────────────────
                async.when(
                  data: (demandas) => _FilterBar(demandas: demandas),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Lista com seções ───────────────────────────────────────
                Expanded(
                  child: async.when(
                    loading: () => const _LoadingState(),
                    error: (e, _) => _ErrorState(
                      onRetry: () => ref.invalidate(demandasProvider),
                    ),
                    data: (demandas) {
                      final filtradas = filtro == null
                          ? demandas
                          : demandas
                              .where((d) => d.status == filtro)
                              .toList();

                      return RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => ref.refresh(demandasProvider.future),
                        child: filtradas.isEmpty
                            ? _EmptyState(filtro: filtro)
                            : _DemandasAgrupadas(demandas: filtradas),
                      );
                    },
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

// ─── Lista agrupada por seções ────────────────────────────────────────────────

class _DemandasAgrupadas extends StatelessWidget {
  final List<Demanda> demandas;
  const _DemandasAgrupadas({required this.demandas});

  @override
  Widget build(BuildContext context) {
    // Gerais: tudo que não é turma com turno definido
    final gerais = <Demanda>[];
    final porTurno = <String, List<Demanda>>{};

    for (final d in demandas) {
      if (d.tipo == TipoDemanda.turma && d.turno != null) {
        porTurno.putIfAbsent(d.turno!, () => []).add(d);
      } else {
        gerais.add(d);
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (gerais.isNotEmpty) ...[
          _SecaoHeader(
            icon: Icons.grid_view_rounded,
            label: 'Gerais',
            count: gerais.length,
          ),
          const SizedBox(height: 10),
          ...gerais.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DemandaCard(demanda: d),
              )),
        ],
        for (final turno in _turnoOrdem)
          if (porTurno[turno]?.isNotEmpty ?? false) ...[
            if (gerais.isNotEmpty || _turnoOrdem.indexOf(turno) > 0)
              const SizedBox(height: 8),
            _SecaoHeader(
              icon: _turnoIcons[turno]!,
              label: _turnoLabels[turno]!,
              count: porTurno[turno]!.length,
            ),
            const SizedBox(height: 10),
            ...porTurno[turno]!.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DemandaCard(demanda: d),
                )),
          ],
      ],
    );
  }
}

// ─── Cabeçalho de seção ───────────────────────────────────────────────────────

class _SecaoHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _SecaoHeader({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _DemandaCard extends StatelessWidget {
  final Demanda demanda;
  const _DemandaCard({required this.demanda});

  bool get _isDaGestao {
    final role = demanda.criadoPorRole;
    return role != null &&
        (role == 'diretor' || role == 'diretor-adjunto' || role == 'secretaria');
  }

  @override
  Widget build(BuildContext context) {
    final concluida = demanda.status == StatusDemanda.concluida;
    final isIndividual = demanda.tipo == TipoDemanda.individual;

    return Card(
      color: isIndividual
          ? AppColors.primary.withValues(alpha: 0.05)
          : null,
      shape: isIndividual
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.30),
                width: 1.2,
              ),
            )
          : null,
      child: InkWell(
        onTap: () => context.push(
          'demanda/${demanda.id}',
          extra: demanda,
        ),
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
                            _TurmaChip(
                              turma: demanda.turma,
                              isIndividual: isIndividual,
                            ),
                            if (_isDaGestao) ...[
                              const SizedBox(width: 6),
                              const _GestaoChip(),
                            ],
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
  final bool isIndividual;
  const _TurmaChip({required this.turma, this.isIndividual = false});

  @override
  Widget build(BuildContext context) {
    final fg = isIndividual ? AppColors.primary : AppColors.textSecondary;
    final bg = isIndividual
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.surfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isIndividual) ...[
            Icon(Icons.person_rounded, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            turma,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isIndividual ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _GestaoChip extends StatelessWidget {
  const _GestaoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.domain_rounded, size: 11, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(
            'Da Gestão',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
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
            fontWeight:
                atrasada && !concluida ? FontWeight.w600 : FontWeight.w400,
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
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textHint),
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
