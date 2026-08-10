import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/autocomplete.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/material_mod_popup_menu.dart'
    as mod_menu;
import 'package:flutter_hbb/desktop/widgets/popup_menu.dart';
import 'package:flutter_hbb/desktop/widgets/rd_home_theme.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

/// Full-width quick-connect bar (RdClient style).
class RdQuickConnectBar extends StatefulWidget {
  const RdQuickConnectBar({Key? key}) : super(key: key);

  @override
  State<RdQuickConnectBar> createState() => _RdQuickConnectBarState();
}

class _RdQuickConnectBarState extends State<RdQuickConnectBar> {
  final _idController = IDTextEditingController();
  final RxBool _idInputFocused = false.obs;
  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();
  final AllPeersLoader _allPeersLoader = AllPeersLoader();
  Iterable<Peer> _autocompleteOpts = [];
  final _menuOpen = false.obs;

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(_onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
    Get.put<IDTextEditingController>(_idController);
  }

  @override
  void dispose() {
    _idController.dispose();
    _allPeersLoader.clear();
    _idFocusNode.removeListener(_onFocusChanged);
    _idFocusNode.dispose();
    _idEditingController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    _idInputFocused.value = _idFocusNode.hasFocus;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }
      final textLength = _idEditingController.value.text.length;
      _idEditingController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
    }
  }

  void onConnect(
      {bool isFileTransfer = false,
      bool isViewCamera = false,
      bool isTerminal = false}) {
    connect(context, _idController.id,
        isFileTransfer: isFileTransfer,
        isViewCamera: isViewCamera,
        isTerminal: isTerminal);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: RdHomeTheme.panel(context),
      child: Row(
        children: [
          Icon(Icons.connected_tv,
              size: 22, color: RdHomeTheme.textMutedOf(context)),
          const SizedBox(width: 10),
          Text(
            translate('Control Remote Desktop'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: RdHomeTheme.textMutedOf(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _buildIdField(context)),
          const SizedBox(width: 10),
          _connectButton(context),
          const SizedBox(width: 6),
          _moreButton(context),
        ],
      ),
    );
  }

  Widget _buildIdField(BuildContext context) {
    return RawAutocomplete<Peer>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          _autocompleteOpts = const Iterable<Peer>.empty();
        } else if (_allPeersLoader.peers.isEmpty &&
            !_allPeersLoader.isPeersLoaded) {
          _autocompleteOpts = [
            Peer(
              id: '',
              username: '',
              hostname: '',
              alias: '',
              platform: '',
              tags: [],
              hash: '',
              password: '',
              forceAlwaysRelay: false,
              rdpPort: '',
              rdpUsername: '',
              loginName: '',
              device_group_name: '',
              note: '',
            )
          ];
        } else {
          var tev = textEditingValue;
          final textWithoutSpaces = tev.text.replaceAll(" ", "");
          if (int.tryParse(textWithoutSpaces) != null) {
            tev = TextEditingValue(
              text: textWithoutSpaces,
              selection: tev.selection,
            );
          }
          final textToFind = tev.text.toLowerCase();
          _autocompleteOpts = _allPeersLoader.peers
              .where((peer) =>
                  peer.id.toLowerCase().contains(textToFind) ||
                  peer.username.toLowerCase().contains(textToFind) ||
                  peer.hostname.toLowerCase().contains(textToFind) ||
                  peer.alias.toLowerCase().contains(textToFind))
              .toList();
          _allPeersLoader.queryOnlines(_autocompleteOpts);
        }
        return _autocompleteOpts;
      },
      focusNode: _idFocusNode,
      textEditingController: _idEditingController,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldTextEditingController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        updateTextAndPreserveSelection(
            fieldTextEditingController, _idController.text);
        return Obx(() => TextField(
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              focusNode: fieldFocusNode,
              style: const TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 16,
                height: 1.3,
                color: RdHomeTheme.textPrimary,
              ),
              maxLines: 1,
              cursorColor: RdHomeTheme.accent,
              decoration: InputDecoration(
                filled: true,
                fillColor: RdHomeTheme.bg,
                counterText: '',
                hintText: _idInputFocused.value
                    ? null
                    : translate('Enter Remote ID'),
                hintStyle: const TextStyle(
                  color: RdHomeTheme.textMuted,
                  fontSize: 15,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: RdHomeTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: RdHomeTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: RdHomeTheme.accent),
                ),
              ),
              controller: fieldTextEditingController,
              inputFormatters: [IDTextInputFormatter()],
              onChanged: (v) {
                _idController.id = v;
              },
              onSubmitted: (_) {
                onConnect();
              },
            ).workaroundFreezeLinuxMint());
      },
      onSelected: (option) {
        setState(() {
          _idController.id = option.id;
          FocusScope.of(context).unfocus();
        });
      },
      optionsViewBuilder: (BuildContext context,
          AutocompleteOnSelected<Peer> onSelected, Iterable<Peer> options) {
        options = _autocompleteOpts;
        double maxHeight = options.length * 50;
        if (options.length == 1) {
          maxHeight = 52;
        } else if (options.length == 3) {
          maxHeight = 146;
        } else if (options.length == 4) {
          maxHeight = 193;
        }
        maxHeight = maxHeight.clamp(0, 200);

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: RdHomeTheme.surface2,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                maxWidth: 420,
              ),
              child: _allPeersLoader.peers.isEmpty &&
                      !_allPeersLoader.isPeersLoaded
                  ? const SizedBox(
                      height: 80,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : ListView(
                      padding: const EdgeInsets.only(top: 4),
                      children: options
                          .map((peer) => AutocompletePeerTile(
                              onSelect: () => onSelected(peer), peer: peer))
                          .toList(),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _connectButton(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: RdHomeTheme.accentSolid,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => onConnect(),
        icon: const Icon(Icons.play_arrow, size: 20),
        label: Text(translate('Connect')),
      ),
    );
  }

  Widget _moreButton(BuildContext context) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        border: Border.all(color: RdHomeTheme.border),
        borderRadius: BorderRadius.circular(8),
        color: RdHomeTheme.surface2,
      ),
      child: Obx(() => InkWell(
            borderRadius: BorderRadius.circular(8),
            child: Transform.rotate(
              angle: _menuOpen.value ? pi : 0,
              child: const Icon(IconFont.more,
                  size: 14, color: RdHomeTheme.textMuted),
            ),
            onTapDown: (e) async {
              final offset = e.globalPosition;
              _menuOpen.value = true;
              final x = offset.dx;
              final y = offset.dy;
              await mod_menu
                  .showMenu(
                context: context,
                position: RelativeRect.fromLTRB(x, y, x, y),
                items: [
                  ('Transfer file', () => onConnect(isFileTransfer: true)),
                  ('View camera', () => onConnect(isViewCamera: true)),
                  (
                    '${translate('Terminal')} (beta)',
                    () => onConnect(isTerminal: true)
                  ),
                ]
                    .map((e) => MenuEntryButton<String>(
                          childBuilder: (TextStyle? style) => Text(
                            translate(e.$1),
                            style: style,
                          ),
                          proc: () => e.$2(),
                          padding: EdgeInsets.symmetric(
                              horizontal: kDesktopMenuPadding.left),
                          dismissOnClicked: true,
                        ))
                    .map((e) => e.build(
                        context,
                        const MenuConfig(
                            commonColor: CustomPopupMenuTheme.commonColor,
                            height: CustomPopupMenuTheme.height,
                            dividerHeight:
                                CustomPopupMenuTheme.dividerHeight)))
                    .expand((i) => i)
                    .toList(),
                elevation: 8,
              )
                  .then((_) {
                _menuOpen.value = false;
              });
            },
          )),
    );
  }
}
