import 'package:flutter/material.dart';
import 'admin_form.dart';
import 'banners_admin_view.dart';
import 'broadcast_admin_view.dart';
import 'branch_admin_view.dart';
import 'categories_admin_view.dart';
import 'delivery_charges_admin_view.dart';
import 'products_admin_view.dart';
import 'store_info_admin_view.dart';

/// "Store" tab of the admin panel: everything customers see in the app.
class StoreAdminTab extends StatelessWidget {
  const StoreAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String subtitle, Widget page) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: adminColor.withValues(alpha: 0.1), child: Icon(icon, color: adminColor)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          ),
        );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        item(Icons.inventory_2_outlined, 'Products', 'Add and edit products, prices, discounts, stock', const ProductsAdminView()),
        item(Icons.category_outlined, 'Categories', 'Vegetables, Fruits and Market Shopping tiles', const CategoriesAdminView()),
        item(Icons.local_offer_outlined, 'Offers & Deals', 'Home-page banners for offers, discounts and deals', const BannersAdminView()),
        item(Icons.storefront_outlined, 'Branches', 'Add branches: name, address, phone, hours, map location', const BranchesAdminView()),
        item(Icons.local_shipping_outlined, 'Delivery charges', 'Charge by distance from the branch', const DeliveryChargesAdminView()),
        item(Icons.info_outline, 'Store information', 'Support contacts, About Us, Terms, Privacy, FAQ', const StoreInfoAdminView()),
        item(Icons.campaign_outlined, 'Send notification', 'Tell customers about an offer, deal or new product', const BroadcastAdminView()),
      ],
    );
  }
}
