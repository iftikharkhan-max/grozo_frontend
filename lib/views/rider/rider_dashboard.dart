import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../controllers/order_service.dart';
import '../../controllers/location_service.dart';
import '../auth/login_view.dart'; // Required for signout

class RiderDashboard extends StatefulWidget {
  final UserModel user;
  const RiderDashboard({super.key, required this.user});
  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  List<dynamic> _activeAssignments = [];
  final LocationService _loc = LocationService();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  void _loadManifest() async {
    final data = await OrderService.fetchOrdersByRole('rider', widget.user.id);
    setState(() => _activeAssignments = data);
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginView()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          title: const Text('Rider Delivery Manifest'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadManifest),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ]
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadManifest();
        },
        child: _activeAssignments.isEmpty
            ? const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: Center(child: Text("No active deliveries assigned.")),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _activeAssignments.length,
                itemBuilder: (_, idx) {
                  final o = _activeAssignments[idx];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.person, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o['customer_name'] ?? 'Unknown Customer',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      'Mob: ${o['customer_mobile'] ?? 'N/A'}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  o['status'],
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Destination: ${o['destination'] ?? 'Not Provided'}',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (o['status'] == 'Dispatched')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await OrderService.updateStatus(o['id'], 'In the way');
                                  _loc.startTrackingRider(o['id'], widget.user.id);
                                  _loadManifest();
                                },
                                icon: const Icon(Icons.directions_bike),
                                label: const Text('START TRANSIT'),
                              ),
                            ),
                          if (o['status'] == 'In the way') ...[
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cash to Collect (PKR)',
                                prefixText: 'PKR ',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (_amountController.text.isNotEmpty) {
                                    _loc.stopTracking();
                                    await OrderService.updateStatus(o['id'], 'Delivered', amount: double.parse(_amountController.text));
                                    _amountController.clear();
                                    _loadManifest();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondary,
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('CONFIRM DELIVERY'),
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}