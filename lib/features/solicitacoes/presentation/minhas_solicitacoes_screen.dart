import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../domain/solicitacao.dart';
import 'solicitacoes_providers.dart';

class MinhasSolicitacoesScreen extends ConsumerWidget {
  const MinhasSolicitacoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(minhasSolicitacoesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Minhas Solicitações')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
            ),
            error: (_, __) => Center(
              child: FilledButton.icon(
                onPressed: () => ref.invalidate(minhasSolicitacoesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ),
            data: (lista) => lista.isEmpty
                ? _EmptyState(
                    onNova: () async {
                      final ok = await context.push(AppRoutes.novaSolicitacao);
                      if (ok == true) ref.invalidate(minhasSolicitacoesProvider);
                    },
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        ref.refresh(minhasSolicitacoesProvider.future),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _SolicitacaoCard(s: lista[i]),
                    ),
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push(AppRoutes.novaSolicitacao);
          if (ok == true) ref.invalidate(minhasSolicitacoesProvider);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Solicitação'),
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _SolicitacaoCard extends StatelessWidget {
  final Solicitacao s;
  const _SolicitacaoCard({required this.s});

  (Color, IconData) get _statusConfig => switch (s.status) {
        StatusSolicitacao.resolvida   => (AppColors.statusConcluida, Icons.check_circle_rounded),
        StatusSolicitacao.emAndamento => (AppColors.warning, Icons.autorenew_rounded),
        StatusSolicitacao.pendente    => (AppColors.statusPendente, Icons.schedule_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (cor, icon) = _statusConfig;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s.titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: cor),
                    const SizedBox(width: 4),
                    Text(s.status.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cor)),
                  ],
                ),
              ),
            ],
          ),
          if (s.descricao.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              s.descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (s.turmaNome != null) ...[
                Icon(Icons.class_rounded,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(s.turmaNome!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
              ],
              if (s.anexos.isNotEmpty) ...[
                Icon(Icons.attach_file_rounded,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('${s.anexos.length} anexo${s.anexos.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
              ],
              const Spacer(),
              Text(
                _formatData(s.criadaEm),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatData(DateTime d) {
    final hoje = DateTime.now();
    final diff = DateTime(hoje.year, hoje.month, hoje.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNova;
  const _EmptyState({required this.onNova});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_rounded, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Nenhuma solicitação enviada.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onNova,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova Solicitação'),
          ),
        ],
      ),
    );
  }
}
