import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'package:fast_audio_stream/streamaudio.dart';
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
  final TextEditingController _ipController = TextEditingController(text: '192.168.31.182');
  final TextEditingController _idController = TextEditingController();

  late WebSocketChannel channel;
  bool isConnected = false;
  AudioSession? session;
  bool isRecording = false;


  @override
  void initState(){
    super.initState();
  }

  @override
  void dispose() {
    // Always close the WebSocket connection when widget is destroyed
    channel.sink.close();
    _ipController.dispose();
    super.dispose();
  }

  void connectToServer(String ipAddress) {
     channel = WebSocketChannel.connect(Uri.parse("ws://$ipAddress:8765"));
     print('🛰️ Attempted WebSocket connection to: ${channel}');
     setState(() {
       isConnected = true;
     });
     channel.stream.listen(
           (message) {
         print('Message from server: $message');
       },
       onError: (error) {
         print('WebSocket error: $error');
       },
       onDone: () {
         print('WebSocket closed.');
       },
     );
  }

  void disconnectFromServer() {
    channel.sink.close(); // closes the WebSocket connection
    setState(() {
      isConnected = false; // make sure this variable controls your UI state
    });
    print('Disconnected from WebSocket server');
  }

  Future<void> startStreaming(WebSocketChannel channel, String deviceID) async {
    session = await startStream(channel, deviceID);

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
          child: Center(
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
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Device ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20,),
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Server IP Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (isConnected || _ipController.text.trim().isEmpty)
                      ? null
                      : () {
                    final ip = _ipController.text.trim();
                    connectToServer(ip);
                  },
                  child: const Text('Connect to Server'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (isRecording || !isConnected)
                      ? null
                      : () {
                    final deviceID = (_idController.text.trim().isNotEmpty)
                        ? _idController.text.trim()
                        : "device-${DateTime.now().millisecondsSinceEpoch}";
                    startStreaming(channel, deviceID);
                    },
                  style: ElevatedButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                    side: const BorderSide(color: Colors.tealAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Pause'),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: isConnected ? disconnectFromServer : null,
                  style: OutlinedButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                    side: const BorderSide(color: Colors.tealAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Disconnect from Server'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}