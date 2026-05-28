import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthSettingsScreen extends ConsumerStatefulWidget {
  const AuthSettingsScreen({super.key});

  @override
  ConsumerState<AuthSettingsScreen> createState() => _AuthSettingsScreenState();
}

class _AuthSettingsScreenState extends ConsumerState<AuthSettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  
  bool _useBiometric = false;
  bool _usePin = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final useBiometricStr = await _storage.read(key: 'use_biometric');
    final pinStr = await _storage.read(key: 'user_pin');
    
    setState(() {
      _useBiometric = useBiometricStr == 'true';
      _usePin = pinStr != null;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        _showSnackBar('기기에서 생체 인식을 지원하지 않거나 설정되어 있지 않습니다.');
        return;
      }
      
      bool authenticated = await _localAuth.authenticate(
        localizedReason: '생체 인식을 활성화하려면 인증이 필요합니다.',
      );
      
      if (authenticated) {
        await _storage.write(key: 'use_biometric', value: 'true');
        setState(() => _useBiometric = true);
        _showSnackBar('생체 인식이 활성화되었습니다.');
      }
    } else {
      await _storage.delete(key: 'use_biometric');
      setState(() => _useBiometric = false);
      _showSnackBar('생체 인식이 해제되었습니다.');
    }
  }

  Future<void> _setupPin() async {
    if (_usePin) {
      // PIN 해제
      await _storage.delete(key: 'user_pin');
      setState(() => _usePin = false);
      _showSnackBar('PIN 로그인이 해제되었습니다.');
      return;
    }
    
    // PIN 설정
    final pinController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN 설정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '6자리 숫자를 입력하세요',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (pinController.text.length >= 4) {
                Navigator.pop(context, pinController.text);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _storage.write(key: 'user_pin', value: result);
      setState(() => _usePin = true);
      _showSnackBar('PIN 설정이 완료되었습니다.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보안 및 간편 로그인', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('간편 인증 수단', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('생체 인식 (지문/FaceID)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('앱 실행 시 생체 인식으로 빠르게 로그인합니다.', style: TextStyle(fontSize: 13)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.fingerprint, color: Colors.blue.shade700),
                  ),
                  value: _useBiometric,
                  onChanged: _toggleBiometric,
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  title: const Text('PIN 잠금', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_usePin ? '사용 중' : '사용 안 함', style: const TextStyle(fontSize: 13)),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.pin, color: Colors.orange.shade700),
                  ),
                  trailing: ElevatedButton(
                    onPressed: _setupPin,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _usePin ? Colors.grey.shade200 : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      foregroundColor: _usePin ? Colors.black87 : Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_usePin ? '해제' : '설정'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
