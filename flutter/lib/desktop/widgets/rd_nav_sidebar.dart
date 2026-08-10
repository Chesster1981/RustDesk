import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/rd_home_theme.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Unified Views / Groups / Tags sidebar for RdClient-style home.
class RdNavSidebar extends StatefulWidget {
  const RdNavSidebar({Key? key}) : super(key: key);

  @override
  State<RdNavSidebar> createState() => _RdNavSidebarState();
}

class _RdNavSidebarState extends State<RdNavSidebar> {
  final _viewsOpen = true.obs;
  final _groupsOpen = true.obs;
  final _tagsOpen = true.obs;

  Future<void> _selectView(int tabIndex) async {
    final model = gFFI.peerTabModel;
    if (tabIndex != model.currentTab) {
      model.setCurrentTabCachedPeers([]);
    }
    model.setCurrentTab(tabIndex);
    await bind.setLocalFlutterOption(
        k: kOptionPeerTabIndex, v: tabIndex.toString());
    if (tabIndex == PeerTabIndex.ab.index) {
      gFFI.abModel.pullAb(force: ForcePullAb.listAndCurrent, quiet: false);
    } else if (tabIndex == PeerTabIndex.group.index) {
      gFFI.groupModel.pull(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? RdHomeTheme.surface : Theme.of(context).colorScheme.background;
    final border =
        isDark ? RdHomeTheme.border : Theme.of(context).dividerColor;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Consumer<PeerTabModel>(
        builder: (context, model, _) {
          return Obx(() => ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  _section(
                    context,
                    title: translate('Views'),
                    open: _viewsOpen,
                    child: Column(
                      children: model.visibleEnabledOrderedIndexs
                          .map((t) => _viewItem(context, model, t, isDark))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _section(
                    context,
                    title: translate('Groups'),
                    open: _groupsOpen,
                    child: _groupsBody(context, model, isDark),
                  ),
                  const SizedBox(height: 8),
                  _section(
                    context,
                    title: translate('Tags'),
                    open: _tagsOpen,
                    child: _tagsBody(context, model, isDark),
                  ),
                ],
              ));
        },
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required RxBool open,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? RdHomeTheme.textMuted : Colors.grey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => open.value = !open.value,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                Obx(() => Icon(
                      open.value
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      size: 18,
                      color: muted,
                    )),
              ],
            ),
          ),
        ),
        Obx(() => open.value ? child : const SizedBox.shrink()),
      ],
    );
  }

  Widget _viewItem(
      BuildContext context, PeerTabModel model, int tabIndex, bool isDark) {
    final selected = model.currentTab == tabIndex;
    final count = tabIndex == model.currentTab
        ? model.currentTabCachedPeers.length
        : null;
    return _navTile(
      context,
      isDark: isDark,
      selected: selected,
      icon: model.tabIcon(tabIndex),
      label: model.tabTooltip(tabIndex),
      count: count,
      onTap: () => _selectView(tabIndex),
    );
  }

  Widget _groupsBody(
      BuildContext context, PeerTabModel model, bool isDark) {
    if (!model.isEnabled[PeerTabIndex.group.index]) {
      return _emptyHint(context, translate('Disabled'));
    }
    return Obx(() {
      if (!gFFI.userModel.isLogin) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextButton(
            onPressed: loginDialog,
            child: Text(translate('Login'), style: const TextStyle(fontSize: 12)),
          ),
        );
      }
      final groups = gFFI.groupModel.deviceGroups.toList();
      final users = gFFI.groupModel.users.toList();
      if (groups.isEmpty && users.isEmpty) {
        return _emptyHint(context, translate('No groups'));
      }
      final children = <Widget>[];
      for (final g in groups) {
        children.add(_groupItem(context, g.name, true, isDark));
      }
      for (final u in users) {
        children.add(_groupItem(context, u.name, false, isDark,
            display: u.displayNameOrName));
      }
      return Column(children: children);
    });
  }

  Widget _groupItem(
    BuildContext context,
    String name,
    bool isDeviceGroup,
    bool isDark, {
    String? display,
  }) {
    return Obx(() {
      final selected = gFFI.peerTabModel.currentTab == PeerTabIndex.group.index &&
          gFFI.groupModel.isSelectedDeviceGroup.value == isDeviceGroup &&
          gFFI.groupModel.selectedAccessibleItemName.value == name;
      return _navTile(
        context,
        isDark: isDark,
        selected: selected,
        icon: isDeviceGroup ? IconFont.deviceGroupOutline : Icons.person_outline,
        label: display ?? name,
        onTap: () async {
          await _selectView(PeerTabIndex.group.index);
          gFFI.groupModel.isSelectedDeviceGroup.value = isDeviceGroup;
          if (gFFI.groupModel.selectedAccessibleItemName.value == name) {
            gFFI.groupModel.selectedAccessibleItemName.value = '';
          } else {
            gFFI.groupModel.selectedAccessibleItemName.value = name;
          }
        },
      );
    });
  }

  Widget _tagsBody(BuildContext context, PeerTabModel model, bool isDark) {
    if (model.currentTab != PeerTabIndex.ab.index) {
      return _emptyHint(
          context, translate('Switch to Address book to filter tags'));
    }
    return Obx(() {
      if (!gFFI.userModel.isLogin) {
        return _emptyHint(context, translate('Login'));
      }
      final tags = gFFI.abModel.currentAbTags.toList();
      if (tags.isEmpty) {
        return _emptyHint(context, translate('No tags'));
      }
      return Column(
        children: tags
            .map((tag) => _tagItem(context, tag, isDark))
            .toList(),
      );
    });
  }

  Widget _tagItem(BuildContext context, String tag, bool isDark) {
    return Obx(() {
      final selected = gFFI.abModel.selectedTags.contains(tag);
      final tagColor = gFFI.abModel.getCurrentAbTagColor(tag);
      return _navTile(
        context,
        isDark: isDark,
        selected: selected,
        icon: Icons.label_outline,
        iconColor: tagColor,
        label: tag,
        onTap: () {
          if (gFFI.abModel.selectedTags.contains(tag)) {
            gFFI.abModel.selectedTags.remove(tag);
          } else {
            gFFI.abModel.selectedTags.add(tag);
          }
        },
      );
    });
  }

  Widget _emptyHint(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isDark ? RdHomeTheme.textMuted : Colors.grey,
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required bool isDark,
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? count,
    Color? iconColor,
  }) {
    final fg = isDark ? RdHomeTheme.textPrimary : null;
    final muted = isDark ? RdHomeTheme.textMuted : Colors.grey;
    final selBg =
        isDark ? RdHomeTheme.accent.withOpacity(0.15) : MyTheme.accent50;
    final selFg = isDark ? RdHomeTheme.accent : MyTheme.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? selBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor ?? (selected ? selFg : muted)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? selFg : fg,
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
