import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../models/admin_models.dart';
import 'admin_presentation.dart';

class AdminHubLayout extends StatelessWidget {
  const AdminHubLayout({
    super.key,
    required this.section,
    required this.displayName,
    required this.busy,
    required this.onSectionSelected,
    required this.onLogout,
    required this.child,
  });

  final AdminSection section;
  final String displayName;
  final bool busy;
  final ValueChanged<AdminSection> onSectionSelected;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final sidebar = _AdminSidebar(
      section: section,
      busy: busy,
      closeDrawerOnSelect: !wide,
      onSelected: onSectionSelected,
    );
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: _AdminAppBar(
          wide: wide,
          displayName: displayName,
          busy: busy,
          onLogout: onLogout,
        ),
        drawer: wide ? null : Drawer(child: sidebar),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) SizedBox(width: 238, child: sidebar),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AdminAppBar({
    required this.wide,
    required this.displayName,
    required this.busy,
    required this.onLogout,
  });

  final bool wide;
  final String displayName;
  final bool busy;
  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(wide ? 'Quản trị toàn sàn' : 'Admin Hub'),
    leading: wide ? const Icon(Icons.admin_panel_settings_outlined) : null,
    actions: [
      if (MediaQuery.sizeOf(context).width > 650)
        Center(child: Text(displayName, style: const TextStyle(fontSize: 13))),
      IconButton(
        tooltip: 'Về trang mua sắm',
        onPressed: busy ? null : () => AppRouter.backToHome(context),
        icon: const Icon(Icons.storefront_outlined),
      ),
      IconButton(
        tooltip: 'Đăng xuất',
        onPressed: busy ? null : onLogout,
        icon: const Icon(Icons.logout),
      ),
      const SizedBox(width: 12),
    ],
  );
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.section,
    required this.busy,
    required this.closeDrawerOnSelect,
    required this.onSelected,
  });

  final AdminSection section;
  final bool busy;
  final bool closeDrawerOnSelect;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: adminNavy,
    child: SafeArea(
      child: ListView(
        children: [
          const _AdminSidebarBrand(),
          for (final item in AdminSection.values)
            _AdminNavigationTile(
              section: item,
              selected: section == item,
              onTap: busy
                  ? null
                  : () {
                      onSelected(item);
                      if (closeDrawerOnSelect) Navigator.of(context).pop();
                    },
            ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Quản lý hoạt động trên toàn sàn',
              style: TextStyle(
                color: Color(0xFF9CAEC9),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminSidebarBrand extends StatelessWidget {
  const _AdminSidebarBrand();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(24, 28, 24, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shoppy',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 29,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'ADMIN HUB',
          style: TextStyle(
            color: Color(0xFFA6B6D0),
            fontSize: 11,
            letterSpacing: 2.4,
          ),
        ),
      ],
    ),
  );
}

class _AdminNavigationTile extends StatelessWidget {
  const _AdminNavigationTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final AdminSection section;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    child: ListTile(
      key: ValueKey('admin-nav-${section.name}'),
      selected: selected,
      selectedTileColor: const Color(0xFF30405B),
      selectedColor: Colors.white,
      textColor: const Color(0xFFBECAE0),
      iconColor: const Color(0xFFBECAE0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(adminSectionIcon(section), size: 21),
      title: Text(section.title, style: const TextStyle(fontSize: 13)),
      onTap: onTap,
    ),
  );
}

class AdminAccessDeniedView extends StatelessWidget {
  const AdminAccessDeniedView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin Hub')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 64,
              color: adminMuted,
            ),
            const SizedBox(height: 16),
            const Text('Khu vực dành cho quản trị viên'),
            const SizedBox(height: 8),
            const Text(
              'Vui lòng đăng nhập bằng tài khoản có quyền ADMIN.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => AppRouter.login(context),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      ),
    ),
  );
}
