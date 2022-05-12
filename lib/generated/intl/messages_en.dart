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

  static String m0(rainSunMeGithub) =>
      "\nThanks ${rainSunMeGithub} for participating in the test.\n\nAll rights reserved.";

  static String m1(fileName) => "Download [${fileName}] to local?";

  static String m2(runningCount, stoppedCount) =>
      "${runningCount} running, ${stoppedCount} container stopped.";

  static String m3(count) => "${count} container running.";

  static String m4(percent, size) => "${percent}% of ${size}";

  static String m5(count) => "Found ${count} update";

  static String m6(code) => "request failed, status code: ${code}";

  static String m7(url) =>
      "Please make sure that docker is installed correctly, or that you are using a non-self-compiled version. If you don\'t have the above issues, please submit an issue on ${url}.";

  static String m8(myGithub) => "\nMade with ❤️ by ${myGithub}";

  static String m9(user) => "Password for ${user}";

  static String m10(url) => "Please report bugs on ${url}";

  static String m11(time) => "Spent time: ${time}";

  static String m12(name) => "Are you sure to delete [${name}]?";

  static String m13(server) => "Are you sure to delete server [${server}]?";

  static String m14(build) => "Found: v1.0.${build}, click to update";

  static String m15(build) => "Current: v1.0.${build}";

  static String m16(build) => "Current: v1.0.${build}, is up to date";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "aboutThanks": m0,
        "addAServer": MessageLookupByLibrary.simpleMessage("add a server"),
        "addPrivateKey":
            MessageLookupByLibrary.simpleMessage("Add private key"),
        "alreadyLastDir":
            MessageLookupByLibrary.simpleMessage("Already in last directory."),
        "appPrimaryColor":
            MessageLookupByLibrary.simpleMessage("App primary color"),
        "attention": MessageLookupByLibrary.simpleMessage("Attention"),
        "backDir": MessageLookupByLibrary.simpleMessage("Back"),
        "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "choose": MessageLookupByLibrary.simpleMessage("Choose"),
        "chooseDestination":
            MessageLookupByLibrary.simpleMessage("Choose destination"),
        "choosePrivateKey":
            MessageLookupByLibrary.simpleMessage("Choose private key"),
        "clear": MessageLookupByLibrary.simpleMessage("Clear"),
        "close": MessageLookupByLibrary.simpleMessage("Close"),
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
        "dl2Local": m1,
        "dockerStatusRunningAndStoppedFmt": m2,
        "dockerStatusRunningFmt": m3,
        "download": MessageLookupByLibrary.simpleMessage("Download"),
        "downloadFinished":
            MessageLookupByLibrary.simpleMessage("Download finished"),
        "downloadStatus": m4,
        "edit": MessageLookupByLibrary.simpleMessage("Edit"),
        "encode": MessageLookupByLibrary.simpleMessage("Encode"),
        "error": MessageLookupByLibrary.simpleMessage("Error"),
        "exampleName": MessageLookupByLibrary.simpleMessage("Example name"),
        "experimentalFeature":
            MessageLookupByLibrary.simpleMessage("Experimental feature"),
        "export": MessageLookupByLibrary.simpleMessage("Export"),
        "fieldMustNotEmpty": MessageLookupByLibrary.simpleMessage(
            "These fields must not be empty."),
        "files": MessageLookupByLibrary.simpleMessage("Files"),
        "foundNUpdate": m5,
        "go": MessageLookupByLibrary.simpleMessage("Go"),
        "goSftpDlPage":
            MessageLookupByLibrary.simpleMessage("Go to SFTP download page?"),
        "host": MessageLookupByLibrary.simpleMessage("Host"),
        "httpFailedWithCode": m6,
        "import": MessageLookupByLibrary.simpleMessage("Import"),
        "importAndExport":
            MessageLookupByLibrary.simpleMessage("Import and Export"),
        "install": MessageLookupByLibrary.simpleMessage("install"),
        "installDockerWithUrl": MessageLookupByLibrary.simpleMessage(
            "Please https://docs.docker.com/engine/install docker first."),
        "invalidVersionHelp": m7,
        "keepForeground":
            MessageLookupByLibrary.simpleMessage("Keep app foreground!"),
        "keyAuth": MessageLookupByLibrary.simpleMessage("Key Auth"),
        "launchPage": MessageLookupByLibrary.simpleMessage("Launch page"),
        "license": MessageLookupByLibrary.simpleMessage("License"),
        "loadingFiles":
            MessageLookupByLibrary.simpleMessage("Loading files..."),
        "loss": MessageLookupByLibrary.simpleMessage("Loss"),
        "madeWithLove": m8,
        "max": MessageLookupByLibrary.simpleMessage("max"),
        "min": MessageLookupByLibrary.simpleMessage("min"),
        "ms": MessageLookupByLibrary.simpleMessage("ms"),
        "name": MessageLookupByLibrary.simpleMessage("Name"),
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
        "platformNotSupportUpdate": MessageLookupByLibrary.simpleMessage(
            "Current platform does not support in app update.\nPlease build from source and install it."),
        "plzEnterHost":
            MessageLookupByLibrary.simpleMessage("Please enter host."),
        "plzEnterPwd":
            MessageLookupByLibrary.simpleMessage("Please enter password."),
        "plzSelectKey":
            MessageLookupByLibrary.simpleMessage("Please select a key."),
        "port": MessageLookupByLibrary.simpleMessage("Port"),
        "privateKey": MessageLookupByLibrary.simpleMessage("Private Key"),
        "pwd": MessageLookupByLibrary.simpleMessage("Password"),
        "pwdForUser": m9,
        "rename": MessageLookupByLibrary.simpleMessage("Rename"),
        "reportBugsOnGithubIssue": m10,
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
        "spentTime": m11,
        "start": MessageLookupByLibrary.simpleMessage("Start"),
        "stop": MessageLookupByLibrary.simpleMessage("Stop"),
        "sureDelete": m12,
        "sureToDeleteServer": m13,
        "ttl": MessageLookupByLibrary.simpleMessage("TTL"),
        "unknown": MessageLookupByLibrary.simpleMessage("unknown"),
        "unknownError": MessageLookupByLibrary.simpleMessage("Unknown error"),
        "unkownConvertMode":
            MessageLookupByLibrary.simpleMessage("Unknown convert mode"),
        "updateAll": MessageLookupByLibrary.simpleMessage("Update all"),
        "updateIntervalEqual0": MessageLookupByLibrary.simpleMessage(
            "You set to 0, will not update automatically.\nYou can pull to refresh manually."),
        "updateServerStatusInterval": MessageLookupByLibrary.simpleMessage(
            "Server status update interval"),
        "upsideDown": MessageLookupByLibrary.simpleMessage("Upside Down"),
        "urlOrJson": MessageLookupByLibrary.simpleMessage("URL or JSON"),
        "user": MessageLookupByLibrary.simpleMessage("User"),
        "versionHaveUpdate": m14,
        "versionUnknownUpdate": m15,
        "versionUpdated": m16,
        "waitConnection": MessageLookupByLibrary.simpleMessage(
            "Please wait for the connection to be established."),
        "willTakEeffectImmediately":
            MessageLookupByLibrary.simpleMessage("Will take effect immediately")
      };
}
