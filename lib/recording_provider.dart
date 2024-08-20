// import 'dart:convert';
// import 'dart:developer';
// import 'package:flutter/foundation.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:record/record.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;
// import 'package:web_socket_channel/web_socket_channel.dart';

// class OppointmentProvider extends ChangeNotifier {
//   final AudioRecorder _audioRecorder = AudioRecorder();
//   final player = AudioPlayer();

//   String? audioUrl;
//   bool isProcessing = false;
//   bool _isRecording = false;
//   bool _isPaused = false;
//   String _transcribedText = "";
//   final String _deepgramApiKey = 'fb8c0a0556ba93777d40d1732f1fe66d2c163824';

//   bool get isRecording => _isRecording;
//   bool get isPaused => _isPaused;
//   String get transcribedText => _transcribedText;

//   void startRecording() async {
//     try {
//       if (await _audioRecorder.hasPermission()) {
//         print('Microphone permission granted.');
//         await _audioRecorder.start(const RecordConfig(), path: '');
//         print('Recording started.');
//         _isRecording = true;
//         _isPaused = false;
//         await _startListening();
//         notifyListeners();
//       } else {
//         print('Microphone permission denied.');
//       }
//     } catch (e, stackTrace) {
//       print('Error starting recording: $e');
//       print(stackTrace);
//     }
//   }

//   _startListening() async {
//     try {
//       if (_isRecording) {
//         final audioStream = await _audioRecorder.startStream(const RecordConfig(
//           encoder: AudioEncoder.pcm16bits,
//           sampleRate: 16000,
//           numChannels: 1,
//         ));

//         print('Audio stream started.');

//         final Uri uri = Uri.parse("https://api.deepgram.com/v1/listen");
//         final http.Client client = http.Client();

//         final request = http.StreamedRequest("POST", uri);
//         request.headers['Authorization'] = 'Token $_deepgramApiKey';
//         request.headers['Content-Type'] = 'application/octet-stream';
//         request.headers['Transfer-Encoding'] = 'chunked';

//         final queryParams = {
//           'model': 'nova-2-general',
//           'encoding': 'linear16',
//           'sample_rate': '16000',
//           'detect_language': 'true',
//           'filler_words': 'false',
//           'punctuation': 'true',
//         };
//         final urlWithParams = uri.replace(queryParameters: queryParams);

//         print('Sending audio stream to Deepgram...');

//         // Listen to the audio stream and send chunks to Deepgram
//         audioStream.listen((data) async {
//           print('Sending audio data chunk of size: ${data.length}');
//           request.sink.add(Uint8List.fromList(data));
//         }, onDone: () async {
//           print('Audio stream completed.');
//           await request.sink.close(); // Close the stream to signal end of data

//           // Handle the response from Deepgram
//           final response = await client.send(request);
//           if (response.statusCode != 200) {
//             print('Failed to connect to Deepgram: ${response.statusCode}');
//             return;
//           }

//           final responseStream = response.stream.transform(utf8.decoder);

//           await for (final transcriptChunk in responseStream) {
//             print('Received transcription chunk: $transcriptChunk');
//             final Map<String, dynamic> result = jsonDecode(transcriptChunk);
//             if (result.containsKey('results')) {
//               _transcribedText = result['results']['channels'][0]
//                       ['alternatives'][0]['transcript'] ??
//                   '';
//               print('Transcription: $_transcribedText');
//               notifyListeners();
//             } else {
//               print('No results in the transcription response.');
//             }
//           }
//         });
//       }
//     } catch (e, stackTrace) {
//       print('Error during listening: $e');
//       print(stackTrace);
//     }
//   }

//   void pauseRecording() async {
//     try {
//       if (_isRecording && !_isPaused) {
//         await _audioRecorder.pause();
//         _isPaused = true;
//         notifyListeners();
//         print('Recording paused.');
//       }
//     } catch (e, stackTrace) {
//       print('Error pausing recording: $e');
//       print(stackTrace);
//     }
//   }

//   void resumeRecording() async {
//     try {
//       if (_isRecording && _isPaused) {
//         await _audioRecorder.resume();
//         _startListening();
//         _isPaused = false;
//         notifyListeners();
//         print('Recording resumed.');
//       }
//     } catch (e, stackTrace) {
//       print('Error resuming recording: $e');
//       print(stackTrace);
//     }
//   }

//   void stopRecording() async {
//     try {
//       String? path = await _audioRecorder.stop();
//       _isRecording = false;
//       _isPaused = false;
//       notifyListeners();
//       print('Recording stopped.');

//       if (path != null) {
//         print('Recording file path: $path');
//         try {
//           html.Blob? audioBlob = await getRecordedAudioBlob(path);

//           if (audioBlob != null) {
//             FirebaseStorage storage = FirebaseStorage.instance;
//             String fileName = DateTime.now().millisecondsSinceEpoch.toString();
//             Reference ref =
//                 storage.ref().child('recordings').child('$fileName.mp3');

//             UploadTask uploadTask = ref.putBlob(audioBlob);

//             TaskSnapshot taskSnapshot = await uploadTask;
//             String downloadURL = await taskSnapshot.ref.getDownloadURL();

//             await FirebaseFirestore.instance.collection('recordings').add({
//               'url': downloadURL,
//               'createdAt': FieldValue.serverTimestamp(),
//             });

//             audioUrl = downloadURL;
//             notifyListeners();
//             print('Recording saved at: $downloadURL');
//           } else {
//             print('Failed to retrieve Blob from recording.');
//           }
//         } catch (e) {
//           print('Error uploading recording: $e');
//         }
//       } else {
//         print('Recording failed to save.');
//       }
//     } catch (e, stackTrace) {
//       print('Error stopping recording: $e');
//       print(stackTrace);
//     }
//   }

//   Future<html.Blob?> getRecordedAudioBlob(String path) async {
//     try {
//       final request =
//           await html.HttpRequest.request(path, responseType: 'blob');
//       return request.response as html.Blob?;
//     } catch (e, stackTrace) {
//       print('Error getting recorded audio blob: $e');
//       print(stackTrace);
//       return null;
//     }
//   }

//   void resetRecording() {
//     _isRecording = false;
//     _isPaused = false;
//     _transcribedText = "";
//     notifyListeners();
//     print('Recording reset.');
//   }

//   bool isPlaying = false;
//   bool isProcessings = false;
//   String? audioUrls;

//   Future<void> fetchAndPlayLatestAudio() async {
//     try {
//       isProcessings = true;
//       notifyListeners();

//       await Future.delayed(const Duration(seconds: 2));

//       final querySnapshot = await FirebaseFirestore.instance
//           .collection('recordings')
//           .orderBy('createdAt', descending: true)
//           .limit(1)
//           .get();

//       if (querySnapshot.docs.isNotEmpty) {
//         final latestAudio = querySnapshot.docs.first.data();

//         audioUrls = latestAudio['url'];
//         notifyListeners();

//         playAudio();
//       } else {
//         isProcessings = false;
//         notifyListeners();
//         print('No recordings found.');
//       }
//     } catch (e, stackTrace) {
//       print('Error fetching and playing latest audio: $e');
//       print(stackTrace);
//     }
//   }

//   void playAudio() async {
//     try {
//       if (audioUrls != null) {
//         await player.setUrl(audioUrls!);
//         player.play();

//         isPlaying = true;
//         isProcessings = false;
//         notifyListeners();
//       } else {
//         isProcessings = false;
//         notifyListeners();
//         print('No audio URL available to play.');
//       }
//     } catch (e, stackTrace) {
//       print('Error playing audio: $e');
//       print(stackTrace);
//     }
//   }

//   void stopAudio() async {
//     try {
//       isProcessings = true;
//       notifyListeners();

//       await Future.delayed(const Duration(seconds: 2));

//       player.stop();

//       isPlaying = false;
//       isProcessings = false;
//       notifyListeners();
//       print('Audio stopped.');
//     } catch (e, stackTrace) {
//       print('Error stopping audio: $e');
//       print(stackTrace);
//     }
//   }
// }

