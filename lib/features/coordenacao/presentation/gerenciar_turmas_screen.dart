import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/curso_tecnico.dart';
import '../domain/turma.dart';
import '../services/coordenacao_service.dart';
import '../services/cursos_tecnicos_service.dart';
import 'coordenacao_providers.dart';

class GerenciarTurmasScreen extends ConsumerWidget {
  const GerenciarTurmasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(turmasProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gerenciar Turmas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
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
                  const Text('Erro ao carregar turmas.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(turmasProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (turmas) => _TurmasList(turmas: turmas),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(context, ref, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Turma'),
      ),
    );
  }

  static void _showFormDialog(
      BuildContext context, WidgetRef ref, Turma? turma) {
    showDialog<void>(
      context: context,
      builder: (_) => _TurmaFormDialog(turma: turma, ref: ref),
    );
  }
}

// ─── Lista de turmas agrupada por turno ──────────────────────────────────────

class _TurmasList extends ConsumerWidget {
  final List<Turma> turmas;
  const _TurmasList({required this.turmas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (turmas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.class_outlined,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Nenhuma turma cadastrada.\nToque em + para adicionar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
            ),
          ],
        ),
      );
    }

    // Agrupa por turno
    final grupos = <Turno, List<Turma>>{};
    for (final t in turmas) {
      grupos.putIfAbsent(t.turno, () => []).add(t);
    }
    final ordenados = [
      Turno.matutino,
      Turno.integral,
      Turno.vespertino,
      Turno.noturno,
    ].where(grupos.containsKey).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (final turno in ordenados) ...[
          _TurnoHeader(turno: turno),
          const SizedBox(height: 8),
          for (final t in grupos[turno]!) ...[
            _TurmaCard(turma: t),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TurnoHeader extends StatelessWidget {
  final Turno turno;
  const _TurnoHeader({required this.turno});

  Color get _cor => switch (turno) {
        Turno.matutino   => const Color(0xFFF59E0B),
        Turno.vespertino => AppColors.primary,
        Turno.integral   => AppColors.secondary,
        Turno.noturno    => const Color(0xFF6366F1),
      };

  IconData get _icon => switch (turno) {
        Turno.matutino   => Icons.wb_sunny_rounded,
        Turno.vespertino => Icons.wb_twilight_rounded,
        Turno.integral   => Icons.brightness_5_rounded,
        Turno.noturno    => Icons.nights_stay_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, color: _cor, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          turno.label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _cor,
              ),
        ),
      ],
    );
  }
}

class _TurmaCard extends ConsumerStatefulWidget {
  final Turma turma;
  const _TurmaCard({required this.turma});

  @override
  ConsumerState<_TurmaCard> createState() => _TurmaCardState();
}

class _TurmaCardState extends ConsumerState<_TurmaCard> {
  bool _excluindo = false;

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 32),
        title: const Text('Excluir turma?'),
        content: Text(
          'A turma "${widget.turma.nome}" será removida permanentemente. '
          'Isso não afeta demandas já enviadas.',
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

    if (ok != true || !mounted) return;

    setState(() => _excluindo = true);
    try {
      await TurmasService.excluirTurma(widget.turma.id);
      if (!mounted) return;
      ref.invalidate(turmasProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.turma.nome,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.turma.serie.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.turma.serie,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (widget.turma.etapa != null ||
                    widget.turma.cursoTecnicoNome != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (widget.turma.etapa != null)
                        _Badge(
                          label: widget.turma.etapa!.label,
                          color: AppColors.secondary,
                        ),
                      if (widget.turma.cursoTecnicoNome != null)
                        _Badge(
                          label: widget.turma.cursoTecnicoNome!,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_excluindo)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.textSecondary),
              tooltip: 'Editar',
              onPressed: () => _showEditDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.error),
              tooltip: 'Excluir',
              onPressed: _excluir,
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _TurmaFormDialog(turma: widget.turma, ref: ref),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Dialog: criar/editar turma ───────────────────────────────────────────────

class _TurmaFormDialog extends StatefulWidget {
  final Turma? turma;
  final WidgetRef ref;
  const _TurmaFormDialog({required this.turma, required this.ref});

  @override
  State<_TurmaFormDialog> createState() => _TurmaFormDialogState();
}

class _TurmaFormDialogState extends State<_TurmaFormDialog> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _serieCtrl;
  late Turno  _turno;
  Etapa?      _etapa;
  String?     _cursoTecnicoId;
  List<CursoTecnico> _cursosTecnicos = [];
  bool _salvando       = false;
  bool _carregandoCursos = true;

  bool get _editando => widget.turma != null;

  @override
  void initState() {
    super.initState();
    _nomeCtrl       = TextEditingController(text: widget.turma?.nome  ?? '');
    _serieCtrl      = TextEditingController(text: widget.turma?.serie ?? '');
    _turno          = widget.turma?.turno ?? Turno.matutino;
    _etapa          = widget.turma?.etapa;
    _cursoTecnicoId = widget.turma?.cursoTecnicoId;
    _carregarCursos();
  }

  Future<void> _carregarCursos() async {
    try {
      final cursos = await CursosTecnicosService.getCursos();
      if (mounted) {
        setState(() {
          _cursosTecnicos   = cursos;
          _carregandoCursos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregandoCursos = false);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _serieCtrl.dispose();
    super.dispose();
  }

  // Quando o turno muda, garante que a etapa selecionada ainda é válida
  void _onTurnoChanged(Turno t) {
    setState(() {
      _turno = t;
      if (_etapa != null && !_etapa!.turnosValidos.contains(t)) {
        _etapa = null;
      }
    });
  }

  Future<void> _salvar() async {
    final nome  = _nomeCtrl.text.trim();
    final serie = _serieCtrl.text.trim();
    if (nome.isEmpty) return;

    setState(() => _salvando = true);
    try {
      if (_editando) {
        await TurmasService.editarTurma(
          id:             widget.turma!.id,
          nome:           nome,
          serie:          serie,
          turno:          _turno,
          etapa:          _etapa,
          cursoTecnicoId: _cursoTecnicoId,
        );
      } else {
        await TurmasService.criarTurma(
          nome:           nome,
          serie:          serie,
          turno:          _turno,
          etapa:          _etapa,
          cursoTecnicoId: _cursoTecnicoId,
        );
      }
      if (!mounted) return;
      widget.ref.invalidate(turmasProvider);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Etapas compatíveis com o turno selecionado
    final etapasVisiveis = Etapa.values
        .where((e) => e.turnosValidos.contains(_turno))
        .toList();

    return AlertDialog(
      title: Text(_editando ? 'Editar Turma' : 'Nova Turma'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome
            TextField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nome da turma *',
                hintText: 'Ex: 9A, 7B, 1ºEM',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Série
            TextField(
              controller: _serieCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Série',
                hintText: 'Ex: 9º Ano, 1º EM',
              ),
            ),
            const SizedBox(height: 16),

            // Turno
            Text('Turno',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Turno.values.map((t) {
                final sel = _turno == t;
                return FilterChip(
                  label: Text(t.label),
                  selected: sel,
                  onSelected: (_) => _onTurnoChanged(t),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  side: BorderSide(
                      color: sel ? AppColors.primary : AppColors.divider),
                  labelStyle: TextStyle(
                    color: sel ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Etapa de ensino
            Text('Etapa de ensino',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Define qual coordenador recebe as solicitações desta turma.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: etapasVisiveis.map((e) {
                final sel = _etapa == e;
                return FilterChip(
                  label: Text(e.label),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    _etapa = sel ? null : e;
                    // Curso técnico só faz sentido no Médio
                    if (_etapa != Etapa.medioParcial) _cursoTecnicoId = null;
                  }),
                  selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.secondary,
                  side: BorderSide(
                      color: sel ? AppColors.secondary : AppColors.divider),
                  labelStyle: TextStyle(
                    color: sel ? AppColors.secondary : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            // Curso técnico (apenas para Ensino Médio e quando há cursos cadastrados)
            if (!_carregandoCursos && _cursosTecnicos.isNotEmpty &&
                _etapa == Etapa.medioParcial) ...[
              const SizedBox(height: 16),
              Text('Curso Técnico',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Preencha se for uma turma do ensino técnico.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Nenhum'),
                    selected: _cursoTecnicoId == null,
                    onSelected: (_) =>
                        setState(() => _cursoTecnicoId = null),
                    selectedColor: AppColors.divider,
                    checkmarkColor: AppColors.textSecondary,
                    side: BorderSide(
                        color: _cursoTecnicoId == null
                            ? AppColors.textSecondary
                            : AppColors.divider),
                    labelStyle: TextStyle(
                      color: _cursoTecnicoId == null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: _cursoTecnicoId == null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  ..._cursosTecnicos.map((c) {
                    final sel = _cursoTecnicoId == c.id;
                    return FilterChip(
                      label: Text(c.nome),
                      selected: sel,
                      onSelected: (_) =>
                          setState(() => _cursoTecnicoId = sel ? null : c.id),
                      selectedColor:
                          AppColors.secondary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.secondary,
                      side: BorderSide(
                          color:
                              sel ? AppColors.secondary : AppColors.divider),
                      labelStyle: TextStyle(
                        color: sel
                            ? AppColors.secondary
                            : AppColors.textSecondary,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando || _nomeCtrl.text.trim().isEmpty ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_editando ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}
