import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/anexos_section.dart';
import '../domain/demanda_resumo.dart';
import '../domain/status_professor.dart';
import '../../demandas/domain/demanda.dart';
import '../services/coordenacao_service.dart';
import 'coordenacao_providers.dart';

class DetalheDemandaCoordenacaoScreen extends ConsumerWidget {
  final String demandaId;
  final DemandaResumo? demanda;

  const DetalheDemandaCoordenacaoScreen({
    super.key,
    required this.demandaId,
    this.demanda,
  });

  Future<void> _confirmarExclusao(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir demanda?'),
        content: const Text(
          'Essa ação não pode ser desfeita. A demanda será removida para todos os professores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await CoordenacaoService.excluirDemanda(demandaId);
      ref.invalidate(coordenacaoDemandasProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(detalhesProfessoresProvider(demandaId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          demanda?.titulo ?? 'Detalhe',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (demanda != null)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Editar',
              onPressed: () async {
                final alterado = await context.push(
                  '/coordenacao/demanda/$demandaId/editar',
                  extra: demanda,
                );
                if (alterado == true) {
                  ref.invalidate(detalhesProfessoresProvider(demandaId));
                }
              },
            ),
          if (demanda != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Excluir',
              color: AppColors.error,
              onPressed: () => _confirmarExclusao(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(detalhesProfessoresProvider(demandaId)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Cabeçalho com info da demanda ──────────────────────────────
          if (demanda != null) _InfoHeader(demanda: demanda!),

          // ── Anexos ─────────────────────────────────────────────────────
          if (demanda != null)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: AnexosSection(
                demandaId: demandaId,
                podeEditar: true,
              ),
            ),

          // ── Lista de professores ────────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
              error: (_, __) => _ErrorState(
                onRetry: () =>
                    ref.invalidate(detalhesProfessoresProvider(demandaId)),
              ),
              data: (professores) => professores.isEmpty
                  ? const _EmptyState()
                  : _ProfessoresList(professores: professores),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cabeçalho ────────────────────────────────────────────────────────────────

class _InfoHeader extends StatelessWidget {
  final DemandaResumo demanda;
  const _InfoHeader({required this.demanda});

  @override
  Widget build(BuildContext context) {
    final hoje     = DateTime.now();
    final diaHoje  = DateTime(hoje.year, hoje.month, hoje.day);
    final diaPrazo = DateTime(
        demanda.prazo.year, demanda.prazo.month, demanda.prazo.day);
    final diff     = diaPrazo.difference(diaHoje).inDays;
    final atrasada = diff < 0 && !demanda.todosConcluidam;

    final prazoLabel = switch (diff) {
      _ when diff < 0 => 'Atrasada ${-diff}d',
      0               => 'Hoje',
      1               => 'Amanhã',
      _ when diff < 7 => 'Em ${diff}d',
      _               => '${demanda.prazo.day.toString().padLeft(2, '0')}/${demanda.prazo.month.toString().padLeft(2, '0')}',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progresso
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: demanda.progresso,
                    minHeight: 6,
                    backgroundColor: AppColors.divider,
                    color: demanda.todosConcluidam
                        ? AppColors.statusConcluida
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${demanda.concluidas}/${demanda.total}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Chips de info
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.label_rounded,
                label: _tipoLabel(demanda.tipo),
                color: AppColors.primary,
              ),
              if (demanda.turma.isNotEmpty)
                _InfoChip(
                  icon: Icons.class_rounded,
                  label: demanda.turma,
                  color: AppColors.textSecondary,
                ),
              _InfoChip(
                icon: atrasada
                    ? Icons.warning_amber_rounded
                    : Icons.calendar_today_rounded,
                label: prazoLabel,
                color: atrasada ? AppColors.error : AppColors.textSecondary,
              ),
              _InfoChip(
                icon: Icons.flag_rounded,
                label: _prioridadeLabel(demanda.prioridade),
                color: _prioridadeCor(demanda.prioridade),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _tipoLabel(String tipo) => switch (tipo) {
        'geral'      => 'Geral',
        'turma'      => 'Por Turma',
        'individual' => 'Individual',
        _            => tipo,
      };

  String _prioridadeLabel(PrioridadeDemanda p) => switch (p) {
        PrioridadeDemanda.alta  => 'Alta',
        PrioridadeDemanda.media => 'Média',
        PrioridadeDemanda.baixa => 'Baixa',
      };

  Color _prioridadeCor(PrioridadeDemanda p) => switch (p) {
        PrioridadeDemanda.alta  => AppColors.error,
        PrioridadeDemanda.media => AppColors.warning,
        PrioridadeDemanda.baixa => AppColors.primary,
      };
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista de professores ─────────────────────────────────────────────────────

class _ProfessoresList extends StatelessWidget {
  final List<StatusProfessor> professores;
  const _ProfessoresList({required this.professores});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: professores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ProfessorTile(prof: professores[i]),
    );
  }
}

class _ProfessorTile extends StatelessWidget {
  final StatusProfessor prof;
  const _ProfessorTile({required this.prof});

  (Color, IconData, String) get _config => switch (prof.status) {
        'concluida'   => (AppColors.statusConcluida, Icons.check_circle_rounded, 'Concluída'),
        'visualizada' => (AppColors.statusVisualizada, Icons.visibility_rounded, 'Visualizada'),
        _             => (AppColors.statusPendente, Icons.schedule_rounded, 'Pendente'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _config;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar inicial
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  prof.nome.isNotEmpty ? prof.nome[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Nome
              Expanded(
                child: Text(
                  prof.nome,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Badge de status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (prof.observacao != null && prof.observacao!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.comment_outlined,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    prof.observacao!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Estados ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 48, color: AppColors.textHint),
            SizedBox(height: 12),
            Text(
              'Nenhum professor atribuído.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
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
            const Text(
              'Erro ao carregar.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}
