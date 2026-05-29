import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../features/coordenacao/domain/demanda_anexo.dart';
import '../../features/coordenacao/presentation/coordenacao_providers.dart';
import '../../features/coordenacao/services/coordenacao_service.dart';

/// Seção de anexos de PDF — usada tanto na tela da coordenação (podeEditar: true)
/// quanto na tela do professor (podeEditar: false).
class AnexosSection extends ConsumerStatefulWidget {
  final String demandaId;
  final bool podeEditar;

  const AnexosSection({
    super.key,
    required this.demandaId,
    this.podeEditar = false,
  });

  @override
  ConsumerState<AnexosSection> createState() => _AnexosSectionState();
}

class _AnexosSectionState extends ConsumerState<AnexosSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      await AnexosService.uploadAnexo(
        widget.demandaId,
        file.name,
        file.bytes!,
      );
      ref.invalidate(anexosProvider(widget.demandaId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(DemandaAnexo anexo) async {
    try {
      await AnexosService.deleteAnexo(anexo.id, anexo.storagePath);
      ref.invalidate(anexosProvider(widget.demandaId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover arquivo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(anexosProvider(widget.demandaId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (anexos) {
        // Professor sem anexos → não exibe a seção
        if (anexos.isEmpty && !widget.podeEditar) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.attach_file_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Anexos${anexos.isNotEmpty ? ' (${anexos.length})' : ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (widget.podeEditar)
                  _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : TextButton.icon(
                          onPressed: _pickAndUpload,
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text('Anexar arquivo'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Lista ───────────────────────────────────────────────────────
            if (anexos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  'Nenhum arquivo anexado.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              )
            else
              ...anexos.map(
                (a) => _AnexoTile(
                  anexo: a,
                  podeEditar: widget.podeEditar,
                  onDelete: () => _delete(a),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Tile de um arquivo ───────────────────────────────────────────────────────

class _AnexoTile extends StatelessWidget {
  final DemandaAnexo anexo;
  final bool podeEditar;
  final VoidCallback onDelete;

  const _AnexoTile({
    required this.anexo,
    required this.podeEditar,
    required this.onDelete,
  });

  Future<void> _abrir(BuildContext context) async {
    final uri = Uri.parse(anexo.url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
        );
      }
    }
  }

  /// Retorna (ícone, cor) baseado na extensão do arquivo
  (IconData, Color) _iconForFile(String nome) {
    final ext = nome.toLowerCase().split('.').last;
    return switch (ext) {
      'pdf'         => (Icons.picture_as_pdf_rounded,    const Color(0xFFE53935)),
      'doc' || 'docx' => (Icons.description_rounded,     const Color(0xFF1976D2)),
      _             => (Icons.insert_drive_file_rounded, AppColors.textSecondary),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _iconForFile(anexo.nome);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anexo.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (anexo.tamanhoLabel.isNotEmpty)
                  Text(
                    anexo.tamanhoLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
              ],
            ),
          ),
          // Abrir
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded,
                size: 18, color: AppColors.primary),
            tooltip: 'Abrir',
            visualDensity: VisualDensity.compact,
            onPressed: () => _abrir(context),
          ),
          // Excluir (só coordenação)
          if (podeEditar)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error.withValues(alpha: 0.7)),
              tooltip: 'Remover',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
