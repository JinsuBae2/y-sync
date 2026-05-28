import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/notice_provider.dart'; // secureStorageProvider 참조를 위해 임포트
import 'main_tab_screen.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final storage = ref.read(secureStorageProvider);
      
      // PIN 저장 및 온보딩 확인 플래그 설정
      await storage.write(key: 'user_pin', value: _pinController.text.trim());
      await storage.write(key: 'has_seen_pin_setup', value: 'true');

      // 생체인증 여부 묻는 간단한 다이얼로그 띄우기
      if (mounted) {
        _showBiometricDialog(storage);
      }
    } catch (e) {
      _showSnackBar('PIN 설정 중 오류가 발생했습니다.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _skipPinSetup() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(secureStorageProvider);
      // 온보딩 확인 플래그만 세팅
      await storage.write(key: 'has_seen_pin_setup', value: 'true');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainTabScreen()),
        );
      }
    } catch (e) {
      _showSnackBar('설정 스킵 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBiometricDialog(FlutterSecureStorage storage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('생체인증 사용', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('지문 또는 FaceID를 사용하여 다음 로그인 시 더욱 편리하게 인증하시겠습니까?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () async {
              await storage.write(key: 'use_biometric', value: 'false');
              if (mounted) {
                Navigator.pop(context); // 닫기
                _navigateToMain();
              }
            },
            child: const Text('아니오', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await storage.write(key: 'use_biometric', value: 'true');
              if (mounted) {
                Navigator.pop(context); // 닫기
                _navigateToMain();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('예'),
          ),
        ],
      ),
    );
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainTabScreen()),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('보안 설정'),
        centerTitle: true,
        automaticallyImplyLeading: false, // 뒤로가기 버튼 비활성화
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(Icons.lock_person_rounded, size: 72, color: primaryColor),
                const SizedBox(height: 24),
                Text(
                  '간편 PIN 설정 (선택)',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '학과 전용 Y-Sync 서비스를 보다 안전하게 이용하기 위해\n6자리 PIN 번호를 설정할 수 있습니다.\n(언제든지 마이페이지에서 다시 변경 가능합니다.)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // PIN 입력 필드
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 18, letterSpacing: 8.0, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'PIN 번호 입력 (6자리)',
                    labelStyle: const TextStyle(letterSpacing: 0, fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(Icons.password_rounded),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length != 6) {
                      return '6자리 숫자를 입력해 주세요.';
                    }
                    if (int.tryParse(value) == null) {
                      return '숫자만 입력 가능합니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // PIN 확인 필드
                TextFormField(
                  controller: _confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 18, letterSpacing: 8.0, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'PIN 번호 확인',
                    labelStyle: const TextStyle(letterSpacing: 0, fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value != _pinController.text) {
                      return '입력한 PIN 번호와 일치하지 않습니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 48),

                // 저장 완료 버튼
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('설정 완료 및 시작', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),

                // 다음에 하기 버튼
                SizedBox(
                  height: 54,
                  child: TextButton(
                    onPressed: _isLoading ? null : _skipPinSetup,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                      ),
                    ),
                    child: const Text('다음에 하기 (건너뛰기)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
