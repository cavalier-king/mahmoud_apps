import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  static const _storage = FlutterSecureStorage();
  static const String _kVaultItems = 'vault_items_json'; // secure storage key
  static const String _kVaultPin = 'vault_pin'; // prefs key

  bool _unlocked = false;
  String? _pin;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadPinAndMaybeUnlock();
  }

  Future<void> _loadPinAndMaybeUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_kVaultPin);
    setState(() => _pin = pin);

    // If no pin, force set pin screen first
    if (pin == null || pin.isEmpty) {
      setState(() => _unlocked = false);
      return;
    }

    // If pin exists, show unlock screen
    setState(() => _unlocked = false);
  }

  Future<void> _loadVault() async {
    final raw = await _storage.read(key: _kVaultItems);
    if (raw == null || raw.isEmpty) {
      setState(() => _items = []);
      return;
    }
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    setState(() => _items = list);
  }

  Future<void> _saveVault() async {
    await _storage.write(key: _kVaultItems, value: jsonEncode(_items));
  }

  Future<void> _setPinFlow() async {
    final t = AppLocalizations.of(context)!;
    final pin1 = TextEditingController();
    final pin2 = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.setPin),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pin1,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(labelText: t.enterPin),
            ),
            TextField(
              controller: pin2,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(labelText: t.confirmPin),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pin1.text.trim().isEmpty || pin1.text != pin2.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.pinMismatch)),
                );
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_kVaultPin, pin1.text.trim());
              if (!mounted) return;
              setState(() {
                _pin = pin1.text.trim();
                _unlocked = true;
              });
              await _loadVault();
              if (mounted) Navigator.pop(context);
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockFlow() async {
    final t = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.unlockVault),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: InputDecoration(labelText: t.enterPin),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim() == (_pin ?? '')) {
                setState(() => _unlocked = true);
                await _loadVault();
                if (mounted) Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.wrongPin)),
                );
              }
            },
            child: Text(t.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEditItem({Map<String, dynamic>? existing, int? index}) async {
    final t = AppLocalizations.of(context)!;

    final title = TextEditingController(text: existing?['title'] ?? '');
    final username = TextEditingController(text: existing?['username'] ?? '');
    final password = TextEditingController(text: existing?['password'] ?? '');
    final note = TextEditingController(text: existing?['note'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? t.addItem : t.editItem),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(labelText: t.title),
              ),
              TextField(
                controller: username,
                decoration: InputDecoration(labelText: t.username),
              ),
              TextField(
                controller: password,
                decoration: InputDecoration(labelText: t.password),
                obscureText: true,
              ),
              TextField(
                controller: note,
                decoration: InputDecoration(labelText: t.note),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final item = {
                "title": title.text.trim(),
                "username": username.text.trim(),
                "password": password.text.trim(),
                "note": note.text.trim(),
                "ts": DateTime.now().toIso8601String(),
              };

              setState(() {
                if (existing == null) {
                  _items.insert(0, item);
                } else {
                  _items[index!] = item;
                }
              });

              await _saveVault();
              if (mounted) Navigator.pop(context);
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(int index) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _items.removeAt(index));
    await _saveVault();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleted)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (_pin == null || _pin!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.tabVault, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text(t.vaultNeedPin, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _setPinFlow,
                      icon: const Icon(Icons.lock),
                      label: Text(t.setPin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_unlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.tabVault, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text(t.vaultLocked, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _unlockFlow,
                      icon: const Icon(Icons.lock_open),
                      label: Text(t.unlockVault),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.tabVault,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: t.addItem,
                  onPressed: () => _addOrEditItem(),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(child: Text(t.empty))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final title = (it['title'] ?? '').toString().isEmpty ? t.untitled : it['title'].toString();
                      final username = (it['username'] ?? '').toString();

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.vpn_key),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(username, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _addOrEditItem(existing: it, index: i);
                              if (v == 'del') _deleteItem(i);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(t.editItem)),
                              PopupMenuItem(value: 'del', child: Text(t.delete)),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(title),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (username.isNotEmpty) Text("${t.username}: $username"),
                                      const SizedBox(height: 6),
                                      if ((it['password'] ?? '').toString().isNotEmpty)
                                        Text("${t.password}: ${(it['password'] ?? '').toString()}"),
                                      const SizedBox(height: 6),
                                      if ((it['note'] ?? '').toString().isNotEmpty)
                                        Text("${t.note}: ${(it['note'] ?? '').toString()}"),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(t.ok),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
