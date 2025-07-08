import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:typed_data';
import 'dart:async';

class AudioSession {
  final StreamSubscription<Uint8List> subscription;
  final AudioRecorder recorder;

  AudioSession({ required this.subscription, required this.recorder});
}

Future<AudioSession?> startStream(WebSocketChannel channel) async{
  final recorder = AudioRecorder();

  if (await recorder.hasPermission()) {
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );

    print('🎤 Recording started. Streaming chunks...');

    final subscription = stream.listen((Uint8List data) {
      print('🔊 Audio chunk: ${data.length} bytes');
      channel.sink.add(data); // send to WebSocket
    });

    return AudioSession(subscription: subscription, recorder: recorder);
  }
  else {
    print('❌ Microphone permission not granted.');
    return null;
  }
}