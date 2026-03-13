import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const YSyncApp());
}

class YSyncApp extends StatelessWidget {
  const YSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Y-Sync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HelloScreen(),
    );
  }
}

class HelloScreen extends StatefulWidget {
  const HelloScreen({super.key});

  @override
  State<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends State<HelloScreen> {
  String _message = "서버 응답 대기 중...";
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchHelloMessage();
  }

  Future<void> _fetchHelloMessage() async {
    try {
      final response = await _dio.get('http://localhost:8080/api/v1/hello');
      setState(() {
        _message = response.data.toString();
      });
    } catch (e) {
      setState(() {
        _message = "에러 발생: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Y-Sync 통신 테스트'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchHelloMessage,
        tooltip: '새로고침',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
