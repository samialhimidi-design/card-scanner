import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// طريقة ترتيب وجهي البطاقة داخل صفحة الـ PDF
enum CardLayout { vertical, horizontal }

/// يمثل بطاقة واحدة تم مسحها (وجه أمامي + وجه خلفي اختياري)
/// جاهزة لإضافتها كصفحة داخل ملف PDF
class CardScanEntry {
  final Uint8List front;
  final Uint8List? back;
  final CardLayout layout;

  CardScanEntry({
    required this.front,
    this.back,
    required this.layout,
  });
}

/// خدمة بناء ملفات PDF بحجم A4 قياسي.
/// الميزة الأساسية هنا: دمج صورتي وجهي البطاقة (بعد مسحهما بشكل منفصل)
/// في صفحة واحدة، بنفس جودة وألوان الصورة الأصلية القادمة من السكانر
/// (بدون أي ضغط إضافي يفقد الجودة).
class PdfExportService {
  pw.Page _buildCardPage(CardScanEntry card) {
    final frontImage = pw.MemoryImage(card.front);
    final backImage = card.back != null ? pw.MemoryImage(card.back!) : null;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        final children = <pw.Widget>[
          pw.Expanded(
            child: pw.Center(
              child: pw.Image(frontImage, fit: pw.BoxFit.contain),
            ),
          ),
          if (backImage != null) ...[
            pw.SizedBox(width: 12, height: 12),
            pw.Expanded(
              child: pw.Center(
                child: pw.Image(backImage, fit: pw.BoxFit.contain),
              ),
            ),
          ],
        ];

        return card.layout == CardLayout.vertical
            ? pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: children,
              )
            : pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: children,
              );
      },
    );
  }

  /// ينشئ ملف PDF يحوي بطاقة واحدة فقط (صفحة واحدة)
  Future<Uint8List> buildSingleCardPdf(CardScanEntry card) async {
    final doc = pw.Document();
    doc.addPage(_buildCardPage(card));
    return doc.save();
  }

  /// ينشئ ملف PDF واحد يحوي عدة بطاقات، كل بطاقة في صفحة A4 مستقلة.
  /// هذا يخدم حالة "تجميع كل البطاقات داخل ملف واحد" التي طلبها المستخدم.
  Future<Uint8List> buildMultiCardPdf(List<CardScanEntry> cards) async {
    final doc = pw.Document();
    for (final card in cards) {
      doc.addPage(_buildCardPage(card));
    }
    return doc.save();
  }
}
