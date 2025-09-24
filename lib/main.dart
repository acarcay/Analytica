// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'auth/login_screen.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

// 1. TEMA TANIMLAMALARINI SINIFIN DIŞINA, BURAYA TAŞIYORUZ
final Color primaryColor = Colors.teal;

// AÇIK TEMA tanımı
final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
);

// KOYU TEMA tanımı
final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: Brightness.dark,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
);


Future<void> _initializeApp() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env yoksa atla
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('tr_TR', null);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Google Fonts için runtime fetch'i kapatıyoruz (daha hızlı açılış)
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(initFuture: _initializeApp()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initFuture});

  final Future<void> initFuture;

  @override
  Widget build(BuildContext context) {
    // 2. TEMA TANIMLAMALARI ARTIK BURADA DEĞİL

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Analytica',
          debugShowCheckedModeBanner: false,
          
          // 3. ARTIK TEMALARA SORUNSUZCA ERİŞEBİLİR
          theme: lightTheme,
          darkTheme: darkTheme,
          
          themeMode: themeProvider.themeMode,
          home: FutureBuilder<void>(
            future: initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _SplashScreen();
              }
              if (snapshot.hasError) {
                return _InitErrorScreen(error: snapshot.error);
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Analytica başlatılıyor...'),
          ],
        ),
      ),
    );
  }
}

class _InitErrorScreen extends StatelessWidget {
  const _InitErrorScreen({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Başlatma sırasında bir sorun oluştu'),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Basit yeniden dene: uygulamayı yeniden başlatmak için aynı route'u yeniden yükle
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => MyApp(initFuture: _initializeApp()),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Tekrar Dene'),
              )
            ],
          ),
        ),
      ),
    );
  }
}