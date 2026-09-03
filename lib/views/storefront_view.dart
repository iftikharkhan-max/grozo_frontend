import 'package:flutter/material.dart';
import 'auth/login_view.dart';
import 'auth/signup_view.dart';
import '../controllers/product_service.dart';
import '../controllers/order_service.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';
import 'customer/customer_dashboard.dart';

class StorefrontView extends StatefulWidget {
  final UserModel? user;
  const StorefrontView({super.key, this.user});
  @override
  State<StorefrontView> createState() => _StorefrontViewState();
}

class _StorefrontViewState extends State<StorefrontView> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  
  // Cart: Map of product ID to quantity
  final Map<dynamic, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final data = await ProductService.fetchCatalog();
    if (mounted) {
      setState(() {
        _products = data;
        _isLoading = false;
      });
    }
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return 'https://via.placeholder.com/150';
    if (path.startsWith('http')) return path;
    return '${Config.rootUrl}$path';
  }

  void _addToCart(dynamic productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart'), duration: Duration(seconds: 1)),
    );
  }

  double get _cartTotal {
    double total = 0;
    _cart.forEach((id, qty) {
      final p = _products.firstWhere(
        (element) => element['id'].toString() == id.toString(), 
        orElse: () => null
      );
      if (p != null) {
        final rawPrice = p['price'];
        double price = 0.0;
        if (rawPrice is num) {
          price = rawPrice.toDouble();
        } else if (rawPrice is String) {
          price = double.tryParse(rawPrice) ?? 0.0;
        }
        total += price * qty;
      }
    });
    return total;
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Shopping Cart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: _cart.isEmpty
                  ? const Center(child: Text('Cart is empty'))
                  : ListView(
                      children: _cart.entries.map((entry) {
                        final p = _products.firstWhere((element) => element['id'].toString() == entry.key.toString());
                        return ListTile(
                          title: Text(p['name']),
                          subtitle: Text('PKR ${p['price']} x ${entry.value}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  setModalState(() {
                                    if (_cart[entry.key]! > 1) {
                                      _cart[entry.key] = _cart[entry.key]! - 1;
                                    } else {
                                      _cart.remove(entry.key);
                                    }
                                  });
                                  setState(() {});
                                },
                              ),
                              Text('${entry.value}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  setModalState(() {
                                    _cart[entry.key] = _cart[entry.key]! + 1;
                                  });
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('PKR ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cart.isEmpty ? null : () => _checkout(ctx),
                  child: const Text('PROCEED TO CHECKOUT'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _checkout(BuildContext modalContext) async {
    if (widget.user == null) {
      Navigator.pop(modalContext);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to place an order')));
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginView()));
      return;
    }

    final items = _cart.entries.map((entry) {
      final p = _products.firstWhere((element) => element['id'].toString() == entry.key.toString());
      return {'name': p['name'], 'qty': entry.value, 'price': p['price']};
    }).toList();

    final success = await OrderService.createOrder(
      customerId: widget.user!.id,
      address: widget.user!.address ?? 'Default Address',
      amount: _cartTotal,
      items: items,
    );

    if (success) {
      setState(() => _cart.clear());
      if (mounted) {
        Navigator.pop(modalContext);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to place order')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grozo Store'),
        leading: widget.user != null 
          ? IconButton(
              icon: const Icon(Icons.account_circle), 
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDashboard(user: widget.user!))),
              tooltip: 'Profile & Orders',
            )
          : null,
        actions: [
          if (widget.user == null) ...[
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginView())),
              child: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupView())),
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: Colors.white),
              child: const Text('Sign Up'),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const StorefrontView()), (route) => false),
            ),
          ],
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.shopping_cart), onPressed: _showCart),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('${_cart.length}', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                  ),
                )
            ],
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProducts,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
            ? const Center(child: Text('No products available yet.'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final p = _products[index];
                  final pId = p['id'];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Image.network(
                              _getImageUrl(p['image_url']),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] ?? 'Unknown Item',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'PKR ${p['price']}',
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _addToCart(pId),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
