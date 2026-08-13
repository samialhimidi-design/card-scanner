import 'package:flutter/material.dart';
import '../services/document_storage_service.dart';
import 'scanner_list_screen.dart';
import 'document_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = DocumentStorageService();
  List<SavedDocument> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final docs = await _storage.loadIndex();
    setState(() {
      _docs = docs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سكانر البطاقات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا يوجد بطاقات محفوظة بعد.\nاضغط على الزر بالأسفل للبدء.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _docs.length,
                  itemBuilder: (context, index) {
                    final doc = _docs[index];
                    return ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(doc.fileName),
                      subtitle: Text(
                        '${doc.createdAt.year}/${doc.createdAt.month}/${doc.createdAt.day} '
                        '${doc.createdAt.hour}:${doc.createdAt.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentViewerScreen(document: doc),
                          ),
                        );
                        _refresh();
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('مسح بطاقة جديدة'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScannerListScreen()),
          );
          _refresh();
        },
      ),
    );
  }
}
