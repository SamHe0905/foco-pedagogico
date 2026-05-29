part of '../professores_screen.dart';

// ─── Bottom sheet: criar demanda para selecionados ───────────────────────────

class _EnviarDemandaSheet extends StatefulWidget {
  final List<ProfessorPerfil> professores;
  final WidgetRef ref;
  const _EnviarDemandaSheet({required this.professores, required this.ref});

  @override
  State<_EnviarDemandaSheet> createState() => _EnviarDemandaSheetState();
}

class _EnviarDemandaSheetState extends State<_EnviarDemandaSheet> {
  final _tituloController    = TextEditingController();
  final _descricaoController = TextEditingController();
  DateTime _prazo    = DateTime.now().add(const Duration(days: 7));
  String _prioridade = 'media';
  bool _enviando     = false;
  String? _erro;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _podeEnviar =>
      _tituloController.text.trim().isNotEmpty && !_enviando;

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _prazo,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _prazo = picked);
  }

  Future<void> _enviar() async {
    setState(() { _enviando = true; _erro = null; });
    try {
      await CoordenacaoService.criarDemanda(
        titulo:       _tituloController.text,
        descricao:    _descricaoController.text,
        tipo:         'individual',
        prazo:        _prazo,
        prioridade:   _prioridade,
        professorIds: widget.professores.map((p) => p.id).toList(),
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        Navigator.of(context).pop();
        final n = widget.professores.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Demanda enviada para $n professor${n > 1 ? 'es' : ''}!',
            ),
            backgroundColor: AppColors.statusConcluida,
          ),
        );
      }
    } catch (e) {
      setState(() => _erro = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dd = _prazo.day.toString().padLeft(2, '0');
    final mm = _prazo.month.toString().padLeft(2, '0');
    final yyyy = _prazo.year;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            Text('Criar Demanda',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            // Chips dos professores selecionados
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.professores
                  .map((p) => Chip(
                        label: Text(p.nome,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(
                            color:
                                AppColors.primary.withValues(alpha: 0.30)),
                        labelStyle:
                            const TextStyle(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Título
            TextField(
              controller: _tituloController,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Título da demanda',
                hintText: 'Ex: Entregar planejamento semanal',
              ),
            ),
            const SizedBox(height: 12),

            // Descrição
            TextField(
              controller: _descricaoController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Prazo
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text('Prazo: $dd/$mm/$yyyy',
                        style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prioridade
            Text(
              'Prioridade',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final opt in const [
                  ('alta', 'Alta'),
                  ('media', 'Média'),
                  ('baixa', 'Baixa'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _prioridade = opt.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _prioridade == opt.$1
                              ? _prioridadeColor(opt.$1)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _prioridade == opt.$1
                                ? _prioridadeColor(opt.$1)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          opt.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _prioridade == opt.$1
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Erro
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_erro!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.error)),
              ),
            ],
            const SizedBox(height: 20),

            // Botão
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _podeEnviar ? _enviar : null,
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.surface),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_enviando ? 'Enviando…' : 'Enviar Demanda'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _prioridadeColor(String p) => switch (p) {
        'alta'  => AppColors.error,
        'baixa' => AppColors.statusConcluida,
        _       => AppColors.secondary,
      };
}
