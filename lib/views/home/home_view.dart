import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../cart/cart_view.dart';
import '../checkout/market_request_view.dart';
import '../catalog/product_list_view.dart';
import '../common/more_menu.dart';
import '../common/product_widgets.dart';
import '../info/branch_view.dart';
import '../shell/main_shell.dart';

class HomeData {
  final List<Map<String, dynamic>> banners;
  final List<Category> featured;
  final List<Category> market;
  final List<Product> discounted;
  final List<Map<String, dynamic>> deliveryCharges;
  final Map<String, dynamic>? branch;

  HomeData.fromJson(Map<String, dynamic> j)
      : banners = List<Map<String, dynamic>>.from(j['banners'] ?? []),
        featured = (j['featured_categories'] as List? ?? []).map((c) => Category.fromJson(c)).toList(),
        market = (j['market_categories'] as List? ?? []).map((c) => Category.fromJson(c)).toList(),
        discounted = (j['discounted_products'] as List? ?? []).map((p) => Product.fromJson(p)).toList(),
        deliveryCharges = List<Map<String, dynamic>>.from(j['delivery_charges'] ?? []),
        branch = j['branch'];
}

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

  void _openCategory(Category c) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductListView(category: c)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(branch: _data?.branch)),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (_data == null)
              SliverFillRemaining(hasScrollBody: false, child: _ErrorState(errorCode: _errorCode, onRetry: () {
                setState(() => _loading = true);
                _load();
              }))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                sliver: SliverList.list(children: _sections(_data!)),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(HomeData d) {
    const gap = SizedBox(height: 14);
    final veg = d.featured.where((c) => c.name.toLowerCase().contains('veg')).firstOrNull;
    final fruit = d.featured.where((c) => c.name.toLowerCase().contains('fruit')).firstOrNull;

    return [
      _PromoCarousel(banners: d.banners, onCategory: (id) {
        final c = [...d.featured, ...d.market].where((c) => c.id == id).firstOrNull;
        if (c != null) _openCategory(c);
      }),
      gap,
      if (d.featured.isNotEmpty) ...[
        Row(
          children: [
            for (final (i, c) in d.featured.take(2).indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _FeaturedCategoryCard(category: c, yellow: i.isOdd, onTap: () => _openCategory(c))),
            ],
          ],
        ),
        gap,
      ],
      _MarketShopping(categories: d.market, onTap: _openCategory),
      gap,
      if (veg != null) ...[_ProductStrip(category: veg, onViewAll: () => _openCategory(veg)), gap],
      if (fruit != null) ...[_ProductStrip(category: fruit, yellow: true, onViewAll: () => _openCategory(fruit)), gap],
      for (final c in d.featured.where((c) => c != veg && c != fruit && c.products.isNotEmpty)) ...[
        _ProductStrip(category: c, onViewAll: () => _openCategory(c)),
        gap,
      ],
      if (d.discounted.isNotEmpty) ...[_DealsStrip(products: d.discounted), gap],
      LayoutBuilder(builder: (context, box) {
        final charges = _DeliveryCharges(tiers: d.deliveryCharges);
        const repeat = _RepeatOrder();
        if (box.maxWidth < 600) return Column(children: [charges, gap, repeat]);
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: charges),
            const SizedBox(width: 10),
            const Expanded(child: repeat),
          ]),
        );
      }),
      gap,
      const _TrustRow(),
    ];
  }
}

// ---------------------------------------------------------------- Header

class _Header extends StatelessWidget {
  final Map<String, dynamic>? branch;
  const _Header({this.branch});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final branchName = branch == null
        ? null
        : (context.lang == 'ur' && (branch!['name_ur'] ?? '').toString().isNotEmpty ? branch!['name_ur'] : branch!['name']).toString();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [brandPrimary, brandGreen], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 8, 4, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchView())),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: brandYellow, size: 22),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(branchName ?? context.tr('branch_location'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                  ]),
                ),
              ),
              _LanguageToggle(current: state.language, onChanged: state.setLanguage),
              _CartIcon(count: state.cartCount),
              IconButton(
                tooltip: context.tr('more'),
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => showMoreMenu(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Image.asset('assets/images/logo.png', height: 34, width: 34),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('GROZO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(context.tr('app_tagline'), style: const TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListView(searchMode: true))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(children: [
                    const Icon(Icons.search, color: Colors.black87),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.tr('search_hint'), style: const TextStyle(color: Colors.black45, fontSize: 15))),
                  ]),
                ),
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: selected ? brandGreen : Colors.transparent, borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(color: selected ? Colors.white : brandPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      // Keep EN on the left regardless of text direction.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [option('en', 'EN'), option('ur', 'اردو')]),
      ),
    );
  }
}

class _CartIcon extends StatelessWidget {
  final int count;
  const _CartIcon({required this.count});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('cart'),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartView())),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
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

  int get _count => widget.banners.length + 1; // +1 for the built-in "Order Anything" card

  @override
  void initState() {
    super.initState();
    if (_count > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_controller.hasClients) {
          _controller.animateToPage((_page + 1) % _count, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
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
    final linkId = b['link_id'] is int ? b['link_id'] as int : int.tryParse('${b['link_id']}');
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
    String? pickLang(String key) => (ur && (b['${key}_ur'] ?? '').toString().isNotEmpty ? b['${key}_ur'] : b[key])?.toString();
    final ends = DateTime.tryParse('${b['ends_at']}')?.toLocal();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pickLang('title') ?? '', style: Theme.of(context).textTheme.titleLarge),
          if (pickLang('subtitle') != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(pickLang('subtitle')!)),
          if (ends != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Valid until ${ends.day}/${ends.month}/${ends.year}', style: const TextStyle(color: brandAccent)),
            ),
          if ((b['terms'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(b['terms'], style: const TextStyle(fontSize: 12, color: Colors.black54))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AspectRatio(
        aspectRatio: 2.3,
        child: PageView.builder(
          controller: _controller,
          itemCount: _count,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (ctx, i) => i == 0 ? const _OrderAnythingCard() : _BannerCard(banner: widget.banners[i - 1], onTap: () => _openBanner(widget.banners[i - 1])),
        ),
      ),
      if (_count > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_count, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == _page ? brandGreen : Colors.black26, borderRadius: BorderRadius.circular(3)),
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
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFFEAF7E4), Color(0xFFFFF6D8)]),
        border: Border.all(color: brandGreen.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            FittedBox(
              child: Text(context.tr('hero_title'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: brandPrimary)),
            ),
            const SizedBox(height: 2),
            Text(context.tr('hero_sub'), maxLines: 2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: brandPrimary)),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: brandPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketRequestView())),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: Text(context.tr('order_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        const Expanded(
          flex: 2,
          child: FittedBox(child: Text('🛵🛍️', style: TextStyle(fontSize: 56))),
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
    String? pick(String key) => (ur && (banner['${key}_ur'] ?? '').toString().isNotEmpty ? banner['${key}_ur'] : banner[key])?.toString();
    final hasImage = (banner['image_url'] ?? '').toString().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        color: brandYellowLight,
        child: InkWell(
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            if (hasImage) NetImage(banner['image_url']),
            if (!hasImage)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: brandAccent, borderRadius: BorderRadius.circular(6)),
                    child: Text((banner['kind'] ?? 'offer').toString().toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Text(pick('title') ?? '', maxLines: 2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: brandPrimary)),
                  if (pick('subtitle') != null) Text(pick('subtitle')!, maxLines: 2, style: const TextStyle(color: Colors.black87)),
                ]),
              ),
          ]),
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
  const _FeaturedCategoryCard({required this.category, required this.yellow, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final other = lang == 'ur' ? category.name : category.nameUr; // mockup shows both languages
    return Material(
      color: yellow ? brandYellowLight : brandGreenLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (yellow ? brandYellow : brandGreen).withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetImage(category.imageUrl, fallbackEmoji: categoryEmoji(category.name)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(category.displayName(lang),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brandPrimary)),
                if ((other ?? '').isNotEmpty)
                  Text(other!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: brandPrimary)),
                if (category.displaySubtitle(lang) != null)
                  Text(category.displaySubtitle(lang)!,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: yellow ? brandAccent : brandGreen)),
              ]),
            ),
            Icon(Icons.chevron_right, color: yellow ? brandAccent : brandGreen, textDirection: Directionality.of(context)),
          ]),
        ),
      ),
    );
  }
}

class _MarketShopping extends StatelessWidget {
  final List<Category> categories;
  final ValueChanged<Category> onTap;
  const _MarketShopping({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return _Panel(
      color: const Color(0xFFF1FAF7),
      borderColor: const Color(0xFFB9E4D3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.storefront, color: brandPrimary, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.tr('market_shopping'),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: brandPrimary)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: brandGreen,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              shape: const StadiumBorder(),
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(context.tr('how_it_works')),
                content: Text(context.tr('how_it_works_body')),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('ok')))],
              ),
            ),
            icon: const Icon(Icons.info_outline, size: 16),
            label: Text(context.tr('how_it_works'), style: const TextStyle(fontSize: 12)),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(context.tr('market_shopping_sub'), style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: brandPrimary, side: const BorderSide(color: brandGreen), backgroundColor: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketRequestView())),
              icon: const Icon(Icons.edit_note),
              label: Text(context.tr('write_list')),
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final c = categories[i];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 0.5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(c),
                  child: SizedBox(
                    width: 88,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(children: [
                        Expanded(child: NetImage(c.imageUrl, fit: BoxFit.contain, fallbackEmoji: categoryEmoji(c.name))),
                        Text(c.displayName(lang),
                            maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ProductStrip extends StatelessWidget {
  final Category category;
  final bool yellow;
  final VoidCallback onViewAll;
  const _ProductStrip({required this.category, this.yellow = false, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final accent = yellow ? brandAccent : brandGreen;
    return _Panel(
      color: yellow ? brandYellowLight : brandGreenLight,
      borderColor: (yellow ? brandYellow : brandGreen).withValues(alpha: 0.45),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(categoryEmoji(category.name), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${context.tr('our')} ${category.displayName(lang)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brandPrimary)),
          ),
          IconButton.filled(
            tooltip: context.tr('view_all'),
            style: IconButton.styleFrom(backgroundColor: accent, visualDensity: VisualDensity.compact),
            onPressed: onViewAll,
            icon: Icon(Icons.chevron_right, textDirection: Directionality.of(context)),
          ),
        ]),
        if (category.displaySubtitle(lang) != null)
          Text(category.displaySubtitle(lang)!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        if (category.products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(context.tr('no_products_yet'), style: const TextStyle(color: Colors.black54))),
          )
        else
          SizedBox(
            height: 216,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: category.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (ctx, i) => ProductCard(category.products[i], fallbackEmoji: categoryEmoji(category.name)),
            ),
          ),
      ]),
    );
  }
}

class _DealsStrip extends StatelessWidget {
  final List<Product> products;
  const _DealsStrip({required this.products});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: const Color(0xFFFFF1E6),
      borderColor: brandAccent.withValues(alpha: 0.35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_offer, color: brandAccent),
          const SizedBox(width: 6),
          Text(context.tr('deals_discounts'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brandPrimary)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (ctx, i) => ProductCard(products[i]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Delivery / repeat / trust

class _DeliveryCharges extends StatelessWidget {
  final List<Map<String, dynamic>> tiers;
  const _DeliveryCharges({required this.tiers});

  String _num(dynamic v) {
    final d = double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: brandGreenLight,
      borderColor: brandGreen.withValues(alpha: 0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_shipping_outlined, color: brandGreen, size: 26),
          const SizedBox(width: 8),
          Text(context.tr('delivery_charges'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brandPrimary)),
        ]),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _cell(context.tr('distance_km'), bold: true),
                _cell(context.tr('charge_rs'), bold: true),
              ],
            ),
            for (final t in tiers)
              TableRow(
                decoration: const BoxDecoration(color: Colors.white),
                children: [
                  _cell('${_num(t['min_km'])} – ${_num(t['max_km'])} KM'),
                  _cell('Rs. ${_num(t['charge'])}', bold: true),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.info_outline, size: 16, color: brandGreen),
          const SizedBox(width: 4),
          Expanded(child: Text(context.tr('delivery_note'), style: const TextStyle(fontSize: 11.5, color: brandPrimary))),
        ]),
      ]),
    );
  }

  Widget _cell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}

class _RepeatOrder extends StatelessWidget {
  const _RepeatOrder();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, Color color, String label, VoidCallback onTap) => Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: brandGreen.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                Icon(Icons.chevron_right, textDirection: Directionality.of(context)),
              ]),
            ),
          ),
        );

    return _Panel(
      color: brandGreenLight,
      borderColor: brandGreen.withValues(alpha: 0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.sync, color: brandGreen, size: 26),
          const SizedBox(width: 8),
          Text(context.tr('repeat_order'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brandPrimary)),
        ]),
        Text(context.tr('repeat_order_sub'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 10),
        tile(Icons.history, brandPrimary, context.tr('reorder_previous'), () => MainShell.switchTab(context, MainShell.orders)),
        const SizedBox(height: 8),
        tile(Icons.favorite_border, Colors.red, context.tr('favorites'), () => MainShell.switchTab(context, MainShell.favorites)),
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
      (Icons.support_agent, 'trust_support'),
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
                Text(context.tr(key), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
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
  const _Panel({required this.child, required this.color, required this.borderColor, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
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
        Icon(errorCode == 'network' ? Icons.wifi_off : Icons.cloud_off, size: 56, color: Colors.black38),
        const SizedBox(height: 12),
        Text(errorCode == 'network' ? context.tr('err_network') : context.tr('err_home'), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: Text(context.tr('retry'))),
      ]),
    );
  }
}
