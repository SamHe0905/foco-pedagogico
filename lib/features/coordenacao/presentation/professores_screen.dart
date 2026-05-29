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

// Widgets e sheets da tela, separados em arquivos-parte desta mesma biblioteca.
part 'professores/membros_list.dart';
part 'professores/opcoes_sheet.dart';
part 'professores/turmas_sheet.dart';
part 'professores/enviar_demanda_sheet.dart';
part 'professores/cursos_sheet.dart';
part 'professores/etapas_sheet.dart';
part 'professores/integrar_sheet.dart';
part 'professores/professores_states.dart';

// ─── Opções de cargo disponíveis por quem convida ────────────────────────────

const _rolesParaCoordenador = [
  ('professor',       'Professor'),
  ('professor_aee',   'Prof. AEE'),
  ('supervisor',      'Supervisor'),
  ('coordenacao',     'Coordenação'),
  ('pcsa',            'PCSA'),
];

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

// ─── Screen ──────────────────────────────────────────────────────────────────

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
