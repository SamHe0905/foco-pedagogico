import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// Importação condicional: web usa dart:js, outras plataformas usam stub.
import '_pwa_detector_stub.dart'
    if (dart.library.js) '_pwa_detector_web.dart' as pwa;

/// Wrapper que exibe, uma vez por sessão, um banner incentivando o usuário a
/// instalar o app na tela inicial (PWA).
///
/// Uso — envolva o body de qualquer Scaffold principal:
/// ```dart
/// body: const PwaInstallBanner(child: MinhaTelaBody()),
/// ```
class PwaInstallBanner extends StatefulWidget {
  final Widget child;
  const PwaInstallBanner({super.key, required this.child});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner>
    with SingleTickerProviderStateMixin {
  // Estático: persiste enquanto o app estiver aberto na mesma aba.
  static bool _sessionDismissed = false;

  bool _showBanner = false;
  bool _isIOS      = false;
  bool _hasPrompt  = false;

  late final AnimationController _anim;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    if (kIsWeb && !_sessionDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkPwa());
    }
  }

  void _checkPwa() {
    if (_sessionDismissed) return;

    // Já instalado como PWA? Não exibe.
    if (pwa.isStandalone()) return;

    _isIOS     = pwa.isIOS();
    _hasPrompt = pwa.hasInstallPrompt();

    // Mostra sempre que não estiver instalado
    setState(() => _showBanner = true);
    _anim.forward();
  }

  void _instalar() {
    pwa.triggerInstall();
    _fechar();
  }

  void _fechar() {
    _anim.reverse().then((_) {
      if (mounted) {
        setState(() {
          _sessionDismissed = true;
          _showBanner = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (kIsWeb && _showBanner && !_sessionDismissed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slide,
              child: _BannerCard(
                isIOS:     _isIOS,
                hasPrompt: _hasPrompt,
                onInstall: _instalar,
                onDismiss: _fechar,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Card do banner ───────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final bool isIOS;
  final bool hasPrompt;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  const _BannerCard({
    required this.isIOS,
    required this.hasPrompt,
    required this.onInstall,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          shadowColor: Colors.black26,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                // Ícone
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.install_mobile_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),

                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Adicione à tela inicial',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIOS
                            ? 'Toque em Compartilhar ↑ → "Adicionar à Tela de Início".'
                            : hasPrompt
                                ? 'Acesse mais rápido e receba notificações em tempo real.'
                                : 'No menu do navegador, escolha "Instalar app" ou "Adicionar à tela inicial".',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Botão principal — apenas Chrome/Edge com prompt disponível
                if (!isIOS && hasPrompt)
                  TextButton(
                    onPressed: onInstall,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Instalar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),

                // Fechar
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
