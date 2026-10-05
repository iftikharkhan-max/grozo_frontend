import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../account/account_view.dart';
import '../common/login_required.dart';
import '../favorites/favorites_view.dart';
import '../home/home_view.dart';
import '../orders/my_orders_view.dart';
import 'grozo_header.dart';
import 'order_options.dart';

/// Customer app frame. The Grozo header and the footer stay on screen on every
/// page: each footer tab has its own navigator, and pages open inside it.
class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});

  static const home = 0, orders = 1, favorites = 2, account = 3;

  static _MainShellState? _of(BuildContext context) =>
      context.findAncestorStateOfType<_MainShellState>();

  /// Switches the footer tab (e.g. "My Favorites" on the home page).
  static void switchTab(BuildContext context, int index) =>
      _of(context)?.select(index);

  /// Opens [page] in the current tab, below the header and above the footer.
  static Future<T?> push<T>(BuildContext context, Widget page) {
    final shell = _of(context);
    if (shell == null) {
      return Navigator.push<T>(
          context, MaterialPageRoute(builder: (_) => page));
    }
    return shell._push<T>(page);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _index = widget.initialTab;
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  /// Pages open in each tab that have their own bottom action button.
  final Map<int, int> _ownBottomButton = {};

  void _registerBottomButton(int tab, int delta) {
    if (!mounted) return;
    setState(
        () => _ownBottomButton[tab] = (_ownBottomButton[tab] ?? 0) + delta);
  }

  /// Who the tabs were built for. A tab's navigator keeps its first page, so
  /// when the user logs in or out the account-dependent tabs are rebuilt;
  /// otherwise "Please log in" would stay after logging in.
  int? _tabsUserId;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the notification badge fresh while the app is open.
    _unreadTimer = Timer.periodic(const Duration(seconds: 60),
        (_) => context.read<AppState>().refreshUnread());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      context.read<AppState>().refreshUnread();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    super.dispose();
  }

  void select(int i) {
    if (i == MainShell.home) homeRefresh.value++;
    if (i == _index) {
      // Tapping the current tab again returns to its first page.
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  Future<T?> _push<T>(Widget page) => _navKeys[_index]
      .currentState!
      .push<T>(MaterialPageRoute(builder: (_) => page));

  void _handleBack() {
    final nav = _navKeys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_index != MainShell.home) {
      select(MainShell.home);
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _tab(int i, Widget root) => Navigator(
        key: _navKeys[i],
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !state.sessionExpired) return;
        state.sessionExpired = false;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('err_session'))));
      });
    }

    final user = state.user;
    if (user?.id != _tabsUserId) {
      _tabsUserId = user?.id;
      for (final i in [
        MainShell.orders,
        MainShell.favorites,
        MainShell.account
      ]) {
        _navKeys[i] = GlobalKey<NavigatorState>();
      }
    }
    final pages = [
      const HomeView(),
      user == null
          ? const LoginRequired(titleKey: 'my_orders')
          : MyOrdersView(key: ValueKey(user.id)),
      user == null
          ? const LoginRequired(titleKey: 'favorites')
          : const FavoritesView(),
      const AccountView(),
    ];

    // Pages inside the frame get compact white title bars under the green header.
    final base = Theme.of(context);
    final innerTheme = base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: brandPrimary,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        toolbarHeight: 48,
        titleTextStyle: const TextStyle(
            color: brandPrimary, fontSize: 17, fontWeight: FontWeight.bold),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
          labelColor: brandPrimary,
          unselectedLabelColor: Colors.black54,
          indicatorColor: brandGreen),
    );

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: Column(children: [
          // Hidden while typing so the field being typed in (e.g. the delivery
          // address at checkout) keeps enough room above the keyboard.
          if (keyboardOpen)
            Container(
                color: brandPrimary, height: MediaQuery.paddingOf(context).top)
          else
            GrozoHeader(onOpen: (page) => _push(page)),
          Expanded(
            // The Builder's context is inside the Scaffold body, whose MediaQuery
            // no longer counts the keyboard (the body is already resized above
            // it). Using the shell's own context here put the keyboard height
            // back, so pages subtracted it twice and, on small phones, forms such
            // as the checkout address shrank to nothing while typing.
            child: Builder(
              builder: (bodyContext) => MediaQuery.removePadding(
                context: bodyContext,
                removeTop: true,
                child: Theme(
                  data: innerTheme,
                  child: IndexedStack(
                    index: _index,
                    children: [for (final (i, p) in pages.indexed) _tab(i, p)],
                  ),
                ),
              ),
            ),
          ),
        ]),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        // Hidden while typing so it never covers a form (search, checkout, address).
        floatingActionButton: keyboardOpen ||
                (_ownBottomButton[_index] ?? 0) > 0
            ? null
            : _OrderNowButton(
                count: state.cartCount,
                onTap: () => showOrderOptions(context, open: (p) => _push(p))),
        bottomNavigationBar: BottomAppBar(
          height: 68,
          padding: EdgeInsets.zero,
          color: Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Row(
            children: [
              _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: context.tr('home'),
                  active: _index == 0,
                  onTap: () => select(0)),
              _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: context.tr('my_orders'),
                  active: _index == 1,
                  onTap: () => select(1)),
              const SizedBox(width: 84),
              _NavItem(
                  icon: Icons.favorite_border,
                  activeIcon: Icons.favorite,
                  label: context.tr('favorites'),
                  active: _index == 2,
                  onTap: () => select(2)),
              _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: context.tr('my_account'),
                  active: _index == 3,
                  onTap: () => select(3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a page that has its own full-width button at the bottom (Confirm
/// order, Add to cart, Save…). The floating Order Now button would sit on top
/// of the middle of that button and catch the tap, so it is hidden while such
/// a page is open in the current tab.
class HidesOrderNowButton extends StatefulWidget {
  final Widget child;
  const HidesOrderNowButton({super.key, required this.child});

  @override
  State<HidesOrderNowButton> createState() => _HidesOrderNowButtonState();
}

class _HidesOrderNowButtonState extends State<HidesOrderNowButton> {
  _MainShellState? _shell;
  late int _tab;

  @override
  void initState() {
    super.initState();
    _shell = MainShell._of(context);
    if (_shell == null) return;
    _tab = _shell!._index;
    // The shell is not rebuilt in the middle of building this page.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _shell?._registerBottomButton(_tab, 1));
  }

  @override
  void dispose() {
    final shell = _shell;
    if (shell != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => shell._registerBottomButton(_tab, -1));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.active,
      required this.onTap});

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
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderNowButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _OrderNowButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr('order_now'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: brandGreen,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                  color: brandGreen.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white, size: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.tr('order_now'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (count > 0)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 20),
                    child: Text('$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
