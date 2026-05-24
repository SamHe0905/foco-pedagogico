import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Identidade visual ──────────────────────────────────────────────────────
  // Azul marinho (topo do "P" e texto "foco")
  static const primary      = Color(0xFF1B3D8F);
  static const primaryLight = Color(0xFF2B57CC);
  static const primaryDark  = Color(0xFF122A65);

  // Verde (base do "P" e texto "pedagógico")
  static const secondary      = Color(0xFF2BAD6B);
  static const secondaryLight = Color(0xFF3DC97E);
  static const secondaryDark  = Color(0xFF1F8550);

  // ── Base ───────────────────────────────────────────────────────────────────
  static const background    = Color(0xFFF7F8FA);
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEEF2F7);

  // ── Texto ──────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1A1D23);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint      = Color(0xFFADB5BD);

  // ── Semânticas ─────────────────────────────────────────────────────────────
  static const success = Color(0xFF2BAD6B);   // mesmo verde da marca
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);

  static const divider = Color(0xFFE5E7EB);

  // ── Status de demanda ──────────────────────────────────────────────────────
  static const statusPendente   = Color(0xFFF59E0B);
  static const statusVisualizada = Color(0xFF2B57CC);  // azul claro da marca
  static const statusConcluida  = Color(0xFF2BAD6B);   // verde da marca
}
