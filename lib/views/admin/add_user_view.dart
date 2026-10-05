import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
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

  /// Removed (deactivated) Managers and Riders, who can be reactivated.
  List<Map<String, dynamic>> _inactiveStaff = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  // --- EXISTING STAFF LOGIC ---
  void _loadStaff() async {
    try {
      final res = await Api.client
          .get(Uri.parse('${Config.baseUrl}/admin'), headers: Api.authHeaders);
      if (res.statusCode == 200) {
        if (mounted) setState(() => _staffList = jsonDecode(res.body));
      }
    } catch (_) {}
    final inactive = await Api.get('/admin/inactive');
    if (inactive.ok && inactive.data is List && mounted) {
      setState(() =>
          _inactiveStaff = List<Map<String, dynamic>>.from(inactive.data));
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _clearForm() {
    _name.clear();
    _email.clear();
    _pass.clear();
    _cnic.clear();
    _mobile.clear();
    _address.clear();
  }

  void _provision() async {
    if (!_formKey.currentState!.validate()) return;

    final res = await Api.post('/admin/add-user', {
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'password': _pass.text,
      'role': _role,
      'cnic': _cnic.text.trim(),
      'mobile': _mobile.text.trim(),
      'address': _address.text.trim(),
    });

    if (!mounted) return;
    if (res.ok) {
      _toast('Successfully added $_role!');
      _clearForm();
      _loadStaff();
      return;
    }
    final data = res.data is Map ? res.data as Map : const {};
    if (data['code'] == 'inactive_user' && data['user'] is Map) {
      // This person was removed before: bring the same account back (keeps
      // their order history) instead of creating a duplicate.
      final user = Map<String, dynamic>.from(data['user']);
      final ok = await _confirmReactivate('${data['message']}');
      if (ok == true) await _reactivate(user, withFormDetails: true);
      return;
    }
    _toast(res.isNetworkError
        ? 'Network error connecting to backend engine.'
        : (res.message ?? 'Failed to provision staff account.'));
  }

  Future<bool?> _confirmReactivate(String message) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Previously removed staff'),
          content: Text('$message\n\nReactivating restores the same account '
              'as $_role with the details entered on this form. Past orders '
              'stay linked to it.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reactivate')),
          ],
        ),
      );

  /// Reactivates a removed staff member. From the Add Staff form the newly
  /// entered role, password and contact details are applied too.
  Future<void> _reactivate(Map<String, dynamic> user,
      {bool withFormDetails = false}) async {
    final res = await Api.put(
        '/admin/${user['id']}/reactivate',
        withFormDetails
            ? {
                'role': _role,
                'name': _name.text.trim(),
                'mobile': _mobile.text.trim(),
                'address': _address.text.trim(),
                'password': _pass.text,
              }
            : {});
    if (!mounted) return;
    if (res.ok) {
      _toast('${res.data?['message'] ?? '${user['name']} reactivated.'}');
      if (withFormDetails) _clearForm();
      _loadStaff();
    } else {
      _toast(res.message ?? 'Reactivation failed.');
    }
  }

  Future<void> _askReactivate(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reactivate ${u['name']}?'),
        content: Text('${u['name']} will be able to log in again as '
            '${u['role']} with their previous password.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reactivate')),
        ],
      ),
    );
    if (ok == true) _reactivate(u);
  }

  Widget _inactiveSection() => ExpansionTile(
        leading: const Icon(Icons.person_off_outlined, color: Colors.grey),
        title: Text('Removed staff (${_inactiveStaff.length})'),
        subtitle: const Text('Reactivate someone who was removed earlier'),
        children: [
          for (final u in _inactiveStaff)
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  child: Text('${u['role'] ?? '?'}'[0])),
              title: Text('${u['name']} (${u['role']})'),
              subtitle: Text('${u['email']}\n${u['mobile'] ?? ''}'),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () => _askReactivate(u),
                child: const Text('REACTIVATE'),
              ),
            ),
        ],
      );

  void _showUpdateDialog(dynamic staff) {
    final updateMobile =
        TextEditingController(text: staff['mobile']?.toString() ?? '');
    final updateAddress =
        TextEditingController(text: staff['address']?.toString() ?? '');
    String updateRole = staff['role'] ?? 'Rider';
    bool isCustomer = updateRole == 'Customer';
    // Admin accounts are not edited here: the role list only offers staff and
    // customer roles, and an admin must not lock themself out.
    final isAdmin = updateRole == 'Admin';
    final isMe = staff['id'] == context.read<AppState>().user?.id;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: Text('Update ${staff['name']}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAdmin)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                              isMe
                                  ? 'This is your own Admin account. It cannot be changed or deactivated here.'
                                  : 'Admin accounts cannot be edited here. Only deactivation is permitted.',
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 12)),
                        ),
                      if (isCustomer)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                              'Customer profile cannot be edited here. Only deactivation is permitted.',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12)),
                        ),
                      DropdownButtonFormField<String>(
                        isExpanded:
                            true, // long names use the full width and never overflow
                        initialValue: updateRole,
                        items: [
                          'Rider',
                          'Manager',
                          'Customer',
                          if (isAdmin) 'Admin'
                        ]
                            .map((r) =>
                                DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: isCustomer || isAdmin
                            ? null
                            : (val) => setDialogState(() => updateRole = val!),
                        decoration:
                            const InputDecoration(labelText: 'Profile Role'),
                      ),
                      TextField(
                        controller: updateMobile,
                        decoration:
                            const InputDecoration(labelText: 'Mobile Number'),
                        enabled: !isCustomer && !isAdmin,
                      ),
                      TextField(
                        controller: updateAddress,
                        decoration: const InputDecoration(labelText: 'Address'),
                        enabled: !isCustomer && !isAdmin,
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (isMe)
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close')),
                  if (!isMe)
                    TextButton(
                      onPressed: () async {
                        bool confirm = await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm Deactivation'),
                                content: const Text(
                                    'Are you sure you want to deactivate this account? The user will no longer be able to login.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Deactivate',
                                          style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ) ??
                            false;

                        if (confirm) {
                          final success =
                              await AuthService.deleteUser(staff['id']);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(success
                                    ? 'User deactivated'
                                    : 'Deactivation failed')));
                            _loadStaff();
                          }
                        }
                      },
                      child: const Text('DEACTIVATE',
                          style: TextStyle(color: Colors.red)),
                    ),
                  if (!isCustomer && !isAdmin)
                    TextButton(
                      onPressed: () async {
                        final success =
                            await AuthService.updateUser(staff['id'], {
                          'mobile': updateMobile.text,
                          'address': updateAddress.text,
                          'role': updateRole,
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(success
                                  ? 'User updated successfully!'
                                  : 'Update failed.')));
                          _loadStaff();
                        }
                      },
                      child: const Text('Update Profile'),
                    )
                ],
              ),
            ));
  }

  void _logout() => confirmLogout(context);

  final _search = TextEditingController();
  String _roleFilter = 'All';
  final _manageScroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _manageScroll.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredUsers {
    final text = _search.text.trim().toLowerCase();
    return _staffList.where((u) {
      if (_roleFilter != 'All' && u['role'] != _roleFilter) return false;
      if (text.isEmpty) return true;
      return [u['name'], u['email'], u['mobile']]
          .any((v) => '${v ?? ''}'.toLowerCase().contains(text));
    }).toList();
  }

  Widget _manageTab() {
    if (_staffList.isEmpty && _inactiveStaff.isEmpty) {
      return const Center(child: Text("No users found or loading..."));
    }
    final users = _filteredUsers;
    final counts = <String, int>{};
    for (final u in _staffList) {
      counts['${u['role']}'] = (counts['${u['role']}'] ?? 0) + 1;
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search name, email or mobile',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_search.clear)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Wrap(spacing: 6, runSpacing: 2, children: [
          for (final r in ['All', 'Manager', 'Rider', 'Customer', 'Admin'])
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(r == 'All'
                  ? 'All (${_staffList.length})'
                  : '${r}s (${counts[r] ?? 0})'),
              selected: _roleFilter == r,
              onSelected: (_) => setState(() => _roleFilter = r),
            ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => _loadStaff(),
          // Always-visible scrollbar: shows the list is longer than the screen.
          child: Scrollbar(
            controller: _manageScroll,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _manageScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length + 1,
              itemBuilder: (_, idx) {
                if (idx == users.length) {
                  return Column(children: [
                    if (users.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No users match.')),
                    if (_inactiveStaff.isNotEmpty) _inactiveSection(),
                    const SizedBox(height: 24),
                  ]);
                }
                final staff = users[idx];
                final role = '${staff['role'] ?? 'Unknown'}';
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: switch (role) {
                          'Customer' => Colors.green,
                          'Admin' => Colors.deepOrange,
                          _ => Colors.indigo,
                        },
                        foregroundColor: Colors.white,
                        child: Text(role.isEmpty ? '?' : role[0])),
                    title: Text('${staff['name']} ($role)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Email: ${staff['email']}\nAddr: ${staff['address'] ?? 'N/A'}'),
                    isThreeLine: true,
                    onTap: () => _showUpdateDialog(staff),
                    trailing: const Icon(Icons.edit, color: Colors.indigo),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }

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
                  const Text('Add New Staff Member',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded:
                        true, // long names use the full width and never overflow
                    initialValue: _role,
                    items: ['Rider', 'Manager']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setState(() => _role = val!),
                    decoration: const InputDecoration(
                        labelText: 'Staff Profile Role Type'),
                  ),
                  TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(
                      controller: _email,
                      decoration:
                          const InputDecoration(labelText: 'Email Address'),
                      validator: Validators.validateEmail),
                  TextFormField(
                      controller: _pass,
                      decoration:
                          const InputDecoration(labelText: 'Security Password'),
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(
                      controller: _cnic,
                      decoration: const InputDecoration(
                          labelText: 'CNIC (NNNNN-NNNNNNN-N)'),
                      validator: Validators.validateCNIC),
                  TextFormField(
                      controller: _mobile,
                      decoration: const InputDecoration(
                          labelText: 'Mobile Phone (NNNN-NNNNNNN)'),
                      validator: Validators.validateMobile),
                  TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Address')),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: _provision,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white),
                      child: const Text('PROVISION ACCESS ACCOUNT'))
                ],
              ),
            ),

            // --- TAB 2: MANAGE USERS ---
            _manageTab(),

            // --- TAB 3: STORE MANAGEMENT ---
            const StoreAdminTab(),
          ],
        ),
      ),
    );
  }
}
