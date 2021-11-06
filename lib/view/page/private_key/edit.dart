import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/input_decoration.dart';

class PrivateKeyEditPage extends StatefulWidget {
  const PrivateKeyEditPage({Key? key, this.info}) : super(key: key);

  final PrivateKeyInfo? info;

  @override
  _PrivateKeyEditPageState createState() => _PrivateKeyEditPageState();
}

class _PrivateKeyEditPageState extends State<PrivateKeyEditPage>
    with AfterLayoutMixin {
  final nameController = TextEditingController();
  final keyController = TextEditingController();
  final pwdController = TextEditingController();

  late PrivateKeyProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = locator<PrivateKeyProvider>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit'), actions: [
        widget.info != null
            ? IconButton(
                onPressed: () {
                  _provider.delInfo(widget.info!);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete))
            : const SizedBox()
      ]),
      body: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          TextField(
            controller: nameController,
            keyboardType: TextInputType.text,
            decoration: buildDecoration('Name', icon: Icons.info),
          ),
          TextField(
            controller: keyController,
            autocorrect: false,
            minLines: 3,
            maxLines: 10,
            keyboardType: TextInputType.text,
            enableSuggestions: false,
            decoration: buildDecoration('Private Key', icon: Icons.vpn_key),
          ),
          TextField(
            controller: pwdController,
            autocorrect: false,
            keyboardType: TextInputType.text,
            obscureText: true,
            decoration: buildDecoration('Password', icon: Icons.password),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.send),
        onPressed: () {
          final name = nameController.text;
          final key = keyController.text;
          final pwd = pwdController.text;
          if (name.isEmpty || key.isEmpty || pwd.isEmpty) {
            showSnackBar(
                context, const Text('Three fields must not be empty.'));
            return;
          }
          final info = PrivateKeyInfo(name, key, pwd);
          if (widget.info != null) {
            _provider.updateInfo(widget.info!, info);
          } else {
            _provider.addInfo(info);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.info != null) {
      nameController.text = widget.info!.id;
      keyController.text = widget.info!.privateKey;
      pwdController.text = widget.info!.password;
    }
  }
}
