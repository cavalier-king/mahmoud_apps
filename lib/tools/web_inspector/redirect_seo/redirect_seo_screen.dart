import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RedirectSeoScreen extends StatefulWidget {
  const RedirectSeoScreen({super.key});

  @override
  State<RedirectSeoScreen> createState() => _RedirectSeoScreenState();
}

class _RedirectSeoScreenState extends State<RedirectSeoScreen> {
  final _ctrl = TextEditingController();

  bool _loading = false;
  String? _error;

  final List<_RedirectStep> _chain = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check(AppLocalizations t) async {
    setState(() {
      _loading = true;
      _error = null;
      _chain.clear();
    });

    try {
      final input = _ctrl.text.trim();
      if (input.isEmpty) {
        throw FormatException(t.redirectEnterUrl);
      }

      Uri uri = Uri.parse(input.contains('://') ? input : 'https://$input');

      final client = HttpClient();

      for (int i = 0; i < 10; i++) {
        final request = await client.getUrl(uri);
        request.followRedirects = false;

        final response = await request.close();

        _chain.add(_RedirectStep(uri.toString(), response.statusCode));

        if (response.isRedirect) {
          final loc = response.headers.value(HttpHeaders.locationHeader);
          if (loc == null) break;

          uri = Uri.parse(
            loc.startsWith('http') ? loc : '${uri.scheme}://${uri.host}$loc',
          );
        } else {
          break;
        }
      }

      client.close();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.redirectTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: t.redirectUrl,
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
                : Text(t.redirectCheck),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_chain.isNotEmpty) ...[
            Text(
              t.redirectChain,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._chain.map(
              (s) => Card(
                child: ListTile(
                  title: Text(s.url),
                  trailing: Text(
                    s.code.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: s.code == 301
                          ? Colors.green
                          : s.code == 302
                              ? Colors.orange
                              : Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RedirectStep {
  final String url;
  final int code;

  _RedirectStep(this.url, this.code);
}
