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

  static String m0(fileName) => "下载 [${fileName}] 到本地？";

  static String m1(count) => "共 ${count} 个镜像";

  static String m2(runningCount, stoppedCount) =>
      "${runningCount}个正在运行, ${stoppedCount}个已停止";

  static String m3(count) => "${count}个容器正在运行";

  static String m4(percent, size) => "${size} 的 ${percent}%";

  static String m5(count) => "找到 ${count} 个更新";

  static String m6(code) => "请求失败, 状态码: ${code}";

  static String m7(url) =>
      "请确保正确安装了docker，或者使用的非自编译版本。如果没有以上问题，请在 ${url} 提交问题。";

  static String m8(myGithub) => "\n用❤️制作 by ${myGithub}";

  static String m9(url) => "请到 ${url} 提交问题";

  static String m10(date) => "确定恢复 ${date} 的备份吗？";

  static String m11(time) => "耗时: ${time}";

  static String m12(url) => "该功能目前处于测试阶段，请在 ${url} 反馈问题，或者加入我们开发。";

  static String m13(name) => "确定删除[${name}]？";

  static String m14(server) => "你确定要删除服务器 [${server}] 吗？";

  static String m15(build) => "找到新版本：v1.0.${build}, 点击更新";

  static String m16(build) => "当前：v1.0.${build}";

  static String m17(build) => "当前：v1.0.${build}, 已是最新版本";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "aboutThanks":
            MessageLookupByLibrary.simpleMessage("\n保留所有权利。\n\n感谢以下参与软件测试的各位。"),
        "addAServer": MessageLookupByLibrary.simpleMessage("添加服务器"),
        "addOne": MessageLookupByLibrary.simpleMessage("前去新增"),
        "addPrivateKey": MessageLookupByLibrary.simpleMessage("添加一个私钥"),
        "alreadyLastDir": MessageLookupByLibrary.simpleMessage("已经是最上层目录了"),
        "appPrimaryColor": MessageLookupByLibrary.simpleMessage("App主要色"),
        "attention": MessageLookupByLibrary.simpleMessage("注意"),
        "backDir": MessageLookupByLibrary.simpleMessage("返回上一级"),
        "backup": MessageLookupByLibrary.simpleMessage("备份"),
        "backupTip": MessageLookupByLibrary.simpleMessage(
            "导出的数据仅进行了简单加密，请妥善保管。\n除了设置项，恢复的数据不会覆盖现有数据。"),
        "backupVersionNotMatch":
            MessageLookupByLibrary.simpleMessage("备份版本不匹配，无法恢复"),
        "cancel": MessageLookupByLibrary.simpleMessage("取消"),
        "choose": MessageLookupByLibrary.simpleMessage("选择"),
        "chooseDestination": MessageLookupByLibrary.simpleMessage("选择目标"),
        "choosePrivateKey": MessageLookupByLibrary.simpleMessage("选择私钥"),
        "clear": MessageLookupByLibrary.simpleMessage("清除"),
        "clickSee": MessageLookupByLibrary.simpleMessage("点击查看"),
        "close": MessageLookupByLibrary.simpleMessage("关闭"),
        "cmd": MessageLookupByLibrary.simpleMessage("命令"),
        "containerStatus": MessageLookupByLibrary.simpleMessage("容器状态"),
        "convert": MessageLookupByLibrary.simpleMessage("转换"),
        "copy": MessageLookupByLibrary.simpleMessage("复制到剪切板"),
        "copyPath": MessageLookupByLibrary.simpleMessage("复制路径"),
        "createFile": MessageLookupByLibrary.simpleMessage("创建文件"),
        "createFolder": MessageLookupByLibrary.simpleMessage("创建文件夹"),
        "currentMode": MessageLookupByLibrary.simpleMessage("当前模式"),
        "debug": MessageLookupByLibrary.simpleMessage("调试"),
        "decode": MessageLookupByLibrary.simpleMessage("解码"),
        "delete": MessageLookupByLibrary.simpleMessage("删除"),
        "disconnected": MessageLookupByLibrary.simpleMessage("连接断开"),
        "dl2Local": m0,
        "dockerContainerName": MessageLookupByLibrary.simpleMessage("容器名"),
        "dockerEditHost":
            MessageLookupByLibrary.simpleMessage("编辑 DOCKER_HOST"),
        "dockerEmptyRunningItems": MessageLookupByLibrary.simpleMessage(
            "没有正在运行的容器。\n这可能是因为环境变量 DOCKER_HOST 没有被正确读取。你可以通过在终端内运行 `echo \$DOCKER_HOST` 来获取。"),
        "dockerImage": MessageLookupByLibrary.simpleMessage("镜像"),
        "dockerImagesFmt": m1,
        "dockerNotInstalled": MessageLookupByLibrary.simpleMessage("Docker未安装"),
        "dockerStatusRunningAndStoppedFmt": m2,
        "dockerStatusRunningFmt": m3,
        "download": MessageLookupByLibrary.simpleMessage("下载"),
        "downloadFinished": MessageLookupByLibrary.simpleMessage("下载完成！"),
        "downloadStatus": m4,
        "edit": MessageLookupByLibrary.simpleMessage("编辑"),
        "encode": MessageLookupByLibrary.simpleMessage("编码"),
        "error": MessageLookupByLibrary.simpleMessage("出错了"),
        "exampleName": MessageLookupByLibrary.simpleMessage("名称示例"),
        "experimentalFeature": MessageLookupByLibrary.simpleMessage("实验性功能"),
        "export": MessageLookupByLibrary.simpleMessage("导出"),
        "extraArgs": MessageLookupByLibrary.simpleMessage("额外参数"),
        "feedback": MessageLookupByLibrary.simpleMessage("反馈"),
        "feedbackOnGithub":
            MessageLookupByLibrary.simpleMessage("如果你有任何问题，请在GitHub反馈"),
        "fieldMustNotEmpty": MessageLookupByLibrary.simpleMessage("这些输入框不能为空。"),
        "files": MessageLookupByLibrary.simpleMessage("文件"),
        "foundNUpdate": m5,
        "go": MessageLookupByLibrary.simpleMessage("开始"),
        "goto": MessageLookupByLibrary.simpleMessage("前往"),
        "host": MessageLookupByLibrary.simpleMessage("主机"),
        "httpFailedWithCode": m6,
        "imagesList": MessageLookupByLibrary.simpleMessage("镜像列表"),
        "import": MessageLookupByLibrary.simpleMessage("导入"),
        "importAndExport": MessageLookupByLibrary.simpleMessage("导入或导出"),
        "inputDomainHere": MessageLookupByLibrary.simpleMessage("在这里输入域名"),
        "install": MessageLookupByLibrary.simpleMessage("安装"),
        "installDockerWithUrl": MessageLookupByLibrary.simpleMessage(
            "请先 https://docs.docker.com/engine/install docker"),
        "invalidJson": MessageLookupByLibrary.simpleMessage("无效的json，存在格式问题"),
        "invalidVersion": MessageLookupByLibrary.simpleMessage("不支持的版本"),
        "invalidVersionHelp": m7,
        "isBusy": MessageLookupByLibrary.simpleMessage("当前正忙"),
        "keepForeground": MessageLookupByLibrary.simpleMessage("请保持应用处于前台！"),
        "keyAuth": MessageLookupByLibrary.simpleMessage("公钥认证"),
        "lastTry": MessageLookupByLibrary.simpleMessage("最后尝试"),
        "launchPage": MessageLookupByLibrary.simpleMessage("启动页"),
        "license": MessageLookupByLibrary.simpleMessage("开源证书"),
        "loadingFiles": MessageLookupByLibrary.simpleMessage("正在加载目录。。。"),
        "loss": MessageLookupByLibrary.simpleMessage("丢包率"),
        "madeWithLove": m8,
        "max": MessageLookupByLibrary.simpleMessage("最大"),
        "min": MessageLookupByLibrary.simpleMessage("最小"),
        "ms": MessageLookupByLibrary.simpleMessage("毫秒"),
        "name": MessageLookupByLibrary.simpleMessage("名称"),
        "newContainer": MessageLookupByLibrary.simpleMessage("新建容器"),
        "noClient": MessageLookupByLibrary.simpleMessage("没有SSH连接"),
        "noInterface": MessageLookupByLibrary.simpleMessage("没有可用的接口"),
        "noResult": MessageLookupByLibrary.simpleMessage("无结果"),
        "noSavedPrivateKey": MessageLookupByLibrary.simpleMessage("没有已保存的私钥。"),
        "noSavedSnippet": MessageLookupByLibrary.simpleMessage("没有已保存的代码片段。"),
        "noServerAvailable": MessageLookupByLibrary.simpleMessage("没有可用的服务器。"),
        "noUpdateAvailable": MessageLookupByLibrary.simpleMessage("没有可用更新"),
        "ok": MessageLookupByLibrary.simpleMessage("好"),
        "onServerDetailPage": MessageLookupByLibrary.simpleMessage("在服务器详情页"),
        "open": MessageLookupByLibrary.simpleMessage("打开"),
        "path": MessageLookupByLibrary.simpleMessage("路径"),
        "ping": MessageLookupByLibrary.simpleMessage("Ping"),
        "pingAvg": MessageLookupByLibrary.simpleMessage("平均:"),
        "pingInputIP": MessageLookupByLibrary.simpleMessage("请输入目标IP或域名"),
        "pingNoServer": MessageLookupByLibrary.simpleMessage(
            "没有服务器可用于Ping\n请在服务器tab添加服务器后再试"),
        "platformNotSupportUpdate":
            MessageLookupByLibrary.simpleMessage("当前平台不支持更新，请编译最新源码后手动安装"),
        "plzEnterHost": MessageLookupByLibrary.simpleMessage("请输入主机"),
        "plzSelectKey": MessageLookupByLibrary.simpleMessage("请选择私钥"),
        "port": MessageLookupByLibrary.simpleMessage("端口"),
        "preview": MessageLookupByLibrary.simpleMessage("预览"),
        "privateKey": MessageLookupByLibrary.simpleMessage("私钥"),
        "pwd": MessageLookupByLibrary.simpleMessage("密码"),
        "rename": MessageLookupByLibrary.simpleMessage("重命名"),
        "reportBugsOnGithubIssue": m9,
        "restore": MessageLookupByLibrary.simpleMessage("恢复"),
        "restoreSuccess":
            MessageLookupByLibrary.simpleMessage("恢复成功，需要重启App来应用更改"),
        "restoreSureWithDate": m10,
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
        "sftpDlPrepare": MessageLookupByLibrary.simpleMessage("准备连接至服务器..."),
        "sftpNoDownloadTask": MessageLookupByLibrary.simpleMessage("没有下载任务"),
        "sftpSSHConnected":
            MessageLookupByLibrary.simpleMessage("SFTP 已连接，即将开始下载..."),
        "showDistLogo": MessageLookupByLibrary.simpleMessage("显示发行版 Logo"),
        "snippet": MessageLookupByLibrary.simpleMessage("代码片段"),
        "spentTime": m11,
        "sshTip": m12,
        "start": MessageLookupByLibrary.simpleMessage("开始"),
        "stop": MessageLookupByLibrary.simpleMessage("停止"),
        "sureDelete": m13,
        "sureNoPwd": MessageLookupByLibrary.simpleMessage("确认使用无密码？"),
        "sureToDeleteServer": m14,
        "ttl": MessageLookupByLibrary.simpleMessage("缓存时间"),
        "unknown": MessageLookupByLibrary.simpleMessage("未知"),
        "unknownError": MessageLookupByLibrary.simpleMessage("未知错误"),
        "unkownConvertMode": MessageLookupByLibrary.simpleMessage("未知转换模式"),
        "update": MessageLookupByLibrary.simpleMessage("更新"),
        "updateAll": MessageLookupByLibrary.simpleMessage("更新全部"),
        "updateIntervalEqual0": MessageLookupByLibrary.simpleMessage(
            "你设置为0，服务器状态不会自动刷新。\n且不能计算CPU使用情况。"),
        "updateServerStatusInterval":
            MessageLookupByLibrary.simpleMessage("服务器状态刷新间隔"),
        "upsideDown": MessageLookupByLibrary.simpleMessage("上下交换"),
        "urlOrJson": MessageLookupByLibrary.simpleMessage("链接或JSON"),
        "user": MessageLookupByLibrary.simpleMessage("用户"),
        "versionHaveUpdate": m15,
        "versionUnknownUpdate": m16,
        "versionUpdated": m17,
        "waitConnection": MessageLookupByLibrary.simpleMessage("请等待连接建立"),
        "willTakEeffectImmediately":
            MessageLookupByLibrary.simpleMessage("更改将会立即生效")
      };
}
