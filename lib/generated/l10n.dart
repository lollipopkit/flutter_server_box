// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Server`
  String get server {
    return Intl.message(
      'Server',
      name: 'server',
      desc: '',
      args: [],
    );
  }

  /// `Convert`
  String get convert {
    return Intl.message(
      'Convert',
      name: 'convert',
      desc: '',
      args: [],
    );
  }

  /// `Ping`
  String get ping {
    return Intl.message(
      'Ping',
      name: 'ping',
      desc: '',
      args: [],
    );
  }

  /// `Debug`
  String get debug {
    return Intl.message(
      'Debug',
      name: 'debug',
      desc: '',
      args: [],
    );
  }

  /// `add a server`
  String get addAServer {
    return Intl.message(
      'add a server',
      name: 'addAServer',
      desc: '',
      args: [],
    );
  }

  /// `Setting`
  String get setting {
    return Intl.message(
      'Setting',
      name: 'setting',
      desc: '',
      args: [],
    );
  }

  /// `License`
  String get license {
    return Intl.message(
      'License',
      name: 'license',
      desc: '',
      args: [],
    );
  }

  /// `Snippet`
  String get snippet {
    return Intl.message(
      'Snippet',
      name: 'snippet',
      desc: '',
      args: [],
    );
  }

  /// `Private Key`
  String get privateKey {
    return Intl.message(
      'Private Key',
      name: 'privateKey',
      desc: '',
      args: [],
    );
  }

  /// `\nMade with ❤️ by {myGithub}`
  String madeWithLove(Object myGithub) {
    return Intl.message(
      '\nMade with ❤️ by $myGithub',
      name: 'madeWithLove',
      desc: '',
      args: [myGithub],
    );
  }

  /// `\nAll rights reserved.\n\nThanks to the following people who participated in the test.`
  String get aboutThanks {
    return Intl.message(
      '\nAll rights reserved.\n\nThanks to the following people who participated in the test.',
      name: 'aboutThanks',
      desc: '',
      args: [],
    );
  }

  /// `There is no server.\nClick the fab to add one.`
  String get serverTabEmpty {
    return Intl.message(
      'There is no server.\nClick the fab to add one.',
      name: 'serverTabEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Loading...`
  String get serverTabLoading {
    return Intl.message(
      'Loading...',
      name: 'serverTabLoading',
      desc: '',
      args: [],
    );
  }

  /// `Please 'save' this private key again.`
  String get serverTabPlzSave {
    return Intl.message(
      'Please \'save\' this private key again.',
      name: 'serverTabPlzSave',
      desc: '',
      args: [],
    );
  }

  /// `Failed`
  String get serverTabFailed {
    return Intl.message(
      'Failed',
      name: 'serverTabFailed',
      desc: '',
      args: [],
    );
  }

  /// `Unknown state`
  String get serverTabUnkown {
    return Intl.message(
      'Unknown state',
      name: 'serverTabUnkown',
      desc: '',
      args: [],
    );
  }

  /// `Connecting...`
  String get serverTabConnecting {
    return Intl.message(
      'Connecting...',
      name: 'serverTabConnecting',
      desc: '',
      args: [],
    );
  }

  /// `Decode`
  String get decode {
    return Intl.message(
      'Decode',
      name: 'decode',
      desc: '',
      args: [],
    );
  }

  /// `Encode`
  String get encode {
    return Intl.message(
      'Encode',
      name: 'encode',
      desc: '',
      args: [],
    );
  }

  /// `Current Mode`
  String get currentMode {
    return Intl.message(
      'Current Mode',
      name: 'currentMode',
      desc: '',
      args: [],
    );
  }

  /// `Unknown convert mode`
  String get unkownConvertMode {
    return Intl.message(
      'Unknown convert mode',
      name: 'unkownConvertMode',
      desc: '',
      args: [],
    );
  }

  /// `Copy`
  String get copy {
    return Intl.message(
      'Copy',
      name: 'copy',
      desc: '',
      args: [],
    );
  }

  /// `Upside Down`
  String get upsideDown {
    return Intl.message(
      'Upside Down',
      name: 'upsideDown',
      desc: '',
      args: [],
    );
  }

  /// `Avg:`
  String get pingAvg {
    return Intl.message(
      'Avg:',
      name: 'pingAvg',
      desc: '',
      args: [],
    );
  }

  /// `unknown`
  String get unknown {
    return Intl.message(
      'unknown',
      name: 'unknown',
      desc: '',
      args: [],
    );
  }

  /// `min`
  String get min {
    return Intl.message(
      'min',
      name: 'min',
      desc: '',
      args: [],
    );
  }

  /// `max`
  String get max {
    return Intl.message(
      'max',
      name: 'max',
      desc: '',
      args: [],
    );
  }

  /// `ms`
  String get ms {
    return Intl.message(
      'ms',
      name: 'ms',
      desc: '',
      args: [],
    );
  }

  /// `ttl`
  String get ttl {
    return Intl.message(
      'ttl',
      name: 'ttl',
      desc: '',
      args: [],
    );
  }

  /// `loss`
  String get loss {
    return Intl.message(
      'loss',
      name: 'loss',
      desc: '',
      args: [],
    );
  }

  /// `No result`
  String get noResult {
    return Intl.message(
      'No result',
      name: 'noResult',
      desc: '',
      args: [],
    );
  }

  /// `Please input a target IP/domain.`
  String get pingInputIP {
    return Intl.message(
      'Please input a target IP/domain.',
      name: 'pingInputIP',
      desc: '',
      args: [],
    );
  }

  /// `Clear`
  String get clear {
    return Intl.message(
      'Clear',
      name: 'clear',
      desc: '',
      args: [],
    );
  }

  /// `Start`
  String get start {
    return Intl.message(
      'Start',
      name: 'start',
      desc: '',
      args: [],
    );
  }

  /// `App primary color`
  String get appPrimaryColor {
    return Intl.message(
      'App primary color',
      name: 'appPrimaryColor',
      desc: '',
      args: [],
    );
  }

  /// `Server status update interval`
  String get updateServerStatusInterval {
    return Intl.message(
      'Server status update interval',
      name: 'updateServerStatusInterval',
      desc: '',
      args: [],
    );
  }

  /// `Will take effect immediately`
  String get willTakEeffectImmediately {
    return Intl.message(
      'Will take effect immediately',
      name: 'willTakEeffectImmediately',
      desc: '',
      args: [],
    );
  }

  /// `Launch page`
  String get launchPage {
    return Intl.message(
      'Launch page',
      name: 'launchPage',
      desc: '',
      args: [],
    );
  }

  /// `Current: v1.0.{build}, is up to date`
  String versionUpdated(Object build) {
    return Intl.message(
      'Current: v1.0.$build, is up to date',
      name: 'versionUpdated',
      desc: '',
      args: [build],
    );
  }

  /// `Current: v1.0.{build}`
  String versionUnknownUpdate(Object build) {
    return Intl.message(
      'Current: v1.0.$build',
      name: 'versionUnknownUpdate',
      desc: '',
      args: [build],
    );
  }

  /// `Found: v1.0.{build}, click to update`
  String versionHaveUpdate(Object build) {
    return Intl.message(
      'Found: v1.0.$build, click to update',
      name: 'versionHaveUpdate',
      desc: '',
      args: [build],
    );
  }

  /// `s`
  String get second {
    return Intl.message(
      's',
      name: 'second',
      desc: '',
      args: [],
    );
  }

  /// `You set to 0, will not update automatically.\nCan't calculate CPU status.`
  String get updateIntervalEqual0 {
    return Intl.message(
      'You set to 0, will not update automatically.\nCan\'t calculate CPU status.',
      name: 'updateIntervalEqual0',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get edit {
    return Intl.message(
      'Edit',
      name: 'edit',
      desc: '',
      args: [],
    );
  }

  /// `No saved private keys.`
  String get noSavedPrivateKey {
    return Intl.message(
      'No saved private keys.',
      name: 'noSavedPrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get name {
    return Intl.message(
      'Name',
      name: 'name',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get pwd {
    return Intl.message(
      'Password',
      name: 'pwd',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get save {
    return Intl.message(
      'Save',
      name: 'save',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: '',
      args: [],
    );
  }

  /// `These fields must not be empty.`
  String get fieldMustNotEmpty {
    return Intl.message(
      'These fields must not be empty.',
      name: 'fieldMustNotEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Import and Export`
  String get importAndExport {
    return Intl.message(
      'Import and Export',
      name: 'importAndExport',
      desc: '',
      args: [],
    );
  }

  /// `Choose`
  String get choose {
    return Intl.message(
      'Choose',
      name: 'choose',
      desc: '',
      args: [],
    );
  }

  /// `Import`
  String get import {
    return Intl.message(
      'Import',
      name: 'import',
      desc: '',
      args: [],
    );
  }

  /// `Export`
  String get export {
    return Intl.message(
      'Export',
      name: 'export',
      desc: '',
      args: [],
    );
  }

  /// `OK`
  String get ok {
    return Intl.message(
      'OK',
      name: 'ok',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: '',
      args: [],
    );
  }

  /// `URL or JSON`
  String get urlOrJson {
    return Intl.message(
      'URL or JSON',
      name: 'urlOrJson',
      desc: '',
      args: [],
    );
  }

  /// `Go`
  String get go {
    return Intl.message(
      'Go',
      name: 'go',
      desc: '',
      args: [],
    );
  }

  /// `request failed, status code: {code}`
  String httpFailedWithCode(Object code) {
    return Intl.message(
      'request failed, status code: $code',
      name: 'httpFailedWithCode',
      desc: '',
      args: [code],
    );
  }

  /// `Run`
  String get run {
    return Intl.message(
      'Run',
      name: 'run',
      desc: '',
      args: [],
    );
  }

  /// `No saved snippets.`
  String get noSavedSnippet {
    return Intl.message(
      'No saved snippets.',
      name: 'noSavedSnippet',
      desc: '',
      args: [],
    );
  }

  /// `Choose destination`
  String get chooseDestination {
    return Intl.message(
      'Choose destination',
      name: 'chooseDestination',
      desc: '',
      args: [],
    );
  }

  /// `No server available.`
  String get noServerAvailable {
    return Intl.message(
      'No server available.',
      name: 'noServerAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Result`
  String get result {
    return Intl.message(
      'Result',
      name: 'result',
      desc: '',
      args: [],
    );
  }

  /// `Close`
  String get close {
    return Intl.message(
      'Close',
      name: 'close',
      desc: '',
      args: [],
    );
  }

  /// `Attention`
  String get attention {
    return Intl.message(
      'Attention',
      name: 'attention',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to delete server [{server}]?`
  String sureToDeleteServer(Object server) {
    return Intl.message(
      'Are you sure to delete server [$server]?',
      name: 'sureToDeleteServer',
      desc: '',
      args: [server],
    );
  }

  /// `Host`
  String get host {
    return Intl.message(
      'Host',
      name: 'host',
      desc: '',
      args: [],
    );
  }

  /// `Port`
  String get port {
    return Intl.message(
      'Port',
      name: 'port',
      desc: '',
      args: [],
    );
  }

  /// `User`
  String get user {
    return Intl.message(
      'User',
      name: 'user',
      desc: '',
      args: [],
    );
  }

  /// `Key Auth`
  String get keyAuth {
    return Intl.message(
      'Key Auth',
      name: 'keyAuth',
      desc: '',
      args: [],
    );
  }

  /// `Add private key`
  String get addPrivateKey {
    return Intl.message(
      'Add private key',
      name: 'addPrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `Choose private key`
  String get choosePrivateKey {
    return Intl.message(
      'Choose private key',
      name: 'choosePrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `Please enter host.`
  String get plzEnterHost {
    return Intl.message(
      'Please enter host.',
      name: 'plzEnterHost',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to use no password?`
  String get sureNoPwd {
    return Intl.message(
      'Are you sure to use no password?',
      name: 'sureNoPwd',
      desc: '',
      args: [],
    );
  }

  /// `Please select a key.`
  String get plzSelectKey {
    return Intl.message(
      'Please select a key.',
      name: 'plzSelectKey',
      desc: '',
      args: [],
    );
  }

  /// `Example name`
  String get exampleName {
    return Intl.message(
      'Example name',
      name: 'exampleName',
      desc: '',
      args: [],
    );
  }

  /// `Stop`
  String get stop {
    return Intl.message(
      'Stop',
      name: 'stop',
      desc: '',
      args: [],
    );
  }

  /// `Download`
  String get download {
    return Intl.message(
      'Download',
      name: 'download',
      desc: '',
      args: [],
    );
  }

  /// `Copy path`
  String get copyPath {
    return Intl.message(
      'Copy path',
      name: 'copyPath',
      desc: '',
      args: [],
    );
  }

  /// `Keep app foreground!`
  String get keepForeground {
    return Intl.message(
      'Keep app foreground!',
      name: 'keepForeground',
      desc: '',
      args: [],
    );
  }

  /// `Download finished`
  String get downloadFinished {
    return Intl.message(
      'Download finished',
      name: 'downloadFinished',
      desc: '',
      args: [],
    );
  }

  /// `{percent}% of {size}`
  String downloadStatus(Object percent, Object size) {
    return Intl.message(
      '$percent% of $size',
      name: 'downloadStatus',
      desc: '',
      args: [percent, size],
    );
  }

  /// `Preparing to connect...`
  String get sftpDlPrepare {
    return Intl.message(
      'Preparing to connect...',
      name: 'sftpDlPrepare',
      desc: '',
      args: [],
    );
  }

  /// `SFTP Connected`
  String get sftpSSHConnected {
    return Intl.message(
      'SFTP Connected',
      name: 'sftpSSHConnected',
      desc: '',
      args: [],
    );
  }

  /// `Spent time: {time}`
  String spentTime(Object time) {
    return Intl.message(
      'Spent time: $time',
      name: 'spentTime',
      desc: '',
      args: [time],
    );
  }

  /// `Back`
  String get backDir {
    return Intl.message(
      'Back',
      name: 'backDir',
      desc: '',
      args: [],
    );
  }

  /// `Already in last directory.`
  String get alreadyLastDir {
    return Intl.message(
      'Already in last directory.',
      name: 'alreadyLastDir',
      desc: '',
      args: [],
    );
  }

  /// `Open`
  String get open {
    return Intl.message(
      'Open',
      name: 'open',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to delete [{name}]?`
  String sureDelete(Object name) {
    return Intl.message(
      'Are you sure to delete [$name]?',
      name: 'sureDelete',
      desc: '',
      args: [name],
    );
  }

  /// `Container status`
  String get containerStatus {
    return Intl.message(
      'Container status',
      name: 'containerStatus',
      desc: '',
      args: [],
    );
  }

  /// `No client`
  String get noClient {
    return Intl.message(
      'No client',
      name: 'noClient',
      desc: '',
      args: [],
    );
  }

  /// `Please https://docs.docker.com/engine/install docker first.`
  String get installDockerWithUrl {
    return Intl.message(
      'Please https://docs.docker.com/engine/install docker first.',
      name: 'installDockerWithUrl',
      desc: '',
      args: [],
    );
  }

  /// `Please wait for the connection to be established.`
  String get waitConnection {
    return Intl.message(
      'Please wait for the connection to be established.',
      name: 'waitConnection',
      desc: '',
      args: [],
    );
  }

  /// `Unknown error`
  String get unknownError {
    return Intl.message(
      'Unknown error',
      name: 'unknownError',
      desc: '',
      args: [],
    );
  }

  /// `{count} container running.`
  String dockerStatusRunningFmt(Object count) {
    return Intl.message(
      '$count container running.',
      name: 'dockerStatusRunningFmt',
      desc: '',
      args: [count],
    );
  }

  /// `{runningCount} running, {stoppedCount} container stopped.`
  String dockerStatusRunningAndStoppedFmt(
      Object runningCount, Object stoppedCount) {
    return Intl.message(
      '$runningCount running, $stoppedCount container stopped.',
      name: 'dockerStatusRunningAndStoppedFmt',
      desc: '',
      args: [runningCount, stoppedCount],
    );
  }

  /// `install`
  String get install {
    return Intl.message(
      'install',
      name: 'install',
      desc: '',
      args: [],
    );
  }

  /// `Loading files...`
  String get loadingFiles {
    return Intl.message(
      'Loading files...',
      name: 'loadingFiles',
      desc: '',
      args: [],
    );
  }

  /// `No download task.`
  String get sftpNoDownloadTask {
    return Intl.message(
      'No download task.',
      name: 'sftpNoDownloadTask',
      desc: '',
      args: [],
    );
  }

  /// `Create folder`
  String get createFolder {
    return Intl.message(
      'Create folder',
      name: 'createFolder',
      desc: '',
      args: [],
    );
  }

  /// `Create file`
  String get createFile {
    return Intl.message(
      'Create file',
      name: 'createFile',
      desc: '',
      args: [],
    );
  }

  /// `Rename`
  String get rename {
    return Intl.message(
      'Rename',
      name: 'rename',
      desc: '',
      args: [],
    );
  }

  /// `Download [{fileName}] to local?`
  String dl2Local(Object fileName) {
    return Intl.message(
      'Download [$fileName] to local?',
      name: 'dl2Local',
      desc: '',
      args: [fileName],
    );
  }

  /// `Error`
  String get error {
    return Intl.message(
      'Error',
      name: 'error',
      desc: '',
      args: [],
    );
  }

  /// `Disconnected`
  String get disconnected {
    return Intl.message(
      'Disconnected',
      name: 'disconnected',
      desc: '',
      args: [],
    );
  }

  /// `Files`
  String get files {
    return Intl.message(
      'Files',
      name: 'files',
      desc: '',
      args: [],
    );
  }

  /// `Experimental feature`
  String get experimentalFeature {
    return Intl.message(
      'Experimental feature',
      name: 'experimentalFeature',
      desc: '',
      args: [],
    );
  }

  /// `Please report bugs on {url}`
  String reportBugsOnGithubIssue(Object url) {
    return Intl.message(
      'Please report bugs on $url',
      name: 'reportBugsOnGithubIssue',
      desc: '',
      args: [url],
    );
  }

  /// `No update available`
  String get noUpdateAvailable {
    return Intl.message(
      'No update available',
      name: 'noUpdateAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Found {count} update`
  String foundNUpdate(Object count) {
    return Intl.message(
      'Found $count update',
      name: 'foundNUpdate',
      desc: '',
      args: [count],
    );
  }

  /// `Update all`
  String get updateAll {
    return Intl.message(
      'Update all',
      name: 'updateAll',
      desc: '',
      args: [],
    );
  }

  /// `Current platform does not support in app update.\nPlease build from source and install it.`
  String get platformNotSupportUpdate {
    return Intl.message(
      'Current platform does not support in app update.\nPlease build from source and install it.',
      name: 'platformNotSupportUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Please make sure that docker is installed correctly, or that you are using a non-self-compiled version. If you don't have the above issues, please submit an issue on {url}.`
  String invalidVersionHelp(Object url) {
    return Intl.message(
      'Please make sure that docker is installed correctly, or that you are using a non-self-compiled version. If you don\'t have the above issues, please submit an issue on $url.',
      name: 'invalidVersionHelp',
      desc: '',
      args: [url],
    );
  }

  /// `No interface`
  String get noInterface {
    return Intl.message(
      'No interface',
      name: 'noInterface',
      desc: '',
      args: [],
    );
  }

  /// `Last try!`
  String get lastTry {
    return Intl.message(
      'Last try!',
      name: 'lastTry',
      desc: '',
      args: [],
    );
  }

  /// `No server to ping.\nPlease add a server in server tab.`
  String get pingNoServer {
    return Intl.message(
      'No server to ping.\nPlease add a server in server tab.',
      name: 'pingNoServer',
      desc: '',
      args: [],
    );
  }

  /// `The exported data is simply encrypted. \nPlease keep it safe.\nRestoring will not overwrite existing data (except setting).`
  String get backupTip {
    return Intl.message(
      'The exported data is simply encrypted. \nPlease keep it safe.\nRestoring will not overwrite existing data (except setting).',
      name: 'backupTip',
      desc: '',
      args: [],
    );
  }

  /// `Backup`
  String get backup {
    return Intl.message(
      'Backup',
      name: 'backup',
      desc: '',
      args: [],
    );
  }

  /// `Restore`
  String get restore {
    return Intl.message(
      'Restore',
      name: 'restore',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure to restore from {date} ?`
  String restoreSureWithDate(Object date) {
    return Intl.message(
      'Are you sure to restore from $date ?',
      name: 'restoreSureWithDate',
      desc: '',
      args: [date],
    );
  }

  /// `Backup version is not match.`
  String get backupVersionNotMatch {
    return Intl.message(
      'Backup version is not match.',
      name: 'backupVersionNotMatch',
      desc: '',
      args: [],
    );
  }

  /// `Invalid JSON`
  String get invalidJson {
    return Intl.message(
      'Invalid JSON',
      name: 'invalidJson',
      desc: '',
      args: [],
    );
  }

  /// `Restore success. Restart app to apply.`
  String get restoreSuccess {
    return Intl.message(
      'Restore success. Restart app to apply.',
      name: 'restoreSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Click here`
  String get clickSee {
    return Intl.message(
      'Click here',
      name: 'clickSee',
      desc: '',
      args: [],
    );
  }

  /// `Feedback`
  String get feedback {
    return Intl.message(
      'Feedback',
      name: 'feedback',
      desc: '',
      args: [],
    );
  }

  /// `If you have any questions, please feedback on Github.`
  String get feedbackOnGithub {
    return Intl.message(
      'If you have any questions, please feedback on Github.',
      name: 'feedbackOnGithub',
      desc: '',
      args: [],
    );
  }

  /// `Update`
  String get update {
    return Intl.message(
      'Update',
      name: 'update',
      desc: '',
      args: [],
    );
  }

  /// `Input Domain here`
  String get inputDomainHere {
    return Intl.message(
      'Input Domain here',
      name: 'inputDomainHere',
      desc: '',
      args: [],
    );
  }

  /// `Docker not installed`
  String get dockerNotInstalled {
    return Intl.message(
      'Docker not installed',
      name: 'dockerNotInstalled',
      desc: '',
      args: [],
    );
  }

  /// `Invalid version`
  String get invalidVersion {
    return Intl.message(
      'Invalid version',
      name: 'invalidVersion',
      desc: '',
      args: [],
    );
  }

  /// `Command`
  String get cmd {
    return Intl.message(
      'Command',
      name: 'cmd',
      desc: '',
      args: [],
    );
  }

  /// `No running container. \nIt may be that the env DOCKER_HOST is not read correctly. You can found it by running 'echo $DOCKER_HOST' in terminal.`
  String get dockerEmptyRunningItems {
    return Intl.message(
      'No running container. \nIt may be that the env DOCKER_HOST is not read correctly. You can found it by running `echo \$DOCKER_HOST` in terminal.',
      name: 'dockerEmptyRunningItems',
      desc: '',
      args: [],
    );
  }

  /// `Edit DOCKER_HOST`
  String get dockerEditHost {
    return Intl.message(
      'Edit DOCKER_HOST',
      name: 'dockerEditHost',
      desc: '',
      args: [],
    );
  }

  /// `New container`
  String get newContainer {
    return Intl.message(
      'New container',
      name: 'newContainer',
      desc: '',
      args: [],
    );
  }

  /// `Image`
  String get dockerImage {
    return Intl.message(
      'Image',
      name: 'dockerImage',
      desc: '',
      args: [],
    );
  }

  /// `Container name`
  String get dockerContainerName {
    return Intl.message(
      'Container name',
      name: 'dockerContainerName',
      desc: '',
      args: [],
    );
  }

  /// `Extra args`
  String get extraArgs {
    return Intl.message(
      'Extra args',
      name: 'extraArgs',
      desc: '',
      args: [],
    );
  }

  /// `Preview`
  String get preview {
    return Intl.message(
      'Preview',
      name: 'preview',
      desc: '',
      args: [],
    );
  }

  /// `Is busy now`
  String get isBusy {
    return Intl.message(
      'Is busy now',
      name: 'isBusy',
      desc: '',
      args: [],
    );
  }

  /// `Images list`
  String get imagesList {
    return Intl.message(
      'Images list',
      name: 'imagesList',
      desc: '',
      args: [],
    );
  }

  /// `{count} images`
  String dockerImagesFmt(Object count) {
    return Intl.message(
      '$count images',
      name: 'dockerImagesFmt',
      desc: '',
      args: [count],
    );
  }

  /// `Path`
  String get path {
    return Intl.message(
      'Path',
      name: 'path',
      desc: '',
      args: [],
    );
  }

  /// `Go to`
  String get goto {
    return Intl.message(
      'Go to',
      name: 'goto',
      desc: '',
      args: [],
    );
  }

  /// `Show distribution logo`
  String get showDistLogo {
    return Intl.message(
      'Show distribution logo',
      name: 'showDistLogo',
      desc: '',
      args: [],
    );
  }

  /// `On server detail page`
  String get onServerDetailPage {
    return Intl.message(
      'On server detail page',
      name: 'onServerDetailPage',
      desc: '',
      args: [],
    );
  }

  /// `Add one`
  String get addOne {
    return Intl.message(
      'Add one',
      name: 'addOne',
      desc: '',
      args: [],
    );
  }

  /// `This function is now in the experimental stage. \nPlease report bugs on {url} or join our development.`
  String sshTip(Object url) {
    return Intl.message(
      'This function is now in the experimental stage. \nPlease report bugs on $url or join our development.',
      name: 'sshTip',
      desc: '',
      args: [url],
    );
  }

  /// `Update: v1.0.{newest}`
  String updateTip(Object newest) {
    return Intl.message(
      'Update: v1.0.$newest',
      name: 'updateTip',
      desc: '',
      args: [newest],
    );
  }

  /// `Current version is too low, please update to v1.0.{newest}`
  String updateTipTooLow(Object newest) {
    return Intl.message(
      'Current version is too low, please update to v1.0.$newest',
      name: 'updateTipTooLow',
      desc: '',
      args: [newest],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
