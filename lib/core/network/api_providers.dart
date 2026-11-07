import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'api_client.dart';

/// Giữ JWT hiện tại trong bộ nhớ để interceptor đọc đồng bộ mỗi request.
class AuthTokenHolder {
  String? token;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authTokenHolderProvider = Provider<AuthTokenHolder>(
  (ref) => AuthTokenHolder(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final holder = ref.watch(authTokenHolderProvider);
  final client = ApiClient(readToken: () => holder.token);
  ref.onDispose(client.close);
  return client;
});
