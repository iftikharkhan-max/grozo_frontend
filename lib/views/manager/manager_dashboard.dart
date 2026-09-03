import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../controllers/order_service.dart';
import '../storefront_view.dart';

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
  List<dynamic> _customers = []; 
  Map<String, dynamic> _report = {'count': 0, 'total': 0};
  Map<dynamic, dynamic> _selectedRiders = {};

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() async {
    final poolData = await OrderService.fetchGlobalPool();
    final workspaceData = await OrderService.fetchOrdersByRole('manager', widget.user.id);
    final reportData = await OrderService.fetchReports(widget.user.id, 'manager');

    var ridersData = await OrderService.fetchUsersByRole('rider');
    if (ridersData.isEmpty) ridersData = await OrderService.fetchUsersByRole('Rider');
    
    var customersData = await OrderService.fetchUsersByRole('customer');
    if (customersData.isEmpty) customersData = await OrderService.fetchUsersByRole('Customer');

    if (mounted) {
      setState(() {
        _pool = poolData;
        _myWorkspace = workspaceData;
        _riders = ridersData;
        _customers = customersData;
        _report = reportData;
      });
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const StorefrontView()), (route) => false);
  }

  void _createOnBehalfDialog() {
    dynamic selectedCustomerId;
    final address = TextEditingController();
    final amount = TextEditingController();
    final item = TextEditingController();

    showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Phone Order Creation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_customers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text("Loading customers...", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    DropdownButtonFormField<dynamic>(
                      initialValue: selectedCustomerId,
                      hint: const Text('Select Customer'),
                      items: _customers.map<DropdownMenuItem<dynamic>>((c) {
                        final name = c['name'] ?? 'Unknown';
                        final id = c['id'];
                        return DropdownMenuItem<dynamic>(
                          value: id,
                          child: Text("$name (ID: $id)"),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedCustomerId = v;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Customer Account'),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: item, decoration: const InputDecoration(labelText: 'Item Name')),
                  TextField(controller: address, decoration: const InputDecoration(labelText: 'Delivery Destination')),
                  TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order Amount (PKR)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCustomerId == null || item.text.isEmpty) return;
                  await OrderService.createOrder(
                      customerId: int.parse(selectedCustomerId.toString()),
                      address: address.text,
                      amount: double.tryParse(amount.text) ?? 0.0,
                      items: [{'name': item.text, 'qty': 1}],
                      managerId: widget.user.id
                  );
                  if (mounted) Navigator.pop(dialogContext);
                  _refreshAll();
                },
                child: const Text('Create Order'),
              )
            ],
          ),
        )
    );
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
            tabs: [Tab(text: 'Pool'), Tab(text: 'My Tasks'), Tab(text: 'Reports')],
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.add_call), onPressed: _createOnBehalfDialog),
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
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text('Ref: ${o['tracking_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Dest: ${o['destination'] ?? 'N/A'}'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await OrderService.claimOrder(o['id'], widget.user.id);
                          _refreshAll();
                        },
                        child: const Text('Claim'),
                      ),
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
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order: ${o['tracking_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(o['status'] ?? 'Unknown', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          Text('Dest: ${o['destination']}'),
                          Text('Amt: PKR ${o['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          if (['order placed', 'with manager', 'claimed'].contains(o['status'].toString().toLowerCase())) ...[
                            if (_riders.isEmpty)
                              const Text("No riders available.", style: TextStyle(color: Colors.red))
                            else
                              DropdownButtonFormField<dynamic>(
                                initialValue: _selectedRiders[o['id']],
                                items: _riders.map<DropdownMenuItem<dynamic>>((r) {
                                  return DropdownMenuItem<dynamic>(value: r['id'], child: Text("${r['name']} (${r['mobile']})"));
                                }).toList(),
                                onChanged: (v) => setState(() => _selectedRiders[o['id']] = v),
                                decoration: const InputDecoration(labelText: 'Assign Rider'),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _riders.isEmpty ? null : () async {
                                  if (_selectedRiders[o['id']] != null) {
                                    await OrderService.dispatchToRider(o['id'], _selectedRiders[o['id']]);
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
                  const Text('Workspace Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  _buildReportItem('Orders Completed', _report['count'].toString(), Icons.check_circle, Colors.indigo),
                  const SizedBox(height: 20),
                  _buildReportItem('Volume Handled', 'PKR ${_report['total']}', Icons.trending_up, Colors.green),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(String label, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(label, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
