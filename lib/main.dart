// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'auth/login_screen.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

// TEMA TANIMLAMALARI (Değişiklik yok)
final Color primaryColor = Colors.teal;
final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
);
final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: Brightness.dark,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
);

// DEĞİŞİKLİK 1: main fonksiyonunu "async" yapıyoruz.
Future<void> main() async {
  // DEĞİŞİKLİK 2: Tüm başlatma işlemleri artık runApp'ten ÖNCE burada yapılacak.
  // Bu, FutureBuilder ihtiyacını ortadan kaldırır.
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env yoksa sorun değil, devam et.
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await initializeDateFormatting('tr_TR', null);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(), // DEĞİŞİKLİK 3: Artık initFuture parametresi yok.
    ),
  );
}

// DEĞİŞİKLİK 4: MyApp widget'ı artık çok daha basit.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Analytica',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          // Check authentication state and route accordingly
          home: const AuthWrapper(),
        );
      },
    );
  }
}

// Auth wrapper that checks authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // If user is authenticated, show HomeScreen
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }
        
        // If user is not authenticated, show LoginScreen
        return const LoginScreen();
      },
    );
  }
}