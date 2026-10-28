import 'package:flutter/widgets.dart';

import '../data/carp_repository.dart';
import '../domain/models.dart';

enum AppMode { rider, driver }

/// Who is logged in and which mode they use. Shared by the whole app.
class AppState extends ChangeNotifier {
  AppState(this.repo);

  final CarpRepository repo;
  AppUser? user;
  AppMode mode = AppMode.rider;

  bool get isDriver => mode == AppMode.driver;

  void signIn(AppUser u, {AppMode? asMode}) {
    user = u;
    // Users with a vehicle start in driver mode, everyone else as rider.
    mode = asMode ?? (u.vehicleType != null ? AppMode.driver : AppMode.rider);
    notifyListeners();
  }

  void setMode(AppMode m) {
    mode = m;
    notifyListeners();
  }

  void signOut() {
    user = null;
    notifyListeners();
  }
}

/// Makes [AppState] available to every widget: `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without rebuilding when it changes (for button callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
