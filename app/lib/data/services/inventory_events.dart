import 'package:flutter/foundation.dart';

final ValueNotifier<int> inventoryVersion = ValueNotifier<int>(0);

void notifyInventoryChanged() {
  inventoryVersion.value++;
}
