import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../common/product_widgets.dart';

/// Problem customers (no answer, refused the order, …) for managers and
/// riders, and the history a manager checks while taking a phone order.

int customerIncidents(Map row) =>
    (row['customer_incidents'] as num?)?.toInt() ?? 0;

bool customerProblematic(Map row) =>
    row['customer_problematic'] == true || row['customer_problematic'] == 1;

bool customerBlacklisted(Map row) =>
    row['customer_blacklisted'] == true || row['customer_blacklisted'] == 1;

const incidentReasons = {
  'no_answer': 'Did not answer the phone',
  'refused': 'Refused / did not take the order',
  'not_home': 'Not at the address',
  'wrong_address': 'Wrong or fake address',
  'other': 'Other',
};

/// Who the customer is, at a glance: ⛔ Blacklisted, ⚠ Problematic,
/// ★ Regular, 🆕 New or Returning – plus "1 problem recorded" when there
/// are problems below the limit.
class CustomerStandingBadge extends StatelessWidget {
  final Map row;
  const CustomerStandingBadge(this.row, {super.key});

  @override
  Widget build(BuildContext context) {
    final n = customerIncidents(row);
    final problems = '$n problem${n == 1 ? '' : 's'}';
    final delivered = (row['customer_delivered'] as num?)?.toInt() ?? 0;
    final chips = <Widget>[];
    if (customerBlacklisted(row) || row['customer_label'] == 'blacklisted') {
      chips.add(_chip('⛔ Blacklisted customer${n > 0 ? ' · $problems' : ''}',
          Colors.red.shade900));
    } else if (customerProblematic(row)) {
      chips.add(_chip('⚠ Problematic customer${n > 0 ? ' · $problems' : ''}',
          Colors.red.shade700));
    } else {
      switch (row['customer_label']) {
        case 'regular':
          chips.add(_chip('★ Regular customer · $delivered delivered',
              Colors.green.shade800));
        case 'new':
          chips.add(_chip('🆕 New customer', Colors.blue.shade700));
        case 'returning':
          chips.add(_chip('Returning customer · $delivered delivered',
              Colors.blueGrey.shade600));
      }
      if (n > 0) chips.add(_chip('$problems recorded', Colors.orange.shade800));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  static Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      );
}

/// Asks for the reason and puts the customer on (or takes them off) the
/// blacklist. Returns true when it was saved.
Future<bool> setCustomerBlacklisted(
    BuildContext context, int customerId, bool blacklist) async {
  // The dialog owns its text field and returns the reason (null = cancelled).
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _BlacklistReasonDialog(blacklist: blacklist),
  );
  if (text == null || !context.mounted) return false;
  final res = await Api.put('/staff/customers/$customerId/blacklist',
      {'blacklisted': blacklist, 'reason': text});
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok
          ? '${res.data?['message'] ?? 'Saved.'}'
          : (res.message ?? 'Could not save it.'))));
  return res.ok;
}

class _BlacklistReasonDialog extends StatefulWidget {
  final bool blacklist;
  const _BlacklistReasonDialog({required this.blacklist});

  @override
  State<_BlacklistReasonDialog> createState() => _BlacklistReasonDialogState();
}

class _BlacklistReasonDialogState extends State<_BlacklistReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blacklist = widget.blacklist;
    return AlertDialog(
      title: Text(
          blacklist ? 'Blacklist this customer?' : 'Remove from blacklist?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            blacklist
                ? 'They will not be able to order in the app. You can still take their order on the phone.'
                : 'They can order in the app again. Their earlier problems stop counting.',
            style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(
          controller: _reason,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(
              labelText: blacklist
                  ? 'Reason, e.g. fake orders *'
                  : 'How was it resolved? *'),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    blacklist ? Colors.red.shade700 : Colors.green.shade700,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, _reason.text.trim()),
            child: Text(blacklist ? 'Blacklist' : 'Remove')),
      ],
    );
  }
}

/// Everyone on the blacklist, with the reason. Tap for the history, where
/// they can be removed from the list.
class BlacklistView extends StatefulWidget {
  const BlacklistView({super.key});

  @override
  State<BlacklistView> createState() => _BlacklistViewState();
}

class _BlacklistViewState extends State<BlacklistView> {
  List<Map>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/staff/blacklist');
    if (!mounted) return;
    setState(() {
      _error = res.ok ? null : (res.message ?? 'Could not load the list.');
      if (res.ok) _rows = List<Map>.from(res.data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Blacklisted customers')),
      body: rows == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: rows.isEmpty
                  ? ListView(children: const [
                      Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('Nobody is blacklisted.'))),
                    ])
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = rows[i];
                        final at = DateTime.tryParse('${c['blacklisted_at']}')
                            ?.toLocal();
                        return ListTile(
                          leading:
                              Icon(Icons.block, color: Colors.red.shade800),
                          title: Text('${c['name']}  •  ${c['mobile'] ?? ''}'),
                          subtitle: Text([
                            if ((c['blacklist_reason'] ?? '')
                                .toString()
                                .isNotEmpty)
                              '${c['blacklist_reason']}',
                            if (at != null)
                              'Since ${at.day}/${at.month}/${at.year}',
                          ].join('\n')),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CustomerHistoryView(
                                        customerId: (c['id'] as num).toInt())));
                            _load();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

/// Rider/manager: record that the customer caused a problem with [order].
Future<bool> reportCustomerProblem(BuildContext context, Map order) async {
  String? reason;
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text('Problem with ${order['customer_name'] ?? 'the customer'}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RadioGroup<String>(
              groupValue: reason,
              onChanged: (v) => setDialog(() => reason = v),
              child: Column(children: [
                for (final e in incidentReasons.entries)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: e.key,
                    title: Text(e.value),
                  ),
              ]),
            ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: InputDecoration(
                  isDense: true,
                  labelText: reason == 'other'
                      ? 'What happened? *'
                      : 'Note (optional)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: reason == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Record')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  final res = await Api.post('/orders/${order['id']}/incidents',
      {'reason': reason, 'note': note.text.trim()});
  note.dispose();
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok
          ? '${res.data?['message'] ?? 'Recorded.'}'
          : (res.message ?? 'Could not record it.'))));
  return res.ok;
}

/// "History" (managers/admins) and "Report problem" under an order.
class StaffCustomerActions extends StatelessWidget {
  final Map order;
  final bool canViewHistory;
  final VoidCallback? onChanged;
  const StaffCustomerActions(this.order,
      {super.key, this.canViewHistory = false, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 4, children: [
      if (canViewHistory && order['customer_id'] != null)
        TextButton.icon(
          onPressed: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CustomerHistoryView(
                        customerId: (order['customer_id'] as num).toInt())));
            onChanged?.call();
          },
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Customer history'),
        ),
      TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
        onPressed: () async {
          if (await reportCustomerProblem(context, order)) onChanged?.call();
        },
        icon: const Icon(Icons.report_outlined, size: 18),
        label: const Text('Report problem'),
      ),
    ]);
  }
}

/// Everything a manager needs while the customer is on the phone: problems,
/// past orders, cancellations and the loyalty reward.
class CustomerHistoryView extends StatefulWidget {
  final int customerId;
  const CustomerHistoryView({super.key, required this.customerId});

  @override
  State<CustomerHistoryView> createState() => _CustomerHistoryViewState();
}

class _CustomerHistoryViewState extends State<CustomerHistoryView> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/staff/customers/${widget.customerId}/history');
    if (!mounted) return;
    setState(() {
      _error = res.ok ? null : (res.message ?? 'Could not load the history.');
      if (res.ok) _data = Map<String, dynamic>.from(res.data);
    });
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _setFlag(bool flagged) async {
    final res = await Api.put(
        '/staff/customers/${widget.customerId}/flag', {'flagged': flagged});
    if (!mounted) return;
    _toast(res.ok ? '${res.data?['message']}' : (res.message ?? 'Failed.'));
    _load();
  }

  Future<void> _void(Map i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(
            'Remove this problem? Use this if it was recorded by mistake; it will no longer count.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await Api.put('/staff/incidents/${i['id']}/void');
    if (!mounted) return;
    _toast(res.ok ? '${res.data?['message']}' : (res.message ?? 'Failed.'));
    _load();
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    return d == null ? '' : '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              d == null ? 'Customer history' : '${d['customer']['name']}')),
      body: d == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!))
          : RefreshIndicator(onRefresh: _load, child: _body(d)),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final c = d['customer'] as Map;
    final s = d['standing'] as Map;
    final st = d['stats'] as Map;
    final loyalty = d['loyalty'] as Map;
    final incidents = List<Map>.from(d['incidents'] ?? []);
    final orders = List<Map>.from(d['recent_orders'] ?? []);
    final problematic = s['problematic'] == true;
    final blacklisted = s['blacklisted'] == true;
    final log = List<Map>.from(d['blacklist_log'] ?? []);
    final active = incidents
        .where((i) =>
            i['voided'] != 1 &&
            i['voided'] != true &&
            i['cleared'] != 1 &&
            i['cleared'] != true)
        .length;

    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        );

    return ListView(padding: const EdgeInsets.all(12), children: [
      _blacklistCard(s, log),
      Card(
        color: problematic ? Colors.red.shade50 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${c['mobile'] ?? ''}${(c['email'] ?? '').toString().contains('@phone-orders') ? '' : '  •  ${c['email'] ?? ''}'}'),
            CustomerStandingBadge({
              'customer_incidents': s['incidents'],
              'customer_problematic': problematic,
              'customer_blacklisted': blacklisted,
              'customer_label': s['label'],
              'customer_delivered': s['delivered'] ?? st['delivered'],
            }),
            if (problematic && !blacklisted)
              Text(
                  s['flagged'] == true
                      ? 'Marked problematic by staff.'
                      : 'Problematic: ${s['incidents']} problems (limit ${s['threshold']}).',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
            const SizedBox(height: 10),
            Row(children: [
              stat('Orders', '${st['orders']}'),
              stat('Delivered', '${st['delivered']}',
                  color: Colors.green.shade700),
              stat('Cancelled', '${st['cancelled']}',
                  color: Colors.orange.shade800),
              stat('Problems', '$active',
                  color: active > 0 ? Colors.red.shade700 : null),
            ]),
            const SizedBox(height: 6),
            Text(
                'Spent on delivered orders: Rs. ${money((st['spent'] as num?) ?? 0)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _setFlag(s['flagged'] != true),
                icon: Icon(
                    s['flagged'] == true ? Icons.flag_outlined : Icons.flag,
                    size: 18),
                label: Text(s['flagged'] == true
                    ? 'Remove problematic mark'
                    : 'Mark as problematic'),
              ),
            ),
          ]),
        ),
      ),
      if (loyalty['enabled'] == true) _loyaltyCard(loyalty),
      const Padding(
          padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
          child:
              Text('Problems', style: TextStyle(fontWeight: FontWeight.bold))),
      if (incidents.isEmpty)
        const Padding(
            padding: EdgeInsets.all(8), child: Text('No problems recorded.')),
      for (final i in incidents)
        Card(
          child: ListTile(
            dense: true,
            leading: Icon(Icons.report_outlined,
                color: i['voided'] == 1 ||
                        i['voided'] == true ||
                        i['cleared'] == 1 ||
                        i['cleared'] == true
                    ? Colors.black26
                    : Colors.red.shade700),
            title: Text(
              '${incidentReasons[i['reason']] ?? i['reason']}'
              '${i['voided'] == 1 || i['voided'] == true ? '  (removed)' : i['cleared'] == 1 || i['cleared'] == true ? '  (cleared)' : ''}',
              style: TextStyle(
                  decoration: i['voided'] == 1 || i['voided'] == true
                      ? TextDecoration.lineThrough
                      : null),
            ),
            subtitle: Text([
              _date(i['created_at']),
              if (i['tracking_number'] != null) 'Order ${i['tracking_number']}',
              'by ${i['reported_by_name'] ?? i['reporter_role'] ?? 'staff'}',
              if ((i['note'] ?? '').toString().isNotEmpty) '"${i['note']}"',
            ].join('  •  ')),
            trailing: i['voided'] == 1 || i['voided'] == true
                ? null
                : IconButton(
                    tooltip: 'Remove (recorded by mistake)',
                    icon: const Icon(Icons.undo, size: 20),
                    onPressed: () => _void(i)),
          ),
        ),
      const Padding(
          padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text('Recent orders',
              style: TextStyle(fontWeight: FontWeight.bold))),
      if (orders.isEmpty)
        const Padding(
            padding: EdgeInsets.all(8), child: Text('No orders yet.')),
      for (final o in orders)
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(
              switch ('${o['status']}') {
                'Cancelled' => Icons.cancel_outlined,
                'Delivered' || 'Complete' => Icons.check_circle_outline,
                _ => Icons.local_shipping_outlined,
              },
              color: switch ('${o['status']}') {
                'Cancelled' => Colors.orange.shade800,
                'Delivered' || 'Complete' => Colors.green.shade700,
                _ => Colors.blueGrey,
              }),
          title: Text('${o['tracking_number']}  •  ${o['status']}'
              '${o['order_source'] == 'phone' ? '  •  📞' : ''}'
              '${o['loyalty_reward'] == 1 || o['loyalty_reward'] == true ? '  •  🎁' : ''}'),
          subtitle: Text(
              '${_date(o['created_at'])}  •  ${o['destination'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: Text('Rs. ${money(num.tryParse('${o['amount']}') ?? 0)}'),
        ),
    ]);
  }

  /// Blacklisted: why and since when, with "Remove from blacklist".
  /// Otherwise a button to blacklist (e.g. for fraud). The log shows who
  /// added or removed them and why.
  Widget _blacklistCard(Map s, List<Map> log) {
    final on = s['blacklisted'] == true;
    final at = DateTime.tryParse('${s['blacklisted_at']}')?.toLocal();
    final limit = (s['blacklist_threshold'] as num?)?.toInt() ?? 0;
    Future<void> change() async {
      if (await setCustomerBlacklisted(context, widget.customerId, !on)) {
        _load();
      }
    }

    return Card(
      color: on ? Colors.red.shade100 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(on ? Icons.block : Icons.verified_user_outlined,
                color: on ? Colors.red.shade900 : Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(on ? 'BLACKLISTED' : 'Not blacklisted',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: on ? Colors.red.shade900 : Colors.green.shade800)),
            ),
          ]),
          if (on && (s['blacklist_reason'] ?? '').toString().isNotEmpty)
            Text('${s['blacklist_reason']}'),
          if (on && at != null)
            Text('Since ${_date(s['blacklisted_at'])}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          if (on)
            const Text(
                'Can\'t order in the app. You can still take a phone order.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          if (!on)
            Text(
                limit > 0
                    ? 'Blacklisted automatically after $limit problems.'
                    : 'Automatic blacklisting is off.',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          for (final l in log.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  '${_date(l['created_at'])}  •  ${l['action'] == 'added' ? 'Blacklisted' : 'Removed'}'
                  '${l['automatic'] == 1 || l['automatic'] == true ? ' automatically' : ' by ${l['by_name'] ?? 'staff'}'}'
                  '${(l['reason'] ?? '').toString().isNotEmpty ? ': ${l['reason']}' : ''}',
                  style: const TextStyle(fontSize: 12)),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              style: TextButton.styleFrom(
                  foregroundColor:
                      on ? Colors.green.shade800 : Colors.red.shade800),
              onPressed: change,
              child: Text(on ? 'Remove from blacklist' : 'Blacklist'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _loyaltyCard(Map l) {
    final every = (l['every'] as num?)?.toInt() ?? 3;
    final done = (l['done'] as num?)?.toInt() ?? 0;
    final reward = l['reward'] == 'amount'
        ? 'Rs. ${money((l['amount'] as num?) ?? 0)} off'
        : 'free delivery';
    final String text;
    final Color color;
    if (l['eligible'] == true) {
      text = '🎁 Reward due on this order: $reward';
      color = Colors.green.shade700;
    } else if (l['blocked_problematic'] == true) {
      text = 'Reward ($reward) withheld: problematic customer';
      color = Colors.red.shade700;
    } else {
      text =
          'Loyalty: $done of $every orders done – $reward after ${every - done} more';
      color = Colors.blueGrey;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: every == 0 ? 0 : done / every,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15)),
        ]),
      ),
    );
  }
}
