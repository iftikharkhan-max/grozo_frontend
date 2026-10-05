import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';

/// Branch details with a Google Maps directions link. Google Maps works out
/// distance and route from the customer's own location, so the app itself
/// never needs to track the customer.
class BranchView extends StatefulWidget {
  const BranchView({super.key});

  @override
  State<BranchView> createState() => _BranchViewState();
}

class _BranchViewState extends State<BranchView> {
  late Future<ApiResult> _future = Api.get('/branches');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('branch_location'))),
      body: FutureBuilder<ApiResult>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final res = snap.data!;
          if (!res.ok) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(friendlyError(context, errorCode: res.errorCode)),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: () =>
                        setState(() => _future = Api.get('/branches')),
                    child: Text(context.tr('retry'))),
              ]),
            );
          }
          final branches = List<Map<String, dynamic>>.from(res.data ?? []);
          if (branches.isEmpty) {
            return Center(child: Text(context.tr('branch_not_set')));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [for (final b in branches) _BranchCard(branch: b)],
          );
        },
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final ur = context.lang == 'ur';
    final name = (ur && (branch['name_ur'] ?? '').toString().isNotEmpty
            ? branch['name_ur']
            : branch['name'])
        .toString();
    final lat = double.tryParse('${branch['latitude']}');
    final lng = double.tryParse('${branch['longitude']}');
    final address = (branch['address'] ?? '').toString();
    final phone = (branch['phone'] ?? '').toString();
    final hours = (branch['opening_hours'] ?? '').toString();

    final destination = lat != null && lng != null ? '$lat,$lng' : address;
    final mapsUri = Uri.https('www.google.com', '/maps/dir/',
        {'api': '1', 'destination': destination});

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.storefront, color: brandGreen, size: 28),
            const SizedBox(width: 8),
            Expanded(
                child:
                    Text(name, style: Theme.of(context).textTheme.titleLarge)),
          ]),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.location_on_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(address)),
            ]),
          ],
          if (hours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${context.tr('opening_hours')}: $hours')),
            ]),
          ],
          const SizedBox(height: 16),
          if (destination.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    launchUrl(mapsUri, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.directions),
                label: Text(context.tr('open_in_maps')),
              ),
            ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                icon: const Icon(Icons.call),
                label: Text('${context.tr('call_branch')}  $phone'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
