import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'admin/add_user_view.dart';
import 'manager/manager_dashboard.dart';
import 'rider/rider_dashboard.dart';
import 'shell/main_shell.dart';

/// Where a logged-in user starts: staff go to their workspace, customers to the store.
Widget homeFor(UserModel? user) {
  switch (user?.role) {
    case 'Admin':
      return const AddUserView();
    case 'Manager':
      return ManagerDashboard(user: user!);
    case 'Rider':
      return RiderDashboard(user: user!);
    default:
      return const MainShell();
  }
}

/// Clears the navigation stack and goes to the store home (used after logout).
void goToStoreHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const MainShell()),
    (route) => false,
  );
}
