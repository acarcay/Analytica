import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // Bu dosyayı birazdan oluşturacağız

void main() {
  // Not: Önceki cevabımda burada Firebase'i başlatan kodlar vardı.
  // Firebase Studio bunu arka planda otomatik hallediyor olabilir.
  // Şimdilik bu şekilde bırakalım, gerekirse sonra ekleriz.
  runApp(const AnalyticaApp());
}

class AnalyticaApp extends StatelessWidget {
  const AnalyticaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Analytica', // Uygulama adını güncelledik
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), // Ana rengi değiştirebilirsiniz
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false, // Sağ üstteki "Debug" yazısını kaldırır
      home: const HomeScreen(), // Uygulamanın yeni ana sayfası
    );
  }
}