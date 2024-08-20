import 'package:audio_recording/recording_screen.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'recording_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Speech to Text Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SpeechToTextExample(),
    );
  }
}
