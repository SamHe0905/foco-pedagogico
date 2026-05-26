import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../demandas/domain/demanda.dart';
import '../domain/demanda_resumo.dart';
import 'coordenacao_providers.dart';

class MuralDemandasScreen extends ConsumerWidget {
  const MuralDemandasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todasDemandasProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mural de Demandas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(todasDemandasProvider),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              const Text('Erro ao carregar o mural.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(todasDemandasProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (demandas) {
          if (demandas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_outlined,
                      size: 56, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma demanda no mural ainda.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(todasDemandasProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: demandas.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MuralCard(demanda: demandas[i]),
              ),
            ),
          );
        },
          ),
        ),
      ),
    );
  }
}

// ─── Card do mural (somente leitura) ─────────────────────────────────────────

class _MuralCard extends StatelessWidget {
  final DemandaResumo demanda;
  const _MuralCard({required this.demanda});

  Color get _priorCor => switch (demanda.prioridade) {
        PrioridadeDemanda.alta  => AppColors.error,
        PrioridadeDemanda.media => AppColors.warning,
        PrioridadeDemanda.baixa => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                      // Título + ícone concluída
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
                          if (demanda.todosConcluidam) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.statusConcluida, size: 16),
                          ],
                        ],
                      ),

                      // Nome do coordenador
                      if (demanda.criadoPorNome != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 12, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text(
                              demanda.criadoPorNome!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (demanda.turma.isNotEmpty)
                            _Chip(
                              label: demanda.turma,
                              icon: Icons.class_rounded,
                              color: AppColors.textSecondary,
                            ),
                          _Chip(
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

                      // Texto progresso
                      Text(
                        '${demanda.concluidas}/${demanda.total} concluíram',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool bold;

  const _Chip({
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
