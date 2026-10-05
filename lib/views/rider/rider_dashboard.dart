import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../controllers/order_service.dart';
import '../../controllers/location_service.dart';
import '../common/more_menu.dart';
import '../staff/order_info.dart';
import '../../models/order.dart';

class RiderDashboard extends StatefulWidget {
  final UserModel user;
  const RiderDashboard({super.key, required this.user});
  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  List<dynamic> _activeAssignments = [];
  Map<String, dynamic> _report = {'count': 0, 'total': 0};
  final LocationService _loc = LocationService();
  // One "cash collected" field per order.
  final Map<dynamic, TextEditingController> _amounts = {};

  TextEditingController _amountFor(Map o) => _amounts.putIfAbsent(o['id'], () {
        final order = Order.fromJson(
            Map<String, dynamic>.from(o)..putIfAbsent('items', () => const []));
        // Pre-fill the known total; market requests / unknown delivery charge must be entered.
        return TextEditingController(
            text: order.totalPending ? '' : order.amount.toStringAsFixed(0));
      });

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _loadManifest();
    _loadReports();
  }

  void _loadManifest() async {
    final data = await OrderService.fetchOrdersByRole('rider', widget.user.id);
    if (!mounted) return;
    setState(() => _activeAssignments = data);
    // Resume live location after the app was closed during a delivery.
    final inTransit =
        data.where((o) => o['status'] == 'In the way').firstOrNull;
    if (inTransit != null) {
      _loc.startTrackingRider(inTransit['id'], widget.user.id);
    } else {
      _loc.stopTracking();
    }
  }

  void _loadReports() async {
    final data = await OrderService.fetchReports(widget.user.id, 'rider');
    if (mounted) setState(() => _report = data);
  }

  void _logout() => confirmLogout(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('Rider Workspace'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Deliveries'), Tab(text: 'My Reports')],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
              IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ]),
        body: TabBarView(
          children: [
            // Tab 1: Deliveries
            RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: _activeAssignments.isEmpty
                  ? const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 400,
                        child: Center(
                            child: Text("No active deliveries assigned.")),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _activeAssignments.length,
                      itemBuilder: (_, idx) {
                        final o = _activeAssignments[idx];
                        // Extract date from assigned_at or created_at
                        String dateStr = "N/A";
                        final rawDate = o['assigned_at'] ?? o['created_at'];
                        if (rawDate != null) {
                          try {
                            final dt = DateTime.parse(rawDate);
                            dateStr = "${dt.day}/${dt.month}/${dt.year}";
                          } catch (_) {}
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Icon(Icons.person,
                                          color: theme.colorScheme.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            o['customer_name'] ??
                                                'Unknown Customer',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Text('Assigned: $dateStr',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary
                                            .withValues(alpha: 0.1),
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
                                StaffOrderInfo(Map<String, dynamic>.from(o)),
                                const SizedBox(height: 16),
                                if (o['status'] == 'Dispatched')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await OrderService.updateStatus(
                                            o['id'], 'In the way');
                                        final sharing =
                                            await _loc.startTrackingRider(
                                                o['id'], widget.user.id);
                                        if (!sharing && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                'Turn on location (GPS) so the customer can follow the delivery.'),
                                          ));
                                        }
                                        _refresh();
                                      },
                                      icon: const Icon(Icons.directions_bike),
                                      label: const Text('START TRANSIT'),
                                    ),
                                  ),
                                if (o['status'] == 'In the way') ...[
                                  TextField(
                                    controller: _amountFor(o),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Final Cash Collected (PKR)',
                                      prefixText: 'PKR ',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final amount = double.tryParse(
                                            _amountFor(o).text.trim());
                                        if (amount == null) {
                                          // Replace any earlier message so this one shows at once.
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Enter the total cash collected from the customer.')),
                                            );
                                          return;
                                        }
                                        _loc.stopTracking();
                                        await OrderService.updateStatus(
                                            o['id'], 'Delivered',
                                            amount: amount);
                                        _amounts.remove(o['id'])?.dispose();
                                        _refresh();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.secondary,
                                      ),
                                      icon: const Icon(
                                          Icons.check_circle_outline),
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
            // Tab 2: Reports
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('Earnings & Performance',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  _buildReportCard(
                      'Finalized Orders',
                      _report['count'].toString(),
                      Icons.done_all,
                      Colors.green),
                  const SizedBox(height: 20),
                  _buildReportCard('Total Cash Handled',
                      'PKR ${_report['total']}', Icons.payments, Colors.orange),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
      String title, String val, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color)),
            const SizedBox(width: 20),
            // Takes the remaining width; large amounts or phone font sizes shrink to fit.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(val,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
