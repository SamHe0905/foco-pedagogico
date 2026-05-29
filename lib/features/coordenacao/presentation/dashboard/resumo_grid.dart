part of '../dashboard_screen.dart';

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
