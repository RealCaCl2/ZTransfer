import 'package:flutter_test/flutter_test.dart';
import 'package:ztransfer/app.dart';

void main() {
  testWidgets('App launches without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const ZTransferApp());
    await tester.pumpAndSettle();

    // The home screen should show the app title
    expect(find.text('ZTransfer'), findsOneWidget);

    // Camera status card should use the app's configured Chinese locale.
    expect(find.text('未连接相机'), findsOneWidget);
  });
}
