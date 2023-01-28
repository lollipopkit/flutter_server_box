import 'package:flutter/material.dart';
import 'package:toolbox/core/persistant_store.dart';

class SettingStore extends PersistentStore {
  StoreProperty<int> get primaryColor =>
      property('primaryColor', defaultValue: Colors.deepPurpleAccent.value);

  StoreProperty<int> get serverStatusUpdateInterval =>
      property('serverStatusUpdateInterval', defaultValue: 3);

  /// Lanch page idx
  StoreProperty<int> get launchPage => property('launchPage', defaultValue: 0);

  /// Version of store db
  StoreProperty<int> get storeVersion =>
      property('storeVersion', defaultValue: 0);

  /// Show logo on server detail page
  StoreProperty<bool> get showDistLogo =>
      property('showDistLogo', defaultValue: true);

  /// SSH term size
  StoreProperty<String> get sshTermSize =>
      property('sshTermSize', defaultValue: '80x24');

  /// First time to use SSH term
  StoreProperty<bool> get firstTimeUseSshTerm =>
      property('firstTimeUseSshTerm', defaultValue: true);
}
