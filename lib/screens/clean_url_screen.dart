import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

class CleanUrlScreen extends StatefulWidget {
  const CleanUrlScreen({super.key});

  @override
  State<CleanUrlScreen> createState() => _CleanUrlScreenState();
}

class _CleanUrlScreenState extends State<CleanUrlScreen> {
  final TextEditingController _controller = TextEditingController();
  String _cleanUrl = '';

  // ✅ common tracking params / prefixes
  static const List<String> _blockedExact = [
    'fbclid',
    'gclid',
    'msclkid',
    'igshid',
    'mc_cid',
    'mc_eid',
    'ref',
    'ref_src',
    'ref_url',
    '_hsenc',
    '_hsmi',
    'mkt_tok',
    'vero_id',
    'oly_anon_id',
    'oly_enc_id',
    'sr_share',
    'si',
    'spm',
    'scid',
  ];

  static const List<String> _blockedPrefixes = [
    'utm_', // ✅ important
    'yclid',
    'icid',
    'cmpid',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _cleanUrl = '');
  }

  void _clean() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _cleanUrl = '');
      return;
    }

    final cleaned = _cleanUrlString(input);
    setState(() => _cleanUrl = cleaned ?? '');
  }

  String? _cleanUrlString(String input) {
    // try parse
    Uri? uri = _tryParseUri(input);
    if (uri == null) return null;

    // ✅ unwrap common redirectors (Facebook / Google)
    uri = _unwrapRedirectors(uri) ?? uri;

    // ✅ host-specific rules (Google search results)
    final host = uri.host.toLowerCase();
    final path = uri.path;

    if ((host == 'www.google.com' || host == 'google.com') &&
        path == '/search') {
      // keep only q (and optionally tbm if you want)
      final qp = uri.queryParameters;
      final q = qp['q'];
      if (q == null || q.trim().isEmpty) return uri.toString();

      final kept = <String, String>{'q': q};
      return uri.replace(queryParameters: kept, fragment: '').toString();
    }

    // ✅ generic cleaning
    final newQuery = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((key, _) {
        final k = key.toLowerCase();
        if (_blockedExact.contains(k)) return true;
        for (final p in _blockedPrefixes) {
          if (k.startsWith(p)) return true;
        }
        return false;
      });

    // remove empty query completely
    final replaced = uri.replace(
      queryParameters: newQuery.isEmpty ? null : newQuery,
      fragment: '', // remove #...
    );

    return replaced.toString();
  }

  Uri? _tryParseUri(String input) {
    try {
      final u = Uri.parse(input);
      if (u.scheme.isEmpty) {
        // handle "www.example.com/..." without scheme
        final u2 = Uri.parse('https://$input');
        return u2;
      }
      return u;
    } catch (_) {
      return null;
    }
  }

  Uri? _unwrapRedirectors(Uri uri) {
    final host = uri.host.toLowerCase();

    // Facebook redirect: https://l.facebook.com/l.php?u=<ENCODED_URL>&...
    if (host == 'l.facebook.com' || host == 'lm.facebook.com') {
      final target = uri.queryParameters['u'];
      if (target != null && target.isNotEmpty) {
        final decoded = Uri.decodeFull(target);
        return _tryParseUri(decoded) ?? uri;
      }
    }

    // Google redirect: https://www.google.com/url?url=<ENCODED_URL> OR ?q=<URL>
    if (host == 'www.google.com' || host == 'google.com') {
      if (uri.path == '/url') {
        final target = uri.queryParameters['url'] ?? uri.queryParameters['q'];
        if (target != null && target.isNotEmpty) {
          final decoded = Uri.decodeFull(target);
          return _tryParseUri(decoded) ?? uri;
        }
      }
    }

    return null;
  }

  Future<void> _copy() async {
    final t = AppLocalizations.of(context)!;
    if (_cleanUrl.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _cleanUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.copied)),
    );
  }

  Future<void> _share() async {
    if (_cleanUrl.isEmpty) return;
    await Share.share(_cleanUrl);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.toolCleanUrlTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: t.clear,
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
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
                  Row(
                    children: [
                      Image.asset(
                        'assets/home/clean-url.png',
                        width: 36,
                        height: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.toolCleanUrlTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.toolsInput,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: t.toolCleanUrlInputHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _clean(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.toolCleanUrlResult,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.12),
                      ),
                    ),
                    child: SelectableText(
                      _cleanUrl.isEmpty ? t.toolCleanUrlEmpty : _cleanUrl,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _cleanUrl.isEmpty ? null : _copy,
                        icon: const Icon(Icons.copy),
                        label: Text(t.copy),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _cleanUrl.isEmpty ? null : _share,
                        icon: const Icon(Icons.share),
                        label: Text(t.actionShare),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
