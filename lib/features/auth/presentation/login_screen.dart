import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _verificarSessaoExistente();
  }

  /// Se o app foi fechado e reaberto com sessão válida ainda no storage,
  /// navega diretamente para a home sem exigir novo login.
  Future<void> _verificarSessaoExistente() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final usuario = await AuthService.buscarUsuarioAtual();
      if (!mounted) return;
      if (usuario != null) {
        context.go(homeRouteFor(usuario.role));
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _limparErro() {
    if (_erro != null) setState(() => _erro = null);
  }

  Future<void> _entrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final usuario = await AuthService.login(
        _emailController.text,
        _senhaController.text,
      );

      if (!mounted) return;
      context.go(homeRouteFor(usuario.role));
    } on AppAuthException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 28,
                vertical: isWide ? 40 : 0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: isWide ? 16 : 32),
                    _LogoHeader(),
                    const SizedBox(height: 36),
                Text(
                  'Bem-vindo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Entre com sua conta para continuar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 36),

                // ── E-mail ────────────────────────────────────────────────
                Text('E-mail', style: _labelStyle(context)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  onChanged: (_) => _limparErro(),
                  decoration: const InputDecoration(
                    hintText: 'seu@email.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe seu e-mail';
                    if (!v.contains('@')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Senha ─────────────────────────────────────────────────
                Text('Senha', style: _labelStyle(context)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _senhaController,
                  obscureText: !_senhaVisivel,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _limparErro(),
                  onFieldSubmitted: (_) => _entrar(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _senhaVisivel
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      onPressed: () =>
                          setState(() => _senhaVisivel = !_senhaVisivel),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe sua senha';
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _mostrarEsqueciSenha(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Esqueci minha senha'),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Erro ──────────────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _erro != null
                      ? _ErroBanner(mensagem: _erro!)
                      : const SizedBox.shrink(),
                ),

                // ── Botão ─────────────────────────────────────────────────
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _loading ? null : _entrar,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 16),

                // ── Criar conta ───────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.cadastro),
                    child: const Text('Não tenho conta — Criar conta'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  void _mostrarEsqueciSenha(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EsqueciSenhaDialog(
        emailInicial: _emailController.text.trim(),
      ),
    );
  }

  TextStyle _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          );
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _LogoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 180,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _ErroBanner extends StatelessWidget {
  final String mensagem;
  const _ErroBanner({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog: recuperar senha ──────────────────────────────────────────────────

class _EsqueciSenhaDialog extends StatefulWidget {
  final String emailInicial;
  const _EsqueciSenhaDialog({required this.emailInicial});

  @override
  State<_EsqueciSenhaDialog> createState() => _EsqueciSenhaDialogState();
}

class _EsqueciSenhaDialogState extends State<_EsqueciSenhaDialog> {
  late final TextEditingController _ctrl;
  bool    _enviando = false;
  bool    _enviado  = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.emailInicial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _ctrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _erro = 'Informe um e-mail válido.');
      return;
    }
    setState(() { _enviando = true; _erro = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://foco-pedagogico.vercel.app/auth/callback',
      );
      if (mounted) setState(() { _enviado = true; _enviando = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro     = 'Não foi possível enviar. Verifique o e-mail.';
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_enviado ? 'E-mail enviado!' : 'Recuperar senha'),
      content: _enviado
          ? Text(
              'Enviamos um link para ${_ctrl.text.trim()}.\n\n'
              'Clique no link para criar uma nova senha.',
              style: const TextStyle(height: 1.5),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informe seu e-mail para receber o link de redefinição.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  onSubmitted: (_) => _enviar(),
                  onChanged:   (_) => setState(() => _erro = null),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _erro!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.error),
                  ),
                ],
              ],
            ),
      actions: _enviado
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enviar'),
              ),
            ],
    );
  }
}
