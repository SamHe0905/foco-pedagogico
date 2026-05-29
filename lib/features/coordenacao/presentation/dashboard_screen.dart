import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/pwa_install_banner.dart';
import '../../../shared/widgets/saudacao_header.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/services/auth_service.dart';
import '../services/coordenacao_service.dart';
import '../../demandas/domain/demanda.dart';
import '../domain/demanda_resumo.dart';
import '../domain/professor_pendencias.dart';
import '../../solicitacoes/presentation/solicitacoes_providers.dart';
import '../../install/qr_install_dialog.dart';
import 'coordenacao_providers.dart';

// ─── Categoria constants ─────────────────────────────────────────────────────

const _categoriaLabels = {
  'geral': 'Geral',
  'turma': 'Por Turma',
  'individual': 'Individual',
  'coordenacao': 'Coordenação',
  'gestao': 'Gestão',
};

const _categoriaIcons = {
  'geral': Icons.campaign_rounded,
  'turma': Icons.class_rounded,
  'individual': Icons.person_rounded,
  'coordenacao': Icons.supervisor_account_rounded,
  'gestao': Icons.account_balance_rounded,
};

const _categoriaOrdem = [
  'geral', 'turma', 'individual', 'coordenacao', 'gestao'
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Set<String> _selectedIds = {};
  bool _excluindo = false;

  bool get _emModoSelecao => _selectedIds.isNotEmpty;

  void _iniciarSelecao(String id) => setState(() => _selectedIds.add(id));

  void _toggleSelecao(String id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });

  void _cancelarSelecao() => setState(() => _selectedIds.clear());

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

  Future<void> _excluirSelecionadas(List<DemandaResumo> demandas) async {
    final selecionadas =
        demandas.where((d) => _selectedIds.contains(d.id)).toList();
    final qtd = selecionadas.length;
    final naoConcluidas = selecionadas.where((d) => !d.todosConcluidam).length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          naoConcluidas > 0 ? Icons.warning_amber_rounded : Icons.delete_rounded,
          color: naoConcluidas > 0 ? AppColors.warning : AppColors.error,
          size: 32,
        ),
        title: Text('Excluir $qtd demanda${qtd > 1 ? 's' : ''}?'),
        content: Text(
          naoConcluidas > 0
              ? '$naoConcluidas demanda${naoConcluidas > 1 ? 's' : ''} ainda '
                  '${naoConcluidas > 1 ? 'não foram concluídas' : 'não foi concluída'}. '
                  'Deseja excluir mesmo assim?'
              : 'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _excluindo = true);
    try {
      for (final d in selecionadas) {
        await CoordenacaoService.excluirDemanda(d.id);
      }
      if (!mounted) return;
      _cancelarSelecao();
      ref.invalidate(coordenacaoDemandasProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coordenacaoDemandasProvider);
    final categoriaAtual = ref.watch(categoriaDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _DashboardDrawer(onRelatorio: () => _mostrarRelatorio(context, ref)),
      appBar: _emModoSelecao
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _cancelarSelecao,
              ),
              title: Text(
                '${_selectedIds.length} selecionada${_selectedIds.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              actions: [
                _excluindo
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        tooltip: 'Excluir selecionadas',
                        onPressed: () => async.whenData(_excluirSelecionadas),
                      ),
              ],
            )
          : categoriaAtual != null
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  ref.read(categoriaDashboardProvider.notifier).state = null;
                  _cancelarSelecao();
                },
              ),
              title: Text(_categoriaLabels[categoriaAtual] ?? categoriaAtual),
            )
          : AppBar(
              title: Image.asset(
                'assets/images/logo.png',
                height: 36,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
              actions: [
                // Toggle duplo acesso
                Consumer(builder: (context, ref, _) {
                  final userAsync = ref.watch(currentUserProvider);
                  return userAsync.maybeWhen(
                    data: (user) {
                      if (user == null ||
                          !user.temDuploAcesso ||
                          user.roleSecundario == null) {
                        return const SizedBox.shrink();
                      }
                      final isSecundary = ref.watch(viewAsSecundaryProvider);
                      final outroRole =
                          isSecundary ? user.role : user.roleSecundario!;
                      return IconButton(
                        icon: Icon(
                          outroRole.isDashboard
                              ? Icons.admin_panel_settings_rounded
                              : Icons.school_rounded,
                          color: isSecundary ? AppColors.secondary : null,
                        ),
                        tooltip: 'Ver como ${outroRole.cargo}',
                        onPressed: () {
                          final novo = !isSecundary;
                          ref.read(viewAsSecundaryProvider.notifier).state = novo;
                          context.go(homeRouteFor(
                              novo ? user.roleSecundario! : user.role));
                        },
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }),
                // Badge de solicitações pendentes
                Consumer(builder: (context, ref, _) {
                  final count = ref
                      .watch(solicitacoesPendentesCountProvider)
                      .maybeWhen(data: (n) => n, orElse: () => 0);
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: IconButton(
                      icon: const Icon(Icons.assignment_outlined),
                      tooltip: 'Solicitações recebidas',
                      onPressed: () {
                        context.push(AppRoutes.solicitacoesCoordenador);
                        ref.invalidate(solicitacoesPendentesCountProvider);
                      },
                    ),
                  );
                }),
              ],
            ),
      body: PwaInstallBanner(
        child: async.when(
        loading: () => const _LoadingState(),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(coordenacaoDemandasProvider),
        ),
        data: (demandas) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (_emModoSelecao) _cancelarSelecao();
            // ignore: unused_result
            ref.refresh(coordenacaoDemandasProvider);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: demandas.isEmpty
                  ? const _EmptyState()
                  : _DashboardContent(
                      demandas: demandas,
                      selectedIds: _selectedIds,
                      emModoSelecao: _emModoSelecao,
                      onLongPress: _iniciarSelecao,
                      onToggle: _toggleSelecao,
                    ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

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

// ─── Vista filtrada por categoria ────────────────────────────────────────────

enum _FiltroStatus { todas, andamento, concluidas, atrasadas }
enum _OrdemDemanda { prazo, prioridade, progresso, titulo }

class _CategoriaDemandasView extends StatefulWidget {
  final List<DemandaResumo> demandas;
  final Set<String> selectedIds;
  final bool emModoSelecao;
  final void Function(String id) onLongPress;
  final void Function(String id) onToggle;

  const _CategoriaDemandasView({
    required this.demandas,
    required this.selectedIds,
    required this.emModoSelecao,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  State<_CategoriaDemandasView> createState() => _CategoriaDemandasViewState();
}

class _CategoriaDemandasViewState extends State<_CategoriaDemandasView> {
  _FiltroStatus _filtro = _FiltroStatus.todas;
  _OrdemDemanda _ordem  = _OrdemDemanda.prazo;
  final _searchCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DemandaResumo> get _filtradas {
    var lista = switch (_filtro) {
      _FiltroStatus.todas      => widget.demandas,
      _FiltroStatus.andamento  => widget.demandas
          .where((d) => !d.todosConcluidam && !d.atrasada)
          .toList(),
      _FiltroStatus.concluidas => widget.demandas
          .where((d) => d.todosConcluidam)
          .toList(),
      _FiltroStatus.atrasadas  => widget.demandas
          .where((d) => d.atrasada)
          .toList(),
    };

    if (_busca.isNotEmpty) {
      final q = _busca.toLowerCase();
      lista = lista
          .where((d) =>
              d.titulo.toLowerCase().contains(q) ||
              d.turma.toLowerCase().contains(q))
          .toList();
    }

    lista = List.of(lista)
      ..sort((a, b) => switch (_ordem) {
            _OrdemDemanda.prazo      => a.prazo.compareTo(b.prazo),
            _OrdemDemanda.prioridade => _priorInt(a.prioridade)
                .compareTo(_priorInt(b.prioridade)),
            _OrdemDemanda.progresso  => a.progresso.compareTo(b.progresso),
            _OrdemDemanda.titulo     => a.titulo.compareTo(b.titulo),
          });

    return lista;
  }

  int _priorInt(PrioridadeDemanda p) => switch (p) {
        PrioridadeDemanda.alta  => 0,
        PrioridadeDemanda.media => 1,
        PrioridadeDemanda.baixa => 2,
      };

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── Busca + Ordenação ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por título ou turma...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _busca.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _busca = '';
                          }),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_OrdemDemanda>(
              icon: Icon(
                Icons.sort_rounded,
                color: _ordem != _OrdemDemanda.prazo
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              tooltip: 'Ordenar',
              onSelected: (o) => setState(() => _ordem = o),
              itemBuilder: (_) => [
                _ordemItem(_OrdemDemanda.prazo,      'Prazo',      Icons.calendar_today_rounded),
                _ordemItem(_OrdemDemanda.prioridade, 'Prioridade', Icons.flag_rounded),
                _ordemItem(_OrdemDemanda.progresso,  'Progresso',  Icons.pie_chart_rounded),
                _ordemItem(_OrdemDemanda.titulo,     'Título',     Icons.sort_by_alpha_rounded),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Chips de filtro ────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FiltroChip(
                label: 'Todas',
                ativo: _filtro == _FiltroStatus.todas,
                onTap: () => setState(() => _filtro = _FiltroStatus.todas),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Em andamento',
                ativo: _filtro == _FiltroStatus.andamento,
                onTap: () => setState(() => _filtro = _FiltroStatus.andamento),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Concluídas',
                ativo: _filtro == _FiltroStatus.concluidas,
                color: AppColors.statusConcluida,
                onTap: () => setState(() => _filtro = _FiltroStatus.concluidas),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Atrasadas',
                ativo: _filtro == _FiltroStatus.atrasadas,
                color: AppColors.error,
                onTap: () => setState(() => _filtro = _FiltroStatus.atrasadas),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Contador + hint ────────────────────────────────────────────────
        Row(
          children: [
            Text(
              '${lista.length} demanda${lista.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (!widget.emModoSelecao) ...[
              const Spacer(),
              Text(
                'Segure para selecionar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Lista ──────────────────────────────────────────────────────────
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'Nenhuma demanda neste filtro.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...lista.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DemandaCard(
                  demanda: d,
                  isSelected: widget.selectedIds.contains(d.id),
                  emModoSelecao: widget.emModoSelecao,
                  onLongPress: () => widget.onLongPress(d.id),
                  onToggle: () => widget.onToggle(d.id),
                ),
              )),
      ],
    );
  }
}

PopupMenuItem<_OrdemDemanda> _ordemItem(
    _OrdemDemanda v, String label, IconData icon) {
  return PopupMenuItem(
    value: v,
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label),
      ],
    ),
  );
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool ativo;
  final Color color;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.ativo,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ativo ? color : AppColors.divider,
            width: ativo ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
            color: ativo ? color : AppColors.textSecondary,
          ),
        ),
      ),
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

// ─── Resumo 2×2 ──────────────────────────────────────────────────────────────

class _ResumoGrid extends StatelessWidget {
  final int pendentes;
  final int concluidas;
  final int atrasadas;
  final int profPendentes;

  const _ResumoGrid({
    required this.pendentes,
    required this.concluidas,
    required this.atrasadas,
    required this.profPendentes,
  });

  void _mostrarProfsPendentes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProfsPendentesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _ResumoCard(
            icon:  Icons.schedule_rounded,
            value: '$pendentes',
            label: 'Em andamento',
            color: AppColors.primary,
          )),
          const SizedBox(width: 10),
          Expanded(child: _ResumoCard(
            icon:  Icons.check_circle_rounded,
            value: '$concluidas',
            label: 'Concluídas',
            color: AppColors.statusConcluida,
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ResumoCard(
            icon:  Icons.warning_amber_rounded,
            value: '$atrasadas',
            label: 'Atrasadas',
            color: atrasadas > 0 ? AppColors.error : AppColors.textHint,
            destaque: atrasadas > 0,
          )),
          const SizedBox(width: 10),
          Expanded(child: _ResumoCard(
            icon:  Icons.hourglass_top_rounded,
            value: '$profPendentes',
            label: 'Prof. pendentes',
            color: profPendentes > 0 ? AppColors.warning : AppColors.textHint,
            onTap: profPendentes > 0
                ? () => _mostrarProfsPendentes(context)
                : null,
          )),
        ]),
      ],
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool destaque;
  final VoidCallback? onTap;

  const _ResumoCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.destaque = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded,
              size: 14, color: color.withValues(alpha: 0.55)),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: color.withValues(alpha: destaque ? 0.1 : 0.06),
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: destaque ? 0.35 : 0.15),
                width: destaque ? 1.5 : 1,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

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
    return FilledButton.icon(
      onPressed: () async {
        await context.push(AppRoutes.criarDemanda);
        ref.invalidate(coordenacaoDemandasProvider);
      },
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Nova Demanda'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Drawer ───────────────────────────────────────────────────────────────────

class _DashboardDrawer extends ConsumerWidget {
  final VoidCallback onRelatorio;
  const _DashboardDrawer({required this.onRelatorio});

  void _navegar(BuildContext context, String route) {
    Navigator.pop(context); // fecha o drawer
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.maybeWhen(data: (u) => u, orElse: () => null);
    final isGestao = user != null && user.role.isDirector;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Foco Pedagógico',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // ── Demandas ──────────────────────────────────────────────────────
            _DrawerSection(titulo: 'Demandas'),
            _DrawerItem(
              icon: Icons.inbox_rounded,
              label: 'Minhas demandas recebidas',
              onTap: () => _navegar(context, AppRoutes.minhasDemandas),
            ),
            _DrawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Mural de Demandas',
              onTap: () => _navegar(context, AppRoutes.muralDemandas),
            ),
            _DrawerItem(
              icon: Icons.summarize_rounded,
              label: 'Relatório de pendências',
              onTap: () {
                Navigator.pop(context);
                onRelatorio();
              },
            ),

            // ── Escola ────────────────────────────────────────────────────────
            const Divider(),
            _DrawerSection(titulo: 'Escola'),
            _DrawerItem(
              icon: Icons.people_rounded,
              label: 'Equipe',
              onTap: () => _navegar(context, AppRoutes.professores),
            ),
            if (isGestao) ...[
              _DrawerItem(
                icon: Icons.class_rounded,
                label: 'Gerenciar Turmas',
                onTap: () => _navegar(context, AppRoutes.gerenciarTurmas),
              ),
              _DrawerItem(
                icon: Icons.engineering_rounded,
                label: 'Cursos Técnicos',
                onTap: () => _navegar(context, AppRoutes.gerenciarCursosTecnicos),
              ),
            ],

            // ── App ───────────────────────────────────────────────────────────
            const Divider(),
            _DrawerSection(titulo: 'App'),
            _DrawerItem(
              icon: Icons.qr_code_rounded,
              label: 'QR Code de instalação',
              onTap: () {
                Navigator.pop(context);
                showQrInstallDialog(context);
              },
            ),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Sair',
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(context);
                await AuthService.logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String titulo;
  const _DrawerSection({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _DrawerItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: TextStyle(
              color: c, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 8,
    );
  }
}
