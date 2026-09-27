import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:grozo/services/api.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';
import '../../controllers/auth_service.dart';
import 'store/store_admin_tab.dart';
import 'orders/admin_orders_tab.dart';
import '../common/more_menu.dart';

class AddUserView extends StatefulWidget {
  const AddUserView({super.key});
  @override
  State<AddUserView> createState() => _AddUserViewState();
}

class _AddUserViewState extends State<AddUserView> {
  // --- STAFF TAB VARIABLES ---
  final _formKey = GlobalKey<FormState>();
  String _role = 'Rider';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _cnic = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();

  List<dynamic> _staffList = [];


  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  // --- EXISTING STAFF LOGIC ---
  void _loadStaff() async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/admin'), headers: Api.authHeaders);
      if (res.statusCode == 200) {
        if (mounted) setState(() => _staffList = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  void _provision() async {
    if (!_formKey.currentState!.validate()) return;

    final err = await AuthService.adminAddStaff(
        name: _name.text, email: _email.text, password: _pass.text,
        role: _role, cnic: _cnic.text, mobile: _mobile.text, address: _address.text
    );

    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully added $_role!')));
      _name.clear(); _email.clear(); _pass.clear(); _cnic.clear(); _mobile.clear(); _address.clear();
      _loadStaff();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _showUpdateDialog(dynamic staff) {
    final updateMobile = TextEditingController(text: staff['mobile']?.toString() ?? '');
    final updateAddress = TextEditingController(text: staff['address']?.toString() ?? '');
    String updateRole = staff['role'] ?? 'Rider';
    bool isCustomer = updateRole == 'Customer';

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Update ${staff['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCustomer) 
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Customer profile cannot be edited here. Only deactivation is permitted.', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: updateRole,
                    items: ['Rider', 'Manager', 'Customer'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: isCustomer ? null : (val) => setDialogState(() => updateRole = val!),
                    decoration: const InputDecoration(labelText: 'Profile Role'),
                  ),
                  TextField(
                    controller: updateMobile, 
                    decoration: const InputDecoration(labelText: 'Mobile Number'),
                    enabled: !isCustomer,
                  ),
                  TextField(
                    controller: updateAddress, 
                    decoration: const InputDecoration(labelText: 'Address'),
                    enabled: !isCustomer,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  bool confirm = await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirm Deactivation'),
                      content: const Text('Are you sure you want to deactivate this account? The user will no longer be able to login.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ) ?? false;

                  if (confirm) {
                    final success = await AuthService.deleteUser(staff['id']);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'User deactivated' : 'Deactivation failed')));
                      _loadStaff();
                    }
                  }
                },
                child: const Text('DEACTIVATE', style: TextStyle(color: Colors.red)),
              ),
              if (!isCustomer)
                TextButton(
                  onPressed: () async {
                    final success = await AuthService.updateUser(staff['id'], {
                      'mobile': updateMobile.text,
                      'address': updateAddress.text,
                      'role': updateRole,
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'User updated successfully!' : 'Update failed.')));
                      _loadStaff();
                    }
                  },
                  child: const Text('Update Profile'),
                )
            ],
          ),
        )
    );
  }

  void _logout() => confirmLogout(context);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Operations Panel'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
              Tab(icon: Icon(Icons.person_add), text: 'Add Staff'),
              Tab(icon: Icon(Icons.manage_accounts), text: 'Manage'),
              Tab(icon: Icon(Icons.storefront), text: 'Store'),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStaff),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: TabBarView(
          children: [
            // --- ORDERS ---
            const AdminOrdersTab(),

            // --- TAB 1: ADD STAFF FORM ---
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const Text('Add New Staff Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    items: ['Rider', 'Manager'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => _role = val!),
                    decoration: const InputDecoration(labelText: 'Staff Profile Role Type'),
                  ),
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email Address'), validator: Validators.validateEmail),
                  TextFormField(controller: _pass, decoration: const InputDecoration(labelText: 'Security Password'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: _cnic, decoration: const InputDecoration(labelText: 'CNIC (NNNNN-NNNNNNN-N)'), validator: Validators.validateCNIC),
                  TextFormField(controller: _mobile, decoration: const InputDecoration(labelText: 'Mobile Phone (NNNN-NNNNNNN)'), validator: Validators.validateMobile),
                  TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _provision, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: const Text('PROVISION ACCESS ACCOUNT'))
                ],
              ),
            ),

            // --- TAB 2: MANAGE USERS ---
            _staffList.isEmpty
                ? const Center(child: Text("No users found or loading..."))
                : ListView.builder(
              itemCount: _staffList.length,
              itemBuilder: (_, idx) {
                final staff = _staffList[idx];
                final role = staff['role'] ?? 'Unknown';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: role == 'Customer' ? Colors.green : Colors.indigo,
                        foregroundColor: Colors.white,
                        child: Text(role[0])
                    ),
                    title: Text('${staff['name']} ($role)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Email: ${staff['email']}\nAddr: ${staff['address'] ?? 'N/A'}'),
                    isThreeLine: true,
                    onTap: () => _showUpdateDialog(staff),
                    trailing: const Icon(Icons.edit, color: Colors.indigo),
                  ),
                );
              },
            ),

            // --- TAB 3: STORE MANAGEMENT ---
            const StoreAdminTab(),
          ],
        ),
      ),
    );
  }
}
