import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../common/product_widgets.dart';

class FavoritesView extends StatefulWidget {
  const FavoritesView({super.key});

  @override
  State<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<FavoritesView> {
  List<Product>? _products;
  String? _errorCode;
  late int _loadedRevision;

  @override
  void initState() {
    super.initState();
    _loadedRevision = context.read<AppState>().favoritesRevision;
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/me/favorites');
    if (!mounted) return;
    setState(() {
      _errorCode = res.ok ? null : (res.errorCode ?? 'generic');
      if (res.ok) {
        _products = (res.data as List).map((p) => Product.fromJson(p)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reload after a favorite is added/removed anywhere and the server has saved it.
    final revision = context.select<AppState, int>((s) => s.favoritesRevision);
    if (revision != _loadedRevision) {
      _loadedRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(context.tr('favorites')),
          automaticallyImplyLeading: false),
      body: _body(),
    );
  }

  Widget _body() {
    if (_errorCode != null && _products == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(friendlyError(context, errorCode: _errorCode)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: Text(context.tr('retry'))),
        ]),
      );
    }
    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products!.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 120),
          const Icon(Icons.favorite_border, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          Text(context.tr('favorites_empty'), textAlign: TextAlign.center),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, mainAxisExtent: 240),
        itemCount: _products!.length,
        itemBuilder: (ctx, i) =>
            ProductCard(_products![i], width: double.infinity),
      ),
    );
  }
}
