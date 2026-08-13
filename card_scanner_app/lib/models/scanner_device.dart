/// يمثل طابعة/سكانر تم اكتشافه على الشبكة أو تمت إضافته يدوياً
class ScannerDevice {
  final String name;
  final String ip;
  final int port;
  final String resourcePath; // غالباً "/eSCL"
  final bool isManual;

  ScannerDevice({
    required this.name,
    required this.ip,
    required this.port,
    this.resourcePath = '/eSCL',
    this.isManual = false,
  });

  /// الرابط الأساسي لكل طلبات eSCL على هذه الطابعة
  String get baseUrl => 'http://$ip:$port$resourcePath';

  @override
  String toString() => '$name ($ip:$port$resourcePath)';
}
