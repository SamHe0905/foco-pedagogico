part of '../dashboard_screen.dart';

// ─── Conteúdo principal ───────────────────────────────────────────────────────

class _DashboardContent extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final categoria = ref.watch(categoriaDashboardProvider);

    if (categoria != null) {
      final filtradas = demandas.where((d) => d.tipo == categoria).toList();
      return _CategoriaDemandasView(
        demandas: filtradas,
        selectedIds: selectedIds,
        emModoSelecao: emModoSelecao,
        onLongPress: onLongPress,
        onToggle: onToggle,
      );
    }

    final atrasadas      = demandas.where((d) => d.atrasada).toList();
    final concluidas     = demandas.where((d) => d.todosConcluidam).length;
    final naoFinalizadas = demandas.where((d) => !d.todosConcluidam).length;
    final profPendentes  = demandas.fold(0, (s, d) => s + d.pendentes);

    final secoes = <(String, List<DemandaResumo>)>[];
    for (final cat in _categoriaOrdem) {
      final ds = demandas.where((d) => d.tipo == cat).toList();
      if (ds.isNotEmpty) secoes.add((cat, ds));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        SaudacaoHeader(action: const _NovaDemandaButton()),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResumoGrid(
                pendentes:     naoFinalizadas,
                concluidas:    concluidas,
                atrasadas:     atrasadas.length,
                profPendentes: profPendentes,
              ),
              if (atrasadas.isNotEmpty) ...[
                const SizedBox(height: 24),
                _PendenciasSection(atrasadas: atrasadas),
              ],
              const SizedBox(height: 24),
              Text(
                'Demandas por Categoria',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: secoes.length,
                itemBuilder: (context, i) {
                  final (cat, ds) = secoes[i];
                  final pendentes = ds.where((d) => !d.todosConcluidam).length;
                  return _CategoriaCard(
                    categoria: cat,
                    total: ds.length,
                    pendentes: pendentes,
                    onTap: () =>
                        ref.read(categoriaDashboardProvider.notifier).state = cat,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Card de categoria ────────────────────────────────────────────────────────

class _CategoriaCard extends StatelessWidget {
  final String categoria;
  final int total;
  final int pendentes;
  final VoidCallback onTap;

  const _CategoriaCard({
    required this.categoria,
    required this.total,
    required this.pendentes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon  = _categoriaIcons[categoria] ?? Icons.category_rounded;
    final label = _categoriaLabels[categoria] ?? categoria;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Ícone — topo esquerdo
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  ),
                ),
                // Badge de pendentes — topo direito
                if (pendentes > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pendentes',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Label + contagem — fundo esquerdo
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$total demanda${total > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
