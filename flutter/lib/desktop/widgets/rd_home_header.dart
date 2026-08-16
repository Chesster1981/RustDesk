import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/rd_home_theme.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// Top brand bar for pure connection-client home (no Your Desktop).
class RdHomeHeader extends StatelessWidget {
  const RdHomeHeader({
    Key? key,
    this.banner,
  }) : super(key: key);

  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final textPrimary = RdHomeTheme.textPrimaryOf(context);
    final textMuted = RdHomeTheme.textMutedOf(context);

    return Container(
      // Match account bar / devices panel: inset margins + rounded panel.
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: RdHomeTheme.panel(context),
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
                      'DCS Norway',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      'Remote Desktop Client',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!bind.isDisableSettings())
                IconButton(
                  tooltip: translate('Settings'),
                  onPressed: () => DesktopTabPage.onAddSetting(),
                  icon: Icon(Icons.settings_outlined,
                      color: textMuted, size: 22),
                ),
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
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: RdHomeTheme.accentSolid,
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.desktop_windows, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
