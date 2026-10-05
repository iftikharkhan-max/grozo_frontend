import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../cart/cart_view.dart';
import '../common/more_menu.dart';

/// Header shown on every customer page:
/// [Location] [logo + tagline] [EN | اردو] [cart] [⋮]
class GrozoHeader extends StatelessWidget {
  /// Opens a page inside the current footer tab (keeps header and footer).
  final void Function(Widget page) onOpen;
  const GrozoHeader({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final branch = state.selectedBranch;
    final branchName = branch == null
        ? context.tr('location')
        : (context.lang == 'ur' &&
                    (branch['name_ur'] ?? '').toString().isNotEmpty
                ? branch['name_ur']
                : branch['name'])
            .toString();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [brandPrimary, brandGreen],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
      ),
      padding:
          EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 4, 0, 6),
      child: Row(
        children: [
          // Location
          Expanded(
            flex: 5,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showBranchPicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.location_on, color: brandYellow, size: 22),
                  Flexible(
                    child: Text(branchName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            height: 1.15)),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 18),
                ]),
              ),
            ),
          ),
          // Logo with the tagline underneath
          Expanded(
            flex: 4,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Image.asset('assets/images/logo.png',
                    height: 46, width: 46),
              ),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(context.tr('app_tagline'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
          _LanguageToggle(
              current: state.language, onChanged: state.setLanguage),
          IconButton(
            tooltip: context.tr('cart'),
            visualDensity: VisualDensity.compact,
            onPressed: () => onOpen(const CartView()),
            icon: Badge(
              isLabelVisible: state.cartCount > 0,
              label: Text('${state.cartCount}'),
              child: const Icon(Icons.shopping_cart_outlined,
                  color: Colors.white, size: 26),
            ),
          ),
          IconButton(
            tooltip: context.tr('more'),
            visualDensity: VisualDensity.compact,
            onPressed: () => showMoreMenu(context, open: onOpen),
            icon: Badge(
              isLabelVisible: state.unreadNotifications > 0,
              label: Text('${state.unreadNotifications}'),
              child: const Icon(Icons.menu, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _LanguageToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(String code, String label) {
      final selected = current == code;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => onChanged(code),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: selected ? brandGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : brandPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      // Keep EN on the left regardless of text direction.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [option('en', 'EN'), option('ur', 'اردو')]),
      ),
    );
  }
}

/// Lists the branches. Choosing one makes it the customer's branch (header,
/// delivery charges) and shows it in Google Maps.
void showBranchPicker(BuildContext context) {
  final state = context.read<AppState>();
  if (state.branches.isEmpty) state.loadBranches();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Consumer<AppState>(
      builder: (ctx, s, _) {
        final ur = context.lang == 'ur';
        return SafeArea(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
            child: ListView(shrinkWrap: true, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(context.tr('select_branch'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (s.branches.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(context.tr('branch_not_set')))),
              for (final b in s.branches)
                ListTile(
                  leading: Icon(
                    s.selectedBranch?['id'] == b['id']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: brandGreen,
                  ),
                  title: Text(
                      (ur && (b['name_ur'] ?? '').toString().isNotEmpty
                              ? b['name_ur']
                              : b['name'])
                          .toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([b['address'], b['opening_hours']]
                      .where((x) => (x ?? '').toString().isNotEmpty)
                      .join('\n')),
                  trailing: const Icon(Icons.map_outlined, color: brandPrimary),
                  onTap: () {
                    s.selectBranch(b['id'] as int);
                    Navigator.pop(ctx);
                    _openInMaps(b);
                  },
                ),
            ]),
          ),
        );
      },
    ),
  );
}

void _openInMaps(Map<String, dynamic> b) {
  final lat = double.tryParse('${b['latitude']}');
  final lng = double.tryParse('${b['longitude']}');
  final query =
      lat != null && lng != null ? '$lat,$lng' : '${b['address'] ?? b['name']}';
  launchUrl(
      Uri.https(
          'www.google.com', '/maps/search/', {'api': '1', 'query': query}),
      mode: LaunchMode.externalApplication);
}
