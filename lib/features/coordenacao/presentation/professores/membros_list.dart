part of '../professores_screen.dart';

// ─── Lista ────────────────────────────────────────────────────────────────────

class _MembrosList extends StatelessWidget {
  final List<ProfessorPerfil> membros;
  final Set<String> selectedIds;
  final bool emModoSelecao;
  final void Function(String) onLongPress;
  final void Function(String) onToggle;

  const _MembrosList({
    required this.membros,
    required this.selectedIds,
    required this.emModoSelecao,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!emModoSelecao)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Segure para selecionar e enviar demanda',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: membros.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _MembroTile(
              membro: membros[i],
              isSelected: selectedIds.contains(membros[i].id),
              emModoSelecao: emModoSelecao,
              onLongPress: () => onLongPress(membros[i].id),
              onToggle: () => onToggle(membros[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _MembroTile extends ConsumerWidget {
  final ProfessorPerfil membro;
  final bool isSelected;
  final bool emModoSelecao;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;

  const _MembroTile({
    required this.membro,
    required this.isSelected,
    required this.emModoSelecao,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : membro.ativo
                  ? AppColors.divider
                  : AppColors.error.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: emModoSelecao
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        key: ValueKey('c'), color: AppColors.primary, size: 36)
                    : _Avatar(
                        key: const ValueKey('a'),
                        nome: membro.nome,
                        ativo: membro.ativo),
              )
            : _Avatar(nome: membro.nome, ativo: membro.ativo),
        title: Row(
          children: [
            Expanded(
              child: Text(
                membro.nome,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      membro.ativo ? AppColors.textPrimary : AppColors.textHint,
                  decoration:
                      membro.ativo ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RoleBadge(role: membro.role),
          ],
        ),
        subtitle: membro.turmas.isEmpty
            ? Text(
                'Sem turmas vinculadas',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic),
              )
            : Wrap(
                spacing: 4,
                runSpacing: 4,
                children: membro.turmas
                    .map((t) => _TurmaChip(nome: t.nomeCompleto))
                    .toList(),
              ),
        trailing: emModoSelecao
            ? null
            : IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textHint),
                onPressed: () => _mostrarOpcoes(context, ref),
              ),
        onTap: emModoSelecao ? onToggle : () => _mostrarOpcoes(context, ref),
        onLongPress: emModoSelecao ? null : onLongPress,
      ),
    );
  }

  void _mostrarOpcoes(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _OpcoesSheet(membro: membro, ref: ref),
    );
  }
}

// ─── Badge de cargo ───────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  (String, Color) get _info => switch (role) {
        'coordenacao'     => ('Coordenação', AppColors.primary),
        'supervisor'      => ('Supervisor',  AppColors.secondary),
        'diretor'         => ('Diretor',     AppColors.primaryDark),
        'diretor-adjunto' => ('Dir. Adj.',   AppColors.primaryDark),
        'pcsa'            => ('PCSA',        AppColors.primary),
        'professor_aee'   => ('AEE',         Colors.teal),
        'secretaria'      => ('Secretária',  AppColors.warning),
        _                 => ('Professor',   AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String nome;
  final bool ativo;
  const _Avatar({super.key, required this.nome, required this.ativo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: ativo
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.divider,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        nome.isNotEmpty ? nome[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ativo ? AppColors.primary : AppColors.textHint,
        ),
      ),
    );
  }
}

class _TurmaChip extends StatelessWidget {
  final String nome;
  const _TurmaChip({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(nome,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary)),
    );
  }
}
