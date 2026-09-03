import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';
import '../../controllers/auth_service.dart';
import '../../controllers/product_service.dart';
import '../storefront_view.dart';

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

  // --- PRODUCT TAB VARIABLES ---
  final _prodFormKey = GlobalKey<FormState>();
  final _prodName = TextEditingController();
  final _prodPrice = TextEditingController();
  final _prodImage = TextEditingController();
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  // --- EXISTING STAFF LOGIC ---
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

  void _logout() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const StorefrontView()), (route) => false);
  }

  // --- NEW PRODUCT LOGIC ---
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  void _addProduct() async {
    if (!_prodFormKey.currentState!.validate()) return;

    final success = await ProductService.createProduct(
      name: _prodName.text,
      price: double.tryParse(_prodPrice.text) ?? 0.0,
      imageFile: _pickedImage,
      imageUrl: _prodImage.text.isEmpty ? null : _prodImage.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added to catalog!')));
      _prodName.clear(); _prodPrice.clear(); _prodImage.clear();
      setState(() {
        _pickedImage = null;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add product.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Operations Panel'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.person_add), text: 'Add Staff'),
              Tab(icon: Icon(Icons.manage_accounts), text: 'Manage'),
              Tab(icon: Icon(Icons.add_shopping_cart), text: 'Add Product'),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStaff),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: TabBarView(
          children: [
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

            // --- TAB 3: ADD PRODUCT FORM ---
            Form(
              key: _prodFormKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const Text('Add New Grocery Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _prodName,
                      decoration: const InputDecoration(labelText: 'Product Name (e.g., Bread)'),
                      validator: (v) => v!.isEmpty ? 'Required' : null
                  ),
                  TextFormField(
                      controller: _prodPrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (PKR)'),
                      validator: (v) => v!.isEmpty ? 'Required' : null
                  ),
                  const SizedBox(height: 20),
                  const Text('Product Image', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: Text(_pickedImage == null ? 'Browse Image' : 'Change Image'),
                        ),
                      ),
                      if (_pickedImage != null) ...[
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _pickedImage!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Center(child: Text('OR')),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _prodImage,
                    decoration: const InputDecoration(labelText: 'Image URL (Fallback)'),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                      onPressed: _addProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('SAVE PRODUCT TO CATALOG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
