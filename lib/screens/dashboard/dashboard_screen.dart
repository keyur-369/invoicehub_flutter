import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/screens/dashboard/home_tab.dart';
import 'package:invoicehub/screens/khata/khata_dashboard_screen.dart';
import 'package:invoicehub/screens/customers/customers_screen.dart';
import 'package:invoicehub/screens/products/products_screen.dart';
import 'package:invoicehub/screens/invoice/invoice_history_screen.dart';
import 'package:invoicehub/screens/profile/profile_settings_screen.dart';
import 'package:invoicehub/providers/dashboard_provider.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/widgets/app_colors.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(dashboardIndexProvider);
    final profile = ref.watch(profileProvider).value;

    final List<Widget> tabs = [
      HomeTab(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      KhataDashboardScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      CustomersScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      ProductsScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      InvoiceHistoryScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      ProfileSettingsScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      extendBody: true, // Enables body to scroll behind floating nav bar
      drawer: _buildAppDrawer(context, ref, profile),
      body: IndexedStack(index: currentIndex, children: tabs),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 18),
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              0,
              Icons.home_rounded,
              Icons.home_outlined,
              'Home',
              currentIndex,
              AppColors.navHome,
            ),
            _buildNavItem(
              1,
              Icons.menu_book_rounded,
              Icons.menu_book_outlined,
              'Khata',
              currentIndex,
              AppColors.navKhata,
            ),
            _buildNavItem(
              2,
              Icons.people_rounded,
              Icons.people_outline_rounded,
              'Customers',
              currentIndex,
              AppColors.navCustomers,
            ),
            _buildNavItem(
              3,
              Icons.inventory_2_rounded,
              Icons.inventory_2_outlined,
              'Products',
              currentIndex,
              AppColors.navProducts,
            ),
            _buildNavItem(
              4,
              Icons.receipt_long_rounded,
              Icons.receipt_long_outlined,
              'History',
              currentIndex,
              AppColors.navHistory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
    String label,
    int currentIndex,
    Color accentColor,
  ) {
    final isSelected = index == currentIndex;

    return InkWell(
      onTap: () => ref.read(dashboardIndexProvider.notifier).state = index,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? accentColor : AppColors.textSecondary,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context, WidgetRef ref, dynamic profile) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.textOnPrimary,
                  backgroundImage: profile?.logoUrl != null
                      ? NetworkImage(profile.logoUrl!)
                      : null,
                  child: profile?.logoUrl == null
                      ? Text(
                          (profile?.shopName?.isNotEmpty ?? false)
                              ? profile.shopName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.shopName ?? 'My Shop',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textOnPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?.ownerName != null
                            ? 'Owner: ${profile.ownerName}'
                            : (profile?.email ?? ''),
                        style: TextStyle(
                          color: AppColors.textOnPrimary.withOpacity(0.85),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _drawerTile(
            context,
            ref,
            Icons.home_rounded,
            AppColors.navHome,
            'Home Dashboard',
            0,
          ),
          _drawerTile(
            context,
            ref,
            Icons.menu_book_rounded,
            AppColors.navKhata,
            'Khata Book (Udhar Ledger)',
            1,
          ),
          _drawerTile(
            context,
            ref,
            Icons.people_rounded,
            AppColors.navCustomers,
            'Customers Management',
            2,
          ),
          _drawerTile(
            context,
            ref,
            Icons.inventory_2_rounded,
            AppColors.navProducts,
            'My Products Catalog',
            3,
          ),
          _drawerTile(
            context,
            ref,
            Icons.receipt_long_rounded,
            AppColors.navHistory,
            'Invoice History',
            4,
          ),
          const Divider(color: AppColors.border, height: 24),
          _drawerTile(
            context,
            ref,
            Icons.settings_rounded,
            AppColors.navSettings,
            'Shop Profile Settings',
            5,
          ),
          const Spacer(),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 12),
          Text(
            'InvoiceHub v1.0.0',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    Color color,
    String title,
    int index,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      onTap: () {
        Navigator.pop(context);
        ref.read(dashboardIndexProvider.notifier).state = index;
      },
    );
  }
}
