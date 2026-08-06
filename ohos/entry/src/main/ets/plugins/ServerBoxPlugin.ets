/*
* Copyright (c) 2026. All rights reserved.
* Native method channel implementations for the url_launcher / share_plus / file_picker
* packages used by the ServerBox app on HarmonyOS.
*/
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import {
  AbilityPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import MethodChannel, { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';

const TAG: string = "ServerBoxPlugin";

const CHANNEL_URL_LAUNCHER: string = "plugins.flutter.io/url_launcher";
const CHANNEL_SHARE: string = "dev.fluttercommunity.plus/share";
const CHANNEL_FILE_PICKER: string = "miguelruivo.flutter.plugins.filepicker";
const SHARE_UNAVAILABLE: string = "dev.fluttercommunity.plus/share/unavailable";

export default class ServerBoxPlugin implements FlutterPlugin, AbilityAware {
  private pluginBinding: FlutterPluginBinding | null = null;
  private context: common.UIAbilityContext | null = null;

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = binding;
    this.setupChannels();
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
    Log.i(TAG, "onAttachedToAbility");
  }

  onDetachedFromAbility(): void {
    this.context = null;
  }

  private setupChannels(): void {
    if (this.pluginBinding == null) {
      return;
    }
    const messenger = this.pluginBinding.getBinaryMessenger();
    const urlChannel = new MethodChannel(messenger, CHANNEL_URL_LAUNCHER);
    const shareChannel = new MethodChannel(messenger, CHANNEL_SHARE);
    const fileChannel = new MethodChannel(messenger, CHANNEL_FILE_PICKER);
    urlChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.onUrlLauncherMethod(call, result);
      }
    });
    shareChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.onShareMethod(call, result);
      }
    });
    fileChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.onFilePickerMethod(call, result);
      }
    });
  }

  // ---------------- url_launcher ----------------

  private onUrlLauncherMethod(call: MethodCall, result: MethodResult): void {
    if (call.method === 'launch') {
      const url = call.argument('url') as string | null;
      if (url == null || url.length === 0) {
        result.error('launch_error', 'url is empty', null);
        return;
      }
      this.doLaunch(url, result);
    } else if (call.method === 'canLaunch') {
      result.success(true);
    } else {
      result.notImplemented();
    }
  }

  private async doLaunch(url: string, result: MethodResult): Promise<void> {
    try {
      await this.launchUrl(url);
      result.success(true);
    } catch (e) {
      const err = e as BusinessError;
      Log.e(TAG, "launch failed for " + url + " : " + err.message);
      result.error('ACTIVITY_NOT_FOUND', err.message, null);
    }
  }

  private async launchUrl(url: string): Promise<void> {
    const ctx = this.context;
    if (ctx == null) {
      throw new Error('ability context is null');
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url
    };
    await ctx.startAbility(want);
  }

  // ---------------- share_plus ----------------

  private onShareMethod(call: MethodCall, result: MethodResult): void {
    if (call.method === 'shareFiles') {
      this.doShareFiles(call, result);
    } else if (call.method === 'share' || call.method === 'shareUri') {
      this.doShareText(call, result);
    } else {
      result.notImplemented();
    }
  }

  private async doShareFiles(call: MethodCall, result: MethodResult): Promise<void> {
    const ctx = this.context;
    if (ctx == null) {
      result.error('share_error', 'ability context is null', null);
      return;
    }
    const paths = call.argument('paths') as Array<string> | null;
    if (paths == null || paths.length === 0) {
      result.success(SHARE_UNAVAILABLE);
      return;
    }
    try {
      const records: Array<systemShare.SharedRecord> = new Array<systemShare.SharedRecord>();
      for (const p of paths) {
        const path = p as string;
        const record: systemShare.SharedRecord = {
          utd: 'general.file',
          uri: fileUri.getUriFromPath(path),
          title: this.nameFromPath(path)
        };
        records.push(record);
      }
      const data = new systemShare.SharedData(records[0]);
      for (let i = 1; i < records.length; i++) {
        data.addRecord(records[i]);
      }
      const options: systemShare.ShareControllerOptions = {
        selectionMode: records.length > 1 ? systemShare.SelectionMode.BATCH : systemShare.SelectionMode.SINGLE
      };
      await new systemShare.ShareController(data).show(ctx, options);
      result.success('success');
    } catch (e) {
      const err = e as BusinessError;
      Log.e(TAG, "shareFiles failed: " + err.message);
      result.error('share_error', err.message, null);
    }
  }

  private async doShareText(call: MethodCall, result: MethodResult): Promise<void> {
    const ctx = this.context;
    if (ctx == null) {
      result.error('share_error', 'ability context is null', null);
      return;
    }
    const text = call.argument('text') as string | null;
    if (text == null || text.length === 0) {
      result.success(SHARE_UNAVAILABLE);
      return;
    }
    try {
      const record: systemShare.SharedRecord = {
        utd: 'general.plain-text',
        content: text
      };
      const data = new systemShare.SharedData(record);
      const options: systemShare.ShareControllerOptions = {
        selectionMode: systemShare.SelectionMode.SINGLE
      };
      await new systemShare.ShareController(data).show(ctx, options);
      result.success('success');
    } catch (e) {
      const err = e as BusinessError;
      Log.e(TAG, "shareText failed: " + err.message);
      result.error('share_error', err.message, null);
    }
  }

  // ---------------- file_picker ----------------

  private onFilePickerMethod(call: MethodCall, result: MethodResult): void {
    if (call.method === 'clear') {
      result.success(true);
      return;
    }
    this.doPickDocument(call, result);
  }

  private async doPickDocument(call: MethodCall, result: MethodResult): Promise<void> {
    const ctx = this.context;
    if (ctx == null) {
      result.error('file_picker_error', 'ability context is null', null);
      return;
    }
    const allowMultiple = (call.argument('allowMultipleSelection') as boolean | null) ?? false;
    const extensions = call.argument('allowedExtensions') as Array<string> | null;
    try {
      const option = new picker.DocumentSelectOptions();
      option.maxSelectNumber = allowMultiple ? 5 : 1;
      if (extensions != null && extensions.length > 0) {
        const suffixFilters: Array<string> = new Array<string>();
        for (const ext of extensions) {
          let suffix = ext as string;
          if (suffix.length > 0 && suffix[0] !== '.') {
            suffix = '.' + suffix;
          }
          suffixFilters.push(suffix);
        }
        option.fileSuffixFilters = suffixFilters;
      }
      const uris: Array<string> = await new picker.DocumentViewPicker(ctx).select(option);
      if (uris.length === 0) {
        result.success(null);
        return;
      }
      result.success(this.copyToSandbox(ctx, uris));
    } catch (e) {
      const err = e as BusinessError;
      Log.e(TAG, "pickDocument failed: " + err.message);
      result.error('file_picker_error', err.message, null);
    }
  }

  private copyToSandbox(ctx: common.UIAbilityContext, uris: Array<string>): Array<Map<string, string | number>> {
    const dir = ctx.filesDir + '/serverbox_picker';
    if (!fileIo.accessSync(dir)) {
      fileIo.mkdirSync(dir, true);
    }
    const files: Array<Map<string, string | number>> = new Array<Map<string, string | number>>();
    for (let i = 0; i < uris.length; i++) {
      const name = this.nameFromUri(uris[i]);
      const dest = dir + '/' + i + '_' + name;
      let srcFile: fileIo.File | null = null;
      let destFile: fileIo.File | null = null;
      try {
        srcFile = fileIo.openSync(uris[i], fileIo.OpenMode.READ_ONLY);
        destFile = fileIo.openSync(dest, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
        fileIo.copyFileSync(srcFile.fd, destFile.fd);
        const stat = fileIo.statSync(dest);
        const item: Map<string, string | number> = new Map<string, string | number>();
        item.set('name', name);
        item.set('path', dest);
        item.set('size', stat.size);
        files.push(item);
      } catch (e) {
        Log.e(TAG, "copyToSandbox failed for " + uris[i] + " : " + (e as BusinessError).message);
      } finally {
        if (srcFile != null) {
          fileIo.closeSync(srcFile);
        }
        if (destFile != null) {
          fileIo.closeSync(destFile);
        }
      }
    }
    return files;
  }

  private nameFromUri(uri: string): string {
    const segments = uri.split('/');
    if (segments.length === 0) {
      return 'file';
    }
    return segments[segments.length - 1];
  }

  private nameFromPath(path: string): string {
    const segments = path.split('/');
    if (segments.length === 0) {
      return 'file';
    }
    return segments[segments.length - 1];
  }
}
