import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../common/login_required.dart';
import 'checkout_view.dart';

/// Market Shopping: the customer writes a free-text list; we buy it from the
/// market and the final bill is confirmed on delivery.
class MarketRequestView extends StatefulWidget {
  final String? prefill;
  const MarketRequestView({super.key, this.prefill});

  @override
  State<MarketRequestView> createState() => _MarketRequestViewState();
}

class _MarketRequestViewState extends State<MarketRequestView> {
  late final _text = TextEditingController(text: widget.prefill ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final list = _text.text.trim();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('market_request_empty'))));
      return;
    }
    if (!context.read<AppState>().isLoggedIn && !await openLogin(context)) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutView(requestText: list)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('market_shopping'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(context.tr('market_request_title'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: brandGreenLight, borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: brandGreen),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('market_request_info'))),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          minLines: 8,
          maxLines: 16,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: context.tr('market_request_hint'),
            alignLabelWithHint: true,
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
              onPressed: _continue,
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.tr('send_request')),
            ),
          ),
        ),
      ),
    );
  }
}
