import 'package:flutter/material.dart';
import '../../../services/api.dart';
import 'admin_form.dart';

class _Tier {
  final TextEditingController min;
  final TextEditingController max;
  final TextEditingController charge;
  _Tier(String a, String b, String c)
      : min = TextEditingController(text: a),
        max = TextEditingController(text: b),
        charge = TextEditingController(text: c);
}

/// Delivery charge per distance band (km from the branch).
/// Addresses farther than the last band are outside the delivery area.
class DeliveryChargesAdminView extends StatefulWidget {
  const DeliveryChargesAdminView({super.key});

  @override
  State<DeliveryChargesAdminView> createState() =>
      _DeliveryChargesAdminViewState();
}

class _DeliveryChargesAdminViewState extends State<DeliveryChargesAdminView> {
  final _form = GlobalKey<FormState>();
  List<_Tier>? _tiers;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.get('/delivery-charges').then((res) {
      if (!mounted) return;
      setState(() => _tiers = res.ok
          ? [
              for (final t in res.data)
                _Tier(numText(t['min_km']), numText(t['max_km']),
                    numText(t['charge']))
            ]
          : []);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final rows = [
      for (final t in _tiers!)
        {
          'min_km': double.parse(t.min.text),
          'max_km': double.parse(t.max.text),
          'charge': double.parse(t.charge.text)
        },
    ];
    if (rows.isEmpty) {
      adminToast(context, 'Add at least one distance band.');
      return;
    }
    if (rows.any((r) => (r['max_km'] as double) <= (r['min_km'] as double))) {
      adminToast(
          context, '"To km" must be larger than "From km" in every row.');
      return;
    }
    setState(() => _busy = true);
    final res = await Api.put('/admin/delivery-charges', rows);
    if (!mounted) return;
    setState(() => _busy = false);
    res.ok
        ? adminToast(context, 'Delivery charges saved.')
        : adminError(context, res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Delivery charges'),
      bottomNavigationBar: _tiers == null
          ? null
          : AdminSaveButton(busy: _busy, onPressed: _save),
      body: _tiers == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text(
                    'Charge is based on the distance from your branch to the customer\'s saved address. '
                    'Addresses beyond the last band cannot order delivery.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                for (final (i, t) in _tiers!.indexed)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: adminNumber(t.min, 'From km', required: true)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: adminNumber(t.max, 'To km', required: true)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: adminNumber(t.charge, 'Rs.', required: true)),
                    IconButton(
                      tooltip: 'Remove row',
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () => setState(() => _tiers!.removeAt(i)),
                    ),
                  ]),
                TextButton.icon(
                  onPressed: () => setState(() {
                    final last = _tiers!.isEmpty ? '0' : _tiers!.last.max.text;
                    _tiers!.add(_Tier(last, '', ''));
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add distance band'),
                ),
              ]),
            ),
    );
  }
}
