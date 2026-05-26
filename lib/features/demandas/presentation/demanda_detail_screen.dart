import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/anexos_section.dart';
import '../domain/demanda.dart';
import '../services/demandas_service.dart';
import 'demandas_providers.dart';

class DemandaDetailScreen extends ConsumerStatefulWidget {
  final String demandaId;
  final Demanda? demanda;

  const DemandaDetailScreen({
    super.key,
    required this.demandaId,
    this.demanda,
  });

  @override
  ConsumerState<DemandaDetailScreen> createState() => _DemandaDetailScreenState();
}

class _DemandaDetailScreenState extends ConsumerState<DemandaDetailScreen> {
  Demanda? _demanda;
  bool _carregando = true;
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    if (widget.demanda != null) {
      _demanda = widget.demanda;
      _carregando = false;
      _autoVisualizar();
    } else {
      _buscarDemanda();
    }
  }

  Future<void> _buscarDemanda() async {
    final demanda = await DemandasService.getDemandaById(widget.demandaId);
    if (!mounted) return;
    setState(() {
      _demanda = demanda;
      _carregando = false;
    });
    _autoVisualizar();
  }

  Future<void> _autoVisualizar() async {
    if (_demanda?.status != StatusDemanda.pendente) return;
    await DemandasService.atualizarStatus(widget.demandaId, StatusDemanda.visualizada);
    if (!mounted) return;
    setState(() => _demanda = _demanda?.copyWith(status: StatusDemanda.visualizada));
    ref.invalidate(demandasProvider);
  }

  Future<void> _marcarConcluida() async {
    setState(() => _atualizando = true);
    await DemandasService.atualizarStatus(widget.demandaId, StatusDemanda.concluida);
    if (!mounted) return;
    setState(() {
      _demanda = _demanda?.copyWith(status: StatusDemanda.concluida);
      _atualizando = false;
    });
    ref.invalidate(demandasProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)),
      );
    }

    if (_demanda == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Demanda não encontrada.'),
        ),
      );
    }

    final d = _demanda!;
    final concluida = d.status == StatusDemanda.concluida;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Demanda'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _PriorityStrip(prioridade: d.prioridade),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBadgeLarge(status: d.status),
                  const SizedBox(height: 14),
                  Text(
                    d.titulo,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          decoration: concluida ? TextDecoration.lineThrough : null,
                          color: concluida ? AppColors.textHint : AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(demanda: d),
                  const SizedBox(height: 24),
                  if (d.descricao.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(
                      'Descrição',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      d.descricao,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                  // ── Anexos ───────────────────────────────────────────
                  const Divider(height: 32),
                  AnexosSection(
                    demandaId: widget.demandaId,
                    podeEditar: false,
                  ),

                  if (concluida) ...[
                    const SizedBox(height: 32),
                    _ConcluidaBanner(),
                  ],
                ],
              ),
            ),
          ),
          if (!concluida) _BottomBar(atualizando: _atualizando, onConcluir: _marcarConcluida),
        ],
      ),
    );
  }
}

// ─── Widgets internos ────────────────────────────────────────────────────────

class _PriorityStrip extends StatelessWidget {
  final PrioridadeDemanda prioridade;
  const _PriorityStrip({required this.prioridade});

  Color get _color => switch (prioridade) {
        PrioridadeDemanda.alta => AppColors.error,
        PrioridadeDemanda.media => AppColors.warning,
        PrioridadeDemanda.baixa => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(height: 3, color: _color);
  }
}

class _StatusBadgeLarge extends StatelessWidget {
  final StatusDemanda status;
  const _StatusBadgeLarge({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final Demanda demanda;
  const _InfoRow({required this.demanda});

  @override
  Widget build(BuildContext context) {
    final atrasada = demanda.atrasada;
    final concluida = demanda.status == StatusDemanda.concluida;
    final prazoColor = concluida
        ? AppColors.textHint
        : atrasada
            ? AppColors.error
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _InfoItem(
            icon: Icons.class_rounded,
            label: 'Turma',
            value: demanda.turma,
            valueColor: AppColors.textPrimary,
          ),
          const SizedBox(height: 12),
          _InfoItem(
            icon: atrasada && !concluida
                ? Icons.warning_amber_rounded
                : Icons.calendar_today_rounded,
            label: 'Prazo',
            value: demanda.prazoLabel,
            valueColor: prazoColor,
            iconColor: prazoColor,
          ),
          const SizedBox(height: 12),
          _InfoItem(
            icon: Icons.flag_rounded,
            label: 'Prioridade',
            value: switch (demanda.prioridade) {
              PrioridadeDemanda.alta => 'Alta',
              PrioridadeDemanda.media => 'Média',
              PrioridadeDemanda.baixa => 'Baixa',
            },
            valueColor: switch (demanda.prioridade) {
              PrioridadeDemanda.alta => AppColors.error,
              PrioridadeDemanda.media => AppColors.warning,
              PrioridadeDemanda.baixa => AppColors.primary,
            },
            iconColor: switch (demanda.prioridade) {
              PrioridadeDemanda.alta => AppColors.error,
              PrioridadeDemanda.media => AppColors.warning,
              PrioridadeDemanda.baixa => AppColors.primary,
            },
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color iconColor;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.iconColor = AppColors.textHint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ConcluidaBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusConcluida.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusConcluida.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.statusConcluida, size: 20),
          SizedBox(width: 10),
          Text(
            'Demanda concluída',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.statusConcluida,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool atualizando;
  final VoidCallback onConcluir;

  const _BottomBar({required this.atualizando, required this.onConcluir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: atualizando ? null : onConcluir,
          icon: atualizando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.surface,
                  ),
                )
              : const Icon(Icons.check_circle_rounded),
          label: const Text('Marcar como Concluída'),
        ),
      ),
    );
  }
}
