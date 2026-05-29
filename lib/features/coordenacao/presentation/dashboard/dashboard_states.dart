part of '../dashboard_screen.dart';

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
          SaudacaoHeader(action: const _NovaDemandaButton()),
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
                  'Nenhuma demanda enviada.\nUse o botão acima para criar a primeira.',
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

// ─── Botão Nova Demanda (inline no SaudacaoHeader) ────────────────────────────

class _NovaDemandaButton extends ConsumerWidget {
  const _NovaDemandaButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Implementacao via Material + InkWell em vez de FilledButton.icon porque
    // FilledButton.icon nao renderiza dentro de Positioned sem dimensoes
    // explicitas em release mode no Flutter Web (bug observado em ff6a1d0
    // tambem). Visual identico ao botao azul anterior.
    return SizedBox(
      width: 148,
      height: 40,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await context.push(AppRoutes.criarDemanda);
            ref.invalidate(coordenacaoDemandasProvider);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Nova Demanda',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
