import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CleanTextToolScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const CleanTextToolScreen({super.key, this.onBack});

  @override
  State<CleanTextToolScreen> createState() => _CleanTextToolScreenState();
}

class _CleanTextToolScreenState extends State<CleanTextToolScreen> {
  final TextEditingController _in = TextEditingController();
  final ScrollController _sc = ScrollController();

  String _out = '';

  @override
  void dispose() {
    _in.dispose();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

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
    setState(() => _out = '');
  }

  Future<void> _pasteIn() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;

    setState(() {
      _in.text = text;
      _in.selection = TextSelection.collapsed(offset: _in.text.length);
    });
  }

  void _copyOut() {
    final t = AppLocalizations.of(context)!;
    if (_out.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _out));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.copied)));
  }

  bool _ensureInputNotEmpty() {
    final t = AppLocalizations.of(context)!;
    if (_in.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.msgEmptyText)));
      return false;
    }
    return true;
  }

  void _doCleanOnly() {
    if (!_ensureInputNotEmpty()) return;
    _setOut(_cleanAll(_in.text, links: false, emoji: false));
  }

  void _doRemoveEmoji() {
    if (!_ensureInputNotEmpty()) return;
    _setOut(_removeEmoji(_in.text));
  }

  void _doRemoveLinks() {
    if (!_ensureInputNotEmpty()) return;
    _setOut(_removeLinksMentionsHashtags(_in.text));
  }

  void _doCleanAll() {
    if (!_ensureInputNotEmpty()) return;
    _setOut(_cleanAll(_in.text));
  }

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
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              ),
Expanded(
  child: Text(
    t.toolCleanTitle,
    style: TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 18,
      color: titleColor,

      // ✅ FORCE: no underline (some themes/devices can inject)
      decoration: TextDecoration.none,
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

          // Input card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/home/ic_clean.png',
                        width: 36,
                        height: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.toolCleanDesc,
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

                  // ✅ FIX: remove yellow underline by fully controlling borders
                  TextField(
                    controller: _in,
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: t.toolsInputHint,

                      // Remove underline / focus border
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),

                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      btn(t.actionPaste, Icons.content_paste, _pasteIn),
                      btn(
                        t.actionClean,
                        Icons.cleaning_services_outlined,
                        _doCleanOnly,
                      ),
                      btn(t.actionRemoveLinks, Icons.link_off, _doRemoveLinks),
                      btn(
                        t.actionRemoveEmoji,
                        Icons.emoji_emotions_outlined,
                        _doRemoveEmoji,
                      ),
                      btn(t.actionCleanAll, Icons.auto_fix_high, _doCleanAll),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Output card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.toolsOutput,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
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
}

/* ===================== LOGIC ===================== */

String _cleanAll(
  String input, {
  bool links = true,
  bool emoji = true,
}) {
  var s = input;

  // 1) normalize digits (fa/ar -> en)
  s = _normalizeDigits(s);

  // 2) remove invisible chars
  s = _removeInvisibleChars(s);

  if (links) {
    s = _removeLinksMentionsHashtags(s);
  }
  if (emoji) {
    s = _removeEmoji(s);
  }

  // 3) final whitespace cleanup
  s = _cleanWhatsAppText(s);
  return s;
}

String _normalizeDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  for (int i = 0; i < 10; i++) {
    input = input.replaceAll(fa[i], i.toString());
    input = input.replaceAll(ar[i], i.toString());
  }
  return input;
}

String _removeInvisibleChars(String input) {
  // ZWNJ, ZWJ, LRM, RLM
  return input.replaceAll(
    RegExp(r'[\u200C\u200D\u200E\u200F]'),
    '',
  );
}

String _cleanWhatsAppText(String input) {
  var s = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  s = s.replaceAll('\t', ' ');

  final lines = s.split('\n');
  final out = <String>[];
  int emptyRun = 0;

  for (final raw in lines) {
    var line = raw.trim();
    line = line.replaceAll(RegExp(r'[ ]{2,}'), ' ');

    if (line.isEmpty) {
      emptyRun++;
      if (emptyRun <= 1) out.add('');
      continue;
    }
    emptyRun = 0;
    out.add(line);
  }

  return out.join('\n').trim();
}

String _removeLinksMentionsHashtags(String input) {
  var s = input;

  // http / https
  s = s.replaceAll(RegExp(r'https?:\/\/\S+', caseSensitive: false), '');

  // www.*
  s = s.replaceAll(
    RegExp(r'(^|\s)(www\.\S+)', caseSensitive: false),
    ' ',
  );

  // @mentions (telegram / instagram) — safe for emails
  s = s.replaceAll(RegExp(r'(^|\s)@[a-zA-Z0-9_.]{3,}'), ' ');

  // #hashtags
  s = s.replaceAll(RegExp(r'(^|\s)#[a-zA-Z0-9_]{2,}'), ' ');

  return s.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
}

String _removeEmoji(String input) {
  final reg = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
    unicode: true,
  );
  return input.replaceAll(reg, '').trim();
}
