import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoppy/app/app_router.dart';
import 'package:shoppy/core/network/api_client.dart';
import 'package:shoppy/core/network/api_providers.dart';
import 'package:shoppy/core/theme/app_theme.dart';
import 'package:shoppy/features/admin/screens/admin_hub_screen.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/catalog/providers/product_list_provider.dart';
import 'package:shoppy/features/notifications/providers/notification_providers.dart';
import 'package:shoppy/shared/widgets/shoppy_header.dart';

import 'helpers/customer_fakes.dart';

User _user(UserRole role) => User(
  id: 31,
  email: 'entry@example.test',
  fullName: 'Người dùng kiểm thử',
  role: role,
);

class _Session extends AuthNotifier {
  _Session(this.user);

  final User user;

  @override
  AuthState build() => AuthState.authenticated(user, 'test-token');
}

class _EmptyApi extends ApiClient {
  _EmptyApi() : super(readToken: () => 'test-token');

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'content': <Map<String, dynamic>>[],
    'page': 0,
    'size': 20,
    'totalElements': 0,
    'totalPages': 0,
    'hasNext': false,
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final role in [
    UserRole.admin,
    UserRole.customer,
    UserRole.seller,
    UserRole.shipper,
  ]) {
    testWidgets('Menu quản trị chỉ hiển thị cho ADMIN: ${role.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _Session(_user(role))),
            trendingKeywordsProvider.overrideWithValue(const []),
            unreadCountProvider.overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ShoppyHeader()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tài khoản'));
      await tester.pumpAndSettle();
      expect(
        find.text('Trung tâm quản trị'),
        role == UserRole.admin ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final role in [UserRole.admin, UserRole.customer]) {
    testWidgets('Đăng nhập ${role.name} giữ đúng luồng điều hướng', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? customerContinuation;
      final api = _EmptyApi();
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authServiceProvider.overrideWithValue(
              FakeAuthService(profile: _user(role)),
            ),
            apiClientProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    customerContinuation = await AppRouter.login(context);
                  },
                  child: const Text('Mở đăng nhập'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở đăng nhập'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'entry@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      await tester.tap(find.text('ĐĂNG NHẬP'));
      await tester.pumpAndSettle();
      if (role == UserRole.admin) {
        expect(find.byType(AdminHubScreen), findsOneWidget);
        // A customer action waiting for login must not open checkout on top
        // of the administration hub.
        expect(customerContinuation, isFalse);
      } else {
        expect(find.byType(AdminHubScreen), findsNothing);
        expect(find.text('Mở đăng nhập'), findsOneWidget);
        expect(customerContinuation, isTrue);
      }
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
