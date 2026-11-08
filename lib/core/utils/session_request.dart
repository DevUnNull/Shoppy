import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Không để thao tác của phiên cũ tiếp tục chờ provider chi tiết của phiên mới.
Future<T> waitForSession<T>(Ref ref, Future<T> request) async {
  final cancelled = Completer<T>();
  final removeListener = ref.onDispose(() {
    cancelled.completeError(StateError('Phiên đăng nhập đã thay đổi.'));
  });
  try {
    return await Future.any([request, cancelled.future]);
  } finally {
    removeListener();
  }
}
