// Full-screen camera barcode scanner for mobile (Android/iOS).
//   Continuous mode: stays open and reports every detected code via [onDetect],
//   which returns true if the product was found & added. A time-based debounce
//   lets the same barcode be re-scanned after a short pause (two identical items),
//   while ignoring the rapid duplicate frames the camera produces for one scan.
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  /// Continuous mode: called for each accepted scan; return true if the code
  /// matched a product. Ignored (and optional) when [singleScan] is true.
  final Future<bool> Function(String code)? onDetect;

  /// Single-shot mode: capture one code, then pop the route returning that code
  /// as a `String`. Use this to fill a form field (e.g. the product barcode).
  final bool singleScan;

  const BarcodeScannerScreen({super.key, this.onDetect, this.singleScan = false})
      : assert(singleScan || onDetect != null,
            'Provide onDetect for continuous mode, or set singleScan: true');

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );

  static const _debounce = Duration(milliseconds: 1200);
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  int _count = 0;

  Future<void> _onCapture(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (code == null) return;

    // Single-shot: return the first valid code and close.
    if (widget.singleScan) {
      _busy = true; // block further captures while popping
      Navigator.of(context).pop(code);
      return;
    }

    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt) < _debounce) return;
    _lastCode = code;
    _lastAt = now;

    _busy = true;
    try {
      final found = await widget.onDetect!(code);
      if (!mounted) return;
      if (found) setState(() => _count++);
      _flash(found ? 'Added  ·  $code' : 'Not found  ·  $code', found);
    } finally {
      _busy = false;
    }
  }

  void _flash(String message, bool ok) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_count == 0 ? 'Scan barcode' : 'Scanned: $_count'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onCapture),
          // Simple reticle to guide aiming.
          IgnorePointer(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: Text(_count == 0 ? 'Done' : 'Done  ($_count added)'),
            ),
          ),
        ],
      ),
    );
  }
}
