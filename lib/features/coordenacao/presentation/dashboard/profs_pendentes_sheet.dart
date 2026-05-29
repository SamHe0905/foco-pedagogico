part of '../dashboard_screen.dart';

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
