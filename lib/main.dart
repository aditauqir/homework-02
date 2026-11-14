import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MessageBoardApp());
}

class MessageBoardApp extends StatelessWidget {
  const MessageBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Aktiv Grotesk',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F1419),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF0F1419),
          outline: Color(0xFFCFD9DE),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F1419),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        dividerColor: const Color(0xFFEFF3F4),
      ),
      home: const SplashScreen(),
    );
  }
}
