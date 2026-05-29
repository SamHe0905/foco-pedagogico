import 'package:supabase_flutter/supabase_flutter.dart';

/// Convites e remoção de usuários (via Edge Functions com service role).
class ConvitesService {
  static final _db = Supabase.instance.client;

  // Integra novo membro via Edge Function
  static Future<void> integrarDocente(String email, String nome, String role) async {
    final res = await _db.functions.invoke(
      'invite-professor',
      body: {'email': email.trim(), 'nome': nome.trim(), 'role': role},
    );
    if (res.status != 200) {
      final erro = res.data?['error'] as String? ?? 'Erro ao enviar convite.';
      final erroLower = erro.toLowerCase();
      if (erroLower.contains('already been registered') ||
          erroLower.contains('already registered')) {
        throw Exception('Este e-mail já está cadastrado. Exclua o usuário antes de reenviar o convite.');
      }
      if (erroLower.contains('rate limit')) {
        throw Exception('Limite de e-mails atingido. Aguarde alguns minutos e tente novamente.');
      }
      throw Exception(erro);
    }
  }

  // Exclui usuário do sistema via Edge Function
  static Future<void> deletarUsuario(String userId) async {
    final res = await _db.functions.invoke(
      'deletar-usuario',
      body: {'userId': userId},
    );
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Erro ao excluir usuário.');
    }
  }
}
