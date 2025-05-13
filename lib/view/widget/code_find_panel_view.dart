import 'dart:math';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

const EdgeInsetsGeometry _kDefaultFindMargin = EdgeInsets.only(right: 10);
const double _kDefaultFindPanelWidth = 360;
const double _kDefaultFindPanelHeight = 36;
const double _kDefaultReplacePanelHeight = _kDefaultFindPanelHeight * 2;
const double _kDefaultFindIconSize = 16;
const double _kDefaultFindIconWidth = 30;
const double _kDefaultFindIconHeight = 30;
const double _kDefaultFindInputFontSize = 13;
const double _kDefaultFindResultFontSize = 12;
const EdgeInsetsGeometry _kDefaultFindPadding = EdgeInsets.only(left: 5, right: 5, top: 2.5, bottom: 2.5);
const EdgeInsetsGeometry _kDefaultFindInputContentPadding = EdgeInsets.only(left: 5, right: 5);

class CodeFindPanelView extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final EdgeInsetsGeometry margin;
  final bool readOnly;
  final Color? iconColor;
  final Color? iconSelectedColor;
  final double iconSize;
  final double inputFontSize;
  final double resultFontSize;
  final Color? inputTextColor;
  final Color? resultFontColor;
  final EdgeInsetsGeometry padding;
  final InputDecoration decoration;

  const CodeFindPanelView({
    super.key,
    required this.controller,
    this.margin = _kDefaultFindMargin,
    required this.readOnly,
    this.iconSelectedColor,
    this.iconColor,
    this.iconSize = _kDefaultFindIconSize,
    this.inputFontSize = _kDefaultFindInputFontSize,
    this.resultFontSize = _kDefaultFindResultFontSize,
    this.inputTextColor,
    this.resultFontColor,
    this.padding = _kDefaultFindPadding,
    this.decoration = const InputDecoration(
      filled: true,
      contentPadding: _kDefaultFindInputContentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(0)),
        gapPadding: 0
      ),
    )
  });

  @override
  Size get preferredSize => Size(
    double.infinity,
    controller.value == null ? 0 :
      ((controller.value!.replaceMode ? _kDefaultReplacePanelHeight : _kDefaultFindPanelHeight) + margin.vertical)
  );

  @override
  Widget build(BuildContext context) {
    if (controller.value == null) {
      return const SizedBox(width: 0, height: 0);
    }
    return Container(
      margin: margin,
      alignment: Alignment.topRight,
      height: preferredSize.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _kDefaultFindPanelWidth,
          child: Column(
            children: [
              _buildFindInputView(context),
              if (controller.value!.replaceMode)
                _buildReplaceInputView(context),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildFindInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    final String result;
    if (value.result == null) {
      result = 'none';
    } else {
      result = '${value.result!.index + 1}/${value.result!.matches.length}';
    }
    return Row(
      children: [
        SizedBox(
          width: _kDefaultFindPanelWidth / 1.75,
          height: _kDefaultFindPanelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildTextField(
                context: context,
                controller: controller.findInputController,
                focusNode: controller.findInputFocusNode,
                iconsWidth: _kDefaultFindIconWidth * 1.5
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildCheckText(
                    context: context,
                    text: 'Aa',
                    checked: value.option.caseSensitive,
                    onPressed: () {
                      controller.toggleCaseSensitive();
                    }
                  ),
                  _buildCheckText(
                    context: context,
                    text: '.*',
                    checked: value.option.regex,
                    onPressed: () {
                      controller.toggleRegex();
                    }
                  )
                ],
              )
            ],
          )
        ),
        Text(result,
          style: TextStyle(
            color: resultFontColor,
            fontSize: resultFontSize
          )
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildIconButton(
                onPressed: value.result == null ? null : () {
                  controller.previousMatch();
                },
                icon: Icons.arrow_upward,
                tooltip: 'Previous'
              ),
              _buildIconButton(
                onPressed: value.result == null ? null : () {
                  controller.nextMatch();
                },
                icon: Icons.arrow_downward,
                tooltip: 'Next'
              ),
              _buildIconButton(
                onPressed: () {
                  controller.close();
                },
                icon: Icons.close,
                tooltip: 'Close'
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildReplaceInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    return Row(
      children: [
        SizedBox(
          width: _kDefaultFindPanelWidth / 1.75,
          height: _kDefaultFindPanelHeight,
          child: _buildTextField(
            context: context,
            controller: controller.replaceInputController,
            focusNode: controller.replaceInputFocusNode,
          ),
        ),
        _buildIconButton(
          onPressed: value.result == null ? null : () {
            controller.replaceMatch();
          },
          icon: Icons.done,
          tooltip: 'Replace'
        ),
        _buildIconButton(
          onPressed: value.result == null ? null : () {
            controller.replaceAllMatches();
          },
          icon: Icons.done_all,
          tooltip: 'Replace All'
        )
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    double iconsWidth = 0,
  }) {
    return Padding(
      padding: padding,
      child: TextField(
        maxLines: 1,
        focusNode: focusNode,
        style: TextStyle(
          color: inputTextColor,
          fontSize: inputFontSize
        ),
        decoration: decoration.copyWith(
          contentPadding: (decoration.contentPadding ?? EdgeInsets.zero).add(EdgeInsets.only(
            right: iconsWidth
          )
        )),
        controller: controller,
      ),
    );
  }

  Widget _buildCheckText({
    required BuildContext context,
    required String text,
    required bool checked,
    required VoidCallback onPressed,
  }) {
    final Color selectedColor = iconSelectedColor ?? Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: _kDefaultFindIconWidth * 0.75,
          child: Text(
            text,
            style: TextStyle(
              color: checked ? selectedColor : iconColor,
              fontSize: inputFontSize,
            )
          ),
        ),
      )
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: iconSize,
      ),
      constraints: const BoxConstraints(
        maxWidth: _kDefaultFindIconWidth,
        maxHeight: _kDefaultFindIconHeight
      ),
      tooltip: tooltip,
      splashRadius: max(_kDefaultFindIconWidth, _kDefaultFindIconHeight) / 2,
    );
  }
}
