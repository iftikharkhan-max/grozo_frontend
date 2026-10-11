import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/staff_alerts.dart';
import '../../controllers/order_service.dart';
import '../common/more_menu.dart';
import '../staff/order_info.dart';
import 'edit_order_view.dart';
import 'phone_order_view.dart';

/// Newest order first (spec 12).
List<dynamic> newestFirst(List<dynamic> orders) => [...orders]..sort((a, b) {
    final ta = DateTime.tryParse('${a['created_at']}');
    final tb = DateTime.tryParse('${b['created_at']}');
    if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
    return ((b['id'] as num?) ?? 0).compareTo((a['id'] as num?) ?? 0);
  });

/// Orange "Change requested" label when the customer asked to change the order.
Widget changeRequestedChip(Map o) => ((o['pending_changes'] as num?) ?? 0) > 0
    ? Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(6)),
        child: Text('✏️ Change requested by customer',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900)),
      )
    : const SizedBox.shrink();

class ManagerDashboard extends StatefulWidget {
  final UserModel user;
  const ManagerDashboard({super.key, required this.user});
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  List<dynamic> _pool = [];
  List<dynamic> _myWorkspace = [];
  List<dynamic> _riders = [];
  Map<String, dynamic> _report = {'count': 0, 'total': 0};
  Map<dynamic, dynamic> _selectedRiders = {};

  late final StaffAlerts _alerts =
      StaffAlerts(userId: widget.user.id, onNewAlerts: _refreshAll);
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    // New orders ring and refresh the lists; lists also refresh on their own.
    _alerts.start();
    _autoRefresh =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshAll());
  }

  @override
  void dispose() {
    _alerts.stop();
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _editOrder(Map o) async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => EditOrderView(orderId: o['id'])));
    if (saved == true) _refreshAll();
  }

  /// Spec 14: give a dispatched order to another rider.
  Future<void> _changeRider(Map o) async {
    final others =
        _riders.where((r) => r['id'] != o['delivery_agent_id']).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other riders available.')));
      return;
    }
    dynamic picked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Change rider for ${o['tracking_number']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Current rider: ${o['rider_name'] ?? 'none'}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<dynamic>(
              isExpanded: true,
              initialValue: picked,
              decoration: const InputDecoration(labelText: 'New rider'),
              items: [
                for (final r in others)
                  DropdownMenuItem(
                      value: r['id'],
                      child: Text("${r['name']} (${r['mobile'] ?? ''})",
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setDialog(() => picked = v),
            ),
            const SizedBox(height: 8),
            const Text(
                'The new rider is alerted; the previous rider is told the order is no longer theirs.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed:
                    picked == null ? null : () => Navigator.pop(ctx, true),
                child: const Text('Reassign')),
          ],
        ),
      ),
    );
    if (ok != true || picked == null || !mounted) return;
    final done = await OrderService.dispatchToRider(o['id'], picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(done ? 'Rider changed.' : 'Could not change the rider.')));
    _refreshAll();
  }

  void _refreshAll() async {
    final poolData = await OrderService.fetchGlobalPool();
    final workspaceData =
        await OrderService.fetchOrdersByRole('manager', widget.user.id);
    final reportData =
        await OrderService.fetchReports(widget.user.id, 'manager');

    var ridersData = await OrderService.fetchUsersByRole('rider');
    if (ridersData.isEmpty) {
      ridersData = await OrderService.fetchUsersByRole('Rider');
    }

    if (mounted) {
      setState(() {
        _pool = newestFirst(poolData);
        _myWorkspace = newestFirst(workspaceData);
        _riders = ridersData;
        _report = reportData;
      });
    }
  }

  void _logout() => confirmLogout(context);

  Future<void> _openPhoneOrder() async {
    final created = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const PhoneOrderView()));
    if (created == true) _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manager Workspace'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pool'),
              Tab(text: 'My Tasks'),
              Tab(text: 'Reports')
            ],
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
                tooltip: 'New phone order',
                icon: const Icon(Icons.add_call),
                onPressed: _openPhoneOrder),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Global Pool
            RefreshIndicator(
              onRefresh: () async => _refreshAll(),
              child: _pool.isEmpty
                  ? const Center(child: Text("Global pool is empty."))
                  : ListView.builder(
                      itemCount: _pool.length,
                      itemBuilder: (_, idx) {
                        final o = _pool[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ExpansionTile(
                            title: Text(
                                'Ref: ${o['tracking_number']}${o['order_source'] == 'phone' ? '  •  📞 PHONE' : ''}${o['order_type'] == 'market_request' ? '  •  MARKET' : ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${o['customer_name'] ?? ''} • ${o['destination'] ?? 'N/A'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  changeRequestedChip(o),
                                ]),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                await OrderService.claimOrder(
                                    o['id'], widget.user.id);
                                _refreshAll();
                              },
                              child: const Text('Claim'),
                            ),
                            children: [
                              StaffOrderInfo(Map<String, dynamic>.from(o))
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Tab 2: My Workspace
            RefreshIndicator(
              onRefresh: () async => _refreshAll(),
              child: _myWorkspace.isEmpty
                  ? const Center(child: Text("No active orders in workspace."))
                  : ListView.builder(
                      itemCount: _myWorkspace.length,
                      itemBuilder: (_, idx) {
                        final o = _myWorkspace[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                          'Order: ${o['tracking_number']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(o['status'] ?? 'Unknown',
                                        style: TextStyle(
                                            color: theme.colorScheme.secondary,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                changeRequestedChip(o),
                                const Divider(),
                                StaffOrderInfo(Map<String, dynamic>.from(o)),
                                if (o['rider_name'] != null &&
                                    o['rider_name'] != 'Unassigned')
                                  Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(children: [
                                        Expanded(
                                            child: Text(
                                                'Rider: ${o['rider_name']}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600))),
                                        if (['Dispatched', 'In the way']
                                            .contains(o['status']))
                                          TextButton.icon(
                                            onPressed: () => _changeRider(o),
                                            icon: const Icon(Icons.swap_horiz,
                                                size: 18),
                                            label: const Text('Change rider'),
                                          ),
                                      ])),
                                if (o['status'] == 'Order Placed')
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _editOrder(o),
                                      icon: const Icon(Icons.edit_note),
                                      label: Text(
                                          ((o['pending_changes'] as num?) ??
                                                      0) >
                                                  0
                                              ? 'Review change request'
                                              : 'Edit order'),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                if ([
                                  'order placed',
                                  'with manager',
                                  'claimed'
                                ].contains(
                                    o['status'].toString().toLowerCase())) ...[
                                  if (_riders.isEmpty)
                                    const Text("No riders available.",
                                        style: TextStyle(color: Colors.red))
                                  else
                                    DropdownButtonFormField<dynamic>(
                                      initialValue: _selectedRiders[o['id']],
                                      // Long rider names/numbers must not overflow the card.
                                      isExpanded: true,
                                      items: _riders
                                          .map<DropdownMenuItem<dynamic>>((r) {
                                        return DropdownMenuItem<dynamic>(
                                          value: r['id'],
                                          child: Text(
                                              "${r['name']} (${r['mobile'] ?? ''})",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (v) => setState(
                                          () => _selectedRiders[o['id']] = v),
                                      decoration: const InputDecoration(
                                          labelText: 'Assign Rider'),
                                    ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _riders.isEmpty
                                          ? null
                                          : () async {
                                              if (_selectedRiders[o['id']] !=
                                                  null) {
                                                await OrderService
                                                    .dispatchToRider(
                                                        o['id'],
                                                        _selectedRiders[
                                                            o['id']]);
                                                _refreshAll();
                                              }
                                            },
                                      child: const Text('DISPATCH'),
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
            // Tab 3: Reports
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('Workspace Performance',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  _buildReportItem(
                      'Orders Completed',
                      _report['count'].toString(),
                      Icons.check_circle,
                      Colors.indigo),
                  const SizedBox(height: 20),
                  _buildReportItem('Volume Handled', 'PKR ${_report['total']}',
                      Icons.trending_up, Colors.green),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(label, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
