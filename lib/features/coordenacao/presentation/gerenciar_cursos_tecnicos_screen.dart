import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/curso_tecnico.dart';
import '../services/cursos_tecnicos_service.dart';
import 'coordenacao_providers.dart';

class GerenciarCursosTecnicosScreen extends ConsumerWidget {
  const GerenciarCursosTecnicosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cursosTecnicosProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cursos Técnicos')),
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
                onPressed: () => ref.invalidate(cursosTecnicosProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ),
            data: (cursos) => cursos.isEmpty
                ? _EmptyState(
                    onAdd: () => _showFormDialog(context, ref, null))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: cursos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _CursoCard(
                      curso: cursos[i],
                      onEdited: () => ref.invalidate(cursosTecnicosProvider),
                    ),
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(context, ref, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Curso'),
      ),
    );
  }

  static void _showFormDialog(
      BuildContext context, WidgetRef ref, CursoTecnico? curso) {
    showDialog<void>(
      context: context,
      builder: (_) => _CursoFormDialog(curso: curso, ref: ref),
    );
  }
}

// ─── Card de curso ────────────────────────────────────────────────────────────

class _CursoCard extends ConsumerStatefulWidget {
  final CursoTecnico curso;
  final VoidCallback onEdited;
  const _CursoCard({required this.curso, required this.onEdited});

  @override
  ConsumerState<_CursoCard> createState() => _CursoCardState();
}

class _CursoCardState extends ConsumerState<_CursoCard> {
  bool _excluindo = false;

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 32),
        title: const Text('Excluir curso?'),
        content: Text(
          'O curso "${widget.curso.nome}" será removido. '
          'As turmas vinculadas a ele perderão essa associação.',
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
      await CursosTecnicosService.excluirCurso(widget.curso.id);
      if (!mounted) return;
      widget.onEdited();
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.engineering_rounded,
                size: 18, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.curso.nome,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
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
      builder: (_) => _CursoFormDialog(curso: widget.curso, ref: ref),
    ).then((_) => widget.onEdited());
  }
}

// ─── Dialog: criar/editar curso ───────────────────────────────────────────────

class _CursoFormDialog extends StatefulWidget {
  final CursoTecnico? curso;
  final WidgetRef ref;
  const _CursoFormDialog({required this.curso, required this.ref});

  @override
  State<_CursoFormDialog> createState() => _CursoFormDialogState();
}

class _CursoFormDialogState extends State<_CursoFormDialog> {
  late final TextEditingController _nomeCtrl;
  bool _salvando = false;

  bool get _editando => widget.curso != null;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.curso?.nome ?? '');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    setState(() => _salvando = true);
    try {
      if (_editando) {
        await CursosTecnicosService.editarCurso(widget.curso!.id, nome);
      } else {
        await CursosTecnicosService.criarCurso(nome);
      }
      if (!mounted) return;
      widget.ref.invalidate(cursosTecnicosProvider);
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
    return AlertDialog(
      title: Text(_editando ? 'Editar Curso' : 'Novo Curso Técnico'),
      content: TextField(
        controller: _nomeCtrl,
        textCapitalization: TextCapitalization.words,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome do curso *',
          hintText: 'Ex: Serviços Jurídicos, Marketing',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _salvando ? null : _salvar(),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando || _nomeCtrl.text.trim().isEmpty
              ? null
              : _salvar,
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

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.book_outlined, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Nenhum curso técnico cadastrado.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar curso'),
          ),
        ],
      ),
    );
  }
}
