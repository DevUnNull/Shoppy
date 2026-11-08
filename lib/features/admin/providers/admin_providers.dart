import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../orders/providers/order_providers.dart';
import '../../shop/providers/shop_providers.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';

final adminServiceProvider = Provider<AdminService>(
  (ref) => AdminService(ref.watch(apiClientProvider)),
);

typedef AdminDetailKey = (AdminSection, int);

final adminDetailProvider = FutureProvider.autoDispose
    .family<AdminRecord, AdminDetailKey>((ref, key) {
      final auth = ref.watch(
        authProvider.select((s) => (s.user?.id, s.token, s.user?.role)),
      );
      if (auth.$1 == null || auth.$3 != UserRole.admin) {
        throw const ApiException('Bạn không có quyền truy cập quản trị.');
      }
      return ref.watch(adminServiceProvider).detail(key.$1, key.$2);
    }, retry: (_, _) => null);

class AdminListState {
  const AdminListState({
    this.items = const [],
    this.query = const AdminQuery(),
    this.totalElements = 0,
    this.totalPages = 0,
    this.hasNext = false,
    this.isLoading = false,
    this.error,
    this.isMutating = false,
    this.mutationError,
  });

  final List<AdminRecord> items;
  final AdminQuery query;
  int get page => query.page;
  int get size => query.size;
  String get search => query.search;
  String get status => query.status;
  String get role => query.role;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
  final bool isLoading;
  final String? error;
  final bool isMutating;
  final String? mutationError;

  AdminListState copyWith({
    List<AdminRecord>? items,
    AdminQuery? query,
    int? totalElements,
    int? totalPages,
    bool? hasNext,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isMutating,
    String? mutationError,
    bool clearMutationError = false,
  }) => AdminListState(
    items: items ?? this.items,
    query: query ?? this.query,
    totalElements: totalElements ?? this.totalElements,
    totalPages: totalPages ?? this.totalPages,
    hasNext: hasNext ?? this.hasNext,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
    isMutating: isMutating ?? this.isMutating,
    mutationError: clearMutationError
        ? null
        : mutationError ?? this.mutationError,
  );
}

// Keep each section alive within the session so leaving/reopening a section
// cannot drop its mutation lock while a request is in flight.
final adminListProvider =
    NotifierProvider.family<AdminListNotifier, AdminListState, AdminSection>(
      AdminListNotifier.new,
    );

class AdminListNotifier extends Notifier<AdminListState> {
  AdminListNotifier(this.section);

  final AdminSection section;
  int _requestId = 0;
  int _session = 0;
  bool _mutationInFlight = false;

  @override
  AdminListState build() {
    final identity = ref.watch(
      authProvider.select((s) => (s.user?.id, s.token, s.user?.role)),
    );
    ++_requestId;
    final session = ++_session;
    _mutationInFlight = false;
    if (identity.$1 == null || identity.$3 != UserRole.admin) {
      return const AdminListState(
        error: 'Bạn không có quyền truy cập quản trị.',
      );
    }
    Future.microtask(() {
      if (ref.mounted && session == _session) refresh();
    });
    return const AdminListState(isLoading: true);
  }

  bool get _allowed {
    final auth = ref.read(authProvider);
    return auth.isLoggedIn && auth.user?.role == UserRole.admin;
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    await _load(state.query);
  }

  Future<void> setFilters({
    String? search,
    String? status,
    String? role,
  }) async {
    if (!ref.mounted) return;
    await _load(
      state.query.copyWith(
        search: search?.trim(),
        status: status,
        role: role,
        page: 0,
      ),
    );
  }

  Future<void> goToPage(int page) async {
    if (!ref.mounted || page < 0) return;
    await _load(state.query.copyWith(page: page));
  }

  Future<void> _load(AdminQuery query) async {
    if (!ref.mounted || !_allowed) return;
    final request = ++_requestId;
    final session = _session;
    state = state.copyWith(
      items: const [],
      query: query,
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await ref
          .read(adminServiceProvider)
          .list(
            section,
            search: query.search,
            status: query.status,
            role: query.role,
            page: query.page,
            size: query.size,
          );
      if (!ref.mounted || request != _requestId || session != _session) return;
      // A delete/status change may remove the final row on the current page.
      if (result.items.isEmpty &&
          query.page > 0 &&
          result.totalPages <= query.page) {
        await _load(
          query.copyWith(
            page: result.totalPages > 0 ? result.totalPages - 1 : 0,
          ),
        );
        return;
      }
      final unique = <int, AdminRecord>{};
      for (final row in result.items) {
        unique[row.id] = row;
      }
      state = state.copyWith(
        items: List.unmodifiable(unique.values),
        query: query.copyWith(page: result.page, size: result.size),
        totalElements: result.totalElements,
        totalPages: result.totalPages,
        hasNext: result.hasNext,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted || request != _requestId || session != _session) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// False means busy, unauthorized, account changed, or an API error. The
  /// backend remains authoritative; no balance/status is edited optimistically.
  Future<bool> mutate(
    Future<void> Function(AdminService service) action,
  ) async {
    if (!ref.mounted || !_allowed || _mutationInFlight) return false;
    _mutationInFlight = true;
    final session = _session;
    state = state.copyWith(isMutating: true, clearMutationError: true);
    try {
      await action(ref.read(adminServiceProvider));
      if (!ref.mounted || session != _session || !_allowed) return false;
      ref.invalidate(adminDetailProvider);
      switch (section) {
        case AdminSection.categories:
          ref.invalidate(categoryTreeProvider);
          ref.invalidate(categoryDetailProvider);
        case AdminSection.shippingCompanies:
          ref.invalidate(shippingCompaniesProvider);
        case AdminSection.shops:
          ref.invalidate(shopProvider);
        case AdminSection.orders:
          ref.invalidate(myOrdersProvider);
          ref.invalidate(orderDetailProvider);
        case AdminSection.users:
          break;
      }
      await refresh();
      return ref.mounted && session == _session && _allowed;
    } catch (error) {
      if (ref.mounted && session == _session) {
        state = state.copyWith(mutationError: error.toString());
      }
      return false;
    } finally {
      if (ref.mounted && session == _session) {
        _mutationInFlight = false;
        state = state.copyWith(isMutating: false);
      }
    }
  }
}
