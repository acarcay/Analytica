// Bu, temel bir Flutter widget testidir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:analytica/main.dart';

void main() {
  testWidgets('HomeScreen smoke test', (WidgetTester tester) async {
    // Uygulamamızı build edip bir frame çizdiriyoruz.
    await tester.pumpWidget(const MyApp());

    // AppBar'da 'Analytica' başlığının olduğunu doğruluyoruz.
    expect(find.text('Analytica'), findsOneWidget);

    // Ekranda karşılama mesajımızın olduğunu doğruluyoruz.
    expect(
      find.text('Siyasi Analiz Verileri Burada Gösterilecek.'),
      findsOneWidget,
    );

    // Artık var olmayan sayaç ikonunu ('+') arıyoruz ve bulamadığımızı doğruluyoruz.
    expect(find.byIcon(Icons.add), findsNothing);

    // Artık var olmayan '0' sayısını arıyoruz ve bulamadığımızı doğruluyoruz.
    expect(find.text('0'), findsNothing);
  });
} 
