import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_state.dart';
import 'firebase_options.dart';
import 'screens/login_gate.dart';
import 'screens/main_shell.dart';
import 'services/session_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final opts = DefaultFirebaseOptions.currentPlatform;
    if (!opts.apiKey.startsWith('YOUR_')) {
      await Firebase.initializeApp(options: opts);
      firebaseReady = true;
    }
  } catch (_) {
    firebaseReady = false;
  }
  await initializeDateFormatting('ko');
  await SessionPrefs.load();
  runApp(const GrimPingPongApp());
}

class GrimPingPongApp extends StatelessWidget {
  const GrimPingPongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JHS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFFF6F91)),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 로그인(ID + 초대코드) → 메인(오늘/달력)
      home: const LoginGate(child: MainShell()),
    );
  }
}
