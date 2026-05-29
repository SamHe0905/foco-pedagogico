part of '../dashboard_screen.dart';

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
