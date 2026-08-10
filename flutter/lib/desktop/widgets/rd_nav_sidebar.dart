import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/rd_home_theme.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Groups-only sidebar for pure Accessible-devices client.
class RdNavSidebar extends StatefulWidget {
  const RdNavSidebar({Key? key}) : super(key: key);

  @override
  State<RdNavSidebar> createState() => _RdNavSidebarState();
}

class _RdNavSidebarState extends State<RdNavSidebar> {
  bool _groupsOpen = true;

  Future<void> _ensureGroupTab() async {
    final model = gFFI.peerTabModel;
    final group = PeerTabIndex.group.index;
    if (model.currentTab != group) {
      model.setCurrentTabCachedPeers([]);
      model.setCurrentTab(group);
      await bind.setLocalFlutterOption(
          k: kOptionPeerTabIndex, v: group.toString());
      gFFI.groupModel.pull(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      // Match account bar + devices panel: same top/bottom air and radius.
      margin: const EdgeInsets.fromLTRB(16, 10, 10, 16),
      decoration: RdHomeTheme.panel(context),
      child: Consumer<PeerTabModel>(
        builder: (context, model, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            children: [
              _section(
                context,
                title: translate('Groups'),
                open: _groupsOpen,
                onToggle: () => setState(() => _groupsOpen = !_groupsOpen),
                child: _groupsBody(context, model),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final muted = RdHomeTheme.textMutedOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: muted,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
        if (open) child,
      ],
    );
  }

  Widget _groupsBody(BuildContext context, PeerTabModel model) {
    if (!model.isEnabled[PeerTabIndex.group.index]) {
      return _emptyHint(context, translate('Disabled'));
    }
    return Obx(() {
      final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
      if (!loggedIn) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextButton(
            onPressed: loginDialog,
            child:
                Text(translate('Login'), style: const TextStyle(fontSize: 12)),
          ),
        );
      }
      final groups = List.of(gFFI.groupModel.deviceGroups);
      final users = List.of(gFFI.groupModel.users);
      final selectedName = gFFI.groupModel.selectedAccessibleItemName.value;
      final selectedIsDevice = gFFI.groupModel.isSelectedDeviceGroup.value;
      final onGroupTab = model.currentTab == PeerTabIndex.group.index;

      if (groups.isEmpty && users.isEmpty) {
        return _emptyHint(context, translate('No groups'));
      }
      return Column(
        children: [
          for (final g in groups)
            _navTile(
              context,
              selected: onGroupTab && selectedIsDevice && selectedName == g.name,
              icon: IconFont.deviceGroupOutline,
              label: g.name,
              onTap: () async {
                await _ensureGroupTab();
                gFFI.groupModel.isSelectedDeviceGroup.value = true;
                if (gFFI.groupModel.selectedAccessibleItemName.value == g.name) {
                  gFFI.groupModel.selectedAccessibleItemName.value = '';
                } else {
                  gFFI.groupModel.selectedAccessibleItemName.value = g.name;
                }
              },
            ),
          for (final u in users)
            _navTile(
              context,
              selected:
                  onGroupTab && !selectedIsDevice && selectedName == u.name,
              icon: Icons.person_outline,
              label: u.displayNameOrName,
              onTap: () async {
                await _ensureGroupTab();
                gFFI.groupModel.isSelectedDeviceGroup.value = false;
                if (gFFI.groupModel.selectedAccessibleItemName.value == u.name) {
                  gFFI.groupModel.selectedAccessibleItemName.value = '';
                } else {
                  gFFI.groupModel.selectedAccessibleItemName.value = u.name;
                }
              },
            ),
        ],
      );
    });
  }

  Widget _emptyHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: RdHomeTheme.textMutedOf(context),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? count,
    Color? iconColor,
  }) {
    final muted = RdHomeTheme.textMutedOf(context);
    final primary = RdHomeTheme.textPrimaryOf(context);
    final selBg = RdHomeTheme.accent.withOpacity(0.15);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? selBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: RdHomeTheme.surface2Of(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: iconColor ??
                        (selected ? RdHomeTheme.accent : muted)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? RdHomeTheme.accent : primary,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
