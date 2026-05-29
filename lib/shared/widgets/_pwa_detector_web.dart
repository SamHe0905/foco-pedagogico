// Implementação web do detector de PWA.
// Importado condicionalmente apenas em targets web.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js' as js;

bool isStandalone() {
  try {
    final mq = js.context.callMethod('matchMedia', ['(display-mode: standalone)']);
    return mq['matches'] as bool? ?? false;
  } catch (_) {
    return false;
  }
}

bool isIOS() {
  try {
    final ua = (js.context['navigator']['userAgent'] as String? ?? '').toLowerCase();
    final touch = js.context['navigator']['maxTouchPoints'] as int? ?? 0;
    return ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        (ua.contains('mac') && touch > 1);
  } catch (_) {
    return false;
  }
}

bool isAndroid() {
  try {
    final ua = (js.context['navigator']['userAgent'] as String? ?? '').toLowerCase();
    return ua.contains('android');
  } catch (_) {
    return false;
  }
}

bool hasInstallPrompt() {
  try {
    return js.context['deferredInstallPrompt'] != null;
  } catch (_) {
    return false;
  }
}

void triggerInstall() {
  try {
    js.context.callMethod('triggerPwaInstall');
  } catch (_) {}
}
