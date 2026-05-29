part of '../dashboard_screen.dart';

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
