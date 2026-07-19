import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/user_model.dart';
import '../../controllers/order_service.dart';
import '../../utils/constants.dart';
import '../auth/login_view.dart'; // Required for Sign-out

class CustomerDashboard extends StatefulWidget {
  final UserModel user;
  const CustomerDashboard({super.key, required this.user});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  List<dynamic> _orders = [];
  List<dynamic> _managers = [];
  WebSocketChannel? _channel;
  String _liveTrackingText = "No active transit delivery broadcasted.";

  // Controllers for the fresh order generation sheet
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadManagers();
    _connectWebSocket();
  }

  void _loadOrders() async {
    final data = await OrderService.fetchOrdersByRole('customer', widget.user.id);
    if (mounted) setState(() => _orders = data);
  }

  void _loadManagers() async {
    final data = await OrderService.fetchUsersByRole('Manager');
    if (mounted) setState(() => _managers = data);
  }

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse(Config.wsUrl));
    _channel!.stream.listen((msg) {
      final Map<String, dynamic> data = jsonDecode(msg);
      if (data['type'] == 'LOCATION_UPDATE') {
        if (mounted) {
          setState(() => _liveTrackingText = "Rider Live Coordinates -> Lat: ${data['lat']}, Lng: ${data['lng']}");
        }
      }
    });
  }

  void _redirectToWhatsApp() async {
    if (_managers.isEmpty) {
      // Try to load again
      _loadManagers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching support managers... please try again in a moment.')),
      );
      
      // If still empty, use a default support number as a fallback
      Future.delayed(const Duration(seconds: 1), () async {
        if (_managers.isEmpty) {
          final Uri url = Uri.parse("https://wa.me/923001234567"); // Default Support
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        }
      });
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select a Manager to Order'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _managers.length,
            itemBuilder: (context, index) {
              final manager = _managers[index];
              return ListTile(
                title: Text(manager['name']),
                subtitle: Text(manager['mobile'] ?? 'N/A'),
                onTap: () async {
                  Navigator.pop(context);
                  String phone = manager['mobile'] ?? '923001234567';
                  phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
                  if (!phone.startsWith('92')) {
                    if (phone.startsWith('0')) {
                      phone = '92${phone.substring(1)}';
                    } else {
                      phone = '92$phone';
                    }
                  }
                  final Uri url = Uri.parse("https://wa.me/$phone");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginView()), (route) => false);
  }

  void _showCreateOrderBottomSheet({dynamic orderToEdit}) {
    if (orderToEdit != null) {
      _addressController.text = orderToEdit['destination'] ?? '';
      _amountController.text = orderToEdit['amount'].toString();
      // Items handling could be more complex, but for now we take the first one
      final items = jsonDecode(orderToEdit['items_json'] ?? '[]');
      if (items.isNotEmpty) {
        _itemController.text = items[0]['name'] ?? '';
        _qtyController.text = items[0]['qty']?.toString() ?? '1';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(orderToEdit == null ? 'Place a New Order' : 'Edit Order', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: _itemController, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: _qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Delivery Destination')),
            TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Collect Amount (PKR)')),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () async {
                if (_addressController.text.isEmpty || _amountController.text.isEmpty || _itemController.text.isEmpty) return;

                final double? amount = double.tryParse(_amountController.text);
                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount format.')));
                  return;
                }

                bool success;
                if (orderToEdit == null) {
                  success = await OrderService.createOrder(
                      customerId: widget.user.id,
                      address: _addressController.text,
                      amount: amount,
                      items: [{'name': _itemController.text, 'qty': _qtyController.text}]
                  );
                } else {
                  success = await OrderService.editOrder(
                      orderId: orderToEdit['id'],
                      address: _addressController.text,
                      amount: amount,
                      items: [{'name': _itemController.text, 'qty': _qtyController.text}]
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Action completed!' : 'Action failed.')),
                  );
                }
                _loadOrders();

                _itemController.clear();
                _addressController.clear();
                _amountController.clear();
                _qtyController.text = '1';
              },
              child: Text(orderToEdit == null ? 'Submit Order Request' : 'Update Order'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _cancelOrder(dynamic orderId) async {
    final success = await OrderService.cancelOrder(orderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Order canceled.' : 'Cancel failed.')),
      );
    }
    _loadOrders();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
    Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text('Welcome, ${widget.user.name}'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ]
      ),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.secondary.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: Row(
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _liveTrackingText,
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('New Order'),
                    onPressed: _showCreateOrderBottomSheet,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // WhatsApp brand color usually kept
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.phone),
                    label: const Text('Support'),
                    onPressed: _redirectToWhatsApp,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadOrders();
              },
              child: _orders.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            const Text("No tracking orders found.", style: TextStyle(color: Colors.grey)),
                            const Text("Pull down to refresh", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _orders.length,
                      itemBuilder: (context, idx) {
                        final o = _orders[idx];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              child: Icon(Icons.local_shipping, color: theme.colorScheme.primary),
                            ),
                            title: Text(
                              'Order: ${o['tracking_number'] ?? 'PENDING'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Status: ${o['status']}\nDestination: ${o['destination'] ?? "N/A"}\nAmount: PKR ${o['amount']}',
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                            trailing: (o['status'] ?? '').toString().toLowerCase().trim() == 'delivered'
                                ? ElevatedButton(
                              onPressed: () async {
                                await OrderService.updateStatus(o['id'], 'Complete');
                                _loadOrders();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                backgroundColor: theme.colorScheme.secondary,
                              ),
                              child: const Text('Receive', style: TextStyle(fontSize: 12)),
                            )
                                : (o['status'] ?? '').toString().toLowerCase().trim() == 'order placed'
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _showCreateOrderBottomSheet(orderToEdit: o),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.red),
                                          onPressed: () => _cancelOrder(o['id']),
                                        ),
                                      ],
                                    )
                                  : null,
                          ),
                        );
                      },
                    ),
            ),
          )
        ],
      ),
    );
  }
}