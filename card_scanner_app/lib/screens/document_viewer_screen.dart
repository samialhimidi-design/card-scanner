import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/document_storage_service.dart';

class DocumentViewerScreen extends StatelessWidget {
  final SavedDocument document;
  const DocumentViewerScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document.fileName),
        actions: [
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تأكيد الحذف'),
                  content: const Text('هل تريد حذف هذا الملف نهائياً؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DocumentStorageService().deleteDocument(document);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      // مكتبة printing توفر عرض PDF داخل التطبيق + أزرار مشاركة وطباعة جاهزة
      body: PdfPreview(
        build: (format) => File(document.filePath).readAsBytes(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowSharing: true,
        allowPrinting: true,
        pdfFileName: document.fileName,
      ),
    );
  }
}
