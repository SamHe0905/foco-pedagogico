import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/turma.dart';
import '../services/coordenacao_service.dart';
import 'coordenacao_providers.dart';

class CriarDemandaScreen extends ConsumerStatefulWidget {
  const CriarDemandaScreen({super.key});

  @override
  ConsumerState<CriarDemandaScreen> createState() => _CriarDemandaScreenState();
}

class _CriarDemandaScreenState extends ConsumerState<CriarDemandaScreen> {
  final _tituloController    = TextEditingController();
  final _descricaoController = TextEditingController();

  String    _tipo       = 'geral';   // 'geral' | 'turma' | 'individual'
  String    _prioridade = 'media';
  DateTime? _prazo;

  // Seleções condicionais
  Turma?              _turmaSelecionada;
  List<ProfessorItem> _professoresSelecionados = [];

  // Anexos selecionados antes de enviar
  final List<PlatformFile> _arquivos = [];

  bool _enviando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _podeEnviar {
    if (_tituloController.text.trim().isEmpty) return false;
    if (_prazo == null) return false;
    if (_enviando) return false;
    if (_tipo == 'turma' && _turmaSelecionada == null) return false;
    if (_tipo == 'individual' && _professoresSelecionados.isEmpty) return false;
    return true;
  }

  Future<void> _adicionarArquivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    const limiteMb = 20;
    const limiteBytes = limiteMb * 1024 * 1024;

    int rejeitados = 0;
    final novos = <PlatformFile>[];
    for (final f in result.files) {
      if (f.size > limiteBytes) {
        rejeitados++;
      } else if (!_arquivos.any((a) => a.name == f.name)) {
        novos.add(f);
      }
    }

    setState(() => _arquivos.addAll(novos));

    if (rejeitados > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$rejeitados arquivo(s) ignorado(s): limite de $limiteMb MB por arquivo.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removerArquivo(int index) {
    setState(() => _arquivos.removeAt(index));
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: hoje.add(const Duration(days: 1)),
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

  Future<void> _enviar() async {
    if (!_podeEnviar) return;
    setState(() => _enviando = true);

    try {
      final demandaId = await CoordenacaoService.criarDemanda(
        titulo:       _tituloController.text,
        descricao:    _descricaoController.text,
        tipo:         _tipo,
        prazo:        _prazo!,
        prioridade:   _prioridade,
        turmaId:      _turmaSelecionada?.id,
        turmaNome:    _turmaSelecionada?.nome,
        turnoFiltro:  _turmaSelecionada?.turno.dbValue,
        professorIds: _professoresSelecionados.map((p) => p.id).toList(),
      );

      // Upload dos arquivos selecionados (se houver)
      for (final arquivo in _arquivos) {
        if (arquivo.bytes != null) {
          await CoordenacaoService.uploadAnexo(
            demandaId,
            arquivo.name,
            arquivo.bytes!,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demanda enviada com sucesso!'),
          backgroundColor: AppColors.statusConcluida,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gestão (diretor, dir. adjunto, secretaria) vê opção "Gestão" no lugar de "Coordenação"
    final showGestao =
        ref.watch(currentUserProvider).valueOrNull?.role.isDirector ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nova Demanda')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tipo ───────────────────────────────────────────────
                  _Label('Tipo de demanda'),
                  const SizedBox(height: 8),
                  _TipoSelector(
                    tipo: _tipo,
                    showGestao: showGestao,
                    onChanged: (v) => setState(() {
                      _tipo = v;
                      _turmaSelecionada        = null;
                      _professoresSelecionados  = [];
                    }),
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
                  _DatePicker(
                    prazo: _prazo,
                    onTap: _selecionarData,
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
                  const SizedBox(height: 20),

                  // ── Seção condicional ──────────────────────────────────
                  if (_tipo == 'turma') ...[
                    _Label('Turma'),
                    const SizedBox(height: 4),
                    Text(
                      'Selecione uma turma',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    _TurmaPicker(
                      selecionada: _turmaSelecionada,
                      onChanged: (t) => setState(() {
                        _turmaSelecionada = t;
                      }),
                    ),
                  ],

                  if (_tipo == 'individual') ...[
                    _Label('Professor'),
                    const SizedBox(height: 4),
                    Text(
                      'Selecione um ou mais professores',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    _ProfessorPicker(
                      selecionados: _professoresSelecionados,
                      onChanged: (p) => setState(() {
                        if (_professoresSelecionados.any((x) => x.id == p.id)) {
                          _professoresSelecionados.removeWhere((x) => x.id == p.id);
                        } else {
                          _professoresSelecionados.add(p);
                        }
                      }),
                    ),
                  ],

                  if (_tipo == 'geral') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esta demanda será enviada para todos os professores.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_tipo == 'coordenacao') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esta demanda será enviada para a coordenação '
                              'pedagógica (coordenação, supervisão, PCSA e PCPI), '
                              'exceto você.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_tipo == 'gestao') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryDark.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.domain_rounded,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esta demanda será enviada para a gestão '
                              '(Direção, Direção Adjunta e Secretaria), '
                              'exceto você.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Anexos (PDFs / Word opcionais) ─────────────────────
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.attach_file_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Anexos${_arquivos.isNotEmpty ? ' (${_arquivos.length})' : ''}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _enviando ? null : _adicionarArquivo,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Adicionar arquivo'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_arquivos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        'Nenhum arquivo adicionado.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    )
                  else
                    ...List.generate(_arquivos.length, (i) {
                      final f = _arquivos[i];
                      final kb = f.size / 1024;
                      final sizeLabel = kb >= 1024
                          ? '${(kb / 1024).toStringAsFixed(1)} MB'
                          : '${kb.toStringAsFixed(0)} KB';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded,
                                color: Color(0xFFE53935), size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    sizeLabel,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.error.withValues(alpha: 0.7),
                              ),
                              tooltip: 'Remover',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _removerArquivo(i),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Botão enviar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: _podeEnviar ? _enviar : null,
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _enviando && _arquivos.isNotEmpty
                      ? 'Enviando arquivos...'
                      : 'Enviar Demanda',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tipo selector ────────────────────────────────────────────────────────────

class _TipoSelector extends StatelessWidget {
  final String tipo;
  final ValueChanged<String> onChanged;
  /// Quando true, substitui "Coordenação" por "Gestão" (para diretores/secretaria).
  final bool showGestao;

  const _TipoSelector({
    required this.tipo,
    required this.onChanged,
    this.showGestao = false,
  });

  @override
  Widget build(BuildContext context) {
    // Diretores/secretaria têm 5 opções (inclui Gestão);
    // demais têm 4. Em 5 opções, "Coordenação" vira "Coord." para caber.
    final options = showGestao
        ? const [
            ('geral',       Icons.groups_rounded,               'Geral'),
            ('turma',       Icons.class_rounded,                'Turma'),
            ('individual',  Icons.person_rounded,               'Individual'),
            ('coordenacao', Icons.admin_panel_settings_rounded, 'Coord.'),
            ('gestao',      Icons.domain_rounded,               'Gestão'),
          ]
        : const [
            ('geral',       Icons.groups_rounded,               'Geral'),
            ('turma',       Icons.class_rounded,                'Turma'),
            ('individual',  Icons.person_rounded,               'Individual'),
            ('coordenacao', Icons.admin_panel_settings_rounded, 'Coordenação'),
          ];

    return Row(
      children: options.map((opt) {
        final (valor, icon, label) = opt;
        final ativo = tipo == valor;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(valor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  color: ativo
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ativo ? AppColors.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: ativo ? AppColors.primary : AppColors.textHint,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            ativo ? FontWeight.w600 : FontWeight.w400,
                        color: ativo
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Date picker ──────────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  final DateTime? prazo;
  final VoidCallback onTap;

  const _DatePicker({required this.prazo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: prazo != null
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: prazo != null ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(width: 12),
            Text(
              prazo == null
                  ? 'Selecionar data'
                  : '${prazo!.day.toString().padLeft(2, '0')}/${prazo!.month.toString().padLeft(2, '0')}/${prazo!.year}',
              style: TextStyle(
                fontSize: 14,
                color: prazo != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Turma picker (single-select) ─────────────────────────────────────────────

class _TurmaPicker extends ConsumerWidget {
  final Turma? selecionada;
  final ValueChanged<Turma?> onChanged;

  const _TurmaPicker({required this.selecionada, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(turmasProvider);

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
      error: (_, __) => Text(
        'Erro ao carregar turmas.',
        style: TextStyle(color: AppColors.error, fontSize: 13),
      ),
      data: (turmas) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: turmas.map((t) {
          final sel = selecionada?.id == t.id;
          return FilterChip(
            label: Text(t.nome),
            selected: sel,
            onSelected: (_) => onChanged(sel ? null : t),
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
    );
  }
}

// ─── Professor picker ─────────────────────────────────────────────────────────

class _ProfessorPicker extends ConsumerWidget {
  final List<ProfessorItem> selecionados;
  final ValueChanged<ProfessorItem> onChanged;

  const _ProfessorPicker({required this.selecionados, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(professoresProvider);

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
      error: (_, __) => Text(
        'Erro ao carregar professores.',
        style: TextStyle(color: AppColors.error, fontSize: 13),
      ),
      data: (professores) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: professores.map((p) {
          final sel = selecionados.any((x) => x.id == p.id);
          return FilterChip(
            label: Text(p.nome),
            selected: sel,
            onSelected: (_) => onChanged(p),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceVariant,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? AppColors.surface : AppColors.textSecondary,
            ),
            showCheckmark: true,
            side: BorderSide(
              color: sel ? AppColors.primary : Colors.transparent,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

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
  final String label;
  final String valor;
  final Color cor;
  final String selecionada;
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
          color: ativa ? cor.withValues(alpha: 0.12) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ativa ? cor : Colors.transparent,
            width: 1.5,
          ),
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
