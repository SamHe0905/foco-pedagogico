import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/usuario.dart';

// Tabela necessária no Supabase (rodar via SQL Editor):
//
// create table public.profiles (
//   id   uuid references auth.users on delete cascade primary key,
//   nome text not null,
//   role text not null check (role in ('professor', 'coordenacao'))
// );
//
// alter table public.profiles enable row level security;
// create policy "Usuário lê próprio perfil"
//   on public.profiles for select
//   using (auth.uid() = id);

// Nome distinto do AuthException do SDK Supabase/gotrue
class AppAuthException implements Exception {
  final String mensagem;
  const AppAuthException(this.mensagem);
}

class AuthService {
  static final _auth = Supabase.instance.client.auth;
  static final _db = Supabase.instance.client;

  // ── Login ─────────────────────────────────────────────────────────────────

  static Future<Usuario> login(String email, String senha) async {
    try {
      final res = await _auth.signInWithPassword(
        email: email.trim(),
        password: senha,
      );

      final user = res.user;
      if (user == null) throw const AppAuthException('Login falhou. Tente novamente.');

      return await _buscarPerfil(user.id, user.email ?? email);
    } catch (e) {
      if (e is AppAuthException) rethrow;
      // Supabase/gotrue lança AuthException — extrai e mapeia a mensagem
      throw AppAuthException(_mapErro(e.toString()));
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ── Estado atual ──────────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static Session? get currentSession => _auth.currentSession;
  static Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  // Retorna o usuário logado com perfil do banco; null se não autenticado
  static Future<Usuario?> buscarUsuarioAtual() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _buscarPerfil(user.id, user.email ?? '');
    } catch (_) {
      return null;
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  static Future<Usuario> _buscarPerfil(String userId, String email) async {
    // Tenta buscar o perfil existente
    var data = await _db
        .from('profiles')
        .select('nome, role')
        .eq('id', userId)
        .maybeSingle();

    // Perfil ainda não existe — tenta criar automaticamente
    if (data == null) {
      final authUser = _auth.currentUser;
      final nomeRaw = authUser?.userMetadata?['nome'] as String?;
      final roleRaw = authUser?.userMetadata?['role'] as String?;
      final nome = (nomeRaw != null && nomeRaw.trim().isNotEmpty)
          ? nomeRaw.trim()
          : email.split('@').first;
      final role = (roleRaw != null && roleRaw.trim().isNotEmpty)
          ? roleRaw.trim()
          : 'professor';

      try {
        await _db.from('profiles').insert({
          'id':   userId,
          'nome': nome,
          'role': role,
        });
        data = {'nome': nome, 'role': role};
      } catch (_) {
        // INSERT falhou (RLS ou perfil criado por outro caminho) — tenta buscar novamente
        data = await _db
            .from('profiles')
            .select('nome, role')
            .eq('id', userId)
            .maybeSingle();
      }
    }

    if (data == null) {
      throw const AppAuthException(
        'Perfil não encontrado. Entre em contato com a coordenação.',
      );
    }

    return Usuario(
      id: userId,
      email: email,
      nome: data['nome'] as String,
      role: RoleUsuarioX.fromString(data['role'] as String),
    );
  }

  static String _mapErro(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    if (lower.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    }
    return 'Sem conexão. Verifique sua internet e tente novamente.';
  }
}
