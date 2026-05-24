class DemandaAnexo {
  final String id;
  final String demandaId;
  final String nome;
  final String url;
  final String storagePath;
  final int? tamanho;

  const DemandaAnexo({
    required this.id,
    required this.demandaId,
    required this.nome,
    required this.url,
    required this.storagePath,
    this.tamanho,
  });

  factory DemandaAnexo.fromMap(Map<String, dynamic> m) => DemandaAnexo(
        id:          m['id']           as String,
        demandaId:   m['demanda_id']   as String,
        nome:        m['nome']         as String,
        url:         m['url']          as String,
        storagePath: m['storage_path'] as String,
        tamanho:     m['tamanho']      as int?,
      );

  String get tamanhoLabel {
    if (tamanho == null) return '';
    final kb = tamanho! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}
