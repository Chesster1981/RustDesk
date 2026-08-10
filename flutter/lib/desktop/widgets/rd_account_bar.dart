import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/desktop/widgets/rd_home_theme.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

/// Account / login status bar for the RdClient-style home shell.
class RdAccountBar extends StatelessWidget {
  const RdAccountBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final surface = RdHomeTheme.surfaceOf(context);
    final border = RdHomeTheme.borderOf(context);
    final textPrimary = RdHomeTheme.textPrimaryOf(context);
    final textMuted = RdHomeTheme.textMutedOf(context);
    final surface2 = RdHomeTheme.surface2Of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Obx(() {
        final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
        final display = gFFI.userModel.displayNameOrUserName;
        final handle = gFFI.userModel.userName.value;
        final avatar =
            bind.mainResolveAvatarUrl(avatar: gFFI.userModel.avatar.value);

        return Row(
          children: [
            _avatar(avatar, loggedIn, surface2, border, textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: loggedIn
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$handle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('Not logged in'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          translate('Sign in to see accessible devices'),
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RdHomeTheme.accentSolid,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (loggedIn) {
                    logOutConfirmDialog();
                  } else {
                    loginDialog();
                  }
                },
                child: Text(
                  loggedIn
                      ? '${translate('Logout')} ($display)'
                      : translate('Login'),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _avatar(String avatar, bool loggedIn, Color surface2, Color border,
      Color textMuted) {
    final built =
        loggedIn ? buildAvatarWidget(avatar: avatar, size: 40) : null;
    if (built != null) return built;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: surface2,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Icon(
        loggedIn ? Icons.person : Icons.person_outline,
        color: textMuted,
        size: 22,
      ),
    );
  }
}
