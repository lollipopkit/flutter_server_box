import 'package:flutter/material.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../data/res/color.dart';

class TagEditor extends StatelessWidget {
  final List<String> tags;
  final String s;
  final void Function(List<String>)? onChanged;

  const TagEditor(
      {super.key, required this.tags, this.onChanged, required this.s});

  @override
  Widget build(BuildContext context) {
    return RoundRectCard(ListTile(
      leading: const Icon(Icons.tag),
      title: _buildTags(
        tags,
        _onTapDelete,
      ),
      trailing: InkWell(
        child: const Icon(Icons.add),
        onTap: () {
          _showTagDialog(context, tags, onChanged);
        },
      ),
    ));
  }

  void _onTapDelete(String tag) {
    tags.remove(tag);
    onChanged?.call(tags);
  }

  Widget _buildTags(
    List<String> tags,
    Function(String) onTagDelete,
  ) {
    if (tags.isEmpty) return Text(s);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: tags.map((e) => _buildTagItem(e, onTagDelete)).toList(),
      ),
    );
  }

  Widget _buildTagItem(String tag, Function(String) onTagDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(20.0)),
          color: primaryColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '#$tag',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 4.0),
            InkWell(
              child: const Icon(
                Icons.cancel,
                size: 14.0,
                color: Colors.white,
              ),
              onTap: () {
                onTagDelete(tag);
              },
            )
          ],
        ),
      ),
    );
  }

  void _showTagDialog(
    BuildContext context,
    List<String> tags,
    void Function(List<String>)? onChanged,
  ) {
    final textEditingController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: Input(
            controller: textEditingController,
            hint: 'Tag',
          ),
          actions: [
            TextButton(
              onPressed: () {
                final tag = textEditingController.text;
                tags.add(tag.trim());
                onChanged?.call(tags);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
