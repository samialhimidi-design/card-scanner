import 'package:multicast_dns/multicast_dns.dart';
import '../models/scanner_device.dart';

/// يكتشف الطابعات/السكانرات المتوفرة على شبكة الواي فاي المحلية
/// عن طريق البحث عن خدمة eSCL القياسية (_uscan._tcp) عبر بروتوكول mDNS/Bonjour.
///
/// ملاحظة: بعض الطابعات قد لا تُعلن نفسها عبر mDNS بسبب إعدادات الشبكة
/// (مثل شبكات الشركات التي تمنع بث mDNS)، لذلك يوفر التطبيق أيضاً
/// خيار إضافة الطابعة يدوياً عبر عنوان IP (انظر شاشة اختيار الطابعة).
class MdnsDiscoveryService {
  static const String _serviceType = '_uscan._tcp';

  Future<List<ScannerDevice>> discover({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final List<ScannerDevice> found = [];
    final MDnsClient client = MDnsClient();

    try {
      await client.start();

      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceType),
          )
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        final String displayName =
            ptr.domainName.replaceAll('.$_serviceType.local', '');

        String host = '';
        int port = 80;
        String resourcePath = '/eSCL';

        // البحث عن السيرفر (المضيف) والمنفذ الخاص بالخدمة
        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
          host = srv.target;
          port = srv.port;
        }

        // البحث عن سجل TXT لمعرفة المسار الصحيح لخدمة eSCL (مفتاح rs)
        await for (final TxtResourceRecord txt in client
            .lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(ptr.domainName),
            )
            .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
          final attrs = _parseTxt(txt.text);
          if (attrs.containsKey('rs') && attrs['rs']!.isNotEmpty) {
            resourcePath = '/${attrs['rs']}';
          }
        }

        // تحويل اسم المضيف إلى عنوان IP فعلي
        String ip = '';
        if (host.isNotEmpty) {
          await for (final IPAddressResourceRecord a in client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(host),
              )
              .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
            ip = a.address.address;
          }
        }

        if (ip.isNotEmpty) {
          found.add(ScannerDevice(
            name: displayName.isEmpty ? ip : displayName,
            ip: ip,
            port: port,
            resourcePath: resourcePath,
            isManual: false,
          ));
        }
      }
    } finally {
      client.stop();
    }

    return found;
  }

  Map<String, String> _parseTxt(String raw) {
    final Map<String, String> result = {};
    for (final part in raw.split('\n')) {
      final idx = part.indexOf('=');
      if (idx > 0) {
        result[part.substring(0, idx).trim()] = part.substring(idx + 1).trim();
      }
    }
    return result;
  }
}
