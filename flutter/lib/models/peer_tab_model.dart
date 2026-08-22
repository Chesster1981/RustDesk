import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import '../common.dart';
import 'model.dart';

enum PeerTabIndex {
  recent,
  fav,
  lan,
  ab,
  group,
}

class PeerTabModel with ChangeNotifier {
  WeakReference<FFI> parent;
  int get currentTab => _currentTab;
  int _currentTab = 0; // index in tabNames
  static const int maxTabCount = 5;
  static const List<String> tabNames = [
    'Recent sessions',
    'Favorites',
    'Discovered',
    'Address book',
    'Available devices',
  ];
  static const List<IconData> icons = [
    Icons.access_time_filled,
    Icons.star,
    Icons.explore,
    IconFont.addressBook,
    IconFont.deviceGroupFill,
  ];
  // Pure connection client: only Accessible devices.
  List<bool> isEnabled = List.from([
    false,
    false,
    false,
    false,
    !(bind.isDisableGroupPanel() || bind.isDisableAccount()),
  ]);
  final List<bool> _isVisible = List.from([
    false,
    false,
    false,
    false,
    true,
  ]);
  List<bool> get isVisibleEnabled => () {
        final list = _isVisible.toList();
        for (int i = 0; i < maxTabCount; i++) {
          list[i] = list[i] && isEnabled[i];
        }
        return list;
      }();
  final List<int> orders =
      List.generate(maxTabCount, (index) => index, growable: false);
  List<int> get visibleEnabledOrderedIndexs =>
      orders.where((e) => isVisibleEnabled[e]).toList();
  List<Peer> _selectedPeers = List.empty(growable: true);
  List<Peer> get selectedPeers => _selectedPeers;
  bool _multiSelectionMode = false;
  bool get multiSelectionMode => _multiSelectionMode;
  List<Peer> _currentTabCachedPeers = List.empty(growable: true);
  List<Peer> get currentTabCachedPeers => _currentTabCachedPeers;
  bool _isShiftDown = false;
  bool get isShiftDown => _isShiftDown;
  String _lastId = '';
  String get lastId => _lastId;

  PeerTabModel(this.parent) {
    // Pure client: only Accessible devices — ignore saved tab visibility.
    for (int i = 0; i < maxTabCount; i++) {
      _isVisible[i] = i == PeerTabIndex.group.index;
    }
    _currentTab = PeerTabIndex.group.index;
    _trySetCurrentTabToFirstVisibleEnabled();
  }

  setCurrentTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      notifyListeners();
    }
  }

  String tabTooltip(int index) {
    if (index >= 0 && index < tabNames.length) {
      return translate(tabNames[index]);
    }
    return index.toString();
  }

  IconData tabIcon(int index) {
    if (index >= 0 && index < icons.length) {
      return icons[index];
    }
    return Icons.help;
  }

  setMultiSelectionMode(bool mode) {
    _multiSelectionMode = mode;
    if (!mode) {
      _selectedPeers.clear();
      _lastId = '';
    }
    notifyListeners();
  }

  select(Peer peer) {
    if (!_multiSelectionMode) {
      // https://github.com/flutter/flutter/issues/101275#issuecomment-1604541700
      // After onTap, the shift key should be pressed for a while when not in multiselection mode,
      // because onTap is delayed when onDoubleTap is not null
      if (isDesktop || isWebDesktop) return;
      _multiSelectionMode = true;
    }
    final cached = _currentTabCachedPeers.map((e) => e.id).toList();
    int thisIndex = cached.indexOf(peer.id);
    int lastIndex = cached.indexOf(_lastId);
    if (_isShiftDown && thisIndex >= 0 && lastIndex >= 0) {
      int start = min(thisIndex, lastIndex);
      int end = max(thisIndex, lastIndex);
      bool remove = isPeerSelected(peer.id);
      for (var i = start; i <= end; i++) {
        if (remove) {
          if (isPeerSelected(cached[i])) {
            _selectedPeers.removeWhere((p) => p.id == cached[i]);
          }
        } else {
          if (!isPeerSelected(cached[i])) {
            _selectedPeers.add(_currentTabCachedPeers[i]);
          }
        }
      }
    } else {
      if (isPeerSelected(peer.id)) {
        _selectedPeers.removeWhere((p) => p.id == peer.id);
      } else {
        _selectedPeers.add(peer);
      }
    }
    _lastId = peer.id;
    notifyListeners();
  }

  // `notifyListeners()` will cause many rebuilds.
  // So, we need to reduce the calls to "notifyListeners()" only when necessary.
  // A better way is to use a new model.
  setCurrentTabCachedPeers(List<Peer> peers) {
    Future.delayed(Duration.zero, () {
      final isPreEmpty = _currentTabCachedPeers.isEmpty;
      _currentTabCachedPeers = peers;
      final isNowEmpty = _currentTabCachedPeers.isEmpty;
      if (isPreEmpty != isNowEmpty) {
        notifyListeners();
      }
    });
  }

  selectAll() {
    _selectedPeers = _currentTabCachedPeers.toList();
    notifyListeners();
  }

  bool isPeerSelected(String id) {
    return selectedPeers.firstWhereOrNull((p) => p.id == id) != null;
  }

  setShiftDown(bool v) {
    if (_isShiftDown != v) {
      _isShiftDown = v;
      if (_multiSelectionMode) {
        notifyListeners();
      }
    }
  }

  setTabVisible(int index, bool _) {
    // Pure client: only Accessible devices; ignore other toggles.
    if (index != PeerTabIndex.group.index) {
      return;
    }
    if (!_isVisible[index]) {
      _isVisible[index] = true;
      try {
        bind.setLocalFlutterOption(
            k: kOptionPeerTabVisible, v: jsonEncode(_isVisible));
      } catch (_) {}
      notifyListeners();
    }
  }

  _trySetCurrentTabToFirstVisibleEnabled() {
    if (!visibleEnabledOrderedIndexs.contains(_currentTab)) {
      if (visibleEnabledOrderedIndexs.isNotEmpty) {
        _currentTab = visibleEnabledOrderedIndexs.first;
      }
    }
  }

  reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 || oldIndex >= visibleEnabledOrderedIndexs.length) {
      return;
    }
    if (newIndex < 0 || newIndex >= visibleEnabledOrderedIndexs.length) {
      return;
    }
    final oldTabValue = visibleEnabledOrderedIndexs[oldIndex];
    final newTabValue = visibleEnabledOrderedIndexs[newIndex];
    int oldValueIndex = orders.indexOf(oldTabValue);
    int newValueIndex = orders.indexOf(newTabValue);
    final list = orders.toList();
    if (oldIndex != -1 && newIndex != -1) {
      list.removeAt(oldValueIndex);
      list.insert(newValueIndex, oldTabValue);
      for (int i = 0; i < list.length; i++) {
        orders[i] = list[i];
      }
      bind.setLocalFlutterOption(k: kOptionPeerTabOrder, v: jsonEncode(orders));
      notifyListeners();
    }
  }
}
