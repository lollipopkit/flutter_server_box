import 'package:after_layout/after_layout.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
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
  late Widget loading;

  @override
  void initState() {
    super.initState();
    _provider = locator<PrivateKeyProvider>();
    loading = const SizedBox();
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          loading
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          final name = nameController.text;
          final key = keyController.text;
          final pwd = pwdController.text;
          if (name.isEmpty || key.isEmpty || pwd.isEmpty) {
            showSnackBar(
                context, const Text('Three fields must not be empty.'));
            return;
          }
          FocusScope.of(context).unfocus();
          setState(() {
            loading = const SizedBox(
              height: 50,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          });
          final info = PrivateKeyInfo(name, key, pwd);
          bool haveErr = false;
          try {
            info.privateKey = await compute(decyptPem, [key, pwd]);
          } catch (e) {
            showSnackBar(context, Text(e.toString()));
            haveErr = true;
          } finally {
            setState(() {
              loading = const SizedBox();
            });
          }
          if (haveErr) return;
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

/// [args] : [key, pwd]
String decyptPem(List<String> args) {
  /// skip when the key is not encrypted, or will throw exception
  if (!SSHKeyPair.isEncryptedPem(args[0])) return args[0];
  final sshKey = SSHKeyPair.fromPem(args[0], args[1]);
  return sshKey.first.toPem();
}
