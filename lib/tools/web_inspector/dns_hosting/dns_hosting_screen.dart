import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DnsHostingScreen extends StatefulWidget {
  const DnsHostingScreen({super.key});

  @override
  State<DnsHostingScreen> createState() => _DnsHostingScreenState();
}

class _DnsHostingScreenState extends State<DnsHostingScreen> {
  final _ctrl = TextEditingController();

  bool _loading = false;
  String? _error;

  List<InternetAddress> _ips = [];
  String? _provider;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _analyze(AppLocalizations t) async {
    setState(() {
      _loading = true;
      _error = null;
      _ips = [];
      _provider = null;
    });

    try {
      final input = _ctrl.text.trim();
      if (input.isEmpty) {
        throw FormatException(t.dnsEnterDomain);
      }

      final host = input
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .replaceAll('/', '')
          .trim();

      if (host.isEmpty) {
        throw FormatException(t.dnsInvalidDomain);
      }

      final addrs = await InternetAddress.lookup(host);
      _ips = addrs;
      _provider = _detectProvider(addrs, t);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _detectProvider(List<InternetAddress> ips, AppLocalizations t) {
    for (final ip in ips) {
      final s = ip.address;
      if (s.startsWith('104.') || s.startsWith('172.67')) return 'Cloudflare';
      if (s.startsWith('8.8.') || s.startsWith('34.')) return 'Google';
      if (s.startsWith('52.') || s.startsWith('18.')) return 'AWS';
    }
    return t.dnsUnknownProvider;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.dnsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: t.dnsDomain,
              hintText: 'example.com',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : () => _analyze(t),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.dnsAnalyze),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_ips.isNotEmpty) ...[
            Card(
              child: ListTile(
                title: Text(t.dnsHostingProvider),
                trailing: Text(
                  _provider ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.dnsResolvedIps,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._ips.map(
              (ip) => Card(
                child: ListTile(
                  title: Text(ip.address),
                  subtitle: Text(ip.type.name),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
