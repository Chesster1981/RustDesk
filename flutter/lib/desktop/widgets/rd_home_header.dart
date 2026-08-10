import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/rd_home_theme.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// Top brand bar for the RdClient-style home shell.
class RdHomeHeader extends StatelessWidget {
  const RdHomeHeader({
    Key? key,
    required this.showThisPc,
    required this.thisPcBuilder,
    this.banner,
  }) : super(key: key);

  final bool showThisPc;
  final WidgetBuilder thisPcBuilder;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? RdHomeTheme.bg : Theme.of(context).colorScheme.background;
    final fg = isDark
        ? RdHomeTheme.textPrimary
        : Theme.of(context).textTheme.titleLarge?.color;
    final muted = isDark
        ? RdHomeTheme.textMuted
        : Theme.of(context).textTheme.bodySmall?.color;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _logo(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translate('Remote Desktop'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    Text(
                      translate('Connect to your devices'),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              if (showThisPc) _thisPcButton(context, isDark),
              if (!bind.isDisableSettings()) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: translate('Settings'),
                  onPressed: () => DesktopTabPage.onAddSetting(),
                  icon: Icon(Icons.settings_outlined, color: muted, size: 22),
                ),
              ],
            ],
          ),
          if (banner != null) ...[
            const SizedBox(height: 8),
            banner!,
          ],
        ],
      ),
    );
  }

  Widget _logo() {
    return ClipOval(
      child: Image.asset(
        'assets/dcs_norway_logo.png',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: RdHomeTheme.accentSolid,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.desktop_windows, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _thisPcButton(BuildContext context, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: isDark ? RdHomeTheme.surface : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color:
                    isDark ? RdHomeTheme.border : Theme.of(context).dividerColor,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: thisPcBuilder(ctx),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? RdHomeTheme.surface : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? RdHomeTheme.border : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.computer,
                size: 18,
                color: isDark ? RdHomeTheme.accent : MyTheme.accent),
            const SizedBox(width: 8),
            Text(
              translate('Your Desktop'),
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? RdHomeTheme.textPrimary
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more,
                size: 18,
                color: isDark ? RdHomeTheme.textMuted : Colors.grey),
          ],
        ),
      ),
    );
  }
}
