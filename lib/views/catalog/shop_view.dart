import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';
import 'market_view.dart';
import 'product_list_view.dart';

/// "Online Order" starting point: every category plus Market Shopping.
class ShopView extends StatefulWidget {
  const ShopView({super.key});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> {
  List<Category>? _categories;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/categories');
    if (!mounted) return;
    setState(() {
      _errorCode = res.ok ? null : (res.errorCode ?? 'generic');
      if (res.ok) {
        _categories =
            (res.data as List).map((c) => Category.fromJson(c)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('shop_all'))),
      body: _categories == null
          ? Center(
              child: _errorCode == null
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _load, child: Text(context.tr('retry'))),
            )
          : ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                color: brandGreenLight,
                child: ListTile(
                  leading: const Icon(Icons.storefront,
                      color: brandPrimary, size: 32),
                  title: Text(context.tr('market_shopping'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(context.tr('not_in_list')),
                  trailing: Icon(Icons.chevron_right,
                      textDirection: Directionality.of(context)),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MarketView())),
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: [
                  for (final c in _categories!)
                    Material(
                      color: c.group == 'featured'
                          ? brandYellowLight
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 0.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProductListView(category: c))),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(children: [
                            Expanded(
                                child: NetImage(c.imageUrl,
                                    fit: BoxFit.contain,
                                    fallbackEmoji: categoryEmoji(c.name))),
                            const SizedBox(height: 4),
                            Text(c.displayName(lang),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5)),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ]),
    );
  }
}
