import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/demanda_resumo.dart';
import '../services/coordenacao_service.dart';
import 'coordenacao_providers.dart';

class EditarDemandaScreen extends ConsumerStatefulWidget {
  final DemandaResumo demanda;
  const EditarDemandaScreen({super.key, required this.demanda});

  @override
  ConsumerState<EditarDemandaScreen> createState() => _EditarDemandaScreenState();
}

class _EditarDemandaScreenState extends ConsumerState<EditarDemandaScreen> {
  late final TextEditingController _tituloController;
  late final TextEditingController _descricaoController;
  late String    _prioridade;
  late DateTime  _prazo;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tituloController    = TextEditingController(text: widget.demanda.titulo);
    _descricaoController = TextEditingController(text: widget.demanda.descricao);
    _prioridade          = widget.demanda.prioridade.name; // 'alta'|'media'|'baixa'
    _prazo               = widget.demanda.prazo;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _podeEnviar =>
      _tituloController.text.trim().isNotEmpty && !_salvando;

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _prazo.isBefore(hoje) ? hoje : _prazo,
      firstDate: hoje,
      lastDate: hoje.add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (data != null) setState(() => _prazo = data);
  }

  Future<void> _salvar() async {
    if (!_podeEnviar) return;
    setState(() => _salvando = true);

    try {
      await DemandasCoordenacaoService.editarDemanda(
        demandaId: widget.demanda.id,
        titulo:    _tituloController.text,
        descricao: _descricaoController.text,
        prazo:     _prazo,
        prioridade: _prioridade,
      );

      if (!mounted) return;
      ref.invalidate(coordenacaoDemandasProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demanda atualizada com sucesso!'),
          backgroundColor: AppColors.statusConcluida,
        ),
      );
      Navigator.of(context).pop(true); // retorna true = houve alteração
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar. Tente novamente.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Editar Demanda')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info sobre o que não muda
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tipo e destinatários não podem ser alterados.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Título ─────────────────────────────────────────────
                  _Label('Título'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tituloController,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Ex: Entregar notas do 3º bimestre',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Descrição ──────────────────────────────────────────
                  _Label('Descrição (opcional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descricaoController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Detalhe a solicitação...',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Prazo ──────────────────────────────────────────────
                  _Label('Prazo'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selecionarData,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            '${_prazo.day.toString().padLeft(2, '0')}/${_prazo.month.toString().padLeft(2, '0')}/${_prazo.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Prioridade ─────────────────────────────────────────
                  _Label('Prioridade'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PrioridadeChip(
                        label: 'Alta',
                        valor: 'alta',
                        cor: AppColors.error,
                        selecionada: _prioridade,
                        onTap: (v) => setState(() => _prioridade = v),
                      ),
                      const SizedBox(width: 8),
                      _PrioridadeChip(
                        label: 'Média',
                        valor: 'media',
                        cor: AppColors.warning,
                        selecionada: _prioridade,
                        onTap: (v) => setState(() => _prioridade = v),
                      ),
                      const SizedBox(width: 8),
                      _PrioridadeChip(
                        label: 'Baixa',
                        valor: 'baixa',
                        cor: AppColors.primary,
                        selecionada: _prioridade,
                        onTap: (v) => setState(() => _prioridade = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Botão salvar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: _podeEnviar ? _salvar : null,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.surface),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Salvar Alterações'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      );
}

class _PrioridadeChip extends StatelessWidget {
  final String label, valor, selecionada;
  final Color cor;
  final ValueChanged<String> onTap;

  const _PrioridadeChip({
    required this.label,
    required this.valor,
    required this.cor,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ativa = selecionada == valor;
    return GestureDetector(
      onTap: () => onTap(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              ativa ? cor.withValues(alpha: 0.12) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: ativa ? cor : Colors.transparent, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: ativa ? FontWeight.w600 : FontWeight.w400,
            color: ativa ? cor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
