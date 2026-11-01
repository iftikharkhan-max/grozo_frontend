import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../account/location_picker_view.dart';
import '../common/product_widgets.dart';

/// Footer tab "Delivery Charges": the charge table, and a calculator where the
/// customer chooses where the order comes from (a branch, or a partner's shop
/// via the branch) and where it goes (any point on the map – not their phone's
/// location), e.g. someone in Lahore ordering for family in Abbottabad.
class DeliveryChargesView extends StatefulWidget {
  const DeliveryChargesView({super.key});

  @override
  State<DeliveryChargesView> createState() => _DeliveryChargesViewState();
}

class _DeliveryChargesViewState extends State<DeliveryChargesView> {
  List<Map<String, dynamic>>? _tiers;
  List<Map<String, dynamic>> _partners = [];
  String? _errorCode;
  int? _branchId;
  int? _partnerId;
  PickedLocation? _to;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (state.branches.isEmpty) state.loadBranches();
    _branchId = state.selectedBranch?['id'] as int?;
    _load();
  }

  Future<void> _load() async {
    final r =
        await Future.wait([Api.get('/delivery-charges'), Api.get('/partners')]);
    if (!mounted) return;
    setState(() {
      _errorCode = r[0].ok ? null : (r[0].errorCode ?? 'generic');
      if (r[0].ok) _tiers = List<Map<String, dynamic>>.from(r[0].data);
      if (r[1].ok) {
        // Only partners whose shop is on the map can be part of a route.
        _partners = List<Map<String, dynamic>>.from(r[1].data)
            .where((p) =>
                _point(p) != null &&
                p['coming_soon'] != 1 &&
                p['coming_soon'] != true)
            .toList();
      }
    });
  }

  static LatLng? _point(Map? m) {
    final lat = double.tryParse('${m?['latitude']}');
    final lng = double.tryParse('${m?['longitude']}');
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  static double _km(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Meter, a, b) / 1000;

  /// Same rule as the server: the tier whose range holds the distance.
  num? _chargeFor(double km) {
    for (final t in _tiers ?? const []) {
      final min = double.tryParse('${t['min_km']}') ?? 0;
      final max = double.tryParse('${t['max_km']}') ?? 0;
      if (km >= min && km <= max) return num.tryParse('${t['charge']}');
    }
    return null;
  }

  Future<void> _pickTo() async {
    final picked = await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<PickedLocation>(
            builder: (_) => LocationPickerView(
                latitude: _to?.latitude, longitude: _to?.longitude)));
    if (picked != null && mounted) setState(() => _to = picked);
  }

  String _name(Map b) =>
      (context.lang == 'ur' && '${b['name_ur'] ?? ''}'.isNotEmpty
              ? b['name_ur']
              : b['name'])
          .toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(context.tr('delivery_charges')),
          automaticallyImplyLeading: false),
      body: _tiers == null
          ? Center(
              child: _errorCode == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(friendlyError(context, errorCode: _errorCode)),
                      TextButton(
                          onPressed: _load, child: Text(context.tr('retry'))),
                    ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                children: [_calculator(), const SizedBox(height: 16), _table()],
              ),
            ),
    );
  }

  Widget _calculator() {
    final branches = context.watch<AppState>().branches;
    final branch = branches.where((b) => b['id'] == _branchId).firstOrNull ??
        branches.firstOrNull;
    final partner = _partners.where((p) => p['id'] == _partnerId).firstOrNull;
    final from = _point(branch);
    final via = _point(partner);
    final to = _to == null ? null : LatLng(_to!.latitude, _to!.longitude);
    double? leg1, leg2, total;
    if (from != null && to != null) {
      if (via != null) {
        leg1 = _km(from, via);
        leg2 = _km(via, to);
        total = leg1 + leg2;
      } else {
        total = _km(from, to);
      }
    }
    final charge = total == null ? null : _chargeFor(total);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: brandPrimary)),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E7E3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calculate_outlined, color: brandGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.tr('charge_calculator'),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: brandPrimary)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(context.tr('charge_calculator_sub'),
            style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
        label('${context.tr('from')} – ${context.tr('branch')}'),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: branch?['id'] as int?,
          decoration: const InputDecoration(
              isDense: true, prefixIcon: Icon(Icons.storefront_outlined)),
          items: [
            for (final b in branches)
              DropdownMenuItem(value: b['id'] as int, child: Text(_name(b))),
          ],
          onChanged: (v) => setState(() => _branchId = v),
        ),
        if (_partners.isNotEmpty) ...[
          label(context.tr('via_partner')),
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: _partnerId,
            decoration: const InputDecoration(
                isDense: true, prefixIcon: Icon(Icons.restaurant_outlined)),
            items: [
              DropdownMenuItem<int?>(
                  value: null, child: Text(context.tr('groceries_only'))),
              for (final p in _partners)
                DropdownMenuItem<int?>(
                    value: p['id'] as int, child: Text(_name(p))),
            ],
            onChanged: (v) => setState(() => _partnerId = v),
          ),
        ],
        label(context.tr('to_delivery_point')),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              alignment: AlignmentDirectional.centerStart),
          onPressed: _pickTo,
          icon: Icon(
              _to == null ? Icons.add_location_alt_outlined : Icons.location_on,
              color: brandGreen),
          label: Text(
              _to == null
                  ? context.tr('pick_on_map')
                  : (_to!.address ??
                      '${_to!.latitude.toStringAsFixed(5)}, ${_to!.longitude.toStringAsFixed(5)}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
        if (from == null && branch != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(context.tr('branch_not_on_map'),
                style:
                    TextStyle(fontSize: 12.5, color: Colors.orange.shade900)),
          ),
        if (total != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: charge == null ? Colors.red.shade50 : brandGreenLight,
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (leg1 != null && leg2 != null) ...[
                Text(
                    '${_name(branch!)} → ${_name(partner!)}: ${leg1.toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 12.5)),
                Text(
                    '${_name(partner)} → ${context.tr('delivery_point')}: ${leg2.toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 4),
              ],
              Text(
                  context
                      .trf('route_total_km', {'km': total.toStringAsFixed(1)}),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                  charge == null
                      ? context.tr('outside_area')
                      : '${context.tr('delivery_charge')}: Rs. ${money(charge)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color:
                          charge == null ? Colors.red.shade800 : brandPrimary)),
            ]),
          ),
      ]),
    );
  }

  Widget _table() {
    String n(dynamic v) {
      final d = double.tryParse('$v') ?? 0;
      return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
    }

    Widget cell(String text, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(text,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('charge_table'),
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w900, color: brandPrimary)),
      const SizedBox(height: 8),
      Table(
        border: TableBorder.all(
            color: Colors.black12, borderRadius: BorderRadius.circular(10)),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: brandGreenLight),
            children: [
              cell(context.tr('distance_km'), bold: true),
              cell(context.tr('charge_rs'), bold: true),
            ],
          ),
          for (final t in _tiers!)
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                cell('${n(t['min_km'])} – ${n(t['max_km'])} KM'),
                cell('Rs. ${n(t['charge'])}', bold: true),
              ],
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(context.tr('charge_table_note'),
          style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]);
  }
}
