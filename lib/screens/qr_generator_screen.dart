import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_gallery_saver2/image_gallery_saver.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();

  String _data = '';
  bool _busy = false;

  // QR color
  Color _qrColor = Colors.black;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    setState(() => _data = _controller.text.trim());
  }

  void _clear() {
    _controller.clear();
    setState(() => _data = '');
  }

  Future<void> _copyText() async {
    final t = AppLocalizations.of(context)!;
    if (_data.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _data));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.copied)),
    );
  }

  Future<Uint8List?> _captureQrPngBytes() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<File?> _savePngToAppFolder(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/qr');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${folder.path}/qr_$ts.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _saveToGallery() async {
    final t = AppLocalizations.of(context)!;
    if (_data.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      // Try permission (some devices need it). If denied, we still try saving.
      if (Platform.isAndroid) {
        await Permission.storage.request();
      } else if (Platform.isIOS) {
        await Permission.photosAddOnly.request();
      }

      final bytes = await _captureQrPngBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.qrSaveFailed)));
        return;
      }

      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: 'qr_${DateTime.now().millisecondsSinceEpoch}',
      );

      final success = (result['isSuccess'] == true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? t.qrSavedToGallery : t.qrSaveFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToAppFolder() async {
    final t = AppLocalizations.of(context)!;
    if (_data.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      final bytes = await _captureQrPngBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.qrSaveFailed)));
        return;
      }

      final file = await _savePngToAppFolder(bytes);
      if (!mounted) return;

      if (file == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.qrSaveFailed)));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.qrSavedTo}: ${file.path}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareQr() async {
    final t = AppLocalizations.of(context)!;
    if (_data.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      final bytes = await _captureQrPngBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.qrShareFailed)));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_share.png');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: t.qrShareText,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openColorPicker() {
    final t = AppLocalizations.of(context)!;

    const colors = <Color>[
      Colors.black,
      Color(0xFF0B1020),
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFEF6C00),
      Color(0xFFC62828),
      Color(0xFF6A1B9A),

      // ✅ extra colors (your additions)
      Color(0xFF111827),
      Color(0xFF1F2937),
      Color(0xFF0F172A),
      Color(0xFF020617),
      Color(0xFF1E3A8A),
      Color(0xFF312E81),
      Color(0xFF064E3B),
      Color(0xFF022C22),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.qrColor,
                  style:
                      const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in colors)
                      InkWell(
                        onTap: () {
                          setState(() => _qrColor = c);
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      // ✅ AppBar حذف شد تا Back دوبار و دو تا Title از بین بره
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/home/ic_qr.png',
                        width: 36,
                        height: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.qrGeneratorDesc,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(t.toolsInput,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: t.qrInputHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _generate,
                        icon: const Icon(Icons.qr_code),
                        label: Text(t.actionGenerate),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _copyText,
                        icon: const Icon(Icons.copy),
                        label: Text(t.copy),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: (_busy || _data.isEmpty) ? null : _saveToGallery,
                        icon: const Icon(Icons.photo),
                        label: Text(t.actionSaveGallery),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: (_busy || _data.isEmpty) ? null : _shareQr,
                        icon: const Icon(Icons.share),
                        label: Text(t.actionShare),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: (_busy || _data.isEmpty) ? null : _saveToAppFolder,
                        icon: const Icon(Icons.download),
                        label: Text(t.actionSave),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_data.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(
                        data: _data,
                        size: 240,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: _qrColor,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: _qrColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // ✅ چون AppBar حذف شد، این دکمه‌ها رو می‌ذاریم پایین (اختیاری)
      floatingActionButton: FloatingActionButton.small(
        onPressed: _openColorPicker,
        child: const Icon(Icons.palette_outlined),
      ),
    );
  }
}
