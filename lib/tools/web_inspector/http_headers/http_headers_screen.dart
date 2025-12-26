import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HttpHeadersScreen extends StatefulWidget {
  const HttpHeadersScreen({super.key});

  @override
  State<HttpHeadersScreen> createState() => _HttpHeadersScreenState();
}

class _HttpHeadersScreenState extends State<HttpHeadersScreen> {
  final TextEditingController _urlCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  /// key -> values
  final Map<String, List<String>> _headers = {};

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _inspect(AppLocalizations t) async {
    setState(() {
      _loading = true;
      _error = null;
      _headers.clear();
    });

    try {
      final input = _urlCtrl.text.trim();
      if (input.isEmpty) {
        throw FormatException(t.httpHeadersEnterUrl);
      }

      final uri =
          Uri.parse(input.contains('://') ? input : 'https://$input');

      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.followRedirects = true;

      final response = await request.close();

      response.headers.forEach((key, values) {
        _headers[key] = values;
      });

      client.close();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _hasHeader(String key) {
    return _headers.keys.any(
      (k) => k.toLowerCase() == key.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.httpHeadersTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: t.httpHeadersUrl,
              hintText: 'https://example.com',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : () => _inspect(t),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.httpHeadersInspect),
          ),
          const SizedBox(height: 20),

          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),

          if (_headers.isNotEmpty) ...[
            Text(
              t.httpHeadersSecurity,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _secTile(
              t,
              'HSTS',
              'strict-transport-security',
            ),
            _secTile(
              t,
              'CSP',
              'content-security-policy',
            ),
            _secTile(
              t,
              'X-Frame-Options',
              'x-frame-options',
            ),
            _secTile(
              t,
              'X-Content-Type-Options',
              'x-content-type-options',
            ),
            const SizedBox(height: 20),
            Text(
              t.httpHeadersAll,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._headers.entries.map(
              (e) => Card(
                child: ListTile(
                  title: Text(e.key),
                  subtitle: Text(e.value.join(', ')),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _secTile(
    AppLocalizations t,
    String title,
    String key,
  ) {
    final ok = _hasHeader(key);
    return Card(
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red,
        ),
        title: Text(title),
        subtitle: Text(
          ok ? t.httpHeadersPresent : t.httpHeadersMissing,
        ),
      ),
    );
  }
}
