import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../catalog/market_view.dart';
import '../partners/partner_view.dart';
import '../catalog/product_list_view.dart';
import '../common/product_widgets.dart';
import '../shell/main_shell.dart';
import '../shell/order_options.dart';

class HomeData {
  final List<Map<String, dynamic>> banners;
  final List<Category> featured;
  final List<Category> market;
  final List<Partner> partners;
  final List<Map<String, dynamic>> deliveryCharges;

  HomeData.fromJson(Map<String, dynamic> j)
      : banners = List<Map<String, dynamic>>.from(j['banners'] ?? []),
        featured = (j['featured_categories'] as List? ?? [])
            .map((c) => Category.fromJson(c))
            .toList(),
        market = (j['market_categories'] as List? ?? [])
            .map((c) => Category.fromJson(c))
            .toList(),
        partners = (j['partners'] as List? ?? [])
            .map((p) => Partner.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
        deliveryCharges =
            List<Map<String, dynamic>>.from(j['delivery_charges'] ?? []);
}

/// Bumped by MainShell when the customer returns to the Home tab, so categories
/// and offers the admin added since are shown without restarting the app.
final homeRefresh = ValueNotifier<int>(0);

/// Home page (the header and footer come from MainShell).
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  HomeData? _data;
  String? _errorCode;
  bool _loading = true;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    homeRefresh.addListener(_refreshIfStale);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeRefresh.removeListener(_refreshIfStale);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refreshIfStale();
  }

  /// Quietly reloads (keeping the current page on screen) unless it just loaded.
  void _refreshIfStale() {
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at).inSeconds < 20) return;
    _load();
  }

  Future<void> _load() async {
    _loadedAt = DateTime.now();
    final res = await Api.get('/home');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        _data = HomeData.fromJson(res.data);
        _errorCode = null;
      } else {
        _errorCode = res.errorCode ?? 'generic';
        _loadedAt = null; // try again on the next visit
      }
    });
  }

  void _openCategory(Category c) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ProductListView(category: c)));

  /// Pull-to-refresh needs something scrollable even while loading.
  Widget _fill(Widget child) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: box.maxHeight, child: Center(child: child)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      body: Column(children: [
        const _SearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? _fill(const CircularProgressIndicator())
                : _data == null
                    ? _fill(_ErrorState(
                        errorCode: _errorCode,
                        onRetry: () {
                          setState(() => _loading = true);
                          _load();
                        }))
                    : _sections(_data!),
          ),
        ),
      ]),
    );
  }

  /// Banner slides are 3 : 1 (width : height) – the shape to design
  /// banners in (e.g. 1200 x 400 px).
  static const bannerRatio = 3.0;

  /// Categories shown on the home page; "View all" lists the rest.
  static const homeCategories = 6;

  /// Layout (as in the design the customer sent): banner, Explore
  /// Categories (two columns), "Item not in the list", and Order from our
  /// partners (it replaced Deals & Discounts).
  Widget _sections(HomeData d) {
    final categories = [...d.featured, ...d.market];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // The page ends clear of the round Order Now button above the footer.
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
      children: [
        LayoutBuilder(
          builder: (context, box) => SizedBox(
            height: box.maxWidth / bannerRatio + 11,
            child: _PromoCarousel(
                banners: d.banners,
                tiers: d.deliveryCharges,
                onCategory: (id) {
                  // A banner may link to a main category or a sub-category.
                  final c = [
                    ...categories,
                    for (final m in categories) ...m.subcategories
                  ].where((c) => c.id == id).firstOrNull;
                  if (c != null) _openCategory(c);
                }),
          ),
        ),
        _SectionTitle(
          title: context.tr('explore_categories'),
          onViewAll: categories.length > homeCategories
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AllCategoriesView(categories: categories)))
              : null,
        ),
        CategoryGrid(
            categories: categories.take(homeCategories).toList(),
            onTap: _openCategory),
        const SizedBox(height: 10),
        const _NotInListCard(),
        if (d.partners.isNotEmpty) ...[
          _SectionTitle(
            title: context.tr('order_from_partners'),
            onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PartnersView(partners: d.partners))),
          ),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.partners.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) =>
                  SizedBox(width: 156, child: PartnerCard(d.partners[i])),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Explore Categories                View All"
class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  const _SectionTitle({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 10),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: brandPrimary)),
          ),
          if (onViewAll != null)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(context.tr('view_all'),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: brandGreen)),
              ),
            ),
        ]),
      );
}

/// Two columns of category cards: picture, name, arrow.
class CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final ValueChanged<Category> onTap;
  const CategoryGrid(
      {super.key, required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < categories.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _CategoryCard(categories[i], onTap: onTap)),
            const SizedBox(width: 10),
            Expanded(
                child: i + 1 < categories.length
                    ? _CategoryCard(categories[i + 1], onTap: onTap)
                    : const SizedBox.shrink()),
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final ValueChanged<Category> onTap;
  const _CategoryCard(this.category, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE3E7E3))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(category),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(children: [
            SizedBox(
              width: 58,
              height: 58,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NetImage(category.imageUrl,
                    fallbackEmoji: categoryEmoji(category.name)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(category.displayName(context.lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: brandPrimary)),
            ),
            Icon(Icons.chevron_right,
                color: Colors.black45,
                textDirection: Directionality.of(context)),
          ]),
        ),
      ),
    );
  }
}

/// "Item not in the list? Add it" – anything we should buy from the market.
class _NotInListCard extends StatelessWidget {
  const _NotInListCard();

  @override
  Widget build(BuildContext context) => Material(
        color: brandYellowLight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: brandAccent, width: 1.2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showAddCustomItem(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.add_shopping_cart, color: brandAccent, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('not_in_list'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: brandPrimary)),
                      Text(context.tr('market_shopping_sub'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.black87)),
                    ]),
              ),
              Icon(Icons.chevron_right,
                  color: brandAccent,
                  textDirection: Directionality.of(context)),
            ]),
          ),
        ),
      );
}

/// "View all" categories.
class AllCategoriesView extends StatelessWidget {
  final List<Category> categories;
  const AllCategoriesView({super.key, required this.categories});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('explore_categories'))),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          CategoryGrid(
            categories: categories,
            onTap: (c) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductListView(category: c))),
          ),
          const SizedBox(height: 10),
          const _NotInListCard(),
          const SizedBox(height: 80),
        ]),
      );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandGreen,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProductListView(searchMode: true))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              const Icon(Icons.search, color: Colors.black87),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(context.tr('search_hint'),
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 15))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Promo banners

class _PromoCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> tiers;
  final ValueChanged<int> onCategory;
  const _PromoCarousel(
      {required this.banners, required this.tiers, required this.onCategory});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  // Slides: "Order Anything", the admin's banners, then "How it works" and
  // "Delivery Charges" (these two used to be buttons in Market Shopping).
  int get _count => widget.banners.length + 3;

  @override
  void initState() {
    super.initState();
    if (_count > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_controller.hasClients) {
          _controller.animateToPage((_page + 1) % _count,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openBanner(Map<String, dynamic> b) {
    final linkId = b['link_id'] is int
        ? b['link_id'] as int
        : int.tryParse('${b['link_id']}');
    if (b['link_type'] == 'category' && linkId != null) {
      widget.onCategory(linkId);
    } else if (b['link_type'] == 'product' && linkId != null) {
      Api.get('/products/$linkId').then((res) {
        if (res.ok && mounted) openProduct(context, Product.fromJson(res.data));
      });
    } else {
      _showBannerDetails(b);
    }
  }

  void _showBannerDetails(Map<String, dynamic> b) {
    final ur = context.lang == 'ur';
    String? pickLang(String key) =>
        (ur && (b['${key}_ur'] ?? '').toString().isNotEmpty
                ? b['${key}_ur']
                : b[key])
            ?.toString();
    final ends = DateTime.tryParse('${b['ends_at']}')?.toLocal();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickLang('title') ?? '',
                  style: Theme.of(context).textTheme.titleLarge),
              if (pickLang('subtitle') != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(pickLang('subtitle')!)),
              if (ends != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Valid until ${ends.day}/${ends.month}/${ends.year}',
                      style: const TextStyle(color: brandAccent)),
                ),
              if ((b['terms'] ?? '').toString().isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(b['terms'],
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54))),
            ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Compact so more of the page is visible without scrolling.
      Expanded(
        child: PageView.builder(
          controller: _controller,
          itemCount: _count,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (ctx, i) {
            if (i == 0) return const _OrderAnythingCard();
            if (i <= widget.banners.length) {
              return _BannerCard(
                  banner: widget.banners[i - 1],
                  onTap: () => _openBanner(widget.banners[i - 1]));
            }
            return i == widget.banners.length + 1
                ? _InfoSlide(
                    icon: Icons.info_outline,
                    title: context.tr('how_it_works'),
                    body: context.tr('market_shopping_sub'),
                    onTap: () => showHowItWorks(context))
                : _InfoSlide(
                    icon: Icons.local_shipping_outlined,
                    title: context.tr('delivery_charges'),
                    body: deliveryChargesSummary(widget.tiers),
                    yellow: true,
                    onTap: () => showDeliveryCharges(context, widget.tiers));
          },
        ),
      ),
      if (_count > 1)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                _count,
                (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: i == _page ? brandGreen : Colors.black26,
                          borderRadius: BorderRadius.circular(3)),
                    )),
          ),
        ),
    ]);
  }
}

void showHowItWorks(BuildContext context) => showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('how_it_works')),
        content: Text(context.tr('how_it_works_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('ok')))
        ],
      ),
    );

/// "0–2 km Rs. 50  •  2–5 km Rs. 100 …" for the Delivery Charges slide.
String deliveryChargesSummary(List<Map<String, dynamic>> tiers) {
  String n(dynamic v) {
    final d = double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : '$d';
  }

  return tiers
      .map(
          (t) => '${n(t['min_km'])}–${n(t['max_km'])} km Rs. ${n(t['charge'])}')
      .join('  •  ');
}

/// A carousel slide for "How it works" / "Delivery Charges"; tap for details.
class _InfoSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool yellow;
  final VoidCallback onTap;
  const _InfoSlide(
      {required this.icon,
      required this.title,
      required this.body,
      required this.onTap,
      this.yellow = false});

  @override
  Widget build(BuildContext context) {
    final accent = yellow ? brandAccent : brandGreen;
    return Material(
      color: yellow ? brandYellowLight : brandGreenLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: accent,
                child: Icon(icon, color: Colors.white, size: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: brandPrimary)),
                    if (body.isNotEmpty)
                      Flexible(
                        child: Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                      ),
                  ]),
            ),
            Icon(Icons.chevron_right,
                color: accent, textDirection: Directionality.of(context)),
          ]),
        ),
      ),
    );
  }
}

class _OrderAnythingCard extends StatelessWidget {
  const _OrderAnythingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
            colors: [Color(0xFFEAF7E4), Color(0xFFFFF6D8)]),
        border: Border.all(color: brandGreen.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Expanded(
          // Shrinks the text a little when the banner is short (small phones).
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Text(context.tr('hero_title'),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: brandPrimary)),
                  ),
                  if (MediaQuery.sizeOf(context).height >= 700)
                    // Keep the subtitle wrapping at a normal width inside the FittedBox.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: Text(context.tr('hero_sub'),
                          maxLines: 2,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: brandPrimary)),
                    ),
                ]),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandYellow,
            foregroundColor: brandPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: const StadiumBorder(),
          ),
          onPressed: () => showOrderOptions(context,
              open: (p) => MainShell.push(context, p)),
          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
          label: Text(context.tr('order_now'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;
  final VoidCallback onTap;
  const _BannerCard({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ur = context.lang == 'ur';
    String? pick(String key) =>
        (ur && (banner['${key}_ur'] ?? '').toString().isNotEmpty
                ? banner['${key}_ur']
                : banner[key])
            ?.toString();
    final hasImage = (banner['image_url'] ?? '').toString().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        color: brandYellowLight,
        child: InkWell(
          onTap: onTap,
          child: hasImage
              ? NetImage(banner['image_url'])
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(pick('title') ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: brandPrimary)),
                        if (pick('subtitle') != null)
                          Text(pick('subtitle')!,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 12.5)),
                      ]),
                ),
        ),
      ),
    );
  }
}

/// Delivery charges chart.
void showDeliveryCharges(
    BuildContext context, List<Map<String, dynamic>> tiers) {
  String num(dynamic v) {
    final d = double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  Widget cell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(text,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.local_shipping_outlined, color: brandGreen),
        const SizedBox(width: 8),
        Flexible(child: Text(context.tr('delivery_charges'))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Table(
          border: TableBorder.all(
              color: Colors.black12, borderRadius: BorderRadius.circular(8)),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: brandGreenLight),
              children: [
                cell(context.tr('distance_km'), bold: true),
                cell(context.tr('charge_rs'), bold: true)
              ],
            ),
            for (final t in tiers)
              TableRow(children: [
                cell('${num(t['min_km'])} – ${num(t['max_km'])} KM'),
                cell('Rs. ${num(t['charge'])}', bold: true)
              ]),
          ],
        ),
        const SizedBox(height: 10),
        Text(context.tr('delivery_note'),
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(context.tr('ok')))
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String? errorCode;
  final VoidCallback onRetry;
  const _ErrorState({required this.errorCode, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(errorCode == 'network' ? Icons.wifi_off : Icons.cloud_off,
            size: 56, color: Colors.black38),
        const SizedBox(height: 12),
        Text(
            errorCode == 'network'
                ? context.tr('err_network')
                : context.tr('err_home'),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: Text(context.tr('retry'))),
      ]),
    );
  }
}
