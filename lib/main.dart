import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'package:signalaudiostream/streamaudio.dart';
import 'package:lottie/lottie.dart';


void main() {
  runApp(const SignalStreamApp());
}

class SignalStreamApp extends StatelessWidget {
  const SignalStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Signal Stream',
      theme: ThemeData.light(),
      home: const HomeScreen(), // <– now wrapped in MaterialApp
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WebSocketChannel channel;
  AudioSession? session;
  bool isRecording = false;

  @override
  void initState(){
    super.initState();
    // WebSocket connection is created here
    channel = WebSocketChannel.connect(
      Uri.parse("ws://192.168.31.182:8765"),
    );
    print('🛰️ Attempted WebSocket connection to: ${channel}');
    channel.stream.listen(
          (message) {
        print('📥 Message from server: $message');
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
      },
      onDone: () {
        print('🔌 WebSocket closed.');
      },
    );
  }

  @override
  void dispose() {
    // Always close the WebSocket connection when widget is destroyed
    channel.sink.close();
    super.dispose();
  }

  Future<void> startStreaming() async {
    session = await startStream(channel);

    if (session != null) {
      print('Audio session started');
      setState(() {
        isRecording = true;
      });
    } else {
      print('Could not start audio session');
    }
  }

  Future<void> pauseStreaming() async {
    await session?.subscription.cancel();
    await session?.recorder.stop();
    await session?.recorder.dispose();
    session = null;
    setState(() {
      isRecording = false;
    });
    print('Recording paused and cleaned up');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signal Stream'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.graphic_eq,
                size: 100,
                color: Colors.tealAccent,
              ),
              if (isRecording)
                Lottie.asset('assets/animations/record.json', height: 120),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isRecording ? null : startStreaming,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Start Stream'),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: isRecording ? pauseStreaming : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  side: const BorderSide(color: Colors.tealAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Pause'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}