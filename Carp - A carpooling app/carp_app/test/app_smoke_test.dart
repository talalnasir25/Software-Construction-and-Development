import 'package:carp_app/data/in_memory_repository.dart';
import 'package:carp_app/main.dart';
import 'package:carp_app/ui/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens every screen for a driver and a rider, at phone and laptop sizes.
/// Fails if any screen throws or overflows.
void main() {
  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('all screens render at ${size.width.toInt()}px wide', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final state = AppState(InMemoryCarpRepository(latency: Duration.zero));
      await tester.pumpWidget(CarpApp(state: state));
      await tester.pumpAndSettle();
      expect(find.text('Carp'), findsOneWidget);

      // Log in as the driver (Ayesha) through the real login form.
      await tester.tap(find.widgetWithText(ActionChip, 'Ayesha Khan'));
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(state.isDriver, isTrue);

      Future<void> visitTabs() async {
        final labels = tester
            .widgetList<NavigationDestination>(find.byType(NavigationDestination))
            .map((d) => d.label)
            .toList();
        for (final label in labels) {
          await tester.tap(find.widgetWithText(NavigationDestination, label));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byType(NavigationDestination).first);
        await tester.pumpAndSettle();
      }

      await visitTabs();

      // Driver: open the first trip, then the post-trip form.
      await tester.tap(find.text('G-11 Markaz').first);
      await tester.pumpAndSettle();
      expect(find.text('Confirm trip'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post a trip'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Post trip'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Post trip'));
      await tester.pump();
      expect(find.text('Please choose a date and time.'), findsWidgets);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Switch to rider mode as Sara.
      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
      await tester.scrollUntilVisible(find.text('Sara Malik'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Sara Malik'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sara Malik'));
      await tester.pumpAndSettle();
      expect(state.isDriver, isFalse);
      await visitTabs();

      // Rider: the full bike trip shows the "full" message.
      await tester.tap(find.text('Bahria Town Phase 7'));
      await tester.pumpAndSettle();
      expect(find.text('This trip is full'), findsOneWidget);
    });
  }
}
