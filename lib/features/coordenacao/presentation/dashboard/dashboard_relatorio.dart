part of '../dashboard_screen.dart';

// ─── Relatório de demandas ────────────────────────────────────────────────────
// Gera o texto do relatório, calcula métricas/análise automática e exibe o dialog.

void _mostrarRelatorio(BuildContext context, WidgetRef ref) {
  final demandas   = ref.read(coordenacaoDemandasProvider).valueOrNull ?? [];
  final profs      = ref.read(professoresPendentesProvider).valueOrNull ?? [];
  final profTotal  = ref.read(professoresProvider).valueOrNull?.length ?? 0;

  final now  = DateTime.now();
  final data = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  final hora = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  // ── Métricas gerais ────────────────────────────────────────────────────
  final total      = demandas.length;
  final concluidas = demandas.where((d) => d.todosConcluidam).length;
  final andamento  = demandas.where((d) => !d.todosConcluidam && !d.atrasada).length;
  final atrasadas  = demandas.where((d) => d.atrasada).toList();
  final aVencer    = demandas
      .where((d) => !d.todosConcluidam && !d.atrasada && d.diffDias >= 0 && d.diffDias <= 3)
      .toList();
  final taxa       = total > 0 ? (concluidas / total * 100).round() : 0;

  // ── Por prioridade ─────────────────────────────────────────────────────
  List<DemandaResumo> byPrio(PrioridadeDemanda p) =>
      demandas.where((d) => d.prioridade == p).toList();
  final alta  = byPrio(PrioridadeDemanda.alta);
  final media = byPrio(PrioridadeDemanda.media);
  final baixa = byPrio(PrioridadeDemanda.baixa);

  String prioLinha(String emoji, String label, List<DemandaResumo> list) {
    if (list.isEmpty) return '';
    final c   = list.where((d) => d.todosConcluidam).length;
    final pct = (c / list.length * 100).round();
    return '$emoji $label: ${list.length} demanda${list.length != 1 ? 's' : ''} — $c concluída${c != 1 ? 's' : ''} ($pct%)';
  }

  // ── Análise automática ────────────────────────────────────────────────
  final altaAtrasadas  = alta.where((d) => d.atrasada).length;
  final profComMuitas  = profs.where((p) => p.demandas.length >= 3).toList();

  String situacao;
  String situacaoEmoji;
  if (altaAtrasadas > 0 || atrasadas.length > 3 || taxa < 30) {
    situacao = 'Crítica';  situacaoEmoji = '🔴';
  } else if (atrasadas.isNotEmpty || taxa < 70 || profComMuitas.isNotEmpty) {
    situacao = 'Atenção';  situacaoEmoji = '🟡';
  } else {
    situacao = 'Saudável'; situacaoEmoji = '🟢';
  }

  final positivos      = <String>[];
  final atencoes       = <String>[];
  final recomendacoes  = <String>[];

  if (concluidas > 0) positivos.add('$concluidas demanda${concluidas != 1 ? 's' : ''} concluída${concluidas != 1 ? 's' : ''} — $taxa% de conclusão');
  if (atrasadas.isEmpty) positivos.add('Nenhuma demanda com prazo vencido');
  if (profs.isEmpty)     positivos.add('Todos os professores estão em dia com as demandas');
  if (aVencer.isEmpty && atrasadas.isEmpty) positivos.add('Prazos sob controle');

  if (altaAtrasadas > 0)  atencoes.add('$altaAtrasadas demanda${altaAtrasadas != 1 ? 's' : ''} de ALTA prioridade atrasada${altaAtrasadas != 1 ? 's' : ''}');
  if (atrasadas.isNotEmpty) atencoes.add('${atrasadas.length} demanda${atrasadas.length != 1 ? 's' : ''} com prazo vencido');
  if (aVencer.isNotEmpty)   atencoes.add('${aVencer.length} demanda${aVencer.length != 1 ? 's' : ''} vence${aVencer.length == 1 ? '' : 'm'} nos próximos 3 dias');
  if (profComMuitas.isNotEmpty) {
    final nomes = profComMuitas.map((p) => p.nome.split(' ').first).join(', ');
    atencoes.add('Professor${profComMuitas.length != 1 ? 'es' : ''} com 3+ pendências: $nomes');
  }
  if (taxa < 50 && total > 0) atencoes.add('Taxa de conclusão abaixo de 50%');

  if (altaAtrasadas > 0)       recomendacoes.add('Priorizar imediatamente as demandas de alta prioridade atrasadas');
  if (aVencer.isNotEmpty)       recomendacoes.add('Acompanhar de perto as ${aVencer.length} demanda${aVencer.length != 1 ? 's' : ''} que vencem em breve');
  if (profComMuitas.isNotEmpty) recomendacoes.add('Verificar individualmente os professores com 3 ou mais pendências');
  if (atencoes.isEmpty)         recomendacoes.add('Manter o ritmo atual — situação sob controle');

  // ── Monta o texto ─────────────────────────────────────────────────────
  String barra(int pct) {
    final filled = (pct / 10).round().clamp(0, 10);
    return '[${'█' * filled}${'░' * (10 - filled)}] $pct%';
  }

  final sb = StringBuffer();
  sb.writeln('📋 RELATÓRIO DE DEMANDAS — FOCO PEDAGÓGICO');
  sb.writeln('Gerado em: $data às $hora');
  sb.writeln();
  sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  sb.writeln('RESUMO GERAL');
  sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  sb.writeln('Total de demandas   : $total');
  sb.writeln('✅ Concluídas        : $concluidas');
  sb.writeln('⏳ Em andamento      : $andamento');
  if (aVencer.isNotEmpty) sb.writeln('⚠️  Vencem em 3 dias  : ${aVencer.length}');
  sb.writeln('🔴 Atrasadas         : ${atrasadas.length}');
  sb.writeln();
  sb.writeln('Taxa de conclusão: ${barra(taxa)}');

  // Por prioridade
  final pAlta  = prioLinha('🔴', 'Alta ', alta);
  final pMedia = prioLinha('🟡', 'Média', media);
  final pBaixa = prioLinha('🟢', 'Baixa', baixa);
  if (pAlta.isNotEmpty || pMedia.isNotEmpty || pBaixa.isNotEmpty) {
    sb.writeln();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('POR PRIORIDADE');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (pAlta.isNotEmpty)  sb.writeln(pAlta);
    if (pMedia.isNotEmpty) sb.writeln(pMedia);
    if (pBaixa.isNotEmpty) sb.writeln(pBaixa);
  }

  // Demandas urgentes (atrasadas + a vencer)
  if (atrasadas.isNotEmpty || aVencer.isNotEmpty) {
    sb.writeln();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('DEMANDAS QUE PRECISAM DE ATENÇÃO');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    for (final d in atrasadas) {
      final prog = '${d.concluidas}/${d.total} concluída${d.concluidas != 1 ? 's' : ''}';
      sb.writeln('• [ATRASADA] ${d.titulo}${d.turma.isNotEmpty ? ' [${d.turma}]' : ''} — ${d.prazoLabel} — $prog');
    }
    for (final d in aVencer) {
      final prog = '${d.concluidas}/${d.total} concluída${d.concluidas != 1 ? 's' : ''}';
      final prazo = d.diffDias == 0 ? 'vence hoje' : d.diffDias == 1 ? 'vence amanhã' : 'vence em ${d.diffDias} dias';
      sb.writeln('• [URGENTE]  ${d.titulo}${d.turma.isNotEmpty ? ' [${d.turma}]' : ''} — $prazo — $prog');
    }
  }

  // Professores com pendências
  if (profs.isNotEmpty) {
    sb.writeln();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final cabecalho = profTotal > 0
        ? 'PROFESSORES COM PENDÊNCIAS (${profs.length} de $profTotal)'
        : 'PROFESSORES COM PENDÊNCIAS';
    sb.writeln(cabecalho);
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final ordenados = [...profs]..sort((a, b) => b.demandas.length.compareTo(a.demandas.length));
    for (final p in ordenados) {
      sb.writeln('• ${p.nome} — ${p.demandas.length} pendência${p.demandas.length != 1 ? 's' : ''}');
      for (final d in p.demandas) sb.writeln('  · $d');
    }
  }

  // Análise automática
  sb.writeln();
  sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  sb.writeln('📊 ANÁLISE AUTOMÁTICA');
  sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  sb.writeln('Situação geral: $situacaoEmoji $situacao');
  if (positivos.isNotEmpty) {
    sb.writeln();
    sb.writeln('Pontos positivos:');
    for (final p in positivos) sb.writeln('  ✓ $p');
  }
  if (atencoes.isNotEmpty) {
    sb.writeln();
    sb.writeln('Pontos de atenção:');
    for (final a in atencoes) sb.writeln('  ! $a');
  }
  if (recomendacoes.isNotEmpty) {
    sb.writeln();
    sb.writeln('Recomendações:');
    for (final r in recomendacoes) sb.writeln('  → $r');
  }

  final texto = sb.toString().trim();

  // ── Dialog ────────────────────────────────────────────────────────────
  // Cor do badge de situação
  final badgeColor = situacao == 'Saudável'
      ? AppColors.success
      : situacao == 'Atenção'
          ? AppColors.warning
          : AppColors.error;

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Relatório de Demandas')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    situacao == 'Saudável'
                        ? Icons.check_circle_rounded
                        : situacao == 'Atenção'
                            ? Icons.warning_rounded
                            : Icons.error_rounded,
                    size: 14,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    situacao,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: SelectableText(
            texto,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.65,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: texto));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Relatório copiado para a área de transferência')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar'),
        ),
      ],
    ),
  );
}
