import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../account/addresses_view.dart';
import '../shell/main_shell.dart';
import 'order_editor.dart';

/// Customer → Current order → Request change (spec 7.2).
/// The customer edits a copy of the order; nothing changes until the manager
/// reviews it and updates the order, so prices and stock stay under the
/// store's control.
class ChangeRequestView extends StatefulWidget {
  final Order order;
  const ChangeRequestView({super.key, required this.order});

  @override
  State<ChangeRequestView> createState() => _ChangeRequestViewState();
}

class _ChangeRequestViewState extends State<ChangeRequestView> {
  late final List<EditLine> _lines = [
    for (final l in widget.order.items)
      if (l.productId != null) EditLine.fromOrderLine(l)
  ];
  late final _note = TextEditingController(text: widget.order.note ?? '');
  final _message = TextEditingController();
  Map<String, dynamic>? _newAddress;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _itemsChanged {
    final before = {
      for (final l in widget.order.items)
        if (l.productId != null) l.productId!: l.qty
    };
    final after = {for (final l in _lines) l.productId: l.qty};
    return before.length != after.length ||
        before.entries.any((e) => after[e.key] != e.value);
  }

  bool get _noteChanged =>
      _note.text.trim() != (widget.order.note ?? '').trim();

  bool get _anything =>
      _itemsChanged ||
      _noteChanged ||
      _newAddress != null ||
      _message.text.trim().isNotEmpty;

  Future<void> _pickAddress() async {
    final a = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => const AddressesView(selectMode: true)));
    if (a != null) setState(() => _newAddress = a);
  }

  Future<void> _send() async {
    if (!_anything) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('change_nothing'))));
      return;
    }
    setState(() => _sending = true);
    final res = await Api.post('/orders/${widget.order.id}/change-request', {
      if (_itemsChanged) 'items': [for (final l in _lines) l.toJson()],
      if (_newAddress != null) 'addressId': _newAddress!['id'],
      if (_noteChanged) 'note': _note.text.trim(),
      'message': _message.text.trim(),
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('change_sent'))));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(context,
              errorCode: res.errorCode, serverMessage: res.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    Widget section(String title, Widget child) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              child,
            ]),
          ),
        );

    return HidesOrderNowButton(
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('request_change'))),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: brandGreenLight,
                borderRadius: BorderRadius.circular(10)),
            child: Text(context.tr('change_how_it_works')),
          ),
          section(
              context.tr('items'),
              OrderItemsEditor(
                  lines: _lines, onChanged: () => setState(() {}))),
          section(
            context.tr('delivery_address'),
            Row(children: [
              Expanded(
                child: Text(_newAddress == null
                    ? (o.destination ?? '')
                    : [_newAddress!['address_line'], _newAddress!['city']]
                        .where((x) => '${x ?? ''}'.isNotEmpty)
                        .join(', ')),
              ),
              TextButton(
                  onPressed: _pickAddress, child: Text(context.tr('change'))),
            ]),
          ),
          section(
            context.tr('note_for_rider'),
            TextField(
                controller: _note,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(isDense: true)),
          ),
          section(
            context.tr('change_message'),
            TextField(
              controller: _message,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  isDense: true, hintText: context.tr('change_message_hint')),
            ),
          ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
                onPressed: _sending || !_anything ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(context.tr('send_change_request')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
