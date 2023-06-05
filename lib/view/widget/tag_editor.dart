import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../../core/utils/ui.dart';
import '../../data/res/color.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: () {
          if (isAdd) {
            tags.add(tag);
          } else {
            tags.remove(tag);
          }
          onChanged?.call(tags);
        },
        onLongPress: () => _showRenameDialog(context, tag),
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
              Icon(
                isAdd ? Icons.add_circle : Icons.cancel,
                size: 14.0,
                color: Colors.white,
              ),
            ],
          ),
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
