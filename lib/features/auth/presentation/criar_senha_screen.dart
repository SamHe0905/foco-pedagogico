import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/app_router.dart';
import '../domain/usuario.dart';
import '../services/auth_service.dart';
import 'auth_providers.dart';

class CriarSenhaScreen extends StatefulWidget {
  const CriarSenhaScreen({super.key});

  @override
  State<CriarSenhaScreen> createState() => _CriarSenhaScreenState();
}

class _CriarSenhaScreenState extends State<CriarSenhaScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _senhaCtrl     = TextEditingController();
  final _confirmaCtrl  = TextEditingController();
  bool _obscureSenha   = true;
  bool _obscureConfirma = true;
  bool _salvando       = false;

  @override
  void dispose() {
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _senhaCtrl.text.trim()),
      );

      // Limpa flag de recovery para não redirecionar de volta aqui
      goRouterAuthNotifier.clearRecovery();

      if (!mounted) return;

      final usuario = await AuthService.buscarUsuarioAtual();
      if (!mounted) return;

      context.go(homeRouteFor(usuario?.role ?? RoleUsuario.professor));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar senha: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
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
                vertical: 40,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Criar senha',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Defina uma senha para acessar o Foco Pedagógico.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _senhaCtrl,
                      obscureText: _obscureSenha,
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureSenha
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureSenha = !_obscureSenha),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmaCtrl,
                      obscureText: _obscureConfirma,
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirma
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureConfirma = !_obscureConfirma),
                        ),
                      ),
                      validator: (v) {
                        if (v != _senhaCtrl.text) {
                          return 'As senhas não coincidem.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _salvando ? null : _salvar,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Salvar senha',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
