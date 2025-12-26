import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:mahmoud_apps/tools/web_inspector/http_headers/http_headers_screen.dart';
import 'domain_reputation/domain_reputation_screen.dart';
import 'dns_hosting/dns_hosting_screen.dart';
import 'redirect_seo/redirect_seo_screen.dart';

class WebInspectorScreen extends StatelessWidget {
  const WebInspectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.toolWebInspectorTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolTile(
            title: t.httpHeadersTitle,
            subtitle: t.webInspectorHttpHeadersSubtitle,
            icon: Icons.http,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HttpHeadersScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ToolTile(
            title: t.webInspectorReputationTitle,
            subtitle: t.webInspectorReputationSubtitle,
            icon: Icons.verified_user_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DomainReputationScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ToolTile(
            title: t.dnsTitle,
            subtitle: t.webInspectorDnsSubtitle,
            icon: Icons.dns_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DnsHostingScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ToolTile(
            title: t.redirectTitle,
            subtitle: t.webInspectorRedirectSubtitle,
            icon: Icons.alt_route_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RedirectSeoScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            t.webInspectorTip,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right,
                color: theme.iconTheme.color?.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
