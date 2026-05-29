part of '../dashboard_screen.dart';

// ─── Vista filtrada por categoria ────────────────────────────────────────────

enum _FiltroStatus { todas, andamento, concluidas, atrasadas }
enum _OrdemDemanda { prazo, prioridade, progresso, titulo }

class _CategoriaDemandasView extends StatefulWidget {
  final List<DemandaResumo> demandas;
  final Set<String> selectedIds;
  final bool emModoSelecao;
  final void Function(String id) onLongPress;
  final void Function(String id) onToggle;

  const _CategoriaDemandasView({
    required this.demandas,
    required this.selectedIds,
    required this.emModoSelecao,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  State<_CategoriaDemandasView> createState() => _CategoriaDemandasViewState();
}

class _CategoriaDemandasViewState extends State<_CategoriaDemandasView> {
  _FiltroStatus _filtro = _FiltroStatus.todas;
  _OrdemDemanda _ordem  = _OrdemDemanda.prazo;
  final _searchCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DemandaResumo> get _filtradas {
    var lista = switch (_filtro) {
      _FiltroStatus.todas      => widget.demandas,
      _FiltroStatus.andamento  => widget.demandas
          .where((d) => !d.todosConcluidam && !d.atrasada)
          .toList(),
      _FiltroStatus.concluidas => widget.demandas
          .where((d) => d.todosConcluidam)
          .toList(),
      _FiltroStatus.atrasadas  => widget.demandas
          .where((d) => d.atrasada)
          .toList(),
    };

    if (_busca.isNotEmpty) {
      final q = _busca.toLowerCase();
      lista = lista
          .where((d) =>
              d.titulo.toLowerCase().contains(q) ||
              d.turma.toLowerCase().contains(q))
          .toList();
    }

    lista = List.of(lista)
      ..sort((a, b) => switch (_ordem) {
            _OrdemDemanda.prazo      => a.prazo.compareTo(b.prazo),
            _OrdemDemanda.prioridade => _priorInt(a.prioridade)
                .compareTo(_priorInt(b.prioridade)),
            _OrdemDemanda.progresso  => a.progresso.compareTo(b.progresso),
            _OrdemDemanda.titulo     => a.titulo.compareTo(b.titulo),
          });

    return lista;
  }

  int _priorInt(PrioridadeDemanda p) => switch (p) {
        PrioridadeDemanda.alta  => 0,
        PrioridadeDemanda.media => 1,
        PrioridadeDemanda.baixa => 2,
      };

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── Busca + Ordenação ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por título ou turma...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _busca.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _busca = '';
                          }),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_OrdemDemanda>(
              icon: Icon(
                Icons.sort_rounded,
                color: _ordem != _OrdemDemanda.prazo
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              tooltip: 'Ordenar',
              onSelected: (o) => setState(() => _ordem = o),
              itemBuilder: (_) => [
                _ordemItem(_OrdemDemanda.prazo,      'Prazo',      Icons.calendar_today_rounded),
                _ordemItem(_OrdemDemanda.prioridade, 'Prioridade', Icons.flag_rounded),
                _ordemItem(_OrdemDemanda.progresso,  'Progresso',  Icons.pie_chart_rounded),
                _ordemItem(_OrdemDemanda.titulo,     'Título',     Icons.sort_by_alpha_rounded),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Chips de filtro ────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FiltroChip(
                label: 'Todas',
                ativo: _filtro == _FiltroStatus.todas,
                onTap: () => setState(() => _filtro = _FiltroStatus.todas),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Em andamento',
                ativo: _filtro == _FiltroStatus.andamento,
                onTap: () => setState(() => _filtro = _FiltroStatus.andamento),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Concluídas',
                ativo: _filtro == _FiltroStatus.concluidas,
                color: AppColors.statusConcluida,
                onTap: () => setState(() => _filtro = _FiltroStatus.concluidas),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Atrasadas',
                ativo: _filtro == _FiltroStatus.atrasadas,
                color: AppColors.error,
                onTap: () => setState(() => _filtro = _FiltroStatus.atrasadas),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Contador + hint ────────────────────────────────────────────────
        Row(
          children: [
            Text(
              '${lista.length} demanda${lista.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (!widget.emModoSelecao) ...[
              const Spacer(),
              Text(
                'Segure para selecionar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Lista ──────────────────────────────────────────────────────────
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'Nenhuma demanda neste filtro.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...lista.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DemandaCard(
                  demanda: d,
                  isSelected: widget.selectedIds.contains(d.id),
                  emModoSelecao: widget.emModoSelecao,
                  onLongPress: () => widget.onLongPress(d.id),
                  onToggle: () => widget.onToggle(d.id),
                ),
              )),
      ],
    );
  }
}

PopupMenuItem<_OrdemDemanda> _ordemItem(
    _OrdemDemanda v, String label, IconData icon) {
  return PopupMenuItem(
    value: v,
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label),
      ],
    ),
  );
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool ativo;
  final Color color;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.ativo,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ativo ? color : AppColors.divider,
            width: ativo ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
            color: ativo ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
