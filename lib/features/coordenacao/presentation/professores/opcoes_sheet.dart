part of '../professores_screen.dart';

// ─── Bottom sheet: opções do membro ──────────────────────────────────────────

class _OpcoesSheet extends ConsumerStatefulWidget {
  final ProfessorPerfil membro;
  final WidgetRef ref;
  const _OpcoesSheet({required this.membro, required this.ref});

  @override
  ConsumerState<_OpcoesSheet> createState() => _OpcoesSheetState();
}

class _OpcoesSheetState extends ConsumerState<_OpcoesSheet> {
  bool _salvando = false;

  Future<void> _confirmarExclusao(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nomeAlvo  = widget.membro.nome;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded,
            color: AppColors.error, size: 32),
        title: const Text('Excluir usuário?'),
        content: Text(
          'Isso vai remover ${widget.membro.nome} permanentemente do sistema. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await CoordenacaoService.deletarUsuario(widget.membro.id);
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('$nomeAlvo foi removido do sistema.'),
            backgroundColor: AppColors.statusConcluida,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alterarCargo(BuildContext context) async {
    final isDirector =
        ref.read(currentUserProvider).valueOrNull?.role.isDirector ?? false;
    final opcoes =
        isDirector ? _rolesParaDiretor : _rolesParaCoordenador;

    String  rolePrincipal  = widget.membro.role;
    String? roleSecundario = widget.membro.roleSecundario;

    final resultado = await showDialog<(String, String?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          // Cargo secundário não pode ser igual ao principal
          if (roleSecundario == rolePrincipal) {
            roleSecundario = null;
          }
          return AlertDialog(
            title: Text('Cargo de ${widget.membro.nome}'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cargo principal ─────────────────────────────────
                    Text(
                      'Cargo principal',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    ...opcoes.map((opt) {
                      final (value, label) = opt;
                      return RadioListTile<String>(
                        value: value,
                        groupValue: rolePrincipal,
                        title: Text(label),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) => setDialog(() => rolePrincipal = v!),
                      );
                    }),

                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ── Cargo secundário ────────────────────────────────
                    Text(
                      'Cargo secundário',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    Text(
                      'Permite ao usuário alternar entre dois papéis (opcional).',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    RadioListTile<String?>(
                      value: null,
                      groupValue: roleSecundario,
                      title: const Text('Nenhum'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (v) => setDialog(() => roleSecundario = v),
                    ),
                    ...opcoes.where((o) => o.$1 != rolePrincipal).map((opt) {
                      final (value, label) = opt;
                      return RadioListTile<String?>(
                        value: value,
                        groupValue: roleSecundario,
                        title: Text(label),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) => setDialog(() => roleSecundario = v),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, (rolePrincipal, roleSecundario)),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado == null || !mounted) return;

    final (novoRole, novoRoleSecundario) = resultado;
    final mudouPrincipal  = novoRole != widget.membro.role;
    final mudouSecundario = novoRoleSecundario != widget.membro.roleSecundario;
    if (!mudouPrincipal && !mudouSecundario) return;

    setState(() => _salvando = true);
    try {
      await CoordenacaoService.alterarCargo(
        widget.membro.id,
        novoRole,
        novoRoleSecundario: novoRoleSecundario, // null = remove duplo acesso
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cargo de ${widget.membro.nome} atualizado.'),
            backgroundColor: AppColors.statusConcluida,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _toggleAtivo() async {
    setState(() => _salvando = true);
    try {
      await CoordenacaoService.toggleAtivoProfessor(
        widget.membro.id,
        ativo: !widget.membro.ativo,
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao alterar status.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(widget.membro.nome,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              _RoleBadge(role: widget.membro.role),
            ],
          ),
          const SizedBox(height: 20),

          // Gerenciar turmas
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.class_rounded, color: AppColors.primary),
            title: const Text('Gerenciar Turmas'),
            subtitle: Text(
              widget.membro.turmas.isEmpty
                  ? 'Nenhuma turma vinculada'
                  : widget.membro.turmas.map((t) => t.nome).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint),
            onTap: () {
              Navigator.of(context).pop();
              _mostrarTurmas(context);
            },
          ),

          // Etapas de ensino (coordenadores — exceto supervisor)
          if (_isCoordRole(widget.membro.role)) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school_rounded,
                  color: AppColors.secondary),
              title: const Text('Etapas de ensino'),
              subtitle: const Text(
                'Define quais solicitações este coordenador recebe',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
              onTap: () {
                Navigator.of(context).pop();
                _mostrarEtapas(context);
              },
            ),
          ],

          // Cursos técnicos (apenas para supervisor)
          if (widget.membro.role == 'supervisor') ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.engineering_rounded,
                  color: AppColors.secondary),
              title: const Text('Cursos técnicos'),
              subtitle: const Text(
                'Define quais turmas técnicas este supervisor acompanha',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
              onTap: () {
                Navigator.of(context).pop();
                _mostrarCursos(context);
              },
            ),
          ],

          const Divider(),

          // Alterar cargo
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined, color: AppColors.secondary),
            title: const Text('Alterar cargo'),
            subtitle: Text(
              'Cargo atual: ${_labelCargo(widget.membro.role)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint),
            onTap: _salvando ? null : () => _alterarCargo(context),
          ),

          const Divider(),

          // Ativar / Desativar
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              widget.membro.ativo
                  ? Icons.block_rounded
                  : Icons.check_circle_rounded,
              color: widget.membro.ativo
                  ? AppColors.error
                  : AppColors.statusConcluida,
            ),
            title: Text(
              widget.membro.ativo ? 'Desativar acesso' : 'Reativar acesso',
              style: TextStyle(
                color: widget.membro.ativo
                    ? AppColors.error
                    : AppColors.statusConcluida,
              ),
            ),
            subtitle: Text(
              widget.membro.ativo
                  ? 'O usuário não conseguirá fazer login'
                  : 'Restaura o acesso ao app',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : null,
            onTap: _salvando ? null : _toggleAtivo,
          ),

          const Divider(),

          // Excluir usuário
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
            title: const Text(
              'Excluir usuário',
              style: TextStyle(color: AppColors.error),
            ),
            subtitle: const Text(
              'Remove permanentemente do sistema',
              style: TextStyle(fontSize: 12),
            ),
            onTap: _salvando ? null : () => _confirmarExclusao(context),
          ),
        ],
      ),
    );
  }

  // Coordenadores pedagógicos (exceto supervisor, que usa lógica de cursos)
  bool _isCoordRole(String role) =>
      role == 'coordenacao' || role == 'pcsa' || role == 'pcpi';

  void _mostrarEtapas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EtapasSheet(membroId: widget.membro.id, ref: ref),
    );
  }

  void _mostrarCursos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CursosSheet(membroId: widget.membro.id, ref: ref),
    );
  }

  String _labelCargo(String role) => switch (role) {
        'coordenacao'     => 'Coordenação',
        'supervisor'      => 'Supervisor',
        'diretor'         => 'Diretor',
        'diretor-adjunto' => 'Dir. Adjunto',
        'pcsa'            => 'PCSA',
        'professor_aee'   => 'Prof. AEE',
        'secretaria'      => 'Secretária',
        _                 => 'Professor',
      };

  void _mostrarTurmas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _TurmasSheet(membro: widget.membro, ref: widget.ref),
    );
  }
}
