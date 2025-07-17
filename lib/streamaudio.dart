import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert'; // Needed for jsonEncode and base64Encode


class AudioSession {
  final StreamSubscription<Uint8List> subscription;
  final AudioRecorder recorder;

  AudioSession({ required this.subscription, required this.recorder});
}

Future<AudioSession?> startStream(WebSocketChannel channel, String deviceID) async{
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

    final subscription = stream.listen(
          (Uint8List data) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final jsonMessage = jsonEncode({
            'msg_type': 'audio_stream',
            'timestamp': timestamp,
            'device_id': deviceID,
            'data': base64Encode(data),
          });

          channel.sink.add(jsonMessage);
        } catch (e) {
          print('❌ Failed to encode or send data: $e');
        }
      },
      onError: (error) {
        print('❌ Audio stream error: $error');
      },
    );

    return AudioSession(subscription: subscription, recorder: recorder);
  }
  else {
    print('❌ Microphone permission not granted.');
    return null;
  }
}