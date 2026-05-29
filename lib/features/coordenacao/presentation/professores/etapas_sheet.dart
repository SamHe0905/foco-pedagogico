part of '../professores_screen.dart';

// ─── Sheet: etapas de ensino do coordenador ───────────────────────────────────

class _EtapasSheet extends StatefulWidget {
  final String    membroId;
  final WidgetRef ref;
  const _EtapasSheet({required this.membroId, required this.ref});

  @override
  State<_EtapasSheet> createState() => _EtapasSheetState();
}

class _EtapasSheetState extends State<_EtapasSheet> {
  Set<EtapaTurno> _selecionadas = {};
  bool _carregando = true;
  bool _salvando   = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista =
          await SolicitacoesService.getEtapasCoordenador(widget.membroId);
      if (mounted) setState(() { _selecionadas = lista.toSet(); _carregando = false; });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await SolicitacoesService.salvarEtapasCoordenador(
          widget.membroId, _selecionadas.toList());
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
          Text('Etapas de ensino',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Marque as etapas e turnos pelos quais este coordenador é responsável. '
            'Professores dessas etapas enviarão solicitações diretamente para ele.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_carregando)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: EtapaTurno.todas.map((et) {
                final sel = _selecionadas.contains(et);
                return FilterChip(
                  label: Text(et.label,
                      style: const TextStyle(fontSize: 13)),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _selecionadas.remove(et);
                    } else {
                      _selecionadas.add(et);
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
            onPressed: _salvando ? null : _salvar,
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
