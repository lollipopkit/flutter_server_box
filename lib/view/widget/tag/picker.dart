import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/tag/btn.dart';

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
    final child = widget.tags.isEmpty
        ? Text(_s.noSavedSnippet)
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_s.tag),
              height13,
              SizedBox(
                height: 37,
                width: _media.size.width * 0.7,
                child: _buildTags(),
              ),
              Text(_s.all),
              height13,
              SizedBox(
                height: 37,
                width: _media.size.width * 0.7,
                child: _buildItems(),
              ),
            ],
          );
    return AlertDialog(
      title: Text(_s.choose),
      content: child,
      actions: [
        TextButton(
          onPressed: () {
            context.pop(_selected);
          },
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
