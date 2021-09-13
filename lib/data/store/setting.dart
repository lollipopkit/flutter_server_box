import 'package:toolbox/core/persistant_store.dart';

class SettingStore extends PersistentStore {
  StoreProperty<bool> get receiveNotification =>
      property('notify', defaultValue: true);
}
