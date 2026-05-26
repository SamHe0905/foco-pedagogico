import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

import '_pwa_detector_stub.dart'
    if (dart.library.js) '_pwa_detector_web.dart' as pwa;

/// Mostra um banner de instalação do PWA quando o app é acessado pelo browser.
/// Não aparece se o app já estiver instalado (modo standalone).
class PwaInstallBanner extends StatefulWidget {
  final Widget child;
  const PwaInstallBanner({super.key, required this.child});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  static bool _sessionDismissed = false;

  bool _showBanner = false;
  bool _isIOS      = false;
  bool _isAndroid  = false;
  bool _hasPrompt  = false;

  @override
  void initState() {
    super.initState();

    if (kIsWeb && !_sessionDismissed) {
      final standalone = pwa.isStandalone();
      if (!standalone) {
        _isIOS      = pwa.isIOS();
        _isAndroid  = pwa.isAndroid();
        _hasPrompt  = pwa.hasInstallPrompt();
        _showBanner = true;

        // Solicita permissão de notificação após um pequeno delay
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
        });
      }
    }
  }

  void _instalar() {
    pwa.triggerInstall();
    _fechar();
  }

  void _fechar() {
    setState(() {
      _sessionDismissed = true;
      _showBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: (_showBanner && !_sessionDismissed)
              ? _BannerCard(
                  isIOS:     _isIOS,
                  isAndroid: _isAndroid,
                  hasPrompt: _hasPrompt,
                  onInstall: _instalar,
                  onDismiss: _fechar,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final bool isIOS;
  final bool isAndroid;
  final bool hasPrompt;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  const _BannerCard({
    required this.isIOS,
    required this.isAndroid,
    required this.hasPrompt,
    required this.onInstall,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          elevation: 6,
          shadowColor: Colors.black26,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.install_mobile_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Adicione à tela inicial',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIOS
                            ? 'Toque em Compartilhar ↑ → "Adicionar à Tela de Início".'
                            : isAndroid && !hasPrompt
                                ? 'Toque nos 3 pontos ⋮ → "Adicionar à tela inicial".'
                                : hasPrompt
                                    ? 'Acesse mais rápido e receba notificações.'
                                    : 'No menu do navegador, escolha "Instalar app".',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (!isIOS && hasPrompt)
                  TextButton(
                    onPressed: onInstall,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    child: const Text('Instalar',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textHint),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
