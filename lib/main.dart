import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'package:fast_audio_stream/streamaudio.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';

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

  Timer? _heartbeatSendTimer;
  bool isConnecting = false;
  Timer? _heartbeatTimeout;

  @override
  void initState(){
    super.initState();
  }

  @override
  void dispose() {
    _heartbeatSendTimer?.cancel();
    _heartbeatTimeout?.cancel();
    channel.sink.close();
    _ipController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _startHeartbeat(String deviceID) {
    _heartbeatSendTimer?.cancel();
    _heartbeatSendTimer = Timer.periodic(Duration(seconds: 2), (_) {
      final heartbeat = {
        "msg_type": "heartbeat",
        "device_id": deviceID,
        "timestamp": DateTime.now().millisecondsSinceEpoch
      };
      try {
        channel.sink.add(jsonEncode(heartbeat));
        print("💓 Sent heartbeat for $deviceID");
      } catch (e) {
        print("❌ Failed to send heartbeat: $e");
      }
    });
  }

  void _showHeartbeatTimeoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Server Timeout"),
          content: const Text("No heartbeat received from the server."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  void _handleHeartbeatAck() {
    // Cancel previous timer
    _heartbeatTimeout?.cancel();

    // Start a new timeout
    _heartbeatTimeout = Timer(const Duration(seconds: 3), () {
      print("❌ No heartbeat from server — connection lost.");
      _handleDisconnect();
      _showHeartbeatTimeoutDialog();
    });
  }

  void _showServerTimeoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Connection Failed"),
          content: const Text("Server did not respond. Please check the IP and try again."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  void _handleDisconnect() {
    if (!isConnected && !isConnecting) return; // already handled

    _heartbeatSendTimer?.cancel();
    _heartbeatTimeout?.cancel();
    _heartbeatSendTimer = null;

    if (mounted) {
      setState(() {
        isConnected = false;
        isConnecting = false;
        isRecording = false;
      });
    }
  }

  void connectToServer(String ipAddress) {
    try {
      final wsUri = Uri.parse("ws://$ipAddress:8765/ws/stream");
      channel = WebSocketChannel.connect(wsUri);
      print('🛰️ Attempting connection to: $wsUri');

      final connectionRequest = {
        "msg_type": "connection_request",
        "device_id": _idController.text.trim(),
        "timestamp": DateTime.now().millisecondsSinceEpoch
      };
      channel.sink.add(jsonEncode(connectionRequest));

      // Temporary state: pending connection
      bool confirmed = false;

      channel.stream.listen(
            (message) {
          print('✅ Message from server: $message');

          try {
            final decoded = jsonDecode(message);
            final msgType = decoded['msg_type'];
            final ackDeviceId = decoded['device_id'];

            // Handle connection ACK
            if (msgType == 'connection_ack' &&
                ackDeviceId == _idController.text.trim()) {
              if (!confirmed) {
                setState(() {
                  isConnected = true;
                  isConnecting = false;
                });
                confirmed = true;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Connected to server"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                _startHeartbeat(_idController.text.trim());
              }
            }

            // Handle heartbeat ACK
            if (msgType == 'heartbeat_ack' &&
                ackDeviceId == _idController.text.trim()) {
                _handleHeartbeatAck(); // reset the 3s watchdog
            }

          } catch (e) {
            print("⚠️ Could not parse server message: $e");
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('❌ WebSocket closed');
          _handleDisconnect();
        },
      );

      // Optional: Add connection timeout safeguard
      Future.delayed(const Duration(seconds: 3), () {
        if (!confirmed) {
          print("❌ Connection timeout — server didn't respond.");
          _handleDisconnect();
          _showServerTimeoutDialog();
          setState(() {
            isConnecting = false;
          });
        }

      });

    } catch (e) {
      print("🚫 WebSocket connection failed: $e");
      setState(() {
        isConnecting = false;
      });
      _handleDisconnect();
    }
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
                  onPressed: (isConnected || isConnecting || _ipController.text.trim().isEmpty)
                      ? null
                      : () {
                    final ip = _ipController.text.trim();
                    setState(() {
                      isConnecting = true;
                    });
                    connectToServer(ip);
                  },
                  child: isConnecting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Connect to Server'),
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