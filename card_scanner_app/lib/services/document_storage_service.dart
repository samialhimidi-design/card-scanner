import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// يمثل مستند PDF محفوظ على الجهاز
class SavedDocument {
  final String id;
  final String fileName;
  final String filePath;
  final DateTime createdAt;

  SavedDocument({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedDocument.fromJson(Map<String, dynamic> json) => SavedDocument(
        id: json['id'],
        fileName: json['fileName'],
        filePath: json['filePath'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

/// خدمة تخزين محلية فقط (لا يتم رفع أي بيانات لأي سيرفر)،
/// تحفظ ملفات PDF داخل مجلد التطبيق الخاص على الجهاز،
/// وتحتفظ بفهرس بسيط (JSON) لعرضها في الشاشة الرئيسية.
class DocumentStorageService {
  static const String _indexFileName = 'documents_index.json';

  Future<Directory> _scansDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/scans');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async {
    final base = await getApplicationDocumentsDirectory();
    return File('${base.path}/$_indexFileName');
  }

  Future<List<SavedDocument>> loadIndex() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final List list = jsonDecode(content);
    return list.map((e) => SavedDocument.fromJson(e)).toList();
  }

  Future<void> _saveIndex(List<SavedDocument> docs) async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(docs.map((d) => d.toJson()).toList()));
  }

  /// يحفظ ملف PDF جديد على الجهاز ويضيفه لفهرس المستندات
  Future<SavedDocument> savePdf(Uint8List bytes, {String? customName}) async {
    final dir = await _scansDir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = customName ?? 'card_$id.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    final doc = SavedDocument(
      id: id,
      fileName: fileName,
      filePath: file.path,
      createdAt: DateTime.now(),
    );

    final docs = await loadIndex();
    docs.insert(0, doc);
    await _saveIndex(docs);

    return doc;
  }

  Future<void> deleteDocument(SavedDocument doc) async {
    final file = File(doc.filePath);
    if (await file.exists()) await file.delete();
    final docs = await loadIndex();
    docs.removeWhere((d) => d.id == doc.id);
    await _saveIndex(docs);
  }
}
