import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/validators.dart';
import '../../utils/constants.dart';
import '../../controllers/auth_service.dart';
import '../auth/login_view.dart'; // Required for Sign-out

class AddUserView extends StatefulWidget {
  const AddUserView({super.key});
  @override
  State<AddUserView> createState() => _AddUserViewState();
}

class _AddUserViewState extends State<AddUserView> {
  final _formKey = GlobalKey<FormState>();
  String _role = 'Rider';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _cnic = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController(); // Added Address field

  List<dynamic> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  void _loadStaff() async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/admin'));
      if (res.statusCode == 200) {
        if (mounted) setState(() => _staffList = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  void _provision() async {
    if (!_formKey.currentState!.validate()) return;

    // AuthService must be updated to accept the address parameter
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
    final updateMobile = TextEditingController(text: staff['mobile']);
    final updateAddress = TextEditingController(text: staff['address']);

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Update ${staff['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: updateMobile, decoration: const InputDecoration(labelText: 'New Mobile Number')),
              TextField(controller: updateAddress, decoration: const InputDecoration(labelText: 'New Address')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await http.put(
                  Uri.parse('${Config.baseUrl}/admin/${staff['id']}'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'mobile': updateMobile.text, 'address': updateAddress.text}),
                );
                if (mounted) Navigator.pop(context);
                _loadStaff();
              },
              child: const Text('Update Staff'),
            )
          ],
        )
    );
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginView()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Operations Panel'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStaff),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const Text('Add New Staff Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _role,
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
          ),
          const Divider(thickness: 3),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Existing Staff Roster (Tap to Update)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _staffList.length,
                    itemBuilder: (_, idx) {
                      final staff = _staffList[idx];
                      return ListTile(
                        leading: CircleAvatar(child: Text(staff['role'][0])),
                        title: Text('${staff['name']} (${staff['role']})'),
                        subtitle: Text('Mobile: ${staff['mobile']} | Addr: ${staff['address'] ?? 'N/A'}'),
                        onTap: () => _showUpdateDialog(staff),
                        trailing: const Icon(Icons.edit),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}