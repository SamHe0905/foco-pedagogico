import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Verifica se o professor abriu o app via QR code de instalação
/// e exibe o dialog apropriado.
void checkAndShowInstallDialog(BuildContext context) {
  final requested =
      html.window.sessionStorage['pwa_install_requested'] == '1';
  if (!requested) return;

  html.window.sessionStorage.remove('pwa_install_requested');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _InstallDialog(),
    );
  });
}

class _InstallDialog extends StatefulWidget {
  const _InstallDialog();

  @override
  State<_InstallDialog> createState() => _InstallDialogState();
}

class _InstallDialogState extends State<_InstallDialog> {
  // true  → Chrome/Edge/Android: prompt nativo disponível
  // false → Safari/iOS: mostra instruções manuais
  late final bool _podeInstalarNativo;

  @override
  void initState() {
    super.initState();
    _podeInstalarNativo =
        js.context.callMethod('canInstallPwa') as bool? ?? false;
  }

  void _instalarNativo() {
    js.context.callMethod('triggerPwaInstall');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.install_mobile_rounded,
                  size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Instalar Foco Pedagógico',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione o app à sua tela inicial para acessar mais rápido, mesmo sem digitar o endereço.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_podeInstalarNativo) ...[
              // Chrome / Edge / Android — prompt nativo
              FilledButton.icon(
                onPressed: _instalarNativo,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Instalar agora'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              // Safari / iOS — instruções manuais
              _Instrucao(
                icone: Icons.ios_share_rounded,
                texto: 'Toque no botão Compartilhar',
                detalhe: '(ícone no centro da barra inferior do Safari)',
              ),
              const SizedBox(height: 12),
              _Instrucao(
                icone: Icons.add_box_outlined,
                texto: 'Toque em "Adicionar à Tela de Início"',
                detalhe: 'Role a lista de opções para encontrar',
              ),
              const SizedBox(height: 12),
              _Instrucao(
                icone: Icons.check_circle_outline_rounded,
                texto: 'Confirme tocando em "Adicionar"',
                detalhe: 'O app aparecerá na tela inicial',
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            _podeInstalarNativo ? 'Agora não' : 'Entendi',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _Instrucao extends StatelessWidget {
  final IconData icone;
  final String texto;
  final String detalhe;
  const _Instrucao(
      {required this.icone, required this.texto, required this.detalhe});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(detalhe,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
