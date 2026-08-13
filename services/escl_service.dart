import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/scanner_device.dart';

class EsclException implements Exception {
  final String message;
  EsclException(this.message);
  @override
  String toString() => message;
}

/// خدمة التعامل مع بروتوكول eSCL (نفس البروتوكول المستخدم في AirPrint Scan)
/// وهو بروتوكول مفتوح مدعوم من أغلب طابعات المكاتب الحديثة
/// (HP, Canon, Epson, Brother, Xerox ...) عبر HTTP على الشبكة المحلية.
class EsclService {
  /// يتحقق أن الطابعة تستجيب فعلاً كخادم eSCL
  Future<bool> checkCapabilities(ScannerDevice device) async {
    try {
      final res = await http
          .get(Uri.parse('${device.baseUrl}/ScannerCapabilities'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// ينفذ عملية مسح ضوئي كاملة (بدء مهمة -> جلب الصورة -> إغلاق المهمة)
  /// ويرجع بايتات الصورة الناتجة (JPEG عالي الجودة)
  Future<Uint8List> scan(
    ScannerDevice device, {
    int resolutionDpi = 300,
    String colorMode = 'RGB24',
    String inputSource = 'Platen',
  }) async {
    final settingsXml = _buildScanSettingsXml(
      resolutionDpi: resolutionDpi,
      colorMode: colorMode,
      inputSource: inputSource,
    );

    final createRes = await http
        .post(
          Uri.parse('${device.baseUrl}/ScanJobs'),
          headers: {'Content-Type': 'application/xml'},
          body: settingsXml,
        )
        .timeout(const Duration(seconds: 15));

    if (createRes.statusCode != 201 || createRes.headers['location'] == null) {
      throw EsclException(
        'تعذر بدء مهمة المسح على الطابعة (رمز الحالة: ${createRes.statusCode}). '
        'تأكد أن الطابعة تدعم بروتوكول eSCL وأنها متصلة بنفس الشبكة.',
      );
    }

    String jobUrl = createRes.headers['location']!;
    if (!jobUrl.startsWith('http')) {
      // بعض الطابعات ترجع مساراً نسبياً بدل رابط كامل
      final jobId = jobUrl.split('/').last;
      jobUrl = '${device.baseUrl}/ScanJobs/$jobId';
    }

    try {
      final docRes = await http
          .get(Uri.parse('$jobUrl/NextDocument'))
          .timeout(const Duration(seconds: 90));

      if (docRes.statusCode != 200) {
        throw EsclException(
          'تعذر جلب الصورة الممسوحة من الطابعة (رمز الحالة: ${docRes.statusCode}).',
        );
      }

      return docRes.bodyBytes;
    } finally {
      // إنهاء المهمة عند الطابعة، دون إيقاف التنفيذ لو فشل هذا الطلب
      try {
        await http.delete(Uri.parse(jobUrl)).timeout(const Duration(seconds: 5));
      } catch (_) {
        // تجاهل أي خطأ هنا، فهو غير حرج
      }
    }
  }

  String _buildScanSettingsXml({
    required int resolutionDpi,
    required String colorMode,
    required String inputSource,
  }) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<scan:ScanSettings xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03"
                    xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:Version>2.0</pwg:Version>
  <scan:Intent>Photo</scan:Intent>
  <pwg:InputSource>$inputSource</pwg:InputSource>
  <scan:ColorMode>$colorMode</scan:ColorMode>
  <scan:XResolution>$resolutionDpi</scan:XResolution>
  <scan:YResolution>$resolutionDpi</scan:YResolution>
  <scan:DocumentFormatExt>image/jpeg</scan:DocumentFormatExt>
</scan:ScanSettings>''';
  }
}
