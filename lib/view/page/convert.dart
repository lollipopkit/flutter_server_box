import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/ui.dart';
import '../../generated/l10n.dart';
import '../widget/input_field.dart';
import '../widget/primary_color.dart';
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
  late ThemeData _theme;
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
    _theme = Theme.of(context);
    _s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        controller: ScrollController(),
        child: Column(
          children: [
            const SizedBox(height: 13),
            _buildInputTop(),
            _buildTypeOption(),
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
        heroTag: 'convert fab',
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
      child: buildInput(context, _textEditingController),
    );
  }

  Widget _buildTypeOption() {
    final decode = _s.decode;
    final encode = _s.encode;
    final List<String> typeOption = [
      'Base64 $decode',
      'Base64 $encode',
      'URL $encode',
      'URL $decode'
    ];
    return PrimaryColor(builder: (context, primaryColor) {
      return RoundRectCard(
        ExpansionTile(
          tilePadding: const EdgeInsets.only(left: 7, right: 27),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(primaryColor)),
                child: Icon(Icons.change_circle, semanticLabel: _s.upsideDown),
                onPressed: () {
                  final temp = _textEditingController.text;
                  _textEditingController.text =
                      _textEditingControllerResult.text;
                  _textEditingControllerResult.text = temp;
                },
              ),
              TextButton(
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all(primaryColor),
                ),
                child: Icon(Icons.copy, semanticLabel: _s.copy),
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                      text: _textEditingControllerResult.text == ''
                          ? ' '
                          : _textEditingControllerResult.text),
                ),
              )
            ],
          ),
          trailing: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _media.size.width * 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  typeOption[_typeOptionIndex],
                  textScaleFactor: 1.0,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                      color: primaryColor),
                ),
                Text(
                  _s.currentMode,
                  textScaleFactor: 1.0,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 9.0, color: Colors.grey),
                )
              ],
            ),
          ),
          children: typeOption
              .map(
                (e) => ListTile(
                  title: Text(
                    e,
                    style: TextStyle(
                      color: _theme.textTheme.bodyMedium?.color?.withAlpha(177),
                    ),
                  ),
                  trailing: _buildRadio(typeOption.indexOf(e)),
                ),
              )
              .toList(),
        ),
      );
    });
  }

  Widget _buildResult() {
    return SizedBox(
      height: _media.size.height * 0.33,
      child: buildInput(context, _textEditingControllerResult),
    );
  }

  Radio _buildRadio(int index) {
    return Radio<int>(
      value: index,
      groupValue: _typeOptionIndex,
      onChanged: (int? value) {
        setState(() {
          _typeOptionIndex = value ?? 0;
        });
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
