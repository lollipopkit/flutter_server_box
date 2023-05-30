import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/data/res/ui.dart';

import '../../core/utils/ui.dart';
import '../widget/input_field.dart';
import '../widget/popup_menu.dart';
import '../widget/round_rect_card.dart';

class ConvertPage extends StatefulWidget {
  const ConvertPage({Key? key}) : super(key: key);

  @override
  _ConvertPageState createState() => _ConvertPageState();
}

class _ConvertPageState extends State<ConvertPage>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _textEditingController;
  late TextEditingController _textEditingControllerResult;
  late MediaQueryData _media;
  late S _s;

  int _typeOptionIndex = 0;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
    _textEditingControllerResult = TextEditingController(text: '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.convert),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        controller: ScrollController(),
        child: Column(
          children: [
            height13,
            _buildInputTop(),
            _buildMiddleBtns(),
            _buildResult(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          try {
            _textEditingControllerResult.text = doConvert();
            FocusScope.of(context).requestFocus(FocusNode());
          } catch (e) {
            showSnackBar(context, Text('Error: \n$e'));
          }
        },
        tooltip: _s.convert,
        child: const Icon(Icons.send),
      ),
    );
  }

  String doConvert() {
    final text = _textEditingController.text.trim();
    switch (_typeOptionIndex) {
      case 0:
        return utf8.decode(base64.decode(text));
      case 1:
        return base64.encode(utf8.encode(text));
      case 2:
        return Uri.encodeFull(text);
      case 3:
        return Uri.decodeFull(text);
      default:
        return _s.unkownConvertMode;
    }
  }

  Widget _buildInputTop() {
    return SizedBox(
      height: _media.size.height * 0.33,
      child: Input(controller: _textEditingController),
    );
  }

  Widget _buildMiddleBtns() {
    final decode = _s.decode;
    final encode = _s.encode;
    final List<String> typeOption = [
      'Base64 $decode',
      'Base64 $encode',
      'URL $encode',
      'URL $decode'
    ];
    final items = typeOption
        .map(
          (e) => PopupMenuItem(value: typeOption.indexOf(e), child: Text(e)),
        )
        .toList();
    return RoundRectCard(
      ListTile(
        contentPadding: const EdgeInsets.only(right: 17),
        title: Row(
          children: [
            TextButton(
              child: Icon(Icons.change_circle, semanticLabel: _s.upsideDown),
              onPressed: () {
                final temp = _textEditingController.text;
                _textEditingController.text = _textEditingControllerResult.text;
                _textEditingControllerResult.text = temp;
              },
            ),
            TextButton(
              child: Icon(Icons.copy, semanticLabel: _s.copy),
              onPressed: () => Clipboard.setData(
                ClipboardData(
                  text: _textEditingControllerResult.text == ''
                      ? ''
                      : _textEditingControllerResult.text,
                ),
              ),
            )
          ],
        ),
        trailing: PopupMenu<int>(
          items: items,
          initialValue: _typeOptionIndex,
          onSelected: (p0) {
            setState(() {
              _typeOptionIndex = p0;
            });
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                typeOption[_typeOptionIndex],
                textScaleFactor: 1.0,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    return SizedBox(
      height: _media.size.height * 0.33,
      child: Input(controller: _textEditingControllerResult),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
