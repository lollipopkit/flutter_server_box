import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late SettingStore _store;
  late int _selectedColorValue;
  double _value = 0;
  late Color _textColor;

@override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _textColor = Theme.of(context).textTheme.bodyText1!.color!;
  }

  @override
  void initState() {
    super.initState();
    _store = locator<SettingStore>();
    _value = _store.serverStatusUpdateInterval.fetch()!.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(17),
        children: [
          RoundRectCard(_buildAppColorPreview()),
          RoundRectCard(
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Server status update interval',
                style: TextStyle(fontSize: 14, color: _textColor),
                textAlign: TextAlign.start,
              ),
              subtitle: const Text(
                'Will take effect the next time app launches.',
                style: TextStyle(color: Colors.grey),
              ),
              trailing: Text('${_value.toInt()} s'),
              children: [
                Slider(
                  thumbColor: primaryColor,
                  activeColor: primaryColor.withOpacity(0.7),
                  min: 0,
                  max: 10,
                  value: _value,
                  onChanged: (newValue) {
                    setState(() {
                      _value = newValue;
                    });
                  },
                  onChangeEnd: (val) =>
                      _store.serverStatusUpdateInterval.put(val.toInt()),
                  label: '${_value.toInt()} seconds',
                  divisions: 10,
                ),
                const SizedBox(height: 3,),
                _value == 0.0 ? const Text('You set to 0, will not update automatically.') : const SizedBox(),
                const SizedBox(height: 13,)
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAppColorPreview() {
    final nowAppColor = _store.primaryColor.fetch()!;
    return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        children: [
          _buildAppColorPicker(Color(nowAppColor)),
          _buildColorPickerConfirmBtn()
        ],
        trailing: ClipOval(
          child: Container(
            color: Color(nowAppColor),
            height: 27,
            width: 27,
          ),
        ),
        title: Text(
          'App primary color',
          style: TextStyle(fontSize: 14, color: _textColor),
        ));
  }

  Widget _buildAppColorPicker(Color selected) {
    return MaterialColorPicker(
        shrinkWrap: true,
        onColorChange: (Color color) {
          _selectedColorValue = color.value;
        },
        selectedColor: selected);
  }

  Widget _buildColorPickerConfirmBtn() {
    return IconButton(
      icon: const Icon(Icons.save),
      onPressed: (() {
        _store.primaryColor.put(_selectedColorValue);
        setState(() {});
      }),
    );
  }
}
