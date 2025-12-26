import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DomainReputationScreen extends StatefulWidget {
  const DomainReputationScreen({super.key});

  @override
  State<DomainReputationScreen> createState() => _DomainReputationScreenState();
}

class _DomainReputationScreenState extends State<DomainReputationScreen> {
  final _ctrl = TextEditingController();

  bool _loading = false;
  String? _error;

  bool? _https;
  bool? _privateIp;
  bool? _riskyTld;
  String? _ip;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check(AppLocalizations t) async {
    setState(() {
      _loading = true;
      _error = null;
      _https = null;
      _privateIp = null;
      _riskyTld = null;
      _ip = null;
    });

    try {
      final input = _ctrl.text.trim();
      if (input.isEmpty) {
        throw FormatException(t.domainRepEnterUrl);
      }

      final uri = Uri.parse(input.contains('://') ? input : 'https://$input');
      _https = uri.scheme == 'https';

      final host = uri.host;
      if (host.isEmpty) {
        throw FormatException(t.domainRepInvalidDomain);
      }

      final addrs = await InternetAddress.lookup(host);
      _ip = addrs.first.address;

      _privateIp = _isPrivateIp(_ip!);
      _riskyTld = _isRiskyTld(host);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isPrivateIp(String ip) {
    return ip.startsWith('10.') ||
        ip.startsWith('192.168.') ||
        ip.startsWith('172.16.');
  }

  bool _isRiskyTld(String host) {
    const risky = ['.tk', '.ml', '.ga', '.cf', '.gq', '.zip', '.mov'];
    return risky.any((t) => host.toLowerCase().endsWith(t));
  }

  String _summary(AppLocalizations t) {
    if (_https == false || _privateIp == true || _riskyTld == true) {
      return t.domainRepPotentialRisk;
    }
    return t.domainRepLikelySafe;
  }

  Color _summaryColor(AppLocalizations t) =>
      _summary(t) == t.domainRepLikelySafe ? Colors.green : Colors.orange;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.domainRepTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: t.domainRepUrlOrDomain,
              hintText: 'https://example.com',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : () => _check(t),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.domainRepCheck),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_https != null && _privateIp != null && _riskyTld != null) ...[
            _tile(t.domainRepHttps, _https! ? t.yes : t.no),
            _tile(t.domainRepResolvedIp, _ip ?? '-'),
            _tile(t.domainRepPrivateIp, _privateIp! ? t.yes : t.no),
            _tile(t.domainRepRiskyTld, _riskyTld! ? t.yes : t.no),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(t.domainRepSummary),
                trailing: Text(
                  _summary(t),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _summaryColor(t),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value),
      ),
    );
  }
}
