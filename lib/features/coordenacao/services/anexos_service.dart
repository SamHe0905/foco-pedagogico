import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/demanda_anexo.dart';

/// Anexos (PDF/Doc) das demandas: listagem, upload e remoção no Storage.
class AnexosService {
  static final _db = Supabase.instance.client;

  static const _bucket = 'demanda-anexos';

  static Future<List<DemandaAnexo>> getAnexos(String demandaId) async {
    final data = await _db
        .from('demanda_anexos')
        .select()
        .eq('demanda_id', demandaId)
        .order('criado_em');
    return (data as List)
        .map((m) => DemandaAnexo.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<void> uploadAnexo(
      String demandaId, String nome, Uint8List bytes) async {
    // Supabase Storage rejeita espaços e caracteres especiais no path
    final safeName = _sanitizeFileName(nome);
    final path =
        '$demandaId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(nome)),
        );

    final url = _db.storage.from(_bucket).getPublicUrl(path);

    await _db.from('demanda_anexos').insert({
      'demanda_id':   demandaId,
      'nome':         nome,
      'url':          url,
      'storage_path': path,
      'tamanho':      bytes.length,
    });
  }

  static Future<void> deleteAnexo(String anexoId, String storagePath) async {
    await _db.storage.from(_bucket).remove([storagePath]);
    await _db.from('demanda_anexos').delete().eq('id', anexoId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Retorna o MIME type apropriado baseado na extensão do arquivo.
  static String _contentTypeFor(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'pdf'  => 'application/pdf',
      'doc'  => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _      => 'application/octet-stream',
    };
  }

  /// Remove espaços, acentos e caracteres especiais do nome do arquivo
  /// para garantir compatibilidade com o Supabase Storage.
  static String _sanitizeFileName(String nome) {
    const acentos = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
      'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Õ': 'O', 'Ô': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C', 'Ñ': 'N',
    };

    var resultado = nome;
    acentos.forEach((acento, substituto) {
      resultado = resultado.replaceAll(acento, substituto);
    });

    // Substitui espaços por underscore e remove outros caracteres inválidos
    return resultado
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\-.]'), '');
  }
}
