import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlInspectorScreen extends StatefulWidget {
  const UrlInspectorScreen({super.key});

  @override
  State<UrlInspectorScreen> createState() => _UrlInspectorScreenState();
}

class _UrlInspectorScreenState extends State<UrlInspectorScreen> {
  final _controller = TextEditingController();

  // URL basics
  String? _scheme;
  String? _host;
  Map<String, String>? _query;
  Uri? _uri;

  // Geo/IP
  String? _ip;
  String? _country;
  String? _countryCode; // for flagcdn
  String? _city;
  String? _isp;
  bool _geoLoading = false;
  String? _geoError;

  // DNS Inspector
  List<String> _ipv4 = [];
  List<String> _ipv6 = [];
  String? _dnsError;

  // Security Quick Check
  bool? _isHttps;
  int? _suggestedPort;
  bool? _hsts; // Strict-Transport-Security present?
  String? _securityError;

  // Redirect Chain Viewer
  List<_RedirectHop> _redirects = [];
  String? _finalUrl;
  String? _redirectError;
  bool _redirectLoading = false;

  Timer? _debounce;
  int _reqId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _resetAllState({bool keepText = true}) {
    setState(() {
      _scheme = null;
      _host = null;
      _query = null;
      _uri = null;

      _ip = null;
      _country = null;
      _countryCode = null;
      _city = null;
      _isp = null;
      _geoLoading = false;
      _geoError = null;

      _ipv4 = [];
      _ipv6 = [];
      _dnsError = null;

      _isHttps = null;
      _suggestedPort = null;
      _hsts = null;
      _securityError = null;

      _redirects = [];
      _finalUrl = null;
      _redirectError = null;
      _redirectLoading = false;
    });
    if (!keepText) _controller.clear();
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    _resetAllState(keepText: true);
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _clear();
      return;
    }

    try {
      Uri uri = Uri.parse(text);
      if (uri.scheme.isEmpty) {
        uri = Uri.parse('https://$text');
      }
      if (uri.host.isEmpty) {
        _clear();
        return;
      }

      setState(() {
        _uri = uri;
        _scheme = uri.scheme;
        _host = uri.host;
        _query = uri.queryParameters.isEmpty ? null : uri.queryParameters;

        // reset network-derived sections
        _ip = null;
        _country = null;
        _countryCode = null;
        _city = null;
        _isp = null;
        _geoLoading = false;
        _geoError = null;

        _ipv4 = [];
        _ipv6 = [];
        _dnsError = null;

        _isHttps = uri.scheme.toLowerCase() == 'https';
        _suggestedPort = (_isHttps == true) ? 443 : 80;
        _hsts = null;
        _securityError = null;

        _redirects = [];
        _finalUrl = null;
        _redirectError = null;
        _redirectLoading = false;
      });

      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 650), () {
        _runDeepChecks(uri);
      });
    } catch (_) {
      _clear();
    }
  }

  // --- Clean tracking ---
  Uri _cleanTracking(Uri uri) {
    final blocked = ['fbclid', 'gclid', 'msclkid', 'igshid', 'ref'];

    final cleaned = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((k, _) =>
          blocked.contains(k.toLowerCase()) ||
          k.toLowerCase().startsWith('utm_'));

    return uri.replace(
      queryParameters: cleaned.isEmpty ? null : cleaned,
      fragment: '',
    );
  }

  void _cleanThisUrl() {
    if (_uri == null) return;
    final cleaned = _cleanTracking(_uri!);
    if (cleaned.toString() == _uri.toString()) return;
    _controller.text = cleaned.toString();
    _analyze();
  }

  // --- Copy helpers ---
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copyText(String text, String toastMsg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _toast(toastMsg);
  }

  void _copyAll(AppLocalizations t) {
    if (_uri == null) return;

    final b = StringBuffer()
      ..writeln('${t.toolUrlInspectorScheme}: $_scheme')
      ..writeln('${t.toolUrlInspectorHost}: $_host');

    if (_query != null) {
      b.writeln('');
      b.writeln(t.toolUrlInspectorQuery);
      _query!.forEach((k, v) => b.writeln('$k = $v'));
    }

    b.writeln('');
    b.writeln('DNS');
    if (_dnsError != null) {
      b.writeln('Error: $_dnsError');
    } else {
      if (_ipv4.isNotEmpty) b.writeln('A (IPv4): ${_ipv4.join(', ')}');
      if (_ipv6.isNotEmpty) b.writeln('AAAA (IPv6): ${_ipv6.join(', ')}');
      if (_ipv4.isEmpty && _ipv6.isEmpty) b.writeln('No records');
    }

    b.writeln('');
    b.writeln('IP / Location');
    if (_geoError != null) {
      b.writeln('Error: $_geoError');
    } else {
      if (_ip != null) b.writeln('IP: $_ip');
      if (_country != null) b.writeln('Country: $_country');
      if (_city != null) b.writeln('City: $_city');
      if (_isp != null) b.writeln('ISP: $_isp');
      if (_ip == null && _country == null && _city == null && _isp == null) {
        b.writeln('No data');
      }
    }

    b.writeln('');
    b.writeln('Security');
    if (_securityError != null) {
      b.writeln('Error: $_securityError');
    } else {
      b.writeln('HTTPS: ${_isHttps == true ? "Yes" : "No"}');
      if (_suggestedPort != null) b.writeln('Port: $_suggestedPort');
      if (_hsts != null) b.writeln('HSTS: ${_hsts == true ? "Yes" : "No"}');
    }

    b.writeln('');
    b.writeln('Redirects');
    if (_redirectError != null) {
      b.writeln('Error: $_redirectError');
    } else if (_redirects.isEmpty) {
      b.writeln('No redirects');
      if (_finalUrl != null) b.writeln('Final: $_finalUrl');
    } else {
      for (final hop in _redirects) {
        b.writeln('${hop.status}  ${hop.url}');
        if (hop.location != null) b.writeln(' -> ${hop.location}');
      }
      if (_finalUrl != null) b.writeln('Final: $_finalUrl');
    }

    Clipboard.setData(ClipboardData(text: b.toString()));
    _toast(t.copied);
  }

  void _share() {
    if (_uri != null) Share.share(_uri.toString());
  }

  Future<void> _open() async {
    if (_uri == null) return;
    if (await canLaunchUrl(_uri!)) {
      await launchUrl(_uri!, mode: LaunchMode.externalApplication);
    }
  }

  // --- Deep Checks runner ---
  Future<void> _runDeepChecks(Uri uri) async {
    final int id = ++_reqId;

    // DNS lookup
    List<InternetAddress> addrs;
    try {
      addrs = await InternetAddress.lookup(uri.host);
    } catch (_) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _dnsError = 'DNS lookup failed';
        _ipv4 = [];
        _ipv6 = [];
      });
      addrs = [];
    }

    if (!mounted || id != _reqId) return;

    final v4 = <String>{};
    final v6 = <String>{};
    for (final a in addrs) {
      if (a.type == InternetAddressType.IPv4) v4.add(a.address);
      if (a.type == InternetAddressType.IPv6) v6.add(a.address);
    }

    setState(() {
      _dnsError = null;
      _ipv4 = v4.toList()..sort();
      _ipv6 = v6.toList()..sort();
    });

    // choose IP for geo (prefer IPv4)
    String? ip;
    for (final a in addrs) {
      if (a.type == InternetAddressType.IPv4) {
        ip = a.address;
        break;
      }
    }
    ip ??= addrs.isNotEmpty ? addrs.first.address : null;

    await Future.wait([
      _fetchGeoByIp(ip, id),
      _fetchRedirectsAndSecurity(uri, id),
    ]);
  }

  // --- Geo (IP -> location) ---
  Future<void> _fetchGeoByIp(String? ip, int id) async {
    if (!mounted || id != _reqId) return;

    setState(() {
      _geoLoading = true;
      _geoError = null;
      _ip = ip;
      _country = null;
      _countryCode = null;
      _city = null;
      _isp = null;
    });

    if (ip == null || ip.isEmpty) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _geoLoading = false;
        _geoError = 'Could not resolve IP';
      });
      return;
    }

    try {
      final data = await _httpGetJson('https://ipapi.co/$ip/json/');
      if (!mounted || id != _reqId) return;

      final err = (data['error'] == true) ||
          (data['reason'] != null && data['reason'].toString().isNotEmpty);

      if (err) {
        setState(() {
          _geoLoading = false;
          _geoError = 'Location lookup failed';
        });
        return;
      }

      final countryName = (data['country_name'] ?? '').toString();
      final countryCode = (data['country'] ?? '').toString(); // e.g. IT
      final city = (data['city'] ?? '').toString();
      final org = (data['org'] ??
              data['asn_org'] ??
              data['organization'] ??
              '').toString();

      setState(() {
        _geoLoading = false;
        _geoError = null;
        _country = countryName.isEmpty ? null : countryName;
        _countryCode = countryCode.isEmpty ? null : countryCode.toLowerCase();
        _city = city.isEmpty ? null : city;
        _isp = org.isEmpty ? null : org;
      });
    } catch (_) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _geoLoading = false;
        _geoError = 'Location lookup failed';
      });
    }
  }

  // --- Redirect chain + Security headers ---
  Future<void> _fetchRedirectsAndSecurity(Uri start, int id) async {
    if (!mounted || id != _reqId) return;

    setState(() {
      _redirectLoading = true;
      _redirectError = null;
      _redirects = [];
      _finalUrl = null;
      _hsts = null;
      _securityError = null;
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      Uri current = start;
      final hops = <_RedirectHop>[];

      Future<HttpClientResponse> requestOnce(Uri u) async {
        try {
          final req = await client.openUrl('HEAD', u);
          req.followRedirects = false;
          req.maxRedirects = 0;
          req.headers
              .set(HttpHeaders.userAgentHeader, 'mahmoud-apps-url-inspector');
          return await req.close();
        } catch (_) {
          final req = await client.openUrl('GET', u);
          req.followRedirects = false;
          req.maxRedirects = 0;
          req.headers
              .set(HttpHeaders.userAgentHeader, 'mahmoud-apps-url-inspector');
          return await req.close();
        }
      }

      const maxHops = 10;

      for (int i = 0; i < maxHops; i++) {
        if (!mounted || id != _reqId) {
          client.close(force: true);
          return;
        }

        final res = await requestOnce(current);

        final hstsHeader = res.headers.value('strict-transport-security');
        if (hstsHeader != null && hstsHeader.trim().isNotEmpty) {
          _hsts = true;
        }

        final status = res.statusCode;
        final location = res.headers.value(HttpHeaders.locationHeader);

        try {
          await res.drain();
        } catch (_) {}

        hops.add(_RedirectHop(
          status: status,
          url: current.toString(),
          location: location,
        ));

        final isRedirect = status >= 300 &&
            status < 400 &&
            location != null &&
            location.isNotEmpty;

        if (!isRedirect) {
          if (!mounted || id != _reqId) {
            client.close(force: true);
            return;
          }
          setState(() {
            _redirects = hops;
            _finalUrl = current.toString();
            _redirectLoading = false;
            _redirectError = null;

            _isHttps = current.scheme.toLowerCase() == 'https';
            _suggestedPort = (_isHttps == true) ? 443 : 80;
            _hsts = (_hsts == true);
          });
          client.close(force: true);
          return;
        }

        final next = current.resolve(location);
        current = next;
      }

      if (!mounted || id != _reqId) {
        client.close(force: true);
        return;
      }
      setState(() {
        _redirects = hops;
        _finalUrl = current.toString();
        _redirectLoading = false;
        _redirectError = 'Too many redirects';
        _isHttps = current.scheme.toLowerCase() == 'https';
        _suggestedPort = (_isHttps == true) ? 443 : 80;
      });
      client.close(force: true);
    } catch (_) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _redirectLoading = false;
        _redirectError = 'Redirect check failed';
        _securityError = 'Security check failed';
      });
    }
  }

  Future<Map<String, dynamic>> _httpGetJson(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } finally {
      client.close(force: true);
    }
  }

  // --- Flag widget ---
  Widget _flagWidget() {
    if (_countryCode == null || _countryCode!.length != 2) {
      return const SizedBox.shrink();
    }
    final url = 'https://flagcdn.com/w40/${_countryCode!}.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 28,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  // --- Timeline UI for redirects ---
  Widget _redirectTimeline() {
    if (_redirectLoading) return const Text('Loading…');
    if (_redirectError != null) return Text(_redirectError!);
    if (_redirects.isEmpty) return const Text('No redirects');

    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (int i = 0; i < _redirects.length; i++)
          _TimelineItem(
            index: i + 1,
            isLast: i == _redirects.length - 1,
            status: _redirects[i].status,
            url: _redirects[i].url,
            location: _redirects[i].location,
            lineColor: cs.onSurface.withOpacity(0.15),
            dotColor: cs.primary,
          ),
        if (_finalUrl != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Final: $_finalUrl'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasUrl = _uri != null;

    final isHttps = (_scheme ?? '').toLowerCase() == 'https';
    final hasGeo = _ip != null || _country != null || _city != null || _isp != null;
    final hasDns = _ipv4.isNotEmpty || _ipv6.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.toolUrlInspectorTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: t.clear,
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.toolUrlInspectorTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: t.toolUrlInspectorInputHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _analyze(),
                  ),

                  if (hasUrl) ...[
                    const SizedBox(height: 16),

                    // Scheme (security)
                    Row(
                      children: [
                        Icon(
                          isHttps ? Icons.lock : Icons.warning_amber_rounded,
                          color: isHttps ? Colors.green : Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${t.toolUrlInspectorScheme}: $_scheme',
                          style: TextStyle(
                            color: isHttps ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Host
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          label: Text(_host ?? ''),
                          avatar: const Icon(Icons.language, size: 18),
                        ),
                      ],
                    ),

                    // Query params
                    if (_query != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t.toolUrlInspectorQuery,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              ..._query!.entries
                                  .map((e) => Text('${e.key} = ${e.value}')),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // DNS Inspector
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('DNS Inspector',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            if (_dnsError != null)
                              Text(_dnsError!)
                            else if (!hasDns)
                              const Text('No records')
                            else ...[
                              if (_ipv4.isNotEmpty)
                                Text('A (IPv4): ${_ipv4.join(', ')}'),
                              if (_ipv6.isNotEmpty)
                                Text('AAAA (IPv6): ${_ipv6.join(', ')}'),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // IP / Location
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('IP / Location',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            if (_geoLoading)
                              const Text('Loading…')
                            else if (_geoError != null)
                              Text(_geoError!)
                            else if (!hasGeo)
                              const Text('No data')
                            else ...[
                              if (_ip != null) Text('IP: $_ip'),
                              if (_country != null)
                                Row(
                                  children: [
                                    _flagWidget(),
                                    if (_countryCode != null)
                                      const SizedBox(width: 8),
                                    Expanded(child: Text('Country: $_country')),
                                  ],
                                ),
                              if (_city != null) Text('City: $_city'),
                              if (_isp != null) Text('ISP: $_isp'),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: (_ip == null || _ip!.isEmpty)
                                      ? null
                                      : () => _copyText(_ip!, t.copied),
                                  icon: const Icon(Icons.content_copy),
                                  label: const Text('Copy IP'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Security Quick Check
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Security Quick Check',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            if (_securityError != null)
                              Text(_securityError!)
                            else ...[
                              Row(
                                children: [
                                  Icon(
                                    (_isHttps == true)
                                        ? Icons.verified
                                        : Icons.error_outline,
                                    color: (_isHttps == true)
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                      'HTTPS: ${_isHttps == true ? "Yes" : "No"}'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (_suggestedPort != null)
                                Text('Port: $_suggestedPort'),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    (_hsts == true)
                                        ? Icons.lock_outline
                                        : Icons.lock_open_outlined,
                                    color: (_hsts == true)
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                      'HSTS: ${_hsts == true ? "Yes" : "No / Unknown"}'),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Redirect Chain (timeline)
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Redirect Chain',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            _redirectTimeline(),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed:
                                      (_finalUrl == null || _finalUrl!.isEmpty)
                                          ? null
                                          : () => _copyText(_finalUrl!, t.copied),
                                  icon: const Icon(Icons.content_copy),
                                  label: const Text('Copy Final URL'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main Buttons
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _copyAll(t),
                          icon: const Icon(Icons.copy),
                          label: Text(t.copy),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _cleanThisUrl,
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(t.clean),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _share,
                          icon: const Icon(Icons.share),
                          label: Text(t.actionShare),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _open,
                          icon: const Icon(Icons.open_in_browser),
                          label: Text(t.open),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _clear,
                          icon: const Icon(Icons.clear),
                          label: Text(t.clear),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedirectHop {
  final int status;
  final String url;
  final String? location;
  _RedirectHop({required this.status, required this.url, this.location});
}

class _TimelineItem extends StatelessWidget {
  final int index;
  final bool isLast;
  final int status;
  final String url;
  final String? location;
  final Color lineColor;
  final Color dotColor;

  const _TimelineItem({
    required this.index,
    required this.isLast,
    required this.status,
    required this.url,
    required this.location,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // timeline rail
        SizedBox(
          width: 22,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 42,
                  margin: const EdgeInsets.only(top: 4),
                  color: lineColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#$index  $status',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(url),
                if (location != null && location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('→ $location', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
