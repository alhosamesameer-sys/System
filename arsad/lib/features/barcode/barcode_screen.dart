import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  late final MobileScannerController controller;
  bool done = false;
  bool retrying = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const <BarcodeFormat>[
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.itf,
        BarcodeFormat.qrCode,
      ],
    );
  }

  void onDetect(BarcodeCapture capture) {
    if (done || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty || !mounted) return;
    done = true;
    Navigator.of(context).pop(code);
  }

  Future<void> retryCamera() async {
    if (retrying || !mounted) return;
    setState(() => retrying = true);
    try {
      await controller.stop();
      await controller.start();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تشغيل الكاميرا. تحقق من إذن الكاميرا وأغلق أي تطبيق يستخدمها ثم حاول مجددًا.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => retrying = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مسح الباركود')),
        body: MobileScanner(
          controller: controller,
          onDetect: onDetect,
          errorBuilder: (context, error, child) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'تعذر تشغيل الكاميرا',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'يرجى السماح لتطبيق أرصاد باستخدام الكاميرا من إعدادات الهاتف.'
                        : 'تحقق من إذن الكاميرا وأغلق أي تطبيق آخر يستخدمها، ثم أعد المحاولة.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: retrying ? null : retryCamera,
                    icon: const Icon(Icons.refresh),
                    label: Text(retrying ? 'جارٍ إعادة المحاولة...' : 'إعادة المحاولة'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
