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
    return Container(
      decoration: const BoxDecoration(
        color: RdHomeTheme.surface,
        border: Border(
          bottom: BorderSide(color: RdHomeTheme.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _logo(),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remote Desktop Client',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: RdHomeTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Connect to your devices',
                      style: TextStyle(
                          fontSize: 12, color: RdHomeTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (!bind.isDisableSettings())
                IconButton(
                  tooltip: translate('Settings'),
                  onPressed: () => DesktopTabPage.onAddSetting(),
                  icon: const Icon(Icons.settings_outlined,
                      color: RdHomeTheme.textMuted, size: 22),
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
          child:
              const Icon(Icons.desktop_windows, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
