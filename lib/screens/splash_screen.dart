import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../firebase_options.dart';
import 'auth_gate.dart';

/// Minimalist Twitter-style splash screen with clean monochrome aesthetics.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Future<FirebaseApp> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<FirebaseApp> _initialize() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.warningCircle,
                      color: const Color(0xFFF4212E),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Connection Failed',
                      style: TextStyle(
                        fontFamily: 'Aktiv Grotesk',
                        color: Color(0xFF0F1419),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Aktiv Grotesk',
                        color: Color(0xFF536471),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F1419),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _initialization = _initialize();
                        });
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontFamily: 'Aktiv Grotesk',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.shieldCheck,
                    size: 56,
                    color: const Color(0xFF0F1419),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Message Board Vault',
                    style: TextStyle(
                      fontFamily: 'Aktiv Grotesk',
                      color: Color(0xFF0F1419),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CSC 4360',
                    style: TextStyle(
                      fontFamily: 'Aktiv Grotesk',
                      color: Color(0xFF536471),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0F1419),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const AuthGate();
      },
    );
  }
}
