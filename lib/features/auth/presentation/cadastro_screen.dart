import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../domain/usuario.dart';
import '../services/auth_service.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nomeCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _senhaCtrl      = TextEditingController();
  final _confirmaCtrl   = TextEditingController();
  bool  _obscureSenha   = true;
  bool  _obscureConfirma = true;
  bool  _loading        = false;
  String? _erro;
  bool  _confirmacaoEnviada = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _erro = null; });

    try {
      final client = Supabase.instance.client;
      final response = await client.auth.signUp(
        email:    _emailCtrl.text.trim(),
        password: _senhaCtrl.text.trim(),
        data:     {'nome': _nomeCtrl.text.trim()},
      );

      if (!mounted) return;

      // Caso o Supabase já abriu sessão (sem confirmação de e-mail)
      if (response.session != null && response.user != null) {
        try {
          await client.from('profiles').insert({
            'id':   response.user!.id,
            'nome': _nomeCtrl.text.trim(),
            'role': 'professor', // cargo padrão; coordenação altera depois
          });
        } catch (_) {
          // Ignora caso o trigger do Supabase já tenha criado o perfil
        }

        if (!mounted) return;
        final usuario = await AuthService.buscarUsuarioAtual();
        if (!mounted) return;
        context.go(homeRouteFor(usuario?.role ?? RoleUsuario.professor));
      } else {
        // Confirmação de e-mail necessária
        setState(() => _confirmacaoEnviada = true);
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.toLowerCase().contains('already registered') ||
          msg.toLowerCase().contains('user already')) {
        msg = 'Este e-mail já está cadastrado.';
      } else {
        msg = msg
            .replaceAll('AuthException: ', '')
            .replaceAll('Exception: ', '');
      }
      setState(() => _erro = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmacaoEnviada) {
      return _ConfirmacaoView(email: _emailCtrl.text.trim());
    }

    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 28,
                vertical:   isWide ? 40 : 0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: isWide ? 16 : 32),

                    // ── Voltar ────────────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go(AppRoutes.login),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Voltar ao login'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Criar conta',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Preencha os dados abaixo para solicitar acesso',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 36),

                    // ── Nome ──────────────────────────────────────────────────
                    Text('Nome completo', style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nomeCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Maria Silva',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe seu nome';
                        if (v.trim().length < 3) return 'Nome muito curto';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ── E-mail ────────────────────────────────────────────────
                    Text('E-mail', style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
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
                      controller: _senhaCtrl,
                      obscureText: _obscureSenha,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Mínimo 6 caracteres',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSenha
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.textHint,
                          ),
                          onPressed: () =>
                              setState(() => _obscureSenha = !_obscureSenha),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ── Confirmar senha ───────────────────────────────────────
                    Text('Confirmar senha', style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmaCtrl,
                      obscureText: _obscureConfirma,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _cadastrar(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirma
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.textHint,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirma = !_obscureConfirma),
                        ),
                      ),
                      validator: (v) {
                        if (v != _senhaCtrl.text) return 'As senhas não coincidem';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Erro ──────────────────────────────────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: _erro != null
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ErroBanner(mensagem: _erro!),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // ── Botão ─────────────────────────────────────────────────
                    FilledButton(
                      onPressed: _loading ? null : _cadastrar,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surface,
                              ),
                            )
                          : const Text('Criar conta'),
                    ),
                    const SizedBox(height: 20),

                    // ── Aviso de cargo ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.20)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Após criar sua conta, a coordenação irá '
                              'atribuir seu cargo no sistema.',
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          );
}

// ─── Confirmação de e-mail pendente ──────────────────────────────────────────

class _ConfirmacaoView extends StatelessWidget {
  final String email;
  const _ConfirmacaoView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mark_email_read_outlined,
                      size: 72, color: AppColors.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Verifique seu e-mail',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enviamos um link de confirmação para\n$email\n\n'
                    'Clique no link para ativar sua conta.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Voltar ao login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Banner de erro ───────────────────────────────────────────────────────────

class _ErroBanner extends StatelessWidget {
  final String mensagem;
  const _ErroBanner({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Icon(Icons.error_outline_rounded,
                size: 16, color: AppColors.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.error, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
