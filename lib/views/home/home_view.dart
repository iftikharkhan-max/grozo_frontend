import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../catalog/market_view.dart';
import '../catalog/product_list_view.dart';
import '../common/product_widgets.dart';
import '../shell/main_shell.dart';
import '../shell/order_options.dart';

class HomeData {
  final List<Map<String, dynamic>> banners;
  final List<Category> featured;
  final List<Category> market;
  final List<Product> discounted;
  final List<Map<String, dynamic>> deliveryCharges;

  HomeData.fromJson(Map<String, dynamic> j)
      : banners = List<Map<String, dynamic>>.from(j['banners'] ?? []),
        featured = (j['featured_categories'] as List? ?? [])
            .map((c) => Category.fromJson(c))
            .toList(),
        market = (j['market_categories'] as List? ?? [])
            .map((c) => Category.fromJson(c))
            .toList(),
        discounted = (j['discounted_products'] as List? ?? [])
            .map((p) => Product.fromJson(p))
            .toList(),
        deliveryCharges =
            List<Map<String, dynamic>>.from(j['delivery_charges'] ?? []);
}

/// Home page (the header and footer come from MainShell).
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  HomeData? _data;
  String? _errorCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/home');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        _data = HomeData.fromJson(res.data);
        _errorCode = null;
      } else {
        _errorCode = res.errorCode ?? 'generic';
      }
    });
  }

  void _openCategory(Category c) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ProductListView(category: c)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _SearchBar()),
            if (_loading)
              const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()))
            else if (_data == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                    errorCode: _errorCode,
                    onRetry: () {
                      setState(() => _loading = true);
                      _load();
                    }),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                sliver: SliverList.list(children: _sections(_data!)),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(HomeData d) {
    const gap = SizedBox(height: 12);
    return [
      _PromoCarousel(
          banners: d.banners,
          onCategory: (id) {
            final c = [...d.featured, ...d.market]
                .where((c) => c.id == id)
                .firstOrNull;
            if (c != null) _openCategory(c);
          }),
      gap,
      if (d.featured.isNotEmpty) ...[
        Row(children: [
          for (final (i, c) in d.featured.take(2).indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
                child: _FeaturedCategoryCard(
                    category: c,
                    yellow: i.isOdd,
                    onTap: () => _openCategory(c))),
          ],
        ]),
        gap,
      ],
      _MarketShopping(
          categories: d.market, tiers: d.deliveryCharges, onTap: _openCategory),
      gap,
      if (d.discounted.isNotEmpty) ...[
        _DealsStrip(products: d.discounted),
        gap
      ],
      const _TrustRow(),
    ];
  }
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
  final ValueChanged<int> onCategory;
  const _PromoCarousel({required this.banners, required this.onCategory});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  int get _count =>
      widget.banners.length + 1; // +1 for the built-in "Order Anything" card

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
      AspectRatio(
        aspectRatio: 3.3,
        child: PageView.builder(
          controller: _controller,
          itemCount: _count,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (ctx, i) => i == 0
              ? const _OrderAnythingCard()
              : _BannerCard(
                  banner: widget.banners[i - 1],
                  onTap: () => _openBanner(widget.banners[i - 1])),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
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
                Text(context.tr('hero_sub'),
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: brandPrimary)),
              ]),
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

// ---------------------------------------------------------------- Categories

class _FeaturedCategoryCard extends StatelessWidget {
  final Category category;
  final bool yellow;
  final VoidCallback onTap;
  const _FeaturedCategoryCard(
      {required this.category, required this.yellow, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final other = lang == 'ur'
        ? category.name
        : category.nameUr; // design shows both languages
    return Material(
      color: yellow ? brandYellowLight : brandGreenLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    (yellow ? brandYellow : brandGreen).withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            SizedBox(
              width: 52,
              height: 52,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetImage(category.imageUrl,
                      fallbackEmoji: categoryEmoji(category.name))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(category.displayName(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: brandPrimary)),
                    if ((other ?? '').isNotEmpty)
                      Text(other!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: brandPrimary)),
                    if (category.displaySubtitle(lang) != null)
                      Text(category.displaySubtitle(lang)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: yellow ? brandAccent : brandGreen)),
                  ]),
            ),
            Icon(Icons.chevron_right,
                color: yellow ? brandAccent : brandGreen,
                textDirection: Directionality.of(context)),
          ]),
        ),
      ),
    );
  }
}

class _MarketShopping extends StatelessWidget {
  final List<Category> categories;
  final List<Map<String, dynamic>> tiers;
  final ValueChanged<Category> onTap;
  const _MarketShopping(
      {required this.categories, required this.tiers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    Widget pill(IconData icon, String label, VoidCallback onPressed) =>
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: brandGreen,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
        );

    return _Panel(
      color: const Color(0xFFF1FAF7),
      borderColor: const Color(0xFFB9E4D3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MarketView())),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.storefront,
                          color: brandPrimary, size: 26),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(context.tr('market_shopping'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: brandPrimary)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(context.tr('market_shopping_sub'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ]),
            ),
          ),
          const SizedBox(width: 6),
          // "Delivery Charges" sits below "How it works", as specified.
          // IntrinsicWidth gives both buttons the width of the wider one; without
          // it, "stretch" inside a Row asks for infinite width and the page fails.
          IntrinsicWidth(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  pill(
                      Icons.info_outline,
                      context.tr('how_it_works'),
                      () => showDialog(
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
                          )),
                  const SizedBox(height: 4),
                  pill(
                      Icons.local_shipping_outlined,
                      context.tr('delivery_charges'),
                      () => showDeliveryCharges(context, tiers)),
                ]),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              if (i == categories.length) {
                // Anything else from the market.
                return _Tile(
                  label: context.tr('not_in_list'),
                  onTap: () => showAddCustomItem(context),
                  child: const Icon(Icons.add_shopping_cart,
                      color: brandAccent, size: 34),
                );
              }
              final c = categories[i];
              return _Tile(
                label: c.displayName(lang),
                onTap: () => onTap(c),
                child: NetImage(c.imageUrl,
                    fit: BoxFit.contain, fallbackEmoji: categoryEmoji(c.name)),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;
  const _Tile({required this.label, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(children: [
                Expanded(child: Center(child: child)),
                Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

/// Delivery charges chart (opened from Market Shopping).
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

class _DealsStrip extends StatelessWidget {
  final List<Product> products;
  const _DealsStrip({required this.products});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: const Color(0xFFFFF1E6),
      borderColor: brandAccent.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_offer, color: brandAccent, size: 20),
          const SizedBox(width: 6),
          Text(context.tr('deals_discounts'),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: brandPrimary)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 2),
            itemBuilder: (ctx, i) => ProductCard(products[i], width: 124),
          ),
        ),
      ]),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.verified_user_outlined, 'trust_quality'),
      (Icons.eco_outlined, 'trust_fresh'),
      (Icons.local_shipping_outlined, 'trust_fast'),
      (Icons.payments_outlined, 'trust_payment'),
    ];
    return _Panel(
      color: brandGreenLight,
      borderColor: brandGreen.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          for (final (icon, key) in items)
            Expanded(
              child: Column(children: [
                Icon(icon, color: brandGreen),
                const SizedBox(height: 4),
                Text(context.tr(key),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsets padding;
  const _Panel(
      {required this.child,
      required this.color,
      required this.borderColor,
      this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor)),
        child: child,
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
