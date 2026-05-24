import '../../features/auth/domain/usuario.dart';

abstract class SaudacaoHelper {
  // ── "Bom dia", "Boa tarde" ou "Boa noite" ────────────────────────────────
  static String saudacaoAtual() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  // ── Primeiro nome a partir do nome completo ───────────────────────────────
  static String primeiroNome(String nomeCompleto) =>
      nomeCompleto.trim().split(' ').first;

  // ── "Coord. Samuel", "Prof. Maria", "Dir. Carlos", etc. ──────────────────
  static String nomeFormatado(String nome, RoleUsuario role) {
    final primeiro = primeiroNome(nome);
    return '${role.prefixo} $primeiro';
  }
}
