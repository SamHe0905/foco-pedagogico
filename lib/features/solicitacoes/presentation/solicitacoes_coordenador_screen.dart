import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/solicitacao.dart';
import '../services/solicitacoes_service.dart';
import 'solicitacoes_providers.dart';

class SolicitacoesCoordenadorScreen extends ConsumerWidget {
  const SolicitacoesCoordenadorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(solicitacoesRecebidasProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Solicitações Recebidas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(solicitacoesRecebidasProvider),
          ),
        ],
      ),
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
                onPressed: () => ref.invalidate(solicitacoesRecebidasProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ),
            data: (lista) => lista.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        ref.refresh(solicitacoesRecebidasProvider.future),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _SolicitacaoTile(
                        s: lista[i],
                        onStatusChanged: () =>
                            ref.invalidate(solicitacoesRecebidasProvider),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Tile de solicitação ──────────────────────────────────────────────────────

class _SolicitacaoTile extends StatefulWidget {
  final Solicitacao s;
  final VoidCallback onStatusChanged;
  const _SolicitacaoTile(
      {required this.s, required this.onStatusChanged});

  @override
  State<_SolicitacaoTile> createState() => _SolicitacaoTileState();
}

class _SolicitacaoTileState extends State<_SolicitacaoTile> {
  bool _expandido = false;
  bool _atualizando = false;

  (Color, IconData, String) _config(StatusSolicitacao status) => switch (status) {
        StatusSolicitacao.resolvida   =>
          (AppColors.statusConcluida, Icons.check_circle_rounded, 'Resolvida'),
        StatusSolicitacao.emAndamento =>
          (AppColors.warning, Icons.autorenew_rounded, 'Em andamento'),
        StatusSolicitacao.pendente    =>
          (AppColors.statusPendente, Icons.schedule_rounded, 'Pendente'),
      };

  Future<void> _atualizarStatus(StatusSolicitacao novo) async {
    setState(() => _atualizando = true);
    try {
      await SolicitacoesService.atualizarStatus(widget.s.id, novo);
      widget.onStatusChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (cor, icon, label) = _config(widget.s.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.s.titulo,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 13, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(widget.s.professorNome,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            if (widget.s.turmaNome != null) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.class_rounded,
                                  size: 13, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(widget.s.turmaNome!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12, color: cor),
                            const SizedBox(width: 4),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: cor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatData(widget.s.criadaEm),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expandido
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo expandido
          if (_expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descrição
                  Text(
                    widget.s.descricao,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),

                  // Anexos
                  if (widget.s.anexos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Anexos',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...widget.s.anexos.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => _abrirAnexo(context, a.url),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.insert_drive_file_rounded,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(a.nome,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.primary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const Icon(Icons.open_in_new_rounded,
                                      size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        )),
                  ],

                  const SizedBox(height: 14),

                  // Ações de status
                  if (_atualizando)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  else
                    Row(
                      children: [
                        if (widget.s.status != StatusSolicitacao.emAndamento)
                          _StatusBtn(
                            label: 'Em andamento',
                            icon: Icons.autorenew_rounded,
                            color: AppColors.warning,
                            onTap: () => _atualizarStatus(
                                StatusSolicitacao.emAndamento),
                          ),
                        if (widget.s.status != StatusSolicitacao.emAndamento)
                          const SizedBox(width: 8),
                        if (widget.s.status != StatusSolicitacao.resolvida)
                          _StatusBtn(
                            label: 'Resolvida',
                            icon: Icons.check_circle_rounded,
                            color: AppColors.statusConcluida,
                            onTap: () => _atualizarStatus(
                                StatusSolicitacao.resolvida),
                          ),
                        if (widget.s.status != StatusSolicitacao.pendente) ...[
                          const SizedBox(width: 8),
                          _StatusBtn(
                            label: 'Pendente',
                            icon: Icons.schedule_rounded,
                            color: AppColors.statusPendente,
                            onTap: () => _atualizarStatus(
                                StatusSolicitacao.pendente),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _abrirAnexo(BuildContext context, String url) {
    // Abre o URL do anexo em nova aba (web)
    try {
      // ignore: avoid_web_libraries_in_flutter
      // dart:html não disponível em todos os targets; use url_launcher se preferir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText(url),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (_) {}
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

class _StatusBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mark_email_read_rounded,
              size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Nenhuma solicitação recebida.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
