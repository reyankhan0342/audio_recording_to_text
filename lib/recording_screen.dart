// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';

class SpeechToTextExample extends StatefulWidget {
  @override
  _SpeechToTextExampleState createState() => _SpeechToTextExampleState();
}

class _SpeechToTextExampleState extends State<SpeechToTextExample> {
  static const serverUrl =
      'wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=16000&language=en-GB';
  static const apiKey = '5d5a2331f6b851f6753b73c4c8c6dece61837193';
  String myText = "To start transcribing your voice, press start.";

  static const platform = MethodChannel('com.example.yourapp/service');

  final RecorderStream _recorder = RecorderStream();

  late StreamSubscription _recorderStatus;
  late StreamSubscription _audioStream;
  late IOWebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback(onLayoutDone);
  }

  void onLayoutDone(Duration timeStamp) async {
    await Permission.microphone.request();
    setState(() {});
  }

  @override
  void dispose() {
    _recorderStatus.cancel();
    _audioStream.cancel();
    channel.sink.close();
    super.dispose();
  }

  Future<void> _initStream() async {
    try {
      channel = IOWebSocketChannel.connect(
        Uri.parse(serverUrl),
        headers: {'Authorization': 'Token $apiKey'},
      );

      channel.stream.listen((event) async {
        try {
          final parsedJson = jsonDecode(event);

          if (parsedJson.containsKey('channel') &&
              parsedJson['channel'].containsKey('alternatives') &&
              parsedJson['channel']['alternatives'].isNotEmpty) {
            updateText(parsedJson['channel']['alternatives'][0]['transcript']);
          } else {
            log('Non-transcription message received: $parsedJson');
          }
        } catch (e) {
          log('Error parsing JSON or accessing data: $e');
        }
      });

      _audioStream = _recorder.audioStream.listen((data) {
        channel.sink.add(data);
      });

      _recorderStatus = _recorder.status.listen((status) {
        if (mounted) {
          setState(() {});
        }
      });

      await Future.wait([
        _recorder.initialize(),
      ]);
    } catch (e) {
      print('Error initializing stream: $e');
    }
  }

  void updateText(String newText) {
    setState(() {
      myText = '$myText $newText';
    });
  }

  void resetText() {
    setState(() {
      myText = '';
    });
  }

  Future<void> _startRecord() async {
    try {
      print('start services calling');
      resetText();
      final String result = await platform.invokeMethod('startService');
      print(result);

      await WakelockPlus.enable();

      await _initStream();
      await _recorder.start();
    } on PlatformException catch (e) {
      print("Failed to start service: '${e.message}'.");
    }
  }

  Future<void> _stopRecord() async {
    try {
      await _recorder.stop();
      final String result = await platform.invokeMethod('stopService');
      print(result);
      await WakelockPlus.disable();
    } on PlatformException catch (e) {
      print("Failed to stop service: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Live Transcription with Deepgram'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    myText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  OutlinedButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.blue),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    onPressed: _startRecord,
                    child: const Text('Start', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 5),
                  OutlinedButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.red),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    onPressed: _stopRecord,
                    child: const Text('Stop', style: TextStyle(fontSize: 30)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
