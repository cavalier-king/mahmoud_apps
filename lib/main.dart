import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahmoud_apps/tools/my_ip_address/my_ip_address_screen.dart';
import 'package:mahmoud_apps/tools/port_check/port_check_screen.dart';
import 'package:mahmoud_apps/tools/net_info/net_info_screen.dart';
import 'package:mahmoud_apps/tools/web_inspector/web_inspector_screen.dart';

import 'package:mahmoud_apps/screens/qr_generator_screen.dart';
import 'package:mahmoud_apps/screens/clean_url_screen.dart';
import 'package:mahmoud_apps/screens/url_inspector_screen.dart';
import 'package:mahmoud_apps/screens/settings_screen.dart';
import 'package:mahmoud_apps/screens/vault_screen.dart';
import 'package:mahmoud_apps/screens/converter_screen.dart';
import 'package:mahmoud_apps/screens/text_tools_screen.dart';
import 'package:mahmoud_apps/screens/scanner_screen.dart';
import 'package:mahmoud_apps/screens/clean_text_tool_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale; // null => device language (auto)
  ThemeMode _themeMode = ThemeMode.dark;
  bool _loadedPrefs = false;

  bool _isRtl(Locale locale) =>
      locale.languageCode == 'fa' || locale.languageCode == 'ar';

  // Prefs keys
  static const String _kLocaleMode = 'locale_mode'; // 'auto' | 'fixed'
  static const String _kLocaleCode = 'locale_code'; // 'en' | 'fa' | 'ar'
  static const String _kThemeMode = 'theme_mode'; // 'dark' | 'light'

  // Brand colors
  static const Color _brandDark = Color(0xFF0B1020);
  static const Color _cardDark = Color(0xFF131A33);
  static const Color _brandLight = Color(0xFFF6F7FB);
  static const Color _cardLight = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final localeMode = prefs.getString(_kLocaleMode) ?? 'auto';
    final localeCode = prefs.getString(_kLocaleCode);

    Locale? loadedLocale;
    if (localeMode == 'fixed' && localeCode != null && localeCode.isNotEmpty) {
      loadedLocale = Locale(localeCode);
    } else {
      loadedLocale = null;
    }

    final themeStr = prefs.getString(_kThemeMode) ?? 'dark';
    final loadedTheme =
        (themeStr == 'light') ? ThemeMode.light : ThemeMode.dark;

    if (!mounted) return;
    setState(() {
      _locale = loadedLocale;
      _themeMode = loadedTheme;
      _loadedPrefs = true;
    });
  }

  Future<void> _saveLocale(Locale? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.setString(_kLocaleMode, 'auto');
      await prefs.remove(_kLocaleCode);
    } else {
      await prefs.setString(_kLocaleMode, 'fixed');
      await prefs.setString(_kLocaleCode, value.languageCode);
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kThemeMode, mode == ThemeMode.light ? 'light' : 'dark');
  }

  void _setLocale(Locale? value) {
    setState(() => _locale = value);
    _saveLocale(value);
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveTheme(mode);
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandDark,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: _brandDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: const CardTheme(
        color: _cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B1020),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _brandLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: _brandLight,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      cardTheme: const CardTheme(
        color: _cardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedPrefs) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: _themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fa'),
        Locale('ar'),
      ],
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      home: Builder(
        builder: (context) {
          final deviceLocale = Localizations.localeOf(context);
          final activeLocale = _locale ?? deviceLocale;

          return Directionality(
            textDirection:
                _isRtl(activeLocale) ? TextDirection.rtl : TextDirection.ltr,
            child: MainHomeScreen(
              activeLocale: activeLocale,
              isAuto: _locale == null,
              onPickLocale: _setLocale,
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
            ),
          );
        },
      ),
    );
  }
}

class MainHomeScreen extends StatelessWidget {
  final Locale activeLocale;
  final bool isAuto;
  final void Function(Locale? value) onPickLocale;
  final ThemeMode themeMode;
  final void Function(ThemeMode mode) onThemeModeChanged;

  const MainHomeScreen({
    super.key,
    required this.activeLocale,
    required this.isAuto,
    required this.onPickLocale,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final items = <_HomeItem>[
      _HomeItem(
        title: t.tabVault,
        asset: 'assets/home/vault.png',
        page: const VaultScreen(),
      ),
      _HomeItem(
        title: t.netInfoTitle,
        asset: 'assets/home/net_info.png',
        page: const NetInfoScreen(),
      ),
      _HomeItem(
        title: t.tabConverter,
        asset: 'assets/home/converter.png',
        page: const ConverterScreen(),
      ),
      _HomeItem(
        title: t.tabQrGenerator,
        asset: 'assets/home/ic_qr.png',
        page: const QrGeneratorScreen(),
      ),
      _HomeItem(
        title: t.toolCleanUrlTitle,
        asset: 'assets/home/clean-url.png',
        page: const CleanUrlScreen(),
      ),
      _HomeItem(
        title: t.toolUrlInspectorTitle,
        asset: 'assets/home/url-inspector.png',
        page: const UrlInspectorScreen(),
      ),
      _HomeItem(
        title: t.toolMyIpTitle,
        asset: 'assets/home/my_ip.png',
        page: const MyIpAddressScreen(),
      ),
      _HomeItem(
        title: t.toolPortCheckTitle,
        asset: 'assets/home/port_check.png',
        page: const PortCheckScreen(),
      ),
      _HomeItem(
        title: t.toolCleanTitle,
        asset: 'assets/home/ic_clean.png',
        page: const CleanTextToolScreen(),
      ),
      _HomeItem(
        title: t.tabTools,
        asset: 'assets/home/tools.png',
        page: const TextToolsScreen(),
      ),
      _HomeItem(
        title: t.tabScanner,
        asset: 'assets/home/scanner.png',
        page: const ScannerScreen(),
      ),
      _HomeItem(
        title: t.toolWebInspectorTitle,
        asset: 'assets/home/web_inspector.png',
        page: const WebInspectorScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            tooltip: t.settingsTitle,
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    activeLocale: activeLocale,
                    isAuto: isAuto,
                    onPickLocale: onPickLocale,
                    themeMode: themeMode,
                    onThemeModeChanged: onThemeModeChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, i) {
              final it = items[i];
              return _HomeCard(
                title: it.title,
                asset: it.asset,
                onTap: () {
                  // ✅ Tools و Clean خودشون Scaffold/AppBar دارن => Wrapper نکن
                  final noWrapper = (it.page is TextToolsScreen) ||
                      (it.page is CleanTextToolScreen) ||
                      (it.page is MyIpAddressScreen) ||
                      (it.page is UrlInspectorScreen) ||
                      (it.page is NetInfoScreen) ||
                      (it.page is WebInspectorScreen) ||
                      (it.page is PortCheckScreen) ||
                      (it.page is CleanUrlScreen);

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          noWrapper ? it.page : _ToolWrapper(title: it.title, child: it.page),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeItem {
  final String title;
  final String asset;
  final Widget page;
  const _HomeItem({
    required this.title,
    required this.asset,
    required this.page,
  });
}

class _HomeCard extends StatelessWidget {
  final String title;
  final String asset;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ FIX: keep icon size consistent across devices
    final w = MediaQuery.of(context).size.width;
    final iconSize = (w / 3) * 0.34; // roughly 34% of tile width
    final clampedIcon = iconSize.clamp(36.0, 54.0); // min/max safe for phones

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surface.withOpacity(
            Theme.of(context).brightness == Brightness.dark ? 0.18 : 1,
          ),
          border: Border.all(color: cs.onSurface.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ FIX: fixed icon box so it never looks tiny
              SizedBox(
                height: clampedIcon,
                width: clampedIcon,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              Text(
  title,
  textAlign: TextAlign.center,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
    fontWeight: FontWeight.w500, // ⬅️ سبک‌تر
    fontSize: 10,              // ⬅️ کوچیک‌تر
    height: 1.2,                 // ⬅️ فاصله بهتر خطوط
  ),
),

            ],
          ),
        ),
      ),
    );
  }
}

class _ToolWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const _ToolWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
      ),
      body: child,
    );
  }
}
