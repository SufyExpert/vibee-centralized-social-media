import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'screens/login_screen.dart';
import 'screens/interests_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/skeleton_loader.dart';
import 'core/config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VibeeApp());
}

class VibeeApp extends StatelessWidget {
  const VibeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

/// Decides which screen to show based on auth + preferences state.
/// Uses a single StreamBuilder + FutureBuilder to avoid nested streams.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnap.data;

        // Not logged in — show login
        if (user == null) return const LoginScreen();

        // Logged in — check preferences to decide next screen
        return FutureBuilder<_AppStartState>(
          future: _resolveStartState(user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final state = snap.data ?? _AppStartState.noPreferences;

            switch (state) {
              case _AppStartState.noPreferences:
                return const InterestsScreen();
              case _AppStartState.showTimePicker:
                return const HomeScreen(showTimePicker: true);
              case _AppStartState.goHome:
                return const HomeScreen();
            }
          },
        );
      },
    );
  }

  static Future<_AppStartState> _resolveStartState(String uid) async {
    try {
      final db = FirestoreService();
      final prefs = await db.getUserPreferences(uid);

      // No preferences set — take user to interests selection
      if (prefs == null || prefs.interests.isEmpty) {
        return _AppStartState.noPreferences;
      }

      // Check if the user wants to skip the session picker
      final profile = await db.watchUserProfile(uid).first;
      if (profile?.skipSessionSelection == true) {
        return _AppStartState.goHome;
      }

      return _AppStartState.showTimePicker;
    } catch (_) {
      // On any error, just go home
      return _AppStartState.goHome;
    }
  }
}

enum _AppStartState { noPreferences, showTimePicker, goHome }

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
    );
  }
}
