import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../cart/cart_view.dart';
import '../common/product_widgets.dart';

/// A partner shop or restaurant (e.g. Faridullah Fish) whose items customers
/// order through Grozo. Our rider collects the order at the partner's shop.
class Partner {
  final int id;
  final String name;
  final String? nameUr;
  final String? kind;
  final String? kindUr;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final bool comingSoon;
  final int productCount;

  const Partner({
    required this.id,
    required this.name,
    this.nameUr,
    this.kind,
    this.kindUr,
    this.logoUrl,
    this.address,
    this.phone,
    this.comingSoon = false,
    this.productCount = 0,
  });

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        nameUr: j['name_ur']?.toString(),
        kind: j['kind']?.toString(),
        kindUr: j['kind_ur']?.toString(),
        logoUrl: j['logo_url']?.toString(),
        address: j['address']?.toString(),
        phone: j['phone']?.toString(),
        comingSoon: j['coming_soon'] == 1 || j['coming_soon'] == true,
        productCount: (j['product_count'] as num?)?.toInt() ?? 0,
      );

  String displayName(String lang) =>
      lang == 'ur' && (nameUr ?? '').isNotEmpty ? nameUr! : name;
  String? displayKind(String lang) =>
      lang == 'ur' && (kindUr ?? '').isNotEmpty ? kindUr : kind;
}

void openPartner(BuildContext context, Partner p) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => PartnerView(partner: p)));

/// Logo, name and kind ("Restaurant") – the card in "Order from our partners".
class PartnerCard extends StatelessWidget {
  final Partner partner;
  const PartnerCard(this.partner, {super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE3E7E3))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openPartner(context, partner),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(fit: StackFit.expand, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: (partner.logoUrl ?? '').isEmpty
                        ? Container(
                            color: brandGreenLight,
                            child: Center(
                              child: Text(
                                  partner.name.isEmpty
                                      ? '?'
                                      : partner.name[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: brandPrimary)),
                            ),
                          )
                        : NetImage(partner.logoUrl, fallbackEmoji: '🏪'),
                  ),
                  if (partner.comingSoon)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: const BoxDecoration(
                          color: Color(0xE6E91E63),
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(14)),
                        ),
                        child: Text(context.tr('soon'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Text(partner.displayName(lang).toUpperCase(),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: brandPrimary)),
            if ((partner.displayKind(lang) ?? '').isNotEmpty)
              Text(partner.displayKind(lang)!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      color: brandGreen,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// "View all" partners.
class PartnersView extends StatelessWidget {
  final List<Partner> partners;
  const PartnersView({super.key, required this.partners});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('order_from_partners'))),
        body: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.8),
          itemCount: partners.length,
          itemBuilder: (_, i) => PartnerCard(partners[i]),
        ),
      );
}

/// One partner: its details and all its items with prices.
class PartnerView extends StatefulWidget {
  final Partner partner;
  const PartnerView({super.key, required this.partner});

  @override
  State<PartnerView> createState() => _PartnerViewState();
}

class _PartnerViewState extends State<PartnerView> {
  late Partner _partner = widget.partner;
  List<Product>? _products;
  String? _errorCode;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/partners/${widget.partner.id}');
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        final d = Map<String, dynamic>.from(res.data);
        _partner = Partner.fromJson(d);
        _products = (d['products'] as List? ?? [])
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        _errorCode = null;
      } else {
        _errorCode = res.errorCode ?? 'generic';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final p = _partner;
    final f = _filter.toLowerCase();
    final items = (_products ?? [])
        .where((x) =>
            f.isEmpty ||
            '${x.name} ${x.nameUr ?? ''}'.toLowerCase().contains(f))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(p.displayName(lang)),
        actions: [
          IconButton(
            tooltip: context.tr('cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CartView())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _header(p, lang)),
          if (p.comingSoon)
            SliverFillRemaining(
              hasScrollBody: false,
              child:
                  _message(Icons.schedule, context.tr('partner_coming_soon')),
            )
          else if (_products == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _errorCode == null
                  ? const Center(child: CircularProgressIndicator())
                  : _message(Icons.cloud_off,
                      friendlyError(context, errorCode: _errorCode),
                      retry: _load),
            )
          else if (_products!.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _message(
                  Icons.inventory_2_outlined, context.tr('partner_no_items')),
            )
          else ...[
            if (_products!.length > 8)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: TextField(
                    decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        hintText: context.tr('search_hint')),
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisExtent: 250,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ProductCard(items[i],
                      width: double.infinity, fallbackEmoji: '🍽️'),
                  childCount: items.length,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _header(Partner p, String lang) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: brandGreenLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: brandGreen.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NetImage(p.logoUrl, fallbackEmoji: '🏪'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayName(lang),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: brandPrimary)),
                    if ((p.displayKind(lang) ?? '').isNotEmpty)
                      Text(p.displayKind(lang)!,
                          style: const TextStyle(
                              color: brandGreen, fontWeight: FontWeight.w600)),
                    if ((p.address ?? '').isNotEmpty)
                      Text(p.address!,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.black54)),
                  ]),
            ),
            if ((p.phone ?? '').isNotEmpty)
              IconButton(
                tooltip: context.tr('call_order'),
                icon: const Icon(Icons.call, color: brandPrimary),
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: p.phone!.trim())),
              ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 16, color: brandPrimary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(context.tr('partner_separate_order'),
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ),
          ]),
        ]),
      );

  Widget _message(IconData icon, String text, {VoidCallback? retry}) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 52, color: Colors.black26),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (retry != null)
            TextButton(onPressed: retry, child: Text(context.tr('retry'))),
        ]),
      );
}
