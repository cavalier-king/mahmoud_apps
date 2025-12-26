import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

class NetInfoScreen extends StatefulWidget {
  const NetInfoScreen({super.key});

  @override
  State<NetInfoScreen> createState() => _NetInfoScreenState();
}

class _NetInfoScreenState extends State<NetInfoScreen> {
  int _openIndex = -1;

  void _toggle(int i) => setState(() => _openIndex = _openIndex == i ? -1 : i);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.netInfoTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section(
            index: 0,
            title: t.netInfoGeoTitle,
            child: const _GeoLookupSection(),
          ),
          _section(
            index: 1,
            title: t.netInfoCodecTitle,
            child: const _UrlCodecSection(),
          ),
          _section(
            index: 2,
            title: t.netInfoWhoisTitle,
            child: const _WhoisSection(),
          ),
          _section(
            index: 3,
            title: t.netInfoDnsTitle,
            child: const _DnsSection(),
          ),
          _section(
            index: 4,
            title: t.netInfoPingTitle,
            child: const _PingSection(),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required int index,
    required String title,
    required Widget child,
  }) {
    final open = _openIndex == index;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
            onTap: () => _toggle(index),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
        ],
      ),
    );
  }
}

////////////////////////
/// Helpers
////////////////////////
String _cleanDomainOrHost(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;

  // If full URL, extract host
  if (s.startsWith('http://') || s.startsWith('https://')) {
    final u = Uri.tryParse(s);
    if (u != null && u.host.isNotEmpty) {
      s = u.host;
    }
  }

  // Remove path if user pasted domain/path
  if (s.contains('/')) {
    s = s.split('/').first.trim();
  }

  // Remove port if host:port
  if (s.contains(':')) {
    final m = RegExp(r'^\[(.+)\]:(\d+)$').firstMatch(s);
    if (m != null) return m.group(1) ?? s;

    final parts = s.split(':');
    if (parts.length == 2) s = parts[0].trim();
  }

  // remove leading www.
  if (s.toLowerCase().startsWith('www.')) {
    s = s.substring(4);
  }

  return s.trim();
}

////////////////////////
/// 1) IP → GEO LOOKUP
////////////////////////
class _GeoLookupSection extends StatefulWidget {
  const _GeoLookupSection();

  @override
  State<_GeoLookupSection> createState() => _GeoLookupSectionState();
}

class _GeoLookupSectionState extends State<_GeoLookupSection> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  String? _ip;
  String? _country;
  String? _city;
  String? _isp;
  String? _asn;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final t = AppLocalizations.of(context)!;
    final ip = _ctrl.text.trim();
    if (ip.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _ip = _country = _city = _isp = _asn = null;
    });

    try {
      final res = await http
          .get(
            Uri.parse('https://ipapi.co/$ip/json/'),
            headers: const {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final Map<String, dynamic> j = json.decode(res.body);

      final ipOut = (j['ip'] ?? '').toString().trim();
      final country = (j['country_name'] ?? '').toString().trim();
      final city = (j['city'] ?? '').toString().trim();
      final org = (j['org'] ?? '').toString().trim();
      final asn = (j['asn'] ?? '').toString().trim();

      if (ipOut.isEmpty) {
        throw Exception(t.netInfoNoResult);
      }

      setState(() {
        _ip = ipOut;
        _country = country.isEmpty ? null : country;
        _city = city.isEmpty ? null : city;
        _isp = org.isEmpty ? null : org;
        _asn = asn.isEmpty ? null : asn;
      });
    } catch (e) {
      setState(() => _error = '${t.netInfoError}: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText: t.netInfoIp,
            hintText: '8.8.8.8',
            suffixIcon: IconButton(
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              onPressed: _loading ? null : _lookup,
            ),
          ),
          onSubmitted: (_) => _loading ? null : _lookup(),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
        if (_ip != null || _country != null || _isp != null) ...[
          _row('IP', _ip),
          _row('Country', _country),
          _row('City', _city),
          _row('ISP', _isp),
          _row('ASN', _asn),
        ] else if (!_loading && _error == null)
          Text(t.netInfoNoResult, style: TextStyle(color: Colors.white.withOpacity(0.75))),
      ],
    );
  }
}

////////////////////////
/// 2) URL / BASE64
////////////////////////
class _UrlCodecSection extends StatefulWidget {
  const _UrlCodecSection();

  @override
  State<_UrlCodecSection> createState() => _UrlCodecSectionState();
}

class _UrlCodecSectionState extends State<_UrlCodecSection> {
  final _ctrl = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _encodeUrl() => setState(() => _out = Uri.encodeComponent(_ctrl.text));
  void _decodeUrl() => setState(() => _out = Uri.decodeComponent(_ctrl.text));
  void _b64enc() => setState(() => _out = base64Encode(utf8.encode(_ctrl.text)));
  void _b64dec() {
    try {
      setState(() => _out = utf8.decode(base64Decode(_ctrl.text)));
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: t.netInfoInput,
            hintText: 'hello world',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(onPressed: _encodeUrl, child: const Text('URL Encode')),
            ElevatedButton(onPressed: _decodeUrl, child: const Text('URL Decode')),
            ElevatedButton(onPressed: _b64enc, child: const Text('Base64 Encode')),
            ElevatedButton(onPressed: _b64dec, child: const Text('Base64 Decode')),
          ],
        ),
        const SizedBox(height: 10),
        if (_out.isNotEmpty) SelectableText(_out),
      ],
    );
  }
}

////////////////////////
/// 3) WHOIS LITE via RDAP
////////////////////////
class _WhoisSection extends StatefulWidget {
  const _WhoisSection();

  @override
  State<_WhoisSection> createState() => _WhoisSectionState();
}

class _WhoisSectionState extends State<_WhoisSection> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  String? _registrar;
  String? _created;
  String? _expires;
  List<String> _nameservers = [];
  List<String> _status = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _pickEventDate(Map<String, dynamic> j, String action) {
    final events = j['events'];
    if (events is! List) return null;
    for (final e in events) {
      if (e is Map) {
        final a = (e['eventAction'] ?? '').toString();
        final d = (e['eventDate'] ?? '').toString();
        if (a == action && d.isNotEmpty) return d;
      }
    }
    return null;
  }

  String? _extractRegistrar(Map<String, dynamic> j) {
    final entities = j['entities'];
    if (entities is! List) return null;

    for (final ent in entities) {
      if (ent is Map) {
        final roles = ent['roles'];
        if (roles is List && roles.map((x) => x.toString()).contains('registrar')) {
          // vcardArray usually: ["vcard", [ [ "fn", {}, "text", "Registrar Name" ], ... ] ]
          final vcard = ent['vcardArray'];
          if (vcard is List && vcard.length >= 2 && vcard[1] is List) {
            final arr = vcard[1] as List;
            for (final item in arr) {
              if (item is List && item.length >= 4 && item[0].toString() == 'fn') {
                final name = item[3].toString().trim();
                if (name.isNotEmpty) return name;
              }
            }
          }
        }
      }
    }
    return null;
  }

  Future<void> _lookup() async {
    final t = AppLocalizations.of(context)!;

    final domain = _cleanDomainOrHost(_ctrl.text);
    if (domain.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _registrar = _created = _expires = null;
      _nameservers = [];
      _status = [];
    });

    try {
      final res = await http
          .get(
            Uri.parse('https://rdap.org/domain/$domain'),
            headers: const {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final Map<String, dynamic> j = json.decode(res.body);

      final registrar = _extractRegistrar(j);

      final created = _pickEventDate(j, 'registration');
      final expires = _pickEventDate(j, 'expiration');

      final status = <String>[];
      final st = j['status'];
      if (st is List) {
        for (final x in st) {
          final s = x.toString().trim();
          if (s.isNotEmpty) status.add(s);
        }
      }

      final nameservers = <String>[];
      final ns = j['nameservers'];
      if (ns is List) {
        for (final x in ns) {
          if (x is Map) {
            final name = (x['ldhName'] ?? '').toString().trim();
            if (name.isNotEmpty) nameservers.add(name);
          }
        }
      }

      setState(() {
        _registrar = registrar;
        _created = created;
        _expires = expires;
        _status = status;
        _nameservers = nameservers;
      });

      if ((_registrar == null) &&
          (_created == null) &&
          (_expires == null) &&
          _status.isEmpty &&
          _nameservers.isEmpty) {
        setState(() => _error = t.netInfoNoResult);
      }
    } catch (e) {
      setState(() => _error = '${t.netInfoError}: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: t.netInfoDomain,
            hintText: 'example.com',
            suffixIcon: IconButton(
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              onPressed: _loading ? null : _lookup,
            ),
          ),
          onSubmitted: (_) => _loading ? null : _lookup(),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
        if (!_loading && _error == null && _registrar == null && _created == null && _expires == null && _nameservers.isEmpty && _status.isEmpty)
          Text(t.netInfoNoResult, style: TextStyle(color: Colors.white.withOpacity(0.75))),
        if (_registrar != null || _created != null || _expires != null || _nameservers.isNotEmpty || _status.isNotEmpty) ...[
          _row(t.netInfoRegistrar, _registrar),
          _row(t.netInfoCreated, _created),
          _row(t.netInfoExpires, _expires),
          _row(t.netInfoStatus, _status.isEmpty ? null : _status.join(', ')),
          const SizedBox(height: 6),
          Text(
            t.netInfoNameservers,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (_nameservers.isEmpty)
            const Text('-', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
          else
            ..._nameservers.map((e) => Text(e, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ],
    );
  }
}

////////////////////////
/// 4) DNS QUICK LOOKUP (A/AAAA)
////////////////////////
class _DnsSection extends StatefulWidget {
  const _DnsSection();

  @override
  State<_DnsSection> createState() => _DnsSectionState();
}

class _DnsSectionState extends State<_DnsSection> {
  final _ctrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<String> _ips = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final t = AppLocalizations.of(context)!;
    final host = _cleanDomainOrHost(_ctrl.text);
    if (host.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _ips = [];
    });

    try {
      final res = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
      final out = <String>[];
      for (final a in res) {
        final ip = a.address.trim();
        if (ip.isNotEmpty && !out.contains(ip)) out.add(ip);
      }
      if (out.isEmpty) {
        setState(() => _error = t.netInfoNoResult);
      } else {
        setState(() => _ips = out);
      }
    } on TimeoutException {
      setState(() => _error = '${t.netInfoError}: ${t.netInfoTimeout}');
    } catch (e) {
      setState(() => _error = '${t.netInfoError}: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: t.netInfoDomain,
            hintText: 'cloudflare.com',
            suffixIcon: IconButton(
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              onPressed: _loading ? null : _lookup,
            ),
          ),
          onSubmitted: (_) => _loading ? null : _lookup(),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
        if (_ips.isNotEmpty) ..._ips.map((e) => Text(e, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        if (!_loading && _error == null && _ips.isEmpty)
          Text(t.netInfoNoResult, style: TextStyle(color: Colors.white.withOpacity(0.75))),
      ],
    );
  }
}

////////////////////////
/// 5) PING HOST (TCP latency)
////////////////////////
class _PingSection extends StatefulWidget {
  const _PingSection();

  @override
  State<_PingSection> createState() => _PingSectionState();
}

class _PingSectionState extends State<_PingSection> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '443');

  bool _loading = false;
  String? _error;

  double? _avg;
  double? _min;
  double? _max;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  int? _parsePort(String s) {
    final p = int.tryParse(s.trim());
    if (p == null) return null;
    if (p < 1 || p > 65535) return null;
    return p;
  }

  Future<double?> _oneTry(String host, int port) async {
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      s.destroy();
      sw.stop();
      return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ping() async {
    final t = AppLocalizations.of(context)!;

    final host = _cleanDomainOrHost(_hostCtrl.text);
    final port = _parsePort(_portCtrl.text);

    if (host.isEmpty || port == null) {
      setState(() => _error = t.netInfoNoResult);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _avg = _min = _max = null;
    });

    try {
      final samples = <double>[];

      // 5 attempts
      for (int i = 0; i < 5; i++) {
        final v = await _oneTry(host, port);
        if (v != null) samples.add(v);
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      if (samples.isEmpty) {
        setState(() => _error = t.netInfoNoResult);
      } else {
        samples.sort();
        final avg = samples.reduce((a, b) => a + b) / samples.length;
        setState(() {
          _min = double.parse(samples.first.toStringAsFixed(1));
          _max = double.parse(samples.last.toStringAsFixed(1));
          _avg = double.parse(avg.toStringAsFixed(1));
        });
      }
    } catch (e) {
      setState(() => _error = '${t.netInfoError}: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _pill(String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        '$label: ${value ?? '-'}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 7,
              child: TextField(
                controller: _hostCtrl,
                decoration: InputDecoration(
                  labelText: t.netInfoHost,
                  hintText: 'google.com',
                ),
                onSubmitted: (_) => _loading ? null : _ping(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _portCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.netInfoPort,
                  hintText: '443',
                ),
                onSubmitted: (_) => _loading ? null : _ping(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: _loading ? null : _ping,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_ping),
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
        if (_avg != null || _min != null || _max != null) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill(t.netInfoAvg, _avg == null ? null : '${_avg!.toStringAsFixed(1)} ms'),
              _pill(t.netInfoMin, _min == null ? null : '${_min!.toStringAsFixed(1)} ms'),
              _pill(t.netInfoMax, _max == null ? null : '${_max!.toStringAsFixed(1)} ms'),
            ],
          ),
        ] else if (!_loading && _error == null)
          Text(t.netInfoNoResult, style: TextStyle(color: Colors.white.withOpacity(0.75))),
      ],
    );
  }
}
