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
  double _intervalValue = 0;
  late Color priColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    priColor = primaryColor;
  }

  @override
  void initState() {
    super.initState();
    _store = locator<SettingStore>();
    _intervalValue = _store.serverStatusUpdateInterval.fetch()!.toDouble();
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
              textColor: priColor,
              title: const Text(
                'Server status update interval',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.start,
              ),
              subtitle: const Text(
                'Will take effect the next time app launches.',
                style: TextStyle(color: Colors.grey),
              ),
              trailing: Text('${_intervalValue.toInt()} s'),
              children: [
                Slider(
                  thumbColor: priColor,
                  activeColor: priColor.withOpacity(0.7),
                  min: 0,
                  max: 10,
                  value: _intervalValue,
                  onChanged: (newValue) {
                    setState(() {
                      _intervalValue = newValue;
                    });
                  },
                  onChangeEnd: (val) =>
                      _store.serverStatusUpdateInterval.put(val.toInt()),
                  label: '${_intervalValue.toInt()} seconds',
                  divisions: 10,
                ),
                const SizedBox(
                  height: 3,
                ),
                _intervalValue == 0.0
                    ? const Text('You set to 0, will not update automatically.')
                    : const SizedBox(),
                const SizedBox(
                  height: 13,
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAppColorPreview() {
    return ExpansionTile(
        textColor: priColor,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        children: [
          _buildAppColorPicker(priColor),
          _buildColorPickerConfirmBtn()
        ],
        trailing: ClipOval(
          child: Container(
            color: priColor,
            height: 27,
            width: 27,
          ),
        ),
        title: const Text(
          'App primary color',
          style: TextStyle(fontSize: 14),
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
