import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class TextToolsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const TextToolsScreen({super.key, this.onBack});

  @override
  State<TextToolsScreen> createState() => _TextToolsScreenState();
}

class _TextToolsScreenState extends State<TextToolsScreen> {
  final TextEditingController _in = TextEditingController();
  final TextEditingController _find = TextEditingController();
  final TextEditingController _replace = TextEditingController();
  final TextEditingController _regex = TextEditingController();
  final TextEditingController _regexReplace = TextEditingController();
  final ScrollController _sc = ScrollController();

  String _out = '';

  int _charCount = 0;
  int _wordCount = 0;
  int _lineCount = 0;

  bool _matchCase = false;
  bool _wholeWord = false;
  int _replaceCount = 0;

  bool _regexCaseSensitive = false;
  bool _regexMultiLine = true;
  int _regexMatchCount = 0;

  @override
  void initState() {
    super.initState();
    _in.addListener(_recount);
  }

  @override
  void dispose() {
    _in.removeListener(_recount);
    _in.dispose();
    _find.dispose();
    _replace.dispose();
    _regex.dispose();
    _regexReplace.dispose();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    final nav = Navigator.of(context);
    final popped = await nav.maybePop();
    if (!popped) nav.popUntil((r) => r.isFirst);
  }

  // ---------- COUNTERS ----------
  void _recount() {
    final text = _in.text;
    final trimmed = text.trim();

    final words = trimmed.isEmpty
        ? 0
        : trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final lines = text.isEmpty ? 0 : text.split('\n').length;

    setState(() {
      _charCount = text.characters.length;
      _wordCount = words;
      _lineCount = lines;
    });
  }

  // ---------- OUTPUT ----------
  void _setOut(String v) {
    setState(() => _out = v);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sc.hasClients) return;
      _sc.animateTo(
        _sc.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearAll() {
    _in.clear();
    _find.clear();
    _replace.clear();
    _regex.clear();
    _regexReplace.clear();
    setState(() {
      _out = '';
      _replaceCount = 0;
      _regexMatchCount = 0;
      _matchCase = false;
      _wholeWord = false;
      _regexCaseSensitive = false;
      _regexMultiLine = true;
    });
  }

  void _copyOut() {
    final t = AppLocalizations.of(context)!;
    if (_out.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _out));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.copied)));
  }

  // ---------- BASIC ----------
  String _removeExtraSpaces(String s) {
    return s
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _sortLines(String s) {
    final lines = s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    lines.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return lines.join('\n');
  }

  String _reverseText(String s) => s.split('').reversed.join();

  String _base64Encode(String s) => base64Encode(utf8.encode(s));

  String _base64Decode(String s) {
    try {
      return utf8.decode(base64Decode(s.trim()));
    } catch (_) {
      final t = AppLocalizations.of(context)!;
      return t.toolsInvalidBase64;
    }
  }

  // ---------- COMMON / عامیانه ----------
  String _trimLines(String s) =>
      s.split('\n').map((l) => l.trim()).join('\n');

  String _removeEmptyLines(String s) =>
      s.split('\n').where((l) => l.trim().isNotEmpty).join('\n');

  String _numberLines(String s) {
    final lines = s.split('\n');
    final pad = lines.length.toString().length;
    final out = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final n = (i + 1).toString().padLeft(pad, '0');
      out.add('$n) ${lines[i]}');
    }
    return out.join('\n');
  }

  String _duplicateLinesOnly(String s) {
    final lines = s.split('\n');
    final counts = <String, int>{};
    for (final l in lines) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    final dups = counts.entries.where((e) => e.key.trim().isNotEmpty && e.value > 1).map((e) => e.key).toList();
    return dups.join('\n');
  }

  String _removeDuplicateLines(String s) {
    final seen = <String>{};
    final out = <String>[];
    for (final line in s.split('\n')) {
      if (seen.add(line)) out.add(line);
    }
    return out.join('\n');
  }

  String _slugify(String s) {
    var x = s.toLowerCase();
    x = x.replaceAll(RegExp(r'[\u200c\u200f]'), ''); // ZWNJ etc
    x = x.replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), '-');
    x = x.replaceAll(RegExp(r'-{2,}'), '-');
    return x.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _extractEmails(String s) {
    final reg = RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false);
    final m = reg.allMatches(s).map((e) => e.group(0)!).toSet().toList();
    m.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return m.join('\n');
  }

  String _extractUrls(String s) {
    final reg = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    final m = reg.allMatches(s).map((e) => e.group(0)!).toSet().toList();
    m.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return m.join('\n');
  }

  // ---------- JSON / URL ----------
  String _jsonPrettify(String s) {
    try {
      final obj = json.decode(s);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(obj);
    } catch (_) {
      return 'Invalid JSON';
    }
  }

  String _jsonMinify(String s) {
    try {
      final obj = json.decode(s);
      return json.encode(obj);
    } catch (_) {
      return 'Invalid JSON';
    }
  }

  String _urlEncode(String s) => Uri.encodeComponent(s);
  String _urlDecode(String s) => Uri.decodeComponent(s);

  // ---------- HASH ----------
  String _hashMd5(String s) => md5.convert(utf8.encode(s)).toString();
  String _hashSha1(String s) => sha1.convert(utf8.encode(s)).toString();
  String _hashSha256(String s) => sha256.convert(utf8.encode(s)).toString();

  // ---------- UUID ----------
  final Uuid _uuid = const Uuid();
  String _newUuidV4() => _uuid.v4();

  // ---------- FIND & REPLACE ----------
  void _replaceAll() {
    final input = _in.text;
    final find = _find.text;

    if (input.isEmpty || find.isEmpty) {
      _setOut(input);
      setState(() => _replaceCount = 0);
      return;
    }

    RegExp reg;
    if (_wholeWord) {
      reg = RegExp(
        r'\b' + RegExp.escape(find) + r'\b',
        caseSensitive: _matchCase,
      );
    } else {
      reg = RegExp(
        RegExp.escape(find),
        caseSensitive: _matchCase,
      );
    }

    final matches = reg.allMatches(input).length;
    final result = input.replaceAll(reg, _replace.text);

    setState(() => _replaceCount = matches);
    _setOut(result);
  }

  // ---------- REGEX ----------
  void _regexFindAll() {
    final input = _in.text;
    final pattern = _regex.text.trim();

    if (pattern.isEmpty) {
      setState(() => _regexMatchCount = 0);
      _setOut(input);
      return;
    }

    try {
      final reg = RegExp(
        pattern,
        caseSensitive: _regexCaseSensitive,
        multiLine: _regexMultiLine,
      );

      final matches = reg.allMatches(input).map((m) => m.group(0) ?? '').where((x) => x.isNotEmpty).toList();
      setState(() => _regexMatchCount = matches.length);

      // خروجی: هر match یک خط
      _setOut(matches.join('\n'));
    } catch (_) {
      setState(() => _regexMatchCount = 0);
      _setOut('Invalid REGEX pattern');
    }
  }

  void _regexReplaceAll() {
    final input = _in.text;
    final pattern = _regex.text.trim();

    if (pattern.isEmpty) {
      setState(() => _regexMatchCount = 0);
      _setOut(input);
      return;
    }

    try {
      final reg = RegExp(
        pattern,
        caseSensitive: _regexCaseSensitive,
        multiLine: _regexMultiLine,
      );

      final matches = reg.allMatches(input).length;
      setState(() => _regexMatchCount = matches);

      final replaced = input.replaceAll(reg, _regexReplace.text);
      _setOut(replaced);
    } catch (_) {
      setState(() => _regexMatchCount = 0);
      _setOut('Invalid REGEX pattern');
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    Widget btn(String label, IconData icon, VoidCallback onTap) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    final titleColor = Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      top: false,
      child: ListView(
        controller: _sc,
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              ),
              Expanded(
                child: Text(
                  t.tabTools,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: titleColor,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                    decorationThickness: 0,
                  ),
                ),
              ),
              IconButton(
                tooltip: t.clear,
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: t.copy,
                onPressed: _copyOut,
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.toolsInput, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _in,
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: t.toolsInputHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // BASIC
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      btn(t.toolsUppercase, Icons.text_fields, () => _setOut(_in.text.toUpperCase())),
                      btn(t.toolsLowercase, Icons.text_fields_outlined, () => _setOut(_in.text.toLowerCase())),
                      btn(t.toolsRemoveExtraSpaces, Icons.cleaning_services_outlined, () => _setOut(_removeExtraSpaces(_in.text))),
                      btn(t.toolsSortLines, Icons.sort_by_alpha, () => _setOut(_sortLines(_in.text))),
                      btn(t.toolsReverse, Icons.swap_horiz, () => _setOut(_reverseText(_in.text))),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),

                  // COMMON / عامیانه
                  const Text('Common', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      btn('Trim each line', Icons.format_align_left, () => _setOut(_trimLines(_in.text))),
                      btn('Remove empty lines', Icons.playlist_remove, () => _setOut(_removeEmptyLines(_in.text))),
                      btn('Number lines', Icons.format_list_numbered, () => _setOut(_numberLines(_in.text))),
                      btn('Remove duplicate lines', Icons.layers_clear, () => _setOut(_removeDuplicateLines(_in.text))),
                      btn('Show only duplicates', Icons.copy_all, () => _setOut(_duplicateLinesOnly(_in.text))),
                      btn('Slugify', Icons.tag, () => _setOut(_slugify(_in.text))),
                      btn('Extract emails', Icons.alternate_email, () => _setOut(_extractEmails(_in.text))),
                      btn('Extract URLs', Icons.link, () => _setOut(_extractUrls(_in.text))),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),

                  // JSON / URL / Base64
                  const Text('Data', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      btn('JSON prettify', Icons.data_object, () => _setOut(_jsonPrettify(_in.text))),
                      btn('JSON minify', Icons.compress, () => _setOut(_jsonMinify(_in.text))),
                      btn('URL encode', Icons.link, () => _setOut(_urlEncode(_in.text))),
                      btn('URL decode', Icons.link_off, () => _setOut(_urlDecode(_in.text))),
                      btn(t.toolsBase64Encode, Icons.lock, () => _setOut(_base64Encode(_in.text))),
                      btn(t.toolsBase64Decode, Icons.lock_open, () => _setOut(_base64Decode(_in.text))),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),

                  // HASH
                  const Text('Hash', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      btn('MD5', Icons.fingerprint, () => _setOut(_hashMd5(_in.text))),
                      btn('SHA1', Icons.fingerprint, () => _setOut(_hashSha1(_in.text))),
                      btn('SHA256', Icons.fingerprint, () => _setOut(_hashSha256(_in.text))),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),

                  // UUID
                  const Text('UUID', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      btn('Generate UUID v4', Icons.qr_code_2, () => _setOut(_newUuidV4())),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),

                  // FIND & REPLACE
                  const Text('Find & Replace', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _find,
                    decoration: const InputDecoration(
                      labelText: 'Find',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _replace,
                    decoration: const InputDecoration(
                      labelText: 'Replace with',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 10,
                    children: [
                      FilterChip(
                        label: const Text('Match case'),
                        selected: _matchCase,
                        onSelected: (v) => setState(() => _matchCase = v),
                      ),
                      FilterChip(
                        label: const Text('Whole word'),
                        selected: _wholeWord,
                        onSelected: (v) => setState(() => _wholeWord = v),
                      ),
                      FilledButton.icon(
                        onPressed: _replaceAll,
                        icon: const Icon(Icons.find_replace),
                        label: const Text('Replace all'),
                      ),
                    ],
                  ),
                  if (_replaceCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Replaced: $_replaceCount'),
                    ),

                  const SizedBox(height: 12),
                  const Divider(),

                  // REGEX
                  const Text('Regex', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _regex,
                    decoration: const InputDecoration(
                      labelText: 'Pattern (regex)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _regexReplace,
                    decoration: const InputDecoration(
                      labelText: 'Replace with',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilterChip(
                        label: const Text('Case sensitive'),
                        selected: _regexCaseSensitive,
                        onSelected: (v) => setState(() => _regexCaseSensitive = v),
                      ),
                      FilterChip(
                        label: const Text('Multiline'),
                        selected: _regexMultiLine,
                        onSelected: (v) => setState(() => _regexMultiLine = v),
                      ),
                      FilledButton.icon(
                        onPressed: _regexFindAll,
                        icon: const Icon(Icons.manage_search),
                        label: const Text('Find all'),
                      ),
                      FilledButton.icon(
                        onPressed: _regexReplaceAll,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Replace all'),
                      ),
                    ],
                  ),
                  if (_regexMatchCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Regex matches: $_regexMatchCount'),
                    ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 10,
                    children: [
                      _statChip('Chars', _charCount),
                      _statChip('Words', _wordCount),
                      _statChip('Lines', _lineCount),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.toolsOutput, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  SelectableText(_out.isEmpty ? t.empty : _out),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
