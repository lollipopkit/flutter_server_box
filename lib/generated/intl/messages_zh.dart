// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh';

  static String m0(rainSunMeGithub) =>
      "\n感谢 ${rainSunMeGithub} 参与软件测试。\n\n保留所有权利。";

  static String m1(code) => "请求失败, 状态码: ${code}";

  static String m2(myGithub) => "\n用❤️制作 by ${myGithub}";

  static String m3(server) => "你确定要删除服务器 [${server}] 吗？";

  static String m4(build) => "找到新版本：v1.0.${build}, 点击更新";

  static String m5(build) => "当前：v1.0.${build}";

  static String m6(build) => "当前：v1.0.${build}, 已是最新版本";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "aboutThanks": m0,
        "addAServer": MessageLookupByLibrary.simpleMessage("添加服务器"),
        "addPrivateKey": MessageLookupByLibrary.simpleMessage("添加一个私钥"),
        "appPrimaryColor": MessageLookupByLibrary.simpleMessage("App主要色"),
        "attention": MessageLookupByLibrary.simpleMessage("注意"),
        "cancel": MessageLookupByLibrary.simpleMessage("取消"),
        "choose": MessageLookupByLibrary.simpleMessage("选择"),
        "chooseDestination": MessageLookupByLibrary.simpleMessage("选择目标"),
        "choosePrivateKey": MessageLookupByLibrary.simpleMessage("选择私钥"),
        "clear": MessageLookupByLibrary.simpleMessage("清除"),
        "close": MessageLookupByLibrary.simpleMessage("关闭"),
        "convert": MessageLookupByLibrary.simpleMessage("转换"),
        "copy": MessageLookupByLibrary.simpleMessage("复制到剪切板"),
        "currentMode": MessageLookupByLibrary.simpleMessage("当前模式"),
        "debug": MessageLookupByLibrary.simpleMessage("调试"),
        "decode": MessageLookupByLibrary.simpleMessage("解码"),
        "delete": MessageLookupByLibrary.simpleMessage("删除"),
        "edit": MessageLookupByLibrary.simpleMessage("编辑"),
        "encode": MessageLookupByLibrary.simpleMessage("编码"),
        "exampleName": MessageLookupByLibrary.simpleMessage("名称示例"),
        "export": MessageLookupByLibrary.simpleMessage("导出"),
        "fieldMustNotEmpty": MessageLookupByLibrary.simpleMessage("这些输入框不能为空。"),
        "go": MessageLookupByLibrary.simpleMessage("开始"),
        "host": MessageLookupByLibrary.simpleMessage("主机"),
        "httpFailedWithCode": m1,
        "import": MessageLookupByLibrary.simpleMessage("导入"),
        "importAndExport": MessageLookupByLibrary.simpleMessage("导入或导出"),
        "keyAuth": MessageLookupByLibrary.simpleMessage("公钥认证"),
        "launchPage": MessageLookupByLibrary.simpleMessage("启动页"),
        "license": MessageLookupByLibrary.simpleMessage("开源证书"),
        "loss": MessageLookupByLibrary.simpleMessage("丢包率"),
        "madeWithLove": m2,
        "max": MessageLookupByLibrary.simpleMessage("最大"),
        "min": MessageLookupByLibrary.simpleMessage("最小"),
        "ms": MessageLookupByLibrary.simpleMessage("毫秒"),
        "name": MessageLookupByLibrary.simpleMessage("名称"),
        "noResult": MessageLookupByLibrary.simpleMessage("无结果"),
        "noSavedPrivateKey": MessageLookupByLibrary.simpleMessage("没有已保存的私钥。"),
        "noSavedSnippet": MessageLookupByLibrary.simpleMessage("没有已保存的代码片段。"),
        "noServerAvailable": MessageLookupByLibrary.simpleMessage("没有可用的服务器。"),
        "ok": MessageLookupByLibrary.simpleMessage("好"),
        "ping": MessageLookupByLibrary.simpleMessage("Ping"),
        "pingAvg": MessageLookupByLibrary.simpleMessage("平均:"),
        "pingInputIP": MessageLookupByLibrary.simpleMessage("请输入目标IP或域名"),
        "plzEnterHost": MessageLookupByLibrary.simpleMessage("请输入主机"),
        "plzEnterPwd": MessageLookupByLibrary.simpleMessage("请输入密码"),
        "plzSelectKey": MessageLookupByLibrary.simpleMessage("请选择私钥"),
        "port": MessageLookupByLibrary.simpleMessage("端口"),
        "privateKey": MessageLookupByLibrary.simpleMessage("私钥"),
        "pwd": MessageLookupByLibrary.simpleMessage("密码"),
        "result": MessageLookupByLibrary.simpleMessage("结果"),
        "run": MessageLookupByLibrary.simpleMessage("运行"),
        "save": MessageLookupByLibrary.simpleMessage("保存"),
        "second": MessageLookupByLibrary.simpleMessage("秒"),
        "server": MessageLookupByLibrary.simpleMessage("服务器"),
        "serverTabConnecting": MessageLookupByLibrary.simpleMessage("连接中..."),
        "serverTabEmpty":
            MessageLookupByLibrary.simpleMessage("现在没有服务器。\n点击右下方按钮来添加。"),
        "serverTabFailed": MessageLookupByLibrary.simpleMessage("失败"),
        "serverTabLoading": MessageLookupByLibrary.simpleMessage("加载中..."),
        "serverTabPlzSave": MessageLookupByLibrary.simpleMessage("请再次保存该私钥"),
        "serverTabUnkown": MessageLookupByLibrary.simpleMessage("未知状态"),
        "setting": MessageLookupByLibrary.simpleMessage("设置"),
        "snippet": MessageLookupByLibrary.simpleMessage("代码片段"),
        "start": MessageLookupByLibrary.simpleMessage("开始"),
        "stop": MessageLookupByLibrary.simpleMessage("停止"),
        "sureToDeleteServer": m3,
        "ttl": MessageLookupByLibrary.simpleMessage("缓存时间"),
        "unknown": MessageLookupByLibrary.simpleMessage("未知"),
        "unkownConvertMode": MessageLookupByLibrary.simpleMessage("未知转换模式"),
        "updateIntervalEqual0": MessageLookupByLibrary.simpleMessage(
            "你设置为0，服务器状态不会自动刷新。\n你可以手动下拉刷新。"),
        "updateServerStatusInterval":
            MessageLookupByLibrary.simpleMessage("服务器状态刷新间隔"),
        "upsideDown": MessageLookupByLibrary.simpleMessage("上下交换"),
        "urlOrJson": MessageLookupByLibrary.simpleMessage("链接或JSON"),
        "user": MessageLookupByLibrary.simpleMessage("用户"),
        "versionHaveUpdate": m4,
        "versionUnknownUpdate": m5,
        "versionUpdated": m6,
        "willTakEeffectImmediately":
            MessageLookupByLibrary.simpleMessage("更改将会立即生效")
      };
}
