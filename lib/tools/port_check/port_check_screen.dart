import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class PortCheckScreen extends StatefulWidget {
  const PortCheckScreen({super.key});

  @override
  State<PortCheckScreen> createState() => _PortCheckScreenState();
}

class _PortCheckScreenState extends State<PortCheckScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '443');

  bool _checking = false;

  // DNS
  bool _dnsLoading = false;
  List<String> _resolvedIps = [];
  String? _dnsError;

  // Results
  String? _details; // text summary for copy
  String? _jsonOut; // json for copy/share
  final List<_ScanResult> _results = [];

  // History
  static const String _kHistoryKey = 'port_check_history';
  final List<_HistoryItem> _history = [];
  bool _historyLoaded = false;

  static const int _historyMax = 15;

  // Presets
  static const List<int> _presetPorts = [80, 443, 22, 21, 25, 53, 3306, 8080];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(raw);
        _history
          ..clear()
          ..addAll(list.map((e) => _HistoryItem.fromJson(e)).whereType<_HistoryItem>());
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _historyLoaded = true);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(_history.map((e) => e.toJson()).toList());
    await prefs.setString(_kHistoryKey, raw);
  }

  Future<void> _addToHistory(_HistoryItem item) async {
    _history.removeWhere((e) => e.host == item.host && e.portSpec == item.portSpec);
    _history.insert(0, item);
    if (_history.length > _historyMax) {
      _history.removeRange(_historyMax, _history.length);
    }
    await _saveHistory();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteHistory(int index) async {
    if (index < 0 || index >= _history.length) return;
    _history.removeAt(index);
    await _saveHistory();
    if (!mounted) return;
    setState(() {});
  }

  void _applyPreset(int port) {
    _portCtrl.text = port.toString();
    FocusScope.of(context).unfocus();
  }

  String _normalizeHost(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;

    if (s.startsWith('http://') || s.startsWith('https://')) {
      final u = Uri.tryParse(s);
      if (u != null && u.host.isNotEmpty) return u.host;
    }

    if (s.contains(':')) {
      final m = RegExp(r'^\[(.+)\]:(\d+)$').firstMatch(s);
      if (m != null) return m.group(1) ?? s;

      final parts = s.split(':');
      if (parts.length == 2 && parts[0].isNotEmpty) return parts[0];
    }

    return s;
  }

  List<int> _parsePortSpec(String input) {
    final s = input.trim();
    if (s.isEmpty) return [];

    final set = <int>{};
    final parts = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);

    for (final part in parts) {
      if (part.contains('-')) {
        final seg = part.split('-').map((e) => e.trim()).toList();
        if (seg.length != 2) continue;
        final a = int.tryParse(seg[0]);
        final b = int.tryParse(seg[1]);
        if (a == null || b == null) continue;
        final start = a < b ? a : b;
        final end = a < b ? b : a;
        for (int p = start; p <= end; p++) {
          if (p >= 1 && p <= 65535) set.add(p);
        }
      } else {
        final p = int.tryParse(part);
        if (p != null && p >= 1 && p <= 65535) set.add(p);
      }
    }

    final list = set.toList()..sort();
    return list;
  }

  Future<void> _resolveDns(String host) async {
    setState(() {
      _dnsLoading = true;
      _dnsError = null;
      _resolvedIps = [];
    });

    try {
      final res = await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
      final ips = <String>[];
      for (final a in res) {
        final ip = a.address.trim();
        if (ip.isNotEmpty && !ips.contains(ip)) ips.add(ip);
      }
      if (!mounted) return;
      setState(() => _resolvedIps = ips);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _dnsError = 'TIMEOUT');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dnsError = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _dnsLoading = false);
    }
  }

  Future<_ScanResult> _checkSinglePort({required String host, required int port}) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      socket.destroy();
      sw.stop();
      final ms = double.parse((sw.elapsedMicroseconds / 1000.0).toStringAsFixed(1));
      return _ScanResult(port: port, status: _PortStatus.open, latencyMs: ms);
    } on TimeoutException {
      return _ScanResult(port: port, status: _PortStatus.timeout, latencyMs: null);
    } on SocketException {
      return _ScanResult(port: port, status: _PortStatus.closed, latencyMs: null);
    } catch (_) {
      return _ScanResult(port: port, status: _PortStatus.error, latencyMs: null);
    }
  }

  Map<String, dynamic> _buildJson(String host, String portSpec) {
    return {
      'host': host,
      'portSpec': portSpec,
      'timestamp': DateTime.now().toIso8601String(),
      'dns': {
        'ips': _resolvedIps,
        'error': _dnsError,
      },
      'results': _results
          .map((r) => {
                'port': r.port,
                'status': r.status.name,
                'latencyMs': r.latencyMs,
              })
          .toList(),
    };
  }

  Future<void> _checkPorts() async {
    final t = AppLocalizations.of(context)!;

    final host = _normalizeHost(_hostCtrl.text);
    final portSpec = _portCtrl.text.trim();

    if (host.isEmpty) {
      _showMsg(t.toolPortCheckEnterHost);
      return;
    }

    final ports = _parsePortSpec(portSpec);
    if (ports.isEmpty) {
      _showMsg(t.toolPortCheckInvalidPort);
      return;
    }

    setState(() {
      _checking = true;
      _results.clear();
      _details = null;
      _jsonOut = null;
      _resolvedIps = [];
      _dnsError = null;
    });

    unawaited(_resolveDns(host));

    try {
      for (final p in ports) {
        final r = await _checkSinglePort(host: host, port: p);
        if (!mounted) return;
        setState(() => _results.add(r));
      }

      final lines = <String>[];
      lines.add('Host: $host');
      lines.add('Ports: $portSpec');
      if (_resolvedIps.isNotEmpty) {
        lines.add('DNS: ${_resolvedIps.join(', ')}');
      }
      lines.add('---');
      for (final r in _results) {
        final s = _statusText(t, r.status);
        final ms = (r.latencyMs == null) ? '' : ' (${r.latencyMs!.toStringAsFixed(1)} ms)';
        lines.add('${r.port}\t$s$ms');
      }
      _details = lines.join('\n');

      final jsonMap = _buildJson(host, portSpec);
      _jsonOut = const JsonEncoder.withIndent('  ').convert(jsonMap);

      await _addToHistory(
        _HistoryItem(
          host: host,
          portSpec: portSpec,
          timeMs: DateTime.now().millisecondsSinceEpoch,
          summary: _summaryForHistory(t, _results),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  String _summaryForHistory(AppLocalizations t, List<_ScanResult> results) {
    int open = 0, closed = 0, timeout = 0, error = 0;
    for (final r in results) {
      switch (r.status) {
        case _PortStatus.open:
          open++;
          break;
        case _PortStatus.closed:
          closed++;
          break;
        case _PortStatus.timeout:
          timeout++;
          break;
        case _PortStatus.error:
          error++;
          break;
      }
    }
    return '${t.toolPortCheckOpen}: $open  '
        '${t.toolPortCheckClosed}: $closed  '
        '${t.toolPortCheckTimeout}: $timeout  '
        '${t.toolPortCheckError}: $error';
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _copyDialog(String title, String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SelectableText(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _shareText(String text) async {
    await Share.share(text);
  }

  Color _statusColor(BuildContext context, _PortStatus st) {
    final b = Theme.of(context).brightness;
    if (st == _PortStatus.open) return b == Brightness.dark ? Colors.greenAccent : Colors.green;
    if (st == _PortStatus.closed) return b == Brightness.dark ? Colors.orangeAccent : Colors.orange;
    if (st == _PortStatus.timeout) return b == Brightness.dark ? Colors.redAccent : Colors.red;
    return Theme.of(context).colorScheme.onSurface;
  }

  String _statusText(AppLocalizations t, _PortStatus st) {
    switch (st) {
      case _PortStatus.open:
        return t.toolPortCheckOpen;
      case _PortStatus.closed:
        return t.toolPortCheckClosed;
      case _PortStatus.timeout:
        return t.toolPortCheckTimeout;
      case _PortStatus.error:
        return t.toolPortCheckError;
    }
  }

  String _formatTime(AppLocalizations t, int msEpoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(msEpoch);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.toolPortCheckTitle),
        actions: [
          IconButton(
            tooltip: t.toolPortCheckRun,
            onPressed: _checking ? null : _checkPorts,
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: ListView(
          children: [
            // Input card
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _hostCtrl,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t.toolPortCheckHost,
                      hintText: 'example.com',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _portCtrl,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _checking ? null : _checkPorts(),
                    decoration: InputDecoration(
                      labelText: t.toolPortCheckPort,
                      hintText: '443  |  80,443,8080  |  20-25',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.toolPortCheckPresets,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetPorts.map((p) {
                      return InkWell(
                        onTap: () => _applyPreset(p),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                          ),
                          child: Text(
                            p.toString(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _checkPorts,
                      icon: const Icon(Icons.network_check),
                      label: Text(t.toolPortCheckRun),
                    ),
                  ),
                ],
              ),
            ),

            // DNS card
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.dns, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.toolPortCheckDns,
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        if (_dnsLoading)
                          const Text('...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                        else if (_dnsError != null)
                          Text(_dnsError!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                        else if (_resolvedIps.isEmpty)
                          Text(t.toolPortCheckDnsEmpty,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                        else
                          Text(_resolvedIps.join(', '),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t.toolPortCheckRefreshDns,
                    onPressed: _dnsLoading
                        ? null
                        : () {
                            final host = _normalizeHost(_hostCtrl.text);
                            if (host.isEmpty) {
                              _showMsg(t.toolPortCheckEnterHost);
                              return;
                            }
                            _resolveDns(host);
                          },
                    icon: _dnsLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    color: Colors.white.withOpacity(0.9),
                  ),
                ],
              ),
            ),

            // Result card
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.toolPortCheckResult,
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (_results.isEmpty)
                    Text(t.toolPortCheckNoResult, style: const TextStyle(color: Colors.white))
                  else
                    Column(
                      children: _results.map((r) {
                        final stText = _statusText(t, r.status);
                        final ms = r.latencyMs == null ? '' : '${r.latencyMs!.toStringAsFixed(1)} ms';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 58,
                                child: Text(
                                  r.port.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  stText,
                                  style: TextStyle(
                                    color: _statusColor(context, r.status),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (ms.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                                  ),
                                  child: Text(ms,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 10),

                  // Text copy + JSON copy/share
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton.icon(
                        onPressed: (_details == null) ? null : () => _copyDialog(t.toolPortCheckCopy, _details!),
                        icon: const Icon(Icons.copy),
                        label: Text(t.toolPortCheckCopyText),
                      ),
                      TextButton.icon(
                        onPressed: (_jsonOut == null) ? null : () => _copyDialog(t.toolPortCheckCopyJson, _jsonOut!),
                        icon: const Icon(Icons.data_object),
                        label: Text(t.toolPortCheckCopyJson),
                      ),
                      TextButton.icon(
                        onPressed: (_jsonOut == null) ? null : () => _shareText(_jsonOut!),
                        icon: const Icon(Icons.share),
                        label: Text(t.toolPortCheckShareJson),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // History card
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.toolPortCheckHistory,
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (!_historyLoaded)
                    const Center(
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_history.isEmpty)
                    Text(t.toolPortCheckHistoryEmpty, style: const TextStyle(color: Colors.white))
                  else
                    Column(
                      children: List.generate(_history.length, (i) {
                        final h = _history[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    _hostCtrl.text = h.host;
                                    _portCtrl.text = h.portSpec;
                                    FocusScope.of(context).unfocus();
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${h.host}   •   ${h.portSpec}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(h.summary, style: TextStyle(color: Colors.white.withOpacity(0.85))),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTime(t, h.timeMs),
                                        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: t.toolPortCheckUse,
                                onPressed: () {
                                  _hostCtrl.text = h.host;
                                  _portCtrl.text = h.portSpec;
                                  FocusScope.of(context).unfocus();
                                  if (!_checking) _checkPorts();
                                },
                                icon: const Icon(Icons.play_arrow),
                                color: Colors.white.withOpacity(0.90),
                              ),
                              IconButton(
                                tooltip: t.toolPortCheckDelete,
                                onPressed: () => _deleteHistory(i),
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PortStatus { open, closed, timeout, error }

class _ScanResult {
  final int port;
  final _PortStatus status;
  final double? latencyMs;

  _ScanResult({required this.port, required this.status, required this.latencyMs});
}

class _HistoryItem {
  final String host;
  final String portSpec;
  final int timeMs;
  final String summary;

  _HistoryItem({required this.host, required this.portSpec, required this.timeMs, required this.summary});

  Map<String, dynamic> toJson() => {
        'host': host,
        'portSpec': portSpec,
        'timeMs': timeMs,
        'summary': summary,
      };

  static _HistoryItem? fromJson(dynamic x) {
    try {
      final m = (x as Map).cast<String, dynamic>();
      final host = (m['host'] ?? '').toString();
      final portSpec = (m['portSpec'] ?? '').toString();
      final timeMs = int.tryParse((m['timeMs'] ?? '').toString()) ?? 0;
      final summary = (m['summary'] ?? '').toString();
      if (host.isEmpty || portSpec.isEmpty) return null;
      return _HistoryItem(host: host, portSpec: portSpec, timeMs: timeMs, summary: summary);
    } catch (_) {
      return null;
    }
  }
}
