enum StatusSolicitacao { pendente, emAndamento, resolvida }

extension StatusSolicitacaoX on StatusSolicitacao {
  static StatusSolicitacao fromString(String v) => switch (v) {
        'em_andamento' => StatusSolicitacao.emAndamento,
        'resolvida'    => StatusSolicitacao.resolvida,
        _              => StatusSolicitacao.pendente,
      };

  String get dbValue => switch (this) {
        StatusSolicitacao.pendente    => 'pendente',
        StatusSolicitacao.emAndamento => 'em_andamento',
        StatusSolicitacao.resolvida   => 'resolvida',
      };

  String get label => switch (this) {
        StatusSolicitacao.pendente    => 'Pendente',
        StatusSolicitacao.emAndamento => 'Em andamento',
        StatusSolicitacao.resolvida   => 'Resolvida',
      };
}

class SolicitacaoAnexo {
  final String id;
  final String nome;
  final String url;
  final String storagePath;
  final int tamanho;

  const SolicitacaoAnexo({
    required this.id,
    required this.nome,
    required this.url,
    required this.storagePath,
    required this.tamanho,
  });

  factory SolicitacaoAnexo.fromMap(Map<String, dynamic> m) => SolicitacaoAnexo(
        id:          m['id']           as String,
        nome:        m['nome']         as String,
        url:         m['url']          as String,
        storagePath: m['storage_path'] as String,
        tamanho:     m['tamanho']      as int? ?? 0,
      );
}

class Solicitacao {
  final String id;
  final String titulo;
  final String descricao;
  final String professorId;
  final String professorNome;
  final String coordenadorId;
  final String? turmaId;
  final String? turmaNome;
  final StatusSolicitacao status;
  final DateTime criadaEm;
  final List<SolicitacaoAnexo> anexos;

  const Solicitacao({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.professorId,
    required this.professorNome,
    required this.coordenadorId,
    this.turmaId,
    this.turmaNome,
    required this.status,
    required this.criadaEm,
    this.anexos = const [],
  });

  factory Solicitacao.fromMap(Map<String, dynamic> m) => Solicitacao(
        id:             m['id']            as String,
        titulo:         m['titulo']        as String,
        descricao:      m['descricao']     as String,
        professorId:    m['professor_id']  as String,
        professorNome:  m['professor_nome'] as String? ?? 'Professor',
        coordenadorId:  m['coordenador_id'] as String,
        turmaId:        m['turma_id']      as String?,
        turmaNome:      m['turma_nome']    as String?,
        status: StatusSolicitacaoX.fromString(m['status'] as String? ?? 'pendente'),
        criadaEm: DateTime.parse(m['criada_em'] as String),
        anexos: (m['solicitacao_anexos'] as List? ?? [])
            .map((a) => SolicitacaoAnexo.fromMap(a as Map<String, dynamic>))
            .toList(),
      );
}
