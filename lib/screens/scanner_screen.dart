import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/services.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _torchOn = false;
  bool _paused = false;

  static const String _kScanHistory = 'scan_history'; // shared_prefs key

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kScanHistory);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list;
  }

  Future<void> _saveHistory(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kScanHistory, jsonEncode(items));
  }

  Future<void> _addToHistory(String value, String format) async {
    final items = await _loadHistory();
    items.insert(0, {
      "value": value,
      "format": format,
      "ts": DateTime.now().toIso8601String(),
    });
    // keep last 200
    if (items.length > 200) {
      items.removeRange(200, items.length);
    }
    await _saveHistory(items);
  }

  Future<void> _showHistorySheet() async {
    final t = AppLocalizations.of(context)!;
    final items = await _loadHistory();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.scannerHistory,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await _saveHistory([]);
                        if (!mounted) return;
                        Navigator.pop(context);
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(t.clear),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: items.isEmpty
                      ? Center(child: Text(t.empty))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final it = items[i];
                            final value = (it["value"] ?? "").toString();
                            final format = (it["format"] ?? "").toString();
                            final ts = (it["ts"] ?? "").toString();

                            return ListTile(
                              leading: const Icon(Icons.qr_code_2),
                              title: Text(
                                value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text("$format • $ts"),
                              trailing: IconButton(
                                tooltip: t.copy,
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: value));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(t.copied)),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_paused) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;

    if (raw == null || raw.trim().isEmpty) return;

    setState(() => _paused = true);
    await _addToHistory(raw, barcode?.format.name ?? "unknown");

    if (!mounted) return;
    final t = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.scanned),
        content: SelectableText(raw),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: raw));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.copied)),
              );
            },
            child: Text(t.copy),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(t.ok),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _paused = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.tabScanner,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              IconButton(
                tooltip: t.history,
                onPressed: _showHistorySheet,
                icon: const Icon(Icons.history),
              ),
              IconButton(
                tooltip: t.torch,
                onPressed: () async {
                  await _controller.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
                icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
        ),
      ],
    );
  }
}
