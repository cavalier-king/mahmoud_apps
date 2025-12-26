import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  final Locale activeLocale; // resolved locale (device or picked)
  final bool isAuto; // true when app uses device language
  final void Function(Locale? value) onPickLocale;

  // Theme controls
  final ThemeMode themeMode;
  final void Function(ThemeMode mode) onThemeModeChanged;

  const SettingsScreen({
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

    final currentLang = isAuto ? 'auto' : activeLocale.languageCode;
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t.settingsGeneral,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),

          // ✅ Language card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.settingsLanguage,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        _labelFor(activeLocale.languageCode),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.settingsChooseLanguage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.70),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _choiceChip(
                        context: context,
                        selected: currentLang == 'auto',
                        label: t.languageAuto,
                        icon: Icons.auto_awesome,
                        onTap: () => onPickLocale(null),
                      ),
                      _choiceChip(
                        context: context,
                        selected: currentLang == 'en',
                        label: 'English',
                        icon: Icons.language,
                        onTap: () => onPickLocale(const Locale('en')),
                      ),
                      _choiceChip(
                        context: context,
                        selected: currentLang == 'fa',
                        label: 'فارسی',
                        icon: Icons.translate,
                        onTap: () => onPickLocale(const Locale('fa')),
                      ),
                      _choiceChip(
                        context: context,
                        selected: currentLang == 'ar',
                        label: 'العربية',
                        icon: Icons.translate,
                        onTap: () => onPickLocale(const Locale('ar')),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      t.settingsCurrent(
                        '${_labelFor(activeLocale.languageCode)}${isAuto ? ' (${t.languageAuto})' : ''}',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.75),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Theme card (Dark/Light)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.settingsTheme,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        isDark ? t.themeDark : t.themeLight,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.settingsChooseTheme,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.70),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _choiceChip(
                        context: context,
                        selected: themeMode == ThemeMode.dark,
                        label: t.themeDark,
                        icon: Icons.dark_mode,
                        onTap: () => onThemeModeChanged(ThemeMode.dark),
                      ),
                      _choiceChip(
                        context: context,
                        selected: themeMode == ThemeMode.light,
                        label: t.themeLight,
                        icon: Icons.light_mode,
                        onTap: () => onThemeModeChanged(ThemeMode.light),
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

  Widget _choiceChip({
    required BuildContext context,
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    final unselectedBg = surface.withOpacity(
      Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.70,
    );

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? Colors.black : onSurface.withOpacity(0.95),
        ),
      ),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.black : onSurface.withOpacity(0.95),
      ),
      side: BorderSide(
        color: selected ? Colors.transparent : onSurface.withOpacity(0.14),
      ),
      backgroundColor: unselectedBg,
      selectedColor: surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  static String _labelFor(String code) {
    switch (code) {
      case 'fa':
        return 'فارسی';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }
}
