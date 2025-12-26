import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vpn_detector/vpn_detector.dart';

class MyIpAddressScreen extends StatefulWidget {
  const MyIpAddressScreen({super.key});

  @override
  State<MyIpAddressScreen> createState() => _MyIpAddressScreenState();
}

class _MyIpAddressScreenState extends State<MyIpAddressScreen> {
  bool _loading = true;
  bool _pingLoading = false;
  bool _netLoading = false;
  String? _error;

  // Data
  String? ip;
  String? countryName;
  String? countryCode;
  String? city;
  String? isp;
  String? asn; // e.g. AS15169
  String? networkType; // WiFi / Mobile / None / Other
  bool? vpnActive;
  double? pingMs;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final geo = await _fetchGeo();
      ip = geo.ip;
      countryName = geo.countryName;
      countryCode = geo.countryCode;
      city = geo.city;
      isp = geo.org;
      asn = geo.asn;

      // Network + VPN
      await _refreshNetworkAndVpn(showLoader: false);

      // Ping
      pingMs = await _measureLatencyMs(
        host: '1.1.1.1',
        port: 443,
        attempts: 5,
        timeout: const Duration(seconds: 2),
      );

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshPing() async {
    if (_pingLoading) return;

    setState(() => _pingLoading = true);
    try {
      final v = await _measureLatencyMs(
        host: '1.1.1.1',
        port: 443,
        attempts: 5,
        timeout: const Duration(seconds: 2),
      );
      if (!mounted) return;
      setState(() => pingMs = v);
    } catch (_) {
      // ignore
    } finally {
      if (!mounted) return;
      setState(() => _pingLoading = false);
    }
  }

  Future<void> _refreshNetworkAndVpn({bool showLoader = true}) async {
    if (_netLoading) return;
    if (showLoader) setState(() => _netLoading = true);

    try {
      // Connectivity
      final result = await Connectivity().checkConnectivity();
      final nt = _mapConnectivity(result);

      // VPN
      bool? vpn;
      try {
        vpn = await VpnDetector().isVpnActive();
      } catch (_) {
        vpn = null; // اگر روی پلتفرمی پشتیبانی نشد
      }

      if (!mounted) return;
      setState(() {
        networkType = nt;
        vpnActive = vpn;
      });
    } finally {
      if (!mounted) return;
      if (showLoader) setState(() => _netLoading = false);
    }
  }

  // ✅ Anti-cache (unique URL + no-cache headers)
  Future<_GeoResult> _fetchGeo() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('https://ipapi.co/json/?t=$ts');

    final res = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Geo API error: HTTP ${res.statusCode}');
    }

    final Map<String, dynamic> j = json.decode(res.body);

    final ip = (j['ip'] ?? '').toString().trim();
    final city = (j['city'] ?? '').toString().trim();
    final countryName = (j['country_name'] ?? '').toString().trim();
    final countryCode =
        (j['country_code'] ?? '').toString().trim().toUpperCase();
    final org = (j['org'] ?? '').toString().trim();

    // ipapi.co معمولاً asn رو میده (مثلاً "AS15169") — اگر نبود، null می‌مونه
    final asn = (j['asn'] ?? '').toString().trim();

    if (ip.isEmpty) {
      throw Exception('Geo API returned empty IP');
    }

    return _GeoResult(
      ip: ip,
      city: city.isEmpty ? null : city,
      countryName: countryName.isEmpty ? null : countryName,
      countryCode: countryCode.isEmpty ? null : countryCode,
      org: org.isEmpty ? null : org,
      asn: asn.isEmpty ? null : asn,
    );
  }

  Future<double> _measureLatencyMs({
    required String host,
    required int port,
    int attempts = 5,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final List<double> samples = [];

    for (int i = 0; i < attempts; i++) {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        socket.destroy();
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    if (samples.isEmpty) {
      throw Exception('Ping failed (no successful attempts)');
    }

    final avg = samples.reduce((a, b) => a + b) / samples.length;
    return double.parse(avg.toStringAsFixed(1));
  }

  String _flagFromCountryCode(String? code) {
    final c = (code ?? '').toUpperCase();
    if (c.length != 2) return '🌐';
    final int first = c.codeUnitAt(0) - 65 + 0x1F1E6;
    final int second = c.codeUnitAt(1) - 65 + 0x1F1E6;
    if (first < 0x1F1E6 || first > 0x1F1FF) return '🌐';
    if (second < 0x1F1E6 || second > 0x1F1FF) return '🌐';
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  String _mapConnectivity(ConnectivityResult r) {
    switch (r) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'mobile';
      case ConnectivityResult.none:
        return 'none';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.vpn:
        return 'vpn';
      case ConnectivityResult.bluetooth:
        return 'bluetooth';
      case ConnectivityResult.other:
      default:
        return 'other';
    }
  }

  String _networkLabel(AppLocalizations t, String? v) {
    switch (v) {
      case 'wifi':
        return t.toolMyIpNetWifi;
      case 'mobile':
        return t.toolMyIpNetMobile;
      case 'none':
        return t.toolMyIpNetNone;
      case 'ethernet':
        return t.toolMyIpNetEthernet;
      case 'vpn':
        return t.toolMyIpNetVpn;
      case 'bluetooth':
        return t.toolMyIpNetBluetooth;
      case 'other':
      default:
        return t.toolMyIpNetOther;
    }
  }

  String _vpnLabel(AppLocalizations t, bool? v) {
    if (v == null) return '-';
    return v ? t.toolMyIpOn : t.toolMyIpOff;
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onCopy,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
          if (onCopy != null)
            IconButton(
              tooltip: 'Copy',
              onPressed: onCopy,
              icon: Icon(Icons.copy, color: Colors.white.withOpacity(0.85)),
            ),
        ],
      ),
    );
  }

  void _copy(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Copy'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.toolMyIpTitle),
        actions: [
          IconButton(
            tooltip: t.toolMyIpRefreshAll,
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
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
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            : (_error != null)
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Error:\n$_error',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadAll,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _flagFromCountryCode(countryCode),
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    countryName ?? '-',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (city ?? '-'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      _infoRow(
                        icon: Icons.public,
                        title: t.toolMyIpConnectionIp,
                        value: ip ?? '-',
                        onCopy: () => _copy(ip ?? ''),
                      ),
                      _infoRow(
                        icon: Icons.flag,
                        title: t.toolMyIpCountry,
                        value:
                            '${countryName ?? '-'} (${countryCode ?? '-'})',
                        onCopy: () => _copy(
                            '${countryName ?? ''} ${countryCode ?? ''}'.trim()),
                      ),
                      _infoRow(
                        icon: Icons.location_city,
                        title: t.toolMyIpCity,
                        value: city ?? '-',
                        onCopy: city == null ? null : () => _copy(city!),
                      ),
                      _infoRow(
                        icon: Icons.router,
                        title: t.toolMyIpIsp,
                        value: isp ?? '-',
                        onCopy: isp == null ? null : () => _copy(isp!),
                      ),

                      // ✅ ASN
                      _infoRow(
                        icon: Icons.apartment,
                        title: t.toolMyIpAsn,
                        value: asn ?? '-',
                        onCopy: asn == null ? null : () => _copy(asn!),
                      ),

                      // ✅ Network Type + VPN (با یک دکمه کوچک رفرش)
                      _infoRow(
                        icon: Icons.wifi_tethering,
                        title: t.toolMyIpNetwork,
                        value: _networkLabel(t, networkType),
                        trailing: IconButton(
                          tooltip: t.toolMyIpRefreshNetwork,
                          onPressed: _netLoading ? null : () => _refreshNetworkAndVpn(),
                          icon: _netLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          color: Colors.white.withOpacity(0.90),
                        ),
                      ),
                      _infoRow(
                        icon: Icons.shield,
                        title: t.toolMyIpVpn,
                        value: _vpnLabel(t, vpnActive),
                      ),

                      // ✅ Ping row + Refresh button inside the card
                      _infoRow(
                        icon: Icons.network_ping,
                        title: t.toolMyIpPing,
                        value: pingMs == null
                            ? '-'
                            : '${pingMs!.toStringAsFixed(1)} ms',
                        onCopy: pingMs == null
                            ? null
                            : () => _copy('${pingMs!.toStringAsFixed(1)} ms'),
                        trailing: IconButton(
                          tooltip: t.toolMyIpRefreshPing,
                          onPressed: _pingLoading ? null : _refreshPing,
                          icon: _pingLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          color: Colors.white.withOpacity(0.90),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _GeoResult {
  final String ip;
  final String? countryName;
  final String? countryCode;
  final String? city;
  final String? org;
  final String? asn;

  _GeoResult({
    required this.ip,
    required this.countryName,
    required this.countryCode,
    required this.city,
    required this.org,
    required this.asn,
  });
}
