import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../solicitacoes/services/solicitacoes_service.dart';
import '../domain/curso_tecnico.dart';
import '../domain/professor_perfil.dart';
import '../domain/turma.dart';
import '../services/coordenacao_service.dart';
import '../services/cursos_tecnicos_service.dart';
import 'coordenacao_providers.dart';

class ProfessoresScreen extends ConsumerStatefulWidget {
  const ProfessoresScreen({super.key});

  @override
  ConsumerState<ProfessoresScreen> createState() => _ProfessoresScreenState();
}

class _ProfessoresScreenState extends ConsumerState<ProfessoresScreen> {
  final Set<String> _selectedIds = {};
  bool get _emModoSelecao => _selectedIds.isNotEmpty;

  void _toggleSelecao(String id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });

  void _cancelar() => setState(() => _selectedIds.clear());

  void _enviarDemandaParaSelecionados(List<ProfessorPerfil> todos) {
    final selecionados =
        todos.where((m) => _selectedIds.contains(m.id)).toList();
    _cancelar();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EnviarDemandaSheet(
        professores: selecionados,
        ref: ref,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync  = ref.watch(currentUserProvider);
    final async      = ref.watch(professoresPerfisProvider);
    final isDirector = userAsync.valueOrNull?.role.isDirector ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _emModoSelecao
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _cancelar,
              ),
              title: Text(
                '${_selectedIds.length} selecionado${_selectedIds.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              actions: [
                async.whenOrNull(
                      data: (membros) => TextButton.icon(
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                        label: const Text('Criar Demanda',
                            style: TextStyle(color: Colors.white)),
                        onPressed: () =>
                            _enviarDemandaParaSelecionados(membros),
                      ),
                    ) ??
                    const SizedBox.shrink(),
              ],
            )
          : AppBar(
              title: Text(isDirector ? 'Equipe' : 'Professores'),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
            ),
            error: (_, __) => _ErrorState(
              onRetry: () => ref.invalidate(professoresPerfisProvider),
            ),
            data: (membros) => membros.isEmpty
                ? const _EmptyState()
                : _MembrosList(
                    membros: membros,
                    selectedIds: _selectedIds,
                    emModoSelecao: _emModoSelecao,
                    onLongPress: _toggleSelecao,
                    onToggle: _toggleSelecao,
                  ),
          ),
        ),
      ),
      floatingActionButton: _emModoSelecao
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _mostrarIntegrar(context, ref, isDirector),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Integrar Docente'),
            ),
    );
  }

  void _mostrarIntegrar(BuildContext context, WidgetRef ref, bool isDirector) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _IntegrarSheet(ref: ref, isDirector: isDirector),
    );
  }
}

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

// ─── Bottom sheet: gerenciar turmas ──────────────────────────────────────────

class _TurmasSheet extends ConsumerStatefulWidget {
  final ProfessorPerfil membro;
  final WidgetRef ref;
  const _TurmasSheet({required this.membro, required this.ref});

  @override
  ConsumerState<_TurmasSheet> createState() => _TurmasSheetState();
}

class _TurmasSheetState extends ConsumerState<_TurmasSheet> {
  late Set<String> _selecionadas;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _selecionadas = widget.membro.turmas.map((t) => t.id).toSet();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await CoordenacaoService.atualizarTurmasProfessor(
        widget.membro.id,
        _selecionadas.toList(),
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turmas atualizadas!'),
            backgroundColor: AppColors.statusConcluida,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar turmas.'),
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
    final turmasAsync = ref.watch(turmasProvider);

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
          Text('Turmas de ${widget.membro.nome}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          turmasAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
            error: (_, __) => const Text('Erro ao carregar turmas.'),
            data: (turmas) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: turmas.map((t) {
                final sel = _selecionadas.contains(t.id);
                return FilterChip(
                  label: Text(t.nomeCompleto),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _selecionadas.remove(t.id);
                    } else {
                      _selecionadas.add(t.id);
                    }
                  }),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? AppColors.surface : AppColors.textSecondary,
                  ),
                  showCheckmark: false,
                  side: BorderSide(
                    color: sel ? AppColors.primary : Colors.transparent,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Salvar Turmas'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet: criar demanda para selecionados ───────────────────────────

class _EnviarDemandaSheet extends StatefulWidget {
  final List<ProfessorPerfil> professores;
  final WidgetRef ref;
  const _EnviarDemandaSheet({required this.professores, required this.ref});

  @override
  State<_EnviarDemandaSheet> createState() => _EnviarDemandaSheetState();
}

class _EnviarDemandaSheetState extends State<_EnviarDemandaSheet> {
  final _tituloController    = TextEditingController();
  final _descricaoController = TextEditingController();
  DateTime _prazo    = DateTime.now().add(const Duration(days: 7));
  String _prioridade = 'media';
  bool _enviando     = false;
  String? _erro;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _podeEnviar =>
      _tituloController.text.trim().isNotEmpty && !_enviando;

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _prazo,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _prazo = picked);
  }

  Future<void> _enviar() async {
    setState(() { _enviando = true; _erro = null; });
    try {
      await CoordenacaoService.criarDemanda(
        titulo:       _tituloController.text,
        descricao:    _descricaoController.text,
        tipo:         'individual',
        prazo:        _prazo,
        prioridade:   _prioridade,
        professorIds: widget.professores.map((p) => p.id).toList(),
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        Navigator.of(context).pop();
        final n = widget.professores.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Demanda enviada para $n professor${n > 1 ? 'es' : ''}!',
            ),
            backgroundColor: AppColors.statusConcluida,
          ),
        );
      }
    } catch (e) {
      setState(() => _erro = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dd = _prazo.day.toString().padLeft(2, '0');
    final mm = _prazo.month.toString().padLeft(2, '0');
    final yyyy = _prazo.year;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            Text('Criar Demanda',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            // Chips dos professores selecionados
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.professores
                  .map((p) => Chip(
                        label: Text(p.nome,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(
                            color:
                                AppColors.primary.withValues(alpha: 0.30)),
                        labelStyle:
                            const TextStyle(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Título
            TextField(
              controller: _tituloController,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Título da demanda',
                hintText: 'Ex: Entregar planejamento semanal',
              ),
            ),
            const SizedBox(height: 12),

            // Descrição
            TextField(
              controller: _descricaoController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Prazo
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text('Prazo: $dd/$mm/$yyyy',
                        style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prioridade
            Text(
              'Prioridade',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final opt in const [
                  ('alta', 'Alta'),
                  ('media', 'Média'),
                  ('baixa', 'Baixa'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _prioridade = opt.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _prioridade == opt.$1
                              ? _prioridadeColor(opt.$1)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _prioridade == opt.$1
                                ? _prioridadeColor(opt.$1)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          opt.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _prioridade == opt.$1
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Erro
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_erro!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.error)),
              ),
            ],
            const SizedBox(height: 20),

            // Botão
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _podeEnviar ? _enviar : null,
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.surface),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_enviando ? 'Enviando…' : 'Enviar Demanda'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _prioridadeColor(String p) => switch (p) {
        'alta'  => AppColors.error,
        'baixa' => AppColors.statusConcluida,
        _       => AppColors.secondary,
      };
}

// ─── Bottom sheet: integrar docente ──────────────────────────────────────────

// Opções de cargo disponíveis por quem convida
const _rolesParaCoordenador = [
  ('professor',       'Professor'),
  ('professor_aee',   'Prof. AEE'),
  ('supervisor',      'Supervisor'),
  ('coordenacao',     'Coordenação'),
  ('pcsa',            'PCSA'),
];

// ─── Bottom sheet: etapas do coordenador ─────────────────────────────────────

// ─── Sheet: cursos técnicos do supervisor ─────────────────────────────────────

class _CursosSheet extends StatefulWidget {
  final String    membroId;
  final WidgetRef ref;
  const _CursosSheet({required this.membroId, required this.ref});

  @override
  State<_CursosSheet> createState() => _CursosSheetState();
}

class _CursosSheetState extends State<_CursosSheet> {
  List<CursoTecnico> _todos        = [];
  Set<String>        _selecionados = {};
  bool _carregando = true;
  bool _salvando   = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final cursos  = await CursosTecnicosService.getCursos();
      final vinculados = await CursosTecnicosService.getCursoIdsSupervisor(
          widget.membroId);
      if (mounted) {
        setState(() {
          _todos        = cursos;
          _selecionados = vinculados.toSet();
          _carregando   = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await CursosTecnicosService.salvarCursosSupervisor(
          widget.membroId, _selecionados.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Cursos técnicos',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Marque os cursos pelos quais este supervisor é responsável. '
            'Professores de turmas desses cursos também enviarão solicitações para ele.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_carregando)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_todos.isEmpty)
            const Text(
              'Nenhum curso técnico cadastrado. Peça à gestão que cadastre os cursos primeiro.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _todos.map((c) {
                final sel = _selecionados.contains(c.id);
                return FilterChip(
                  label: Text(c.nome,
                      style: const TextStyle(fontSize: 13)),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _selecionados.remove(c.id);
                    } else {
                      _selecionados.add(c.id);
                    }
                  }),
                  selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.secondary,
                  side: BorderSide(
                    color: sel ? AppColors.secondary : AppColors.divider,
                  ),
                  labelStyle: TextStyle(
                    color: sel ? AppColors.secondary : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_salvando || _todos.isEmpty) ? null : _salvar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            child: _salvando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet: etapas de ensino do coordenador ───────────────────────────────────

class _EtapasSheet extends StatefulWidget {
  final String    membroId;
  final WidgetRef ref;
  const _EtapasSheet({required this.membroId, required this.ref});

  @override
  State<_EtapasSheet> createState() => _EtapasSheetState();
}

class _EtapasSheetState extends State<_EtapasSheet> {
  Set<EtapaTurno> _selecionadas = {};
  bool _carregando = true;
  bool _salvando   = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista =
          await SolicitacoesService.getEtapasCoordenador(widget.membroId);
      if (mounted) setState(() { _selecionadas = lista.toSet(); _carregando = false; });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await SolicitacoesService.salvarEtapasCoordenador(
          widget.membroId, _selecionadas.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Etapas de ensino',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Marque as etapas e turnos pelos quais este coordenador é responsável. '
            'Professores dessas etapas enviarão solicitações diretamente para ele.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_carregando)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: EtapaTurno.todas.map((et) {
                final sel = _selecionadas.contains(et);
                return FilterChip(
                  label: Text(et.label,
                      style: const TextStyle(fontSize: 13)),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _selecionadas.remove(et);
                    } else {
                      _selecionadas.add(et);
                    }
                  }),
                  selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.secondary,
                  side: BorderSide(
                    color: sel ? AppColors.secondary : AppColors.divider,
                  ),
                  labelStyle: TextStyle(
                    color: sel ? AppColors.secondary : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            child: _salvando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

const _rolesParaDiretor = [
  ('professor',       'Professor'),
  ('professor_aee',   'Prof. AEE'),
  ('supervisor',      'Supervisor'),
  ('coordenacao',     'Coordenação'),
  ('pcsa',            'PCSA'),
  ('diretor',         'Diretor'),
  ('diretor-adjunto', 'Dir. Adjunto'),
  ('secretaria',      'Secretária'),
];

class _IntegrarSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final bool isDirector;
  const _IntegrarSheet({required this.ref, required this.isDirector});

  @override
  ConsumerState<_IntegrarSheet> createState() => _IntegrarSheetState();
}

class _IntegrarSheetState extends ConsumerState<_IntegrarSheet> {
  final _emailController = TextEditingController();
  final _nomeController  = TextEditingController();
  String _roleSelecionada = 'professor';
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  List<(String, String)> get _opcoes =>
      widget.isDirector ? _rolesParaDiretor : _rolesParaCoordenador;

  bool get _podeEnviar =>
      _emailController.text.trim().isNotEmpty &&
      _nomeController.text.trim().isNotEmpty &&
      !_enviando;

  Future<void> _enviar() async {
    setState(() { _enviando = true; _erro = null; });
    try {
      await CoordenacaoService.integrarDocente(
        _emailController.text,
        _nomeController.text,
        _roleSelecionada,
      );
      widget.ref.invalidate(professoresPerfisProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite enviado! O usuário receberá um e-mail.'),
            backgroundColor: AppColors.statusConcluida,
          ),
        );
      }
    } catch (e) {
      setState(() => _erro = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
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
          // Handle
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
          Text('Integrar Docente',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'O usuário receberá um e-mail para definir sua senha e acessar o app.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Nome
          TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              hintText: 'Ex: Maria Silva',
            ),
          ),
          const SizedBox(height: 12),

          // E-mail
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'usuario@escola.com',
            ),
          ),
          const SizedBox(height: 16),

          // Seletor de cargo
          Text(
            'Cargo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _opcoes.map(((String, String) opt) {
              final (value, label) = opt;
              final sel = _roleSelecionada == value;
              return GestureDetector(
                onTap: () => setState(() => _roleSelecionada = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Erro
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _erro!,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Botão
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _podeEnviar ? _enviar : null,
              icon: _enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Enviar Convite'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estados ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 56, color: AppColors.textHint),
            SizedBox(height: 16),
            Text('Nenhum membro cadastrado.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('Erro ao carregar.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}
