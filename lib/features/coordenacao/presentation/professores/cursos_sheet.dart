part of '../professores_screen.dart';

// ─── Sheet: cursos técnicos do supervisor ─────────────────────────────────────

class _CursosSheet extends StatefulWidget {
  final String    membroId;
  final WidgetRef ref;
  const _CursosSheet({required this.membroId, required this.ref});

  @override
  State<_CursosSheet> createState() => _CursosSheetState();
}

class _CursosSheetState extends State<_CursosSheet> {
  List<CursoTecnico> _todos        = [];
  Set<String>        _selecionados = {};
  bool _carregando = true;
  bool _salvando   = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final cursos  = await CursosTecnicosService.getCursos();
      final vinculados = await CursosTecnicosService.getCursoIdsSupervisor(
          widget.membroId);
      if (mounted) {
        setState(() {
          _todos        = cursos;
          _selecionados = vinculados.toSet();
          _carregando   = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await CursosTecnicosService.salvarCursosSupervisor(
          widget.membroId, _selecionados.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Cursos técnicos',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Marque os cursos pelos quais este supervisor é responsável. '
            'Professores de turmas desses cursos também enviarão solicitações para ele.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_carregando)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_todos.isEmpty)
            const Text(
              'Nenhum curso técnico cadastrado. Peça à gestão que cadastre os cursos primeiro.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _todos.map((c) {
                final sel = _selecionados.contains(c.id);
                return FilterChip(
                  label: Text(c.nome,
                      style: const TextStyle(fontSize: 13)),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _selecionados.remove(c.id);
                    } else {
                      _selecionados.add(c.id);
                    }
                  }),
                  selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.secondary,
                  side: BorderSide(
                    color: sel ? AppColors.secondary : AppColors.divider,
                  ),
                  labelStyle: TextStyle(
                    color: sel ? AppColors.secondary : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_salvando || _todos.isEmpty) ? null : _salvar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            child: _salvando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
