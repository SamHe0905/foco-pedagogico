// Stub para builds não-web (Android, iOS).
// Todas as funções retornam valores neutros.

bool isStandalone()      => false;
bool isIOS()             => false;
bool hasInstallPrompt()  => false;
void triggerInstall()    {}
