part of '../professores_screen.dart';

// ─── Bottom sheet: integrar docente ──────────────────────────────────────────

class _IntegrarSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final bool isDirector;
  const _IntegrarSheet({required this.ref, required this.isDirector});

  @override
  ConsumerState<_IntegrarSheet> createState() => _IntegrarSheetState();
}

class _IntegrarSheetState extends ConsumerState<_IntegrarSheet> {
  final _emailController = TextEditingController();
  final _nomeController  = TextEditingController();
  String _roleSelecionada = 'professor';
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  List<(String, String)> get _opcoes =>
      widget.isDirector ? _rolesParaDiretor : _rolesParaCoordenador;

  bool get _podeEnviar =>
      _emailController.text.trim().isNotEmpty &&
      _nomeController.text.trim().isNotEmpty &&
      !_enviando;

  Future<void> _enviar() async {
    setState(() { _enviando = true; _erro = null; });
    try {
      await ConvitesService.integrarDocente(
        _emailController.text,
        _nomeController.text,
        _roleSelecionada,
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite enviado! O usuário receberá um e-mail.'),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
          Text('Integrar Docente',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'O usuário receberá um e-mail para definir sua senha e acessar o app.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Nome
          TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              hintText: 'Ex: Maria Silva',
            ),
          ),
          const SizedBox(height: 12),

          // E-mail
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'usuario@escola.com',
            ),
          ),
          const SizedBox(height: 16),

          // Seletor de cargo
          Text(
            'Cargo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _opcoes.map(((String, String) opt) {
              final (value, label) = opt;
              final sel = _roleSelecionada == value;
              return GestureDetector(
                onTap: () => setState(() => _roleSelecionada = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
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
              child: Text(
                _erro!,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.error),
              ),
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
              label: const Text('Enviar Convite'),
            ),
          ),
        ],
      ),
    );
  }
}
