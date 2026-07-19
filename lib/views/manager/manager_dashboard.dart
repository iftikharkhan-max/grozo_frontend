import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../controllers/order_service.dart';
import '../auth/login_view.dart'; // Required for Sign-out

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
  List<dynamic> _customers = []; // Added to hold fetched customer accounts
  // Use dynamic to handle potential ID type mismatches (String vs int)
  Map<dynamic, dynamic> _selectedRiders = {};

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() async {
    final poolData = await OrderService.fetchGlobalPool();
    final workspaceData = await OrderService.fetchOrdersByRole('manager', widget.user.id);

    // --- DEBUG ENABLED RIDER FETCH ---
    // We try multiple casing variants to ensure we catch whatever the backend database requires
    var ridersData = await OrderService.fetchUsersByRole('rider');
    if (ridersData == null || ridersData.isEmpty) {
      debugPrint("DEBUG - No riders found with lowercase 'rider'. Trying capitalized 'Rider'...");
      ridersData = await OrderService.fetchUsersByRole('Rider');
    }
    if (ridersData == null || ridersData.isEmpty) {
      debugPrint("DEBUG - No riders found with 'Rider'. Trying uppercase 'RIDER'...");
      ridersData = await OrderService.fetchUsersByRole('RIDER');
    }

    // Print the exact runtime response to your terminal console
    debugPrint("==================================================");
    debugPrint("DEBUG - FETCHED RIDERS DATA: $ridersData");
    debugPrint("==================================================");

    // Fetch customers to enable the name selection dropdown during manual order entry
    var customersData = await OrderService.fetchUsersByRole('customer');
    if (customersData == null || customersData.isEmpty) {
      customersData = await OrderService.fetchUsersByRole('Customer');
    }

    if (mounted) {
      setState(() {
        _pool = poolData;
        _myWorkspace = workspaceData;
        _riders = ridersData ?? [];
        _customers = customersData ?? [];
      });
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginView()), (route) => false);
  }

  void _createOnBehalfDialog() {
    dynamic selectedCustomerId; // Holds the selected customer's ID
    final address = TextEditingController();
    final amount = TextEditingController();
    final item = TextEditingController();

    showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Phone Call Order Creation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Searchable/Clean Customer Selection Dropdown
                  if (_customers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text("Loading customers...", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    DropdownButtonFormField<dynamic>(
                      value: selectedCustomerId,
                      hint: const Text('Select Customer'),
                      items: _customers.map<DropdownMenuItem<dynamic>>((c) {
                        final name = c['name'] ?? c['username'] ?? 'Unknown';
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
                      decoration: const InputDecoration(
                        labelText: 'Customer Account',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: item, decoration: const InputDecoration(labelText: 'Item Name / Quantities')),
                  TextField(controller: address, decoration: const InputDecoration(labelText: 'Delivery Destination')),
                  TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order Amount (PKR)')),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCustomerId == null || item.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a customer and enter an item details!'))
                    );
                    return;
                  }
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
                child: const Text('Save ("Order Placed")'),
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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manager Workspace'),
          bottom: TabBar(
            tabs: const [Tab(text: 'Global Pool'), Tab(text: 'My Workspace')],
            indicatorColor: theme.colorScheme.secondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.add_call), onPressed: _createOnBehalfDialog),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () async => _refreshAll(),
              child: _pool.isEmpty
                  ? const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: Center(child: Text("Global pool is currently empty.")),
                ),
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _pool.length,
                itemBuilder: (_, idx) {
                  final o = _pool[idx];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.inventory_2),
                        ),
                      ),
                      title: Text('Ref: ${o['tracking_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Dest: ${o['destination'] ?? 'N/A'}'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await OrderService.claimOrder(o['id'], widget.user.id);
                          _refreshAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Claim'),
                      ),
                    ),
                  );
                },
              ),
            ),
            RefreshIndicator(
              onRefresh: () async => _refreshAll(),
              child: _myWorkspace.isEmpty
                  ? const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: Center(child: Text("You have no active orders in your workspace.")),
                ),
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _myWorkspace.length,
                itemBuilder: (_, idx) {
                  final o = _myWorkspace[idx];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order: ${o['tracking_number']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  o['status'] ?? 'Unknown',
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
                          Text('Destination: ${o['destination']}', style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 4),
                          Text('Amount: PKR ${o['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          if (['order placed', 'with manager', 'claimed'].contains((o['status'] ?? '').toString().toLowerCase().trim())) ...[
                            if (_riders.isEmpty)
                              const Text("No riders available.", style: TextStyle(color: Colors.red))
                            else
                              DropdownButtonFormField<dynamic>(
                                value: _selectedRiders[o['id']],
                                items: _riders.map<DropdownMenuItem<dynamic>>((r) {
                                  // Robust structural key fallbacks for database parameters
                                  final riderName = r['name'] ?? r['username'] ?? 'Unknown';
                                  final riderMobile = r['mobile'] ?? r['phone'] ?? r['phone_number'] ?? 'No Number';
                                  return DropdownMenuItem<dynamic>(
                                      value: r['id'],
                                      child: Text("$riderName ($riderMobile)")
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedRiders[o['id']] = v;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Assign Rider',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _riders.isEmpty ? null : () async {
                                  final assignedRiderId = _selectedRiders[o['id']];
                                  if (assignedRiderId != null) {
                                    final success = await OrderService.dispatchToRider(o['id'], assignedRiderId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(success ? 'Order Dispatched!' : 'Dispatch failed.')),
                                      );
                                    }
                                    _refreshAll();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please select a rider first!'))
                                    );
                                  }
                                },
                                child: const Text('DISPATCH ORDER'),
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
          ],
        ),
      ),
    );
  }
}