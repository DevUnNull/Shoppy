import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_hub_layout.dart';
import 'admin_section_page.dart';

export '../widgets/admin_presentation.dart' show adminStatusLabel;

class AdminHubScreen extends ConsumerStatefulWidget {
  const AdminHubScreen({super.key});

  @override
  ConsumerState<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends ConsumerState<AdminHubScreen> {
  AdminSection _section = AdminSection.users;

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) AppRouter.backToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn || auth.user?.role != UserRole.admin) {
      return const AdminAccessDeniedView();
    }
    final busy = ref.watch(
      adminListProvider(_section).select((state) => state.isMutating),
    );
    return AdminHubLayout(
      section: _section,
      displayName: auth.user!.displayName,
      busy: busy,
      onSectionSelected: (section) => setState(() => _section = section),
      onLogout: _logout,
      child: AdminSectionPage(key: ValueKey(_section), section: _section),
    );
  }
}
