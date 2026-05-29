import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../services/solicitacoes_service.dart';
import 'solicitacoes_providers.dart';

class NovaSolicitacaoScreen extends ConsumerStatefulWidget {
  const NovaSolicitacaoScreen({super.key});

  @override
  ConsumerState<NovaSolicitacaoScreen> createState() =>
      _NovaSolicitacaoScreenState();
}

class _NovaSolicitacaoScreenState extends ConsumerState<NovaSolicitacaoScreen> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();

  // Turmas do professor (carregadas no initState)
  List<_TurmaOpcao> _turmas = [];
  _TurmaOpcao? _turmaSelecionada;
  bool _carregandoTurmas = true;

  // Anexos pendentes (antes de criar a solicitação)
  final List<_AnexoPendente> _anexos = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarTurmas() async {
    try {
      final db     = Supabase.instance.client;
      final userId = db.auth.currentUser!.id;

      // Busca turmas do professor com etapa, turno e curso técnico
      final rows = await db
          .from('professor_turmas')
          .select('turmas(id, nome, turno, etapa, curso_tecnico_id)')
          .eq('professor_id', userId);

      final turmas = (rows as List).map((r) {
        final t = r['turmas'] as Map<String, dynamic>;
        return _TurmaOpcao(
          id:             t['id']    as String,
          nome:           t['nome']  as String,
          turno:          t['turno'] as String? ?? '',
          etapa:          t['etapa'] as String?,
          cursoTecnicoId: t['curso_tecnico_id'] as String?,
        );
      }).where((t) => t.etapa != null).toList();

      if (mounted) setState(() { _turmas = turmas; _carregandoTurmas = false; });
    } catch (_) {
      if (mounted) setState(() => _carregandoTurmas = false);
    }
  }

  Future<void> _adicionarAnexo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _anexos.add(_AnexoPendente(nome: file.name, bytes: file.bytes!));
    });
  }

  bool get _podeSalvar =>
      _tituloCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      _turmaSelecionada != null &&
      !_salvando;

  Future<void> _salvar() async {
    if (!_podeSalvar) return;
    setState(() => _salvando = true);
    try {
      final turma = _turmaSelecionada!;
      final id = await SolicitacoesService.criarSolicitacao(
        titulo:              _tituloCtrl.text.trim(),
        descricao:           _descCtrl.text.trim(),
        turmaId:             turma.id,
        turmaNome:           turma.nome,
        turmaEtapa:          turma.etapa,
        turmaTurno:          turma.turno,
        turmaCursoTecnicoId: turma.cursoTecnicoId,
      );

      // Upload dos anexos
      for (final a in _anexos) {
        await SolicitacoesService.uploadAnexo(id, a.nome, a.bytes);
      }

      if (!mounted) return;
      ref.invalidate(minhasSolicitacoesProvider);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
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
      appBar: AppBar(title: const Text('Nova Solicitação')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              // Título
              TextField(
                controller: _tituloCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  hintText: 'Ex: Impressão de provas — 9A',
                  filled: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Descrição
              TextField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                  hintText: 'Descreva o que você precisa...',
                  alignLabelWithHint: true,
                  filled: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Turma
              Text('Turma *',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _carregandoTurmas
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _turmas.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'Você não tem turmas com etapa de ensino configurada. '
                            'Solicite ao coordenador que configure as etapas.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _turmas.map((t) {
                            final sel = _turmaSelecionada == t;
                            return FilterChip(
                              label: Text(t.nome),
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _turmaSelecionada = sel ? null : t),
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              checkmarkColor: AppColors.primary,
                              side: BorderSide(
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.divider),
                              labelStyle: TextStyle(
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          }).toList(),
                        ),
              const SizedBox(height: 20),

              // Anexos
              Row(
                children: [
                  Text('Anexos',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _adicionarAnexo,
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: const Text('Adicionar'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_anexos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum anexo adicionado.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                )
              else
                ..._anexos.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_rounded,
                        color: AppColors.primary),
                    title: Text(a.nome,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${(a.bytes.length / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.error),
                      onPressed: () =>
                          setState(() => _anexos.removeAt(i)),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Botão enviar
              FilledButton.icon(
                onPressed: _podeSalvar ? _salvar : null,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Enviar Solicitação'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurmaOpcao {
  final String  id;
  final String  nome;
  final String  turno;
  final String? etapa;
  final String? cursoTecnicoId;
  const _TurmaOpcao({
    required this.id,
    required this.nome,
    required this.turno,
    this.etapa,
    this.cursoTecnicoId,
  });
}

class _AnexoPendente {
  final String    nome;
  final Uint8List bytes;
  const _AnexoPendente({required this.nome, required this.bytes});
}
