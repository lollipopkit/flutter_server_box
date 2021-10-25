import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:toolbox/core/utils.dart';
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
  final TextEditingController _intervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store = locator<SettingStore>();
    _intervalController.text =
        _store.serverStatusUpdateInterval.fetch()!.toString();
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Server status update interval (seconds)',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.start,
              ),
              trailing: SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  onSubmitted: (val) {
                    _store.serverStatusUpdateInterval.put(int.parse(val));
                    showSnackBar(
                        context,
                        const Text(
                            'This setting will take effect \nthe next time app launch'));
                  },
                ),
              ),
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
