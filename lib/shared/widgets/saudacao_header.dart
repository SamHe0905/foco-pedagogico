import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/saudacao_helper.dart';
import '../../features/auth/domain/usuario.dart';
import '../../features/auth/presentation/auth_providers.dart';

class SaudacaoHeader extends ConsumerWidget {
  /// Widget opcional exibido à direita da saudação (ex: botão de ação rápida).
  /// Renderizado via Stack para não interferir nas constraints do texto.
  final Widget? action;
  const SaudacaoHeader({super.key, this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const _Skeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (usuario) {
        if (usuario == null) return const SizedBox.shrink();

        final saudacao = SaudacaoHelper.saudacaoAtual();
        final nome     = SaudacaoHelper.nomeFormatado(usuario.nome, usuario.role);
        final cargo    = _cargo(usuario.role);

        final header = Container(
          width: double.infinity,
          // padding direita maior quando há botão para o texto não sobrepor
          padding: EdgeInsets.fromLTRB(20, 14, action != null ? 160 : 20, 14),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$saudacao, $nome!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                cargo,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        );

        if (action == null) return header;

        return Stack(
          alignment: Alignment.centerRight,
          children: [
            header,
            Positioned(
              right: 12,
              child: action!,
            ),
          ],
        );
      },
    );
  }

  String _cargo(RoleUsuario role) => role.cargo;
}

// Placeholder discreto enquanto carrega
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            width: 200,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
