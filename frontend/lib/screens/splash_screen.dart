import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/auth_provider.dart';
import '../models/member.dart';
import 'login_screen.dart';
import 'main_tab_screen.dart';
import 'pin_setup_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isLocalAuthPassed = false; // 💡 로컬 보안 인증 통과 여부

  @override
  void initState() {
    super.initState();
    _checkLocalAuth();
  }

  Future<void> _checkLocalAuth() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      // 토큰이 없으면 로그인 화면으로 이동
      if (mounted) _navigateToLogin();
      return;
    }

    final useBiometric = await _storage.read(key: 'use_biometric') == 'true';
    final userPin = await _storage.read(key: 'user_pin');
    final hasSeenPinSetup = await _storage.read(key: 'has_seen_pin_setup') == 'true';

    if (useBiometric) {
      bool authenticated = false;
      try {
        setState(() => _isAuthenticating = true);
        authenticated = await _localAuth.authenticate(
          localizedReason: '앱을 시작하려면 인증해주세요.',
          biometricOnly: true,
        );
      } catch (e) {
        // 인증 에러 시 PIN으로 폴백
      } finally {
        if (mounted) setState(() => _isAuthenticating = false);
      }

      if (authenticated) {
        _isLocalAuthPassed = true;
        _proceedToMain();
      } else {
        if (userPin != null) {
          _promptPin(userPin);
        } else {
          _forceLogout();
        }
      }
    } else if (userPin != null) {
      _promptPin(userPin);
    } else {
      _isLocalAuthPassed = true;
      if (!hasSeenPinSetup && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
        );
      } else {
        _proceedToMain();
      }
    }
  }

  void _promptPin(String correctPin) {
    if (!mounted) return;
    final pinController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('PIN 입력', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'PIN을 입력해주세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _forceLogout(),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == correctPin) {
                _isLocalAuthPassed = true; // 💡 로컬 인증 통과 설정
                Navigator.pop(context);
                _proceedToMain();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN이 올바르지 않습니다.')),
                );
                pinController.clear();
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) _navigateToLogin();
  }

  void _proceedToMain() {
    if (!_isLocalAuthPassed) return; // 💡 로컬 인증 통과 전에는 화면 전환 금지
    final authState = ref.read(authProvider);
    if (authState is AsyncData<Member?>) {
      final member = authState.value;
      if (member != null && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MainTabScreen()));
      } else if (member == null && mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // _proceedToMain에서 authProvider 변화를 감지하여 자동 라우팅될 수 있게 함
    ref.listen(authProvider, (previous, next) {
      // 💡 로컬 인증이 최종 통과된 경우에만 자동 라우팅 허용
      if (_isLocalAuthPassed) {
        next.whenData((member) {
          if (member != null) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MainTabScreen()));
          } else {
            _navigateToLogin();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF164687),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_rounded, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Y-Sync',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 48),
            if (!_isAuthenticating)
              const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
