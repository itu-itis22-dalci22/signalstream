import 'package:flutter/material.dart';

void main() {
  runApp(const SignalStreamApp());
}

class SignalStreamApp extends StatelessWidget {
  const SignalStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signal Stream',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(primary: Colors.tealAccent),
        scaffoldBackgroundColor: Colors.grey[800],
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {}, // You’ll implement this
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
                onPressed: () {}, // You’ll implement this
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
