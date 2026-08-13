import 'package:flutter/material.dart';
import '../models/scanner_device.dart';
import '../services/mdns_discovery_service.dart';
import '../services/escl_service.dart';
import 'scan_session_screen.dart';

class ScannerListScreen extends StatefulWidget {
  const ScannerListScreen({super.key});

  @override
  State<ScannerListScreen> createState() => _ScannerListScreenState();
}

class _ScannerListScreenState extends State<ScannerListScreen> {
  final _discovery = MdnsDiscoveryService();
  final _escl = EsclService();
  List<ScannerDevice> _devices = [];
  bool _searching = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final found = await _discovery.discover();
      if (mounted) setState(() => _devices = found);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر البحث عن طابعات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addManualDevice() async {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '80');
    final pathController = TextEditingController(text: '/eSCL');

    final device = await showDialog<ScannerDevice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة طابعة يدوياً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(labelText: 'عنوان IP للطابعة'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'المنفذ (Port)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(labelText: 'مسار eSCL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (ipController.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                ScannerDevice(
                  name: 'طابعة (${ipController.text.trim()})',
                  ip: ipController.text.trim(),
                  port: int.tryParse(portController.text.trim()) ?? 80,
                  resourcePath: pathController.text.trim().isEmpty
                      ? '/eSCL'
                      : pathController.text.trim(),
                  isManual: true,
                ),
              );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (device != null) {
      setState(() => _devices = [..._devices, device]);
    }
  }

  Future<void> _selectDevice(ScannerDevice device) async {
    final ok = await _escl.checkCapabilities(device);
    if (!ok && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تنبيه'),
          content: const Text(
            'تعذر التأكد من دعم هذه الطابعة لبروتوكول eSCL. '
            'هل تريد المتابعة والمحاولة على أي حال؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanSessionScreen(device: device)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار الطابعة'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _search),
        ],
      ),
      body: Column(
        children: [
          if (_searching) const LinearProgressIndicator(),
          Expanded(
            child: _devices.isEmpty && !_searching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لم يتم العثور على طابعات تلقائياً.\n'
                        'تأكد أن الجوال والطابعة على نفس شبكة الواي فاي، '
                        'أو أضف الطابعة يدوياً بعنوان IP الخاص بها.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final d = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.print_outlined),
                        title: Text(d.name),
                        subtitle: Text('${d.ip}:${d.port}${d.resourcePath}'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _selectDevice(d),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('إضافة يدوياً'),
        onPressed: _addManualDevice,
      ),
    );
  }
}
