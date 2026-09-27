import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../account/account_view.dart';
import '../cart/cart_view.dart';
import '../common/login_required.dart';
import '../favorites/favorites_view.dart';
import '../home/home_view.dart';
import '../orders/my_orders_view.dart';

/// Customer app frame: Home, My Orders, [Order Now], Favorites, My Account.
class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});

  /// Lets any screen switch the footer tab (e.g. "My Favorites" on the home page).
  static void switchTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainShellState>()?.select(index);

  static const home = 0, orders = 1, favorites = 2, account = 3;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialTab;

  void select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !state.sessionExpired) return;
        state.sessionExpired = false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('err_session'))));
      });
    }

    final user = state.user;
    final pages = [
      const HomeView(),
      user == null ? const LoginRequired(titleKey: 'my_orders') : MyOrdersView(key: ValueKey(user.id)),
      user == null ? const LoginRequired(titleKey: 'favorites') : const FavoritesView(),
      const AccountView(),
    ];

    return PopScope(
      // Back from another tab returns to Home instead of closing the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) select(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _OrderNowButton(count: state.cartCount),
        bottomNavigationBar: BottomAppBar(
          height: 68,
          padding: EdgeInsets.zero,
          color: Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: context.tr('home'), active: _index == 0, onTap: () => select(0)),
              _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: context.tr('my_orders'), active: _index == 1, onTap: () => select(1)),
              const SizedBox(width: 84),
              _NavItem(icon: Icons.favorite_border, activeIcon: Icons.favorite, label: context.tr('favorites'), active: _index == 2, onTap: () => select(2)),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: context.tr('my_account'), active: _index == 3, onTap: () => select(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? brandGreen : Colors.black54;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        child: Semantics(
          selected: active,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, color: color, size: 26),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderNowButton extends StatelessWidget {
  final int count;
  const _OrderNowButton({required this.count});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr('order_now'),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartView())),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: brandGreen,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: brandGreen.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.tr('order_now'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (count > 0)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: _Badge(count: count),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
        constraints: const BoxConstraints(minWidth: 20),
        child: Text('$count', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}
