import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../../core/utils/ui.dart';
import '../../data/res/color.dart';

const _kTagBtnHeight = 31.0;

class TagBtn extends StatelessWidget {
  final String content;
  final void Function() onTap;
  final bool isEnable;

  const TagBtn({
    super.key,
    required this.onTap,
    required this.isEnable,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return _wrap(
      Text(
        content,
        textAlign: TextAlign.center,
        textScaleFactor: 1.0,
        style: isEnable ? textSize13 : textSize13Grey,
      ),
      onTap: onTap,
    );
  }
}

class TagEditor extends StatelessWidget {
  final List<String> tags;
  final S s;
  final void Function(List<String>)? onChanged;
  final void Function(String old, String new_)? onRenameTag;
  final List<String>? tagSuggestions;

  const TagEditor({
    super.key,
    required this.tags,
    required this.s,
    this.onChanged,
    this.onRenameTag,
    this.tagSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    return RoundRectCard(ListTile(
      leading: const Icon(Icons.tag),
      title: _buildTags(context, tags),
      trailing: InkWell(
        child: const Icon(Icons.add),
        onTap: () {
          _showTagDialog(context, tags, onChanged);
        },
      ),
    ));
  }

  Widget _buildTags(BuildContext context, List<String> tags) {
    tagSuggestions?.removeWhere((element) => tags.contains(element));
    final suggestionLen = tagSuggestions?.length ?? 0;
    final counts = tags.length + suggestionLen + (suggestionLen == 0 ? 0 : 1);
    if (counts == 0) return Text(s.tag);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 27),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          if (index < tags.length) {
            return _buildTagItem(context, tags[index], false);
          } else if (index > tags.length) {
            return _buildTagItem(
              context,
              tagSuggestions![index - tags.length - 1],
              true,
            );
          }
          return const VerticalDivider();
        },
        itemCount: counts,
      ),
    );
  }

  Widget _buildTagItem(BuildContext context, String tag, bool isAdd) {
    return _wrap(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '#$tag',
            textAlign: TextAlign.center,
            style: textSize13,
            textScaleFactor: 1.0,
          ),
          const SizedBox(width: 4.0),
          Icon(
            isAdd ? Icons.add_circle : Icons.cancel,
            size: 13.7,
          ),
        ],
      ),
      onTap: () {
        if (isAdd) {
          tags.add(tag);
        } else {
          tags.remove(tag);
        }
        onChanged?.call(tags);
      },
      onLongPress: () => _showRenameDialog(context, tag),
    );
  }

  void _showTagDialog(
    BuildContext context,
    List<String> tags,
    void Function(List<String>)? onChanged,
  ) {
    final textEditingController = TextEditingController();
    showRoundDialog(
      context: context,
      title: Text(s.add),
      child: Input(
        controller: textEditingController,
        hint: s.tag,
      ),
      actions: [
        TextButton(
          onPressed: () {
            final tag = textEditingController.text;
            tags.add(tag.trim());
            onChanged?.call(tags);
            Navigator.pop(context);
          },
          child: Text(s.add),
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, String tag) {
    final textEditingController = TextEditingController(text: tag);
    showRoundDialog(
      context: context,
      title: Text(s.rename),
      child: Input(
        controller: textEditingController,
        hint: s.tag,
      ),
      actions: [
        TextButton(
          onPressed: () {
            final newTag = textEditingController.text.trim();
            if (newTag.isEmpty) return;
            onRenameTag?.call(tag, newTag);
            context.pop();
          },
          child: Text(s.rename),
        ),
      ],
    );
  }
}

class TagPicker<T> extends StatefulWidget {
  final List<T> items;
  final bool Function(T, String?) containsTag;
  final String Function(T) name;
  final Set<String> tags;

  const TagPicker({
    Key? key,
    required this.items,
    required this.containsTag,
    required this.name,
    required this.tags,
  }) : super(key: key);

  @override
  _TagPickerState<T> createState() => _TagPickerState<T>();
}

class _TagPickerState<T> extends State<TagPicker<T>> {
  late S _s;
  late MediaQueryData _media;
  final List<T> _selected = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
    _media = MediaQuery.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (widget.tags.isNotEmpty) {
      children.add(Text(_s.tag));
      children.add(height13);
      children.add(SizedBox(
        height: _kTagBtnHeight,
        width: _media.size.width * 0.7,
        child: _buildTags(),
      ));
    }
    if (widget.items.isNotEmpty) {
      children.add(Text(_s.all));
      children.add(height13);
      children.add(SizedBox(
        height: _kTagBtnHeight,
        width: _media.size.width * 0.7,
        child: _buildItems(),
      ));
    }
    final child = widget.tags.isEmpty && widget.items.isEmpty
        ? Text(_s.noOptions)
        : Column(mainAxisSize: MainAxisSize.min, children: children);
    return AlertDialog(
      title: Text(_s.choose),
      content: child,
      actions: [
        TextButton(
          onPressed: () => context.pop(_selected),
          child: Text(_s.ok),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.tags.length,
      itemBuilder: (_, idx) {
        final item = widget.tags.elementAt(idx);
        final isEnable =
            widget.items.where((ele) => widget.containsTag(ele, item)).every(
                  (element) => _selected.contains(element),
                );
        return TagBtn(
          isEnable: isEnable,
          onTap: () {
            if (isEnable) {
              _selected.removeWhere(
                (element) => widget.containsTag(element, item),
              );
            } else {
              _selected.addAll(widget.items.where(
                (ele) => widget.containsTag(ele, item),
              ));
            }
            setState(() {});
          },
          content: item,
        );
      },
    );
  }

  Widget _buildItems() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final e = widget.items[index];
        return TagBtn(
          isEnable: _selected.contains(e),
          onTap: () {
            if (_selected.contains(e)) {
              _selected.remove(e);
            } else {
              _selected.add(e);
            }
            setState(() {});
          },
          content: widget.name(e),
        );
      },
    );
  }
}

class TagSwitcher extends StatelessWidget {
  final List<String> tags;
  final double width;
  final void Function(String?) onTagChanged;
  final String? initTag;
  final String all;

  const TagSwitcher({
    Key? key,
    required this.tags,
    required this.width,
    required this.onTagChanged,
    required this.all,
    this.initTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return placeholder;
    final items = <String?>[null, ...tags];
    return Container(
      height: _kTagBtnHeight,
      width: width,
      alignment: Alignment.center,
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = items[index];
          return TagBtn(
            content: item == null ? all : '#$item',
            isEnable: initTag == item,
            onTap: () => onTagChanged(item),
          );
        },
        itemCount: items.length,
      ),
    );
  }
}

Widget _wrap(
  Widget child, {
  void Function()? onTap,
  void Function()? onLongPress,
}) {
  return Padding(
    padding: const EdgeInsets.all(3),
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(20.0)),
      child: Material(
        color: primaryColor.withAlpha(20),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            /// Hard coded padding
            /// For centering the text
            padding: const EdgeInsets.fromLTRB(11.7, 2.7, 11.7, 0),
            child: child,
          ),
        ),
      ),
    ),
  );
}
