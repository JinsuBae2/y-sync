import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'signup_screen.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'splash_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showLocalLogin = false;

  Future<void> _login() async {
    final loginId = _loginIdController.text.trim();
    final password = _passwordController.text.trim();

    if (loginId.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).login(loginId, password);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar('아이디 또는 비밀번호를 다시 확인해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithKakao() async {
    try {
      setState(() => _isLoading = true);
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      
      await _handleSocialLoginResult(token.accessToken, 'KAKAO');
    } catch (e) {
      _showErrorSnackBar('카카오 로그인에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(clientId: '286554208893-9glm4n7ul7qo21lin4k8eesfnpku81ah.apps.googleusercontent.com')
          : GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // User canceled
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String token = googleAuth.idToken ?? googleAuth.accessToken ?? '';
      if (token.isEmpty) throw Exception('No Token');
      
      await _handleSocialLoginResult(token, 'GOOGLE');
    } catch (e) {
      String errorMsg = '구글 로그인에 실패했습니다.';
      if (e is Exception) {
        final msg = e.toString().replaceAll('Exception: ', '');
        if (msg.isNotEmpty && msg != 'Exception') errorMsg = msg;
      }
      print('Google Login Error: $e');
      _showErrorSnackBar(errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialLoginResult(String accessToken, String provider) async {
    try {
      final result = await ref.read(authProvider.notifier).socialLogin(accessToken, provider);
      if (result != null) {
        // 202 Accepted: 미가입자, 추가 정보 입력 필요
        if (mounted) {
          _showSocialSignupBottomSheet(result['socialId'], result['provider']);
        }
      } else {
        if (mounted) {
          Navigator.of(this.context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  void _showSocialSignupBottomSheet(String socialId, String provider) {
    final studentIdController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    bool requirePassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${provider == "KAKAO" ? "카카오" : "구글"} 계정 연결',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    requirePassword ? '본인 확인을 위해 기존 계정의 비밀번호를 입력해주세요.' : 'Y-Sync 서비스 이용을 위해 학번과 이름을 입력해주세요.', 
                    style: TextStyle(color: requirePassword ? Colors.redAccent : Colors.grey)
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: studentIdController,
                    enabled: !requirePassword,
                    decoration: InputDecoration(
                      labelText: '학번',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    enabled: !requirePassword,
                    decoration: InputDecoration(
                      labelText: '이름',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (requirePassword) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      if (studentIdController.text.isEmpty || nameController.text.isEmpty) return;
                      if (requirePassword && passwordController.text.isEmpty) return;
                      
                      final navigator = Navigator.of(context);
                      final parentNavigator = Navigator.of(this.context);
                      
                      setSheetState(() => isSubmitting = true);
                      try {
                        await ref.read(authProvider.notifier).socialSignup(
                          studentIdController.text.trim(),
                          nameController.text.trim(),
                          socialId,
                          provider,
                          password: requirePassword ? passwordController.text : null,
                        );
                        if (mounted) {
                          navigator.pop(); // close bottom sheet
                          parentNavigator.pushReplacement(
                            MaterialPageRoute(builder: (_) => const SplashScreen()),
                          );
                        }
                      } catch (e) {
                        if (e.toString().contains('REQUIRE_PASSWORD')) {
                          setSheetState(() => requirePassword = true);
                        } else {
                          String errorMsg = e.toString().replaceAll('Exception: ', '');
                          if (errorMsg == 'Exception') errorMsg = '가입 처리 중 오류가 발생했습니다.';
                          _showErrorSnackBar(errorMsg);
                        }
                      } finally {
                        setSheetState(() => isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('가입 완료 및 로그인', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 로고 및 타이틀 Area
                    // 💡 로고 및 타이틀 Area - 소프트웨어융합과 정체성 반영
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withBlue(180),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.sync_rounded, size: 52, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '영남이공대 소프트웨어융합과',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Y-Sync',
                      style: TextStyle(
                        fontSize: 38, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '학과 정보와 일상을 연결하는 우리들만의 동기화',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Social Login Buttons
                    _buildSocialButton(
                      iconPath: 'assets/images/kakao_logo.png', // 카카오 로고가 필요함 (없으면 기본 아이콘 표시)
                      label: '카카오로 시작하기',
                      color: const Color(0xFFFEE500),
                      textColor: Colors.black87,
                      onPressed: _loginWithKakao,
                      iconFallback: Icons.chat_bubble_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildSocialButton(
                      iconPath: 'assets/images/google_logo.png',
                      label: '구글로 시작하기',
                      color: Colors.white,
                      textColor: Colors.black87,
                      borderColor: Colors.grey.shade300,
                      onPressed: _loginWithGoogle,
                      iconFallback: Icons.g_mobiledata_rounded,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Local Login Toggle
                    InkWell(
                      onTap: () => setState(() => _showLocalLogin = !_showLocalLogin),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '일반 학번으로 로그인',
                              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                            Icon(_showLocalLogin ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                    
                    // Collapsible Local Login Area
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _showLocalLogin ? null : 0,
                      curve: Curves.easeInOut,
                      child: ClipRect(
                        child: _showLocalLogin ? Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: _loginIdController,
                              label: '아이디',
                              hint: '학번을 입력해주세요',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: _passwordController,
                              label: '비밀번호',
                              hint: '비밀번호를 입력해주세요',
                              icon: Icons.lock_outline,
                              isPassword: true,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                    : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('계정이 없으신가요?', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SignupScreen()),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  child: const Text('회원가입하기'),
                                ),
                              ],
                            ),
                          ],
                        ) : const SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String iconPath,
    required String label,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onPressed,
    required IconData iconFallback,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: color == Colors.white ? 1 : 0,
          shadowColor: Colors.black.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderColor != null ? BorderSide(color: borderColor, width: 1.2) : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconFallback, color: textColor, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
