import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/scanner_device.dart';
import '../services/escl_service.dart';
import '../services/pdf_export_service.dart';
import '../services/document_storage_service.dart';
import 'document_viewer_screen.dart';

enum _Step { front, back, layout }

class ScanSessionScreen extends StatefulWidget {
  final ScannerDevice device;
  const ScanSessionScreen({super.key, required this.device});

  @override
  State<ScanSessionScreen> createState() => _ScanSessionScreenState();
}

class _ScanSessionScreenState extends State<ScanSessionScreen> {
  final _escl = EsclService();
  final _pdfService = PdfExportService();
  final _storage = DocumentStorageService();

  _Step _step = _Step.front;
  bool _busy = false;

  Uint8List? _frontImage;
  Uint8List? _backImage;
  CardLayout _layout = CardLayout.vertical;

  // البطاقات التي تمت إضافتها بالفعل لنفس الملف (لحالة تجميع عدة بطاقات بملف واحد)
  final List<CardScanEntry> _accumulatedCards = [];

  Future<void> _scanFront() async {
    setState(() => _busy = true);
    try {
      final bytes = await _escl.scan(widget.device);
      setState(() {
        _frontImage = bytes;
        _step = _Step.back;
      });
    } catch (e) {
      _showError('فشل مسح الوجه الأمامي: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanBack() async {
    setState(() => _busy = true);
    try {
      final bytes = await _escl.scan(widget.device);
      setState(() {
        _backImage = bytes;
        _step = _Step.layout;
      });
    } catch (e) {
      _showError('فشل مسح الوجه الخلفي: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  CardScanEntry get _currentEntry => CardScanEntry(
        front: _frontImage!,
        back: _backImage,
        layout: _layout,
      );

  /// إضافة البطاقة الحالية للقائمة ثم البدء ببطاقة جديدة لنفس الملف
  void _addAnotherCard() {
    setState(() {
      _accumulatedCards.add(_currentEntry);
      _frontImage = null;
      _backImage = null;
      _step = _Step.front;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تمت إضافة البطاقة (${_accumulatedCards.length} حتى الآن). ضع البطاقة التالية.')),
    );
  }

  /// حفظ الملف النهائي (بطاقة واحدة أو عدة بطاقات مجمّعة)
  Future<void> _saveFinalFile() async {
    setState(() => _busy = true);
    try {
      final allCards = [..._accumulatedCards, _currentEntry];

      final pdfBytes = allCards.length == 1
          ? await _pdfService.buildSingleCardPdf(allCards.first)
          : await _pdfService.buildMultiCardPdf(allCards);

      final saved = await _storage.savePdf(pdfBytes);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: saved)),
      );
    } catch (e) {
      _showError('فشل إنشاء ملف PDF: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مسح البطاقة - ${widget.device.name}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : _buildStepBody(),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _Step.front:
        return _buildActionStep(
          title: _accumulatedCards.isEmpty
              ? 'ضع الوجه الأمامي للبطاقة في السكانر'
              : 'ضع الوجه الأمامي للبطاقة التالية في السكانر',
          buttonLabel: 'مسح الوجه الأمامي',
          onPressed: _scanFront,
        );

      case _Step.back:
        return Column(
          children: [
            Expanded(child: Image.memory(_frontImage!, fit: BoxFit.contain)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _scanFront,
                    child: const Text('إعادة مسح الوجه الأمامي'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _scanBack,
                    child: const Text('التالي: الوجه الخلفي'),
                  ),
                ),
              ],
            ),
          ],
        );

      case _Step.layout:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Image.memory(_frontImage!, fit: BoxFit.contain)),
                  const SizedBox(width: 8),
                  if (_backImage != null)
                    Expanded(child: Image.memory(_backImage!, fit: BoxFit.contain)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('اختر طريقة ترتيب الوجهين في الصفحة:'),
            ),
            RadioListTile<CardLayout>(
              title: const Text('عمودي (فوق بعض)'),
              value: CardLayout.vertical,
              groupValue: _layout,
              onChanged: (v) => setState(() => _layout = v!),
            ),
            RadioListTile<CardLayout>(
              title: const Text('أفقي (جنب بعض)'),
              value: CardLayout.horizontal,
              groupValue: _layout,
              onChanged: (v) => setState(() => _layout = v!),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _scanBack,
              child: const Text('إعادة مسح الوجه الخلفي'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('إضافة بطاقة أخرى لنفس الملف'),
                    onPressed: _addAnotherCard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveFinalFile,
                child: Text(
                  _accumulatedCards.isEmpty
                      ? 'حفظ كملف PDF'
                      : 'حفظ الملف (${_accumulatedCards.length + 1} بطاقات)',
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildActionStep({
    required String title,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.credit_card, size: 80, color: Colors.indigo),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.scanner),
            label: Text(buttonLabel),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
