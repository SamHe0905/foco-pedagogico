part of '../professores_screen.dart';

// ─── Bottom sheet: gerenciar turmas ──────────────────────────────────────────

class _TurmasSheet extends ConsumerStatefulWidget {
  final ProfessorPerfil membro;
  final WidgetRef ref;
  const _TurmasSheet({required this.membro, required this.ref});

  @override
  ConsumerState<_TurmasSheet> createState() => _TurmasSheetState();
}

class _TurmasSheetState extends ConsumerState<_TurmasSheet> {
  late Set<String> _selecionadas;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _selecionadas = widget.membro.turmas.map((t) => t.id).toSet();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await EquipeService.atualizarTurmasProfessor(
        widget.membro.id,
        _selecionadas.toList(),
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turmas atualizadas!'),
            backgroundColor: AppColors.statusConcluida,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar turmas.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final turmasAsync = ref.watch(turmasProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Turmas de ${widget.membro.nome}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          turmasAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
            error: (_, __) => const Text('Erro ao carregar turmas.'),
            data: (turmas) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: turmas.map((t) {
                final sel = _selecionadas.contains(t.id);
                return FilterChip(
                  label: Text(t.nomeCompleto),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _selecionadas.remove(t.id);
                    } else {
                      _selecionadas.add(t.id);
                    }
                  }),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? AppColors.surface : AppColors.textSecondary,
                  ),
                  showCheckmark: false,
                  side: BorderSide(
                    color: sel ? AppColors.primary : Colors.transparent,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Salvar Turmas'),
            ),
          ),
        ],
      ),
    );
  }
}
