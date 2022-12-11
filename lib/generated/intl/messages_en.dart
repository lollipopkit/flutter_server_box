// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(fileName) => "Download [${fileName}] to local?";

  static String m1(runningCount, stoppedCount) =>
      "${runningCount} running, ${stoppedCount} container stopped.";

  static String m2(count) => "${count} container running.";

  static String m3(percent, size) => "${percent}% of ${size}";

  static String m4(count) => "Found ${count} update";

  static String m5(code) => "request failed, status code: ${code}";

  static String m6(url) =>
      "Please make sure that docker is installed correctly, or that you are using a non-self-compiled version. If you don\'t have the above issues, please submit an issue on ${url}.";

  static String m7(myGithub) => "\nMade with ❤️ by ${myGithub}";

  static String m8(url) => "Please report bugs on ${url}";

  static String m9(date) => "Are you sure to restore from ${date} ?";

  static String m10(time) => "Spent time: ${time}";

  static String m11(name) => "Are you sure to delete [${name}]?";

  static String m12(server) => "Are you sure to delete server [${server}]?";

  static String m13(build) => "Found: v1.0.${build}, click to update";

  static String m14(build) => "Current: v1.0.${build}";

  static String m15(build) => "Current: v1.0.${build}, is up to date";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "aboutThanks": MessageLookupByLibrary.simpleMessage(
            "\nAll rights reserved.\n\nThanks to the following people who participated in the test."),
        "addAServer": MessageLookupByLibrary.simpleMessage("add a server"),
        "addPrivateKey":
            MessageLookupByLibrary.simpleMessage("Add private key"),
        "alreadyLastDir":
            MessageLookupByLibrary.simpleMessage("Already in last directory."),
        "appPrimaryColor":
            MessageLookupByLibrary.simpleMessage("App primary color"),
        "attention": MessageLookupByLibrary.simpleMessage("Attention"),
        "backDir": MessageLookupByLibrary.simpleMessage("Back"),
        "backup": MessageLookupByLibrary.simpleMessage("Backup"),
        "backupTip": MessageLookupByLibrary.simpleMessage(
            "The exported data is simply encrypted. \nPlease keep it safe.\nRestoring will not overwrite existing data (except setting)."),
        "backupVersionNotMatch": MessageLookupByLibrary.simpleMessage(
            "Backup version is not match."),
        "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "choose": MessageLookupByLibrary.simpleMessage("Choose"),
        "chooseDestination":
            MessageLookupByLibrary.simpleMessage("Choose destination"),
        "choosePrivateKey":
            MessageLookupByLibrary.simpleMessage("Choose private key"),
        "clear": MessageLookupByLibrary.simpleMessage("Clear"),
        "clickSee": MessageLookupByLibrary.simpleMessage("Click here"),
        "close": MessageLookupByLibrary.simpleMessage("Close"),
        "cmd": MessageLookupByLibrary.simpleMessage("Command"),
        "containerStatus":
            MessageLookupByLibrary.simpleMessage("Container status"),
        "convert": MessageLookupByLibrary.simpleMessage("Convert"),
        "copy": MessageLookupByLibrary.simpleMessage("Copy"),
        "copyPath": MessageLookupByLibrary.simpleMessage("Copy path"),
        "createFile": MessageLookupByLibrary.simpleMessage("Create file"),
        "createFolder": MessageLookupByLibrary.simpleMessage("Create folder"),
        "currentMode": MessageLookupByLibrary.simpleMessage("Current Mode"),
        "debug": MessageLookupByLibrary.simpleMessage("Debug"),
        "decode": MessageLookupByLibrary.simpleMessage("Decode"),
        "delete": MessageLookupByLibrary.simpleMessage("Delete"),
        "disconnected": MessageLookupByLibrary.simpleMessage("Disconnected"),
        "dl2Local": m0,
        "dockerContainerName":
            MessageLookupByLibrary.simpleMessage("Container name"),
        "dockerEditHost":
            MessageLookupByLibrary.simpleMessage("Edit DOCKER_HOST"),
        "dockerEmptyRunningItems": MessageLookupByLibrary.simpleMessage(
            "No running container. \nIt may be that the env DOCKER_HOST is not read correctly. You can found it by running `echo \$DOCKER_HOST` in terminal."),
        "dockerImage": MessageLookupByLibrary.simpleMessage("Image"),
        "dockerNotInstalled":
            MessageLookupByLibrary.simpleMessage("Docker not installed"),
        "dockerStatusRunningAndStoppedFmt": m1,
        "dockerStatusRunningFmt": m2,
        "download": MessageLookupByLibrary.simpleMessage("Download"),
        "downloadFinished":
            MessageLookupByLibrary.simpleMessage("Download finished"),
        "downloadStatus": m3,
        "edit": MessageLookupByLibrary.simpleMessage("Edit"),
        "encode": MessageLookupByLibrary.simpleMessage("Encode"),
        "error": MessageLookupByLibrary.simpleMessage("Error"),
        "exampleName": MessageLookupByLibrary.simpleMessage("Example name"),
        "experimentalFeature":
            MessageLookupByLibrary.simpleMessage("Experimental feature"),
        "export": MessageLookupByLibrary.simpleMessage("Export"),
        "extraArgs": MessageLookupByLibrary.simpleMessage("Extra args"),
        "feedback": MessageLookupByLibrary.simpleMessage("Feedback"),
        "feedbackOnGithub": MessageLookupByLibrary.simpleMessage(
            "If you have any questions, please feedback on Github."),
        "fieldMustNotEmpty": MessageLookupByLibrary.simpleMessage(
            "These fields must not be empty."),
        "files": MessageLookupByLibrary.simpleMessage("Files"),
        "foundNUpdate": m4,
        "go": MessageLookupByLibrary.simpleMessage("Go"),
        "goSftpDlPage":
            MessageLookupByLibrary.simpleMessage("Go to SFTP download page?"),
        "host": MessageLookupByLibrary.simpleMessage("Host"),
        "httpFailedWithCode": m5,
        "import": MessageLookupByLibrary.simpleMessage("Import"),
        "importAndExport":
            MessageLookupByLibrary.simpleMessage("Import and Export"),
        "inputDomainHere":
            MessageLookupByLibrary.simpleMessage("Input Domain here"),
        "install": MessageLookupByLibrary.simpleMessage("install"),
        "installDockerWithUrl": MessageLookupByLibrary.simpleMessage(
            "Please https://docs.docker.com/engine/install docker first."),
        "invalidJson": MessageLookupByLibrary.simpleMessage("Invalid JSON"),
        "invalidVersion":
            MessageLookupByLibrary.simpleMessage("Invalid version"),
        "invalidVersionHelp": m6,
        "keepForeground":
            MessageLookupByLibrary.simpleMessage("Keep app foreground!"),
        "keyAuth": MessageLookupByLibrary.simpleMessage("Key Auth"),
        "lastTry": MessageLookupByLibrary.simpleMessage("Last try!"),
        "launchPage": MessageLookupByLibrary.simpleMessage("Launch page"),
        "license": MessageLookupByLibrary.simpleMessage("License"),
        "loadingFiles":
            MessageLookupByLibrary.simpleMessage("Loading files..."),
        "loss": MessageLookupByLibrary.simpleMessage("loss"),
        "madeWithLove": m7,
        "max": MessageLookupByLibrary.simpleMessage("max"),
        "min": MessageLookupByLibrary.simpleMessage("min"),
        "ms": MessageLookupByLibrary.simpleMessage("ms"),
        "name": MessageLookupByLibrary.simpleMessage("Name"),
        "newContainer": MessageLookupByLibrary.simpleMessage("New container"),
        "noClient": MessageLookupByLibrary.simpleMessage("No client"),
        "noInterface": MessageLookupByLibrary.simpleMessage("No interface"),
        "noResult": MessageLookupByLibrary.simpleMessage("No result"),
        "noSavedPrivateKey":
            MessageLookupByLibrary.simpleMessage("No saved private keys."),
        "noSavedSnippet":
            MessageLookupByLibrary.simpleMessage("No saved snippets."),
        "noServerAvailable":
            MessageLookupByLibrary.simpleMessage("No server available."),
        "noUpdateAvailable":
            MessageLookupByLibrary.simpleMessage("No update available"),
        "ok": MessageLookupByLibrary.simpleMessage("OK"),
        "open": MessageLookupByLibrary.simpleMessage("Open"),
        "ping": MessageLookupByLibrary.simpleMessage("Ping"),
        "pingAvg": MessageLookupByLibrary.simpleMessage("Avg:"),
        "pingInputIP": MessageLookupByLibrary.simpleMessage(
            "Please input a target IP/domain."),
        "pingNoServer": MessageLookupByLibrary.simpleMessage(
            "No server to ping.\nPlease add a server in server tab."),
        "platformNotSupportUpdate": MessageLookupByLibrary.simpleMessage(
            "Current platform does not support in app update.\nPlease build from source and install it."),
        "plzEnterHost":
            MessageLookupByLibrary.simpleMessage("Please enter host."),
        "plzSelectKey":
            MessageLookupByLibrary.simpleMessage("Please select a key."),
        "port": MessageLookupByLibrary.simpleMessage("Port"),
        "preview": MessageLookupByLibrary.simpleMessage("Preview"),
        "privateKey": MessageLookupByLibrary.simpleMessage("Private Key"),
        "pwd": MessageLookupByLibrary.simpleMessage("Password"),
        "rename": MessageLookupByLibrary.simpleMessage("Rename"),
        "reportBugsOnGithubIssue": m8,
        "restore": MessageLookupByLibrary.simpleMessage("Restore"),
        "restoreSuccess": MessageLookupByLibrary.simpleMessage(
            "Restore success. Restart app to apply."),
        "restoreSureWithDate": m9,
        "result": MessageLookupByLibrary.simpleMessage("Result"),
        "run": MessageLookupByLibrary.simpleMessage("Run"),
        "save": MessageLookupByLibrary.simpleMessage("Save"),
        "second": MessageLookupByLibrary.simpleMessage("s"),
        "server": MessageLookupByLibrary.simpleMessage("Server"),
        "serverTabConnecting":
            MessageLookupByLibrary.simpleMessage("Connecting..."),
        "serverTabEmpty": MessageLookupByLibrary.simpleMessage(
            "There is no server.\nClick the fab to add one."),
        "serverTabFailed": MessageLookupByLibrary.simpleMessage("Failed"),
        "serverTabLoading": MessageLookupByLibrary.simpleMessage("Loading..."),
        "serverTabPlzSave": MessageLookupByLibrary.simpleMessage(
            "Please \'save\' this private key again."),
        "serverTabUnkown":
            MessageLookupByLibrary.simpleMessage("Unknown state"),
        "setting": MessageLookupByLibrary.simpleMessage("Setting"),
        "sftpDlPrepare":
            MessageLookupByLibrary.simpleMessage("Preparing to connect..."),
        "sftpNoDownloadTask":
            MessageLookupByLibrary.simpleMessage("No download task."),
        "sftpSSHConnected":
            MessageLookupByLibrary.simpleMessage("SFTP Connected"),
        "snippet": MessageLookupByLibrary.simpleMessage("Snippet"),
        "spentTime": m10,
        "start": MessageLookupByLibrary.simpleMessage("Start"),
        "stop": MessageLookupByLibrary.simpleMessage("Stop"),
        "sureDelete": m11,
        "sureNoPwd": MessageLookupByLibrary.simpleMessage(
            "Are you sure to use no password?"),
        "sureToDeleteServer": m12,
        "ttl": MessageLookupByLibrary.simpleMessage("ttl"),
        "unknown": MessageLookupByLibrary.simpleMessage("unknown"),
        "unknownError": MessageLookupByLibrary.simpleMessage("Unknown error"),
        "unkownConvertMode":
            MessageLookupByLibrary.simpleMessage("Unknown convert mode"),
        "update": MessageLookupByLibrary.simpleMessage("Update"),
        "updateAll": MessageLookupByLibrary.simpleMessage("Update all"),
        "updateIntervalEqual0": MessageLookupByLibrary.simpleMessage(
            "You set to 0, will not update automatically."),
        "updateServerStatusInterval": MessageLookupByLibrary.simpleMessage(
            "Server status update interval"),
        "upsideDown": MessageLookupByLibrary.simpleMessage("Upside Down"),
        "urlOrJson": MessageLookupByLibrary.simpleMessage("URL or JSON"),
        "user": MessageLookupByLibrary.simpleMessage("User"),
        "versionHaveUpdate": m13,
        "versionUnknownUpdate": m14,
        "versionUpdated": m15,
        "waitConnection": MessageLookupByLibrary.simpleMessage(
            "Please wait for the connection to be established."),
        "willTakEeffectImmediately":
            MessageLookupByLibrary.simpleMessage("Will take effect immediately")
      };
}
