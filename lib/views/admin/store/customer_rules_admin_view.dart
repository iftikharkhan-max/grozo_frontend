import 'package:flutter/material.dart';
import '../../../services/api.dart';
import 'admin_form.dart';

/// Admin: the loyalty deal ("every N completed orders, the next one has free
/// delivery / Rs. X off") and when a customer counts as problematic.
class CustomerRulesAdminView extends StatefulWidget {
  const CustomerRulesAdminView({super.key});

  @override
  State<CustomerRulesAdminView> createState() => _CustomerRulesAdminViewState();
}

class _CustomerRulesAdminViewState extends State<CustomerRulesAdminView> {
  final _form = GlobalKey<FormState>();
  final _every = TextEditingController();
  final _amount = TextEditingController();
  final _threshold = TextEditingController();
  bool _enabled = false;
  String _reward = 'free_delivery';
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The explanation below the fields follows what is typed.
    for (final c in [_every, _amount]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    Api.get('/admin/customer-rules').then((res) {
      if (!mounted) return;
      if (!res.ok) return adminError(context, res);
      final d = Map<String, dynamic>.from(res.data);
      setState(() {
        _enabled = '${d['loyalty_enabled']}' == '1';
        _every.text = '${d['loyalty_every'] ?? 3}';
        _reward = d['loyalty_reward'] == 'amount' ? 'amount' : 'free_delivery';
        _amount.text = numText(d['loyalty_amount']);
        _threshold.text = '${d['problem_threshold'] ?? 2}';
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _every.dispose();
    _amount.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final res = await Api.put('/admin/customer-rules', {
      'loyalty_enabled': _enabled,
      'loyalty_every': _every.text.trim(),
      'loyalty_reward': _reward,
      'loyalty_amount': _reward == 'amount' ? _amount.text.trim() : '0',
      'problem_threshold': _threshold.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      adminToast(context, 'Saved.');
      Navigator.pop(context);
    } else {
      adminError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(_every.text.trim()) ?? 3;
    final rewardText = _reward == 'amount'
        ? 'Rs. ${_amount.text.trim().isEmpty ? '…' : _amount.text.trim()} off'
        : 'free delivery';
    return Scaffold(
      appBar: adminAppBar('Loyalty deal & problem customers'),
      bottomNavigationBar: AdminSaveButton(busy: _busy, onPressed: _save),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                adminSection('Loyalty deal'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reward regular customers'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (_enabled) ...[
                  adminNumber(_every, 'Completed orders needed',
                      required: true, decimal: false, hint: 'e.g. 3'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _reward,
                      decoration: const InputDecoration(labelText: 'Reward'),
                      items: const [
                        DropdownMenuItem(
                            value: 'free_delivery',
                            child: Text('Free delivery')),
                        DropdownMenuItem(
                            value: 'amount',
                            child: Text('Fixed amount off (Rs.)')),
                      ],
                      onChanged: (v) => setState(() => _reward = v!),
                    ),
                  ),
                  if (_reward == 'amount')
                    adminNumber(_amount, 'Amount off (Rs.)', required: true),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        'After every $n delivered orders, the customer\'s next '
                        'order gets $rewardText automatically – in the app and '
                        'on phone orders. Customers see their progress at '
                        'checkout. Problematic customers don\'t get the reward.'),
                  ),
                ],
                const SizedBox(height: 8),
                adminSection('Problem customers'),
                const Text(
                    'Riders and managers record problems on an order (no answer, '
                    'refused the order, not at the address, wrong address). '
                    'Managers see a warning on the customer\'s orders and when '
                    'taking their phone order.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                adminNumber(_threshold, 'Problems before "Problematic"',
                    required: true,
                    decimal: false,
                    hint: 'e.g. 2 – managers can also mark a customer by hand'),
              ]),
            ),
    );
  }
}
