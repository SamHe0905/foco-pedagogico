import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/professor_perfil.dart';
import '../services/coordenacao_service.dart';
import 'coordenacao_providers.dart';

class ProfessoresScreen extends ConsumerWidget {
  const ProfessoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync  = ref.watch(currentUserProvider);
    final async      = ref.watch(professoresPerfisProvider);
    final isDirector = userAsync.valueOrNull?.role.isDirector ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isDirector ? 'Equipe' : 'Professores'),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(professoresPerfisProvider),
        ),
        data: (membros) => membros.isEmpty
            ? const _EmptyState()
            : _MembrosList(membros: membros),
      ),
      floatingActionButton: FloatingActionButton.extended(
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
  const _MembrosList({required this.membros});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: membros.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _MembroTile(membro: membros[i]),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _MembroTile extends ConsumerWidget {
  final ProfessorPerfil membro;
  const _MembroTile({required this.membro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: membro.ativo
              ? AppColors.divider
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: _Avatar(nome: membro.nome, ativo: membro.ativo),
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
                    .map((t) => _TurmaChip(nome: t.nome))
                    .toList(),
              ),
        trailing: IconButton(
          icon:
              const Icon(Icons.more_vert_rounded, color: AppColors.textHint),
          onPressed: () => _mostrarOpcoes(context, ref),
        ),
        onTap: () => _mostrarOpcoes(context, ref),
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
  const _Avatar({required this.nome, required this.ativo});

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
        ],
      ),
    );
  }

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
                  label: Text(t.nome),
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

// ─── Bottom sheet: integrar docente ──────────────────────────────────────────

// Opções de cargo disponíveis por quem convida
const _rolesParaCoordenador = [
  ('professor',  'Professor'),
  ('supervisor', 'Supervisor'),
  ('coordenacao','Coordenação'),
];

const _rolesParaDiretor = [
  ('professor',       'Professor'),
  ('supervisor',      'Supervisor'),
  ('coordenacao',     'Coordenação'),
  ('diretor',         'Diretor'),
  ('diretor-adjunto', 'Dir. Adjunto'),
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
