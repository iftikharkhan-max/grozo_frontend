import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/user_model.dart';
import '../../controllers/order_service.dart';
import '../../controllers/auth_service.dart';
import '../../utils/constants.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../common/more_menu.dart';
import '../routing.dart';

class CustomerDashboard extends StatefulWidget {
  final UserModel user;

  /// True when shown as the "My Orders" footer tab (no back button).
  final bool embedded;
  const CustomerDashboard({super.key, required this.user, this.embedded = false});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  List<dynamic> _orders = [];
  WebSocketChannel? _channel;
  String _liveTrackingText = "No active transit delivery broadcasted.";

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _connectWebSocket();
  }

  Future<void> _loadOrders() async {
    final data = await OrderService.fetchOrdersByRole('customer', widget.user.id);
    if (mounted) setState(() => _orders = data);
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

  void _logout() => confirmLogout(context);

  void _confirmDeleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('Are you sure you want to delete your account? Your past order history will remain, but you will not be able to log in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final success = await AuthService.deleteAccount(widget.user.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted successfully.')));
          await context.read<AppState>().signOutLocally();
          if (mounted) goToStoreHome(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete account.')));
        }
      }
    }
  }

  void _markAsReceived(dynamic orderId) async {
    final success = await OrderService.updateStatus(orderId, 'Complete');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Order marked as Complete!' : 'Update failed.')),
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
    
    // Separate active tracking orders from history
    final activeOrders = _orders.where((o) => 
      ['order placed', 'dispatched', 'in the way', 'delivered'].contains(o['status'].toString().toLowerCase().trim())
    ).toList();
    
    final historyOrders = _orders.where((o) => 
      o['status'].toString().toLowerCase().trim() == 'complete'
    ).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: const Text('My Orders'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Tracking'), Tab(text: 'History')],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'delete') _confirmDeleteAccount();
                  if (val == 'logout') _logout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'logout', child: Text('Logout')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Account', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
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
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Tracking
                  _buildOrderList(activeOrders, theme, isTracking: true),
                  // Tab 2: History
                  _buildOrderList(historyOrders, theme, isTracking: false),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> orders, ThemeData theme, {required bool isTracking}) {
    if (orders.isEmpty) {
      return Center(child: Text(isTracking ? "No active orders." : "No previous orders."));
    }
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, idx) {
        final o = orders[idx];
        final status = (o['status'] ?? '').toString().toLowerCase().trim();
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text('Order: ${o['tracking_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: ${o['status']}\nAmt: PKR ${o['amount']}'),
            trailing: status == 'delivered' 
              ? ElevatedButton(
                  onPressed: () => _markAsReceived(o['id']),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text('Mark Received', style: TextStyle(fontSize: 10)),
                )
              : null,
          ),
        );
      },
    );
  }
}
