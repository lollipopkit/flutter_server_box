import 'package:flutter/material.dart';
import 'package:toolbox/core/persistant_store.dart';

class SettingStore extends PersistentStore {
  StoreProperty<int> get primaryColor =>
      property('primaryColor', defaultValue: Colors.deepPurpleAccent.value);
  StoreProperty<int> get serverStatusUpdateInterval =>
      property('serverStatusUpdateInterval', defaultValue: 2);
  StoreProperty<int> get launchPage => property('launchPage', defaultValue: 0);
}
