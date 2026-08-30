import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'signup_screen.dart';
import 'splash_screen.dart';
import '../theme/app_design_tokens.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

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

  Future<void> _showPasswordResetDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final loginIdController = TextEditingController(
      text: _loginIdController.text.trim(),
    );
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var codeSent = false;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            '비밀번호 재설정',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    codeSent
                        ? '등록된 학교 이메일로 받은 인증번호와 새 비밀번호를 입력해 주세요.'
                        : '학번과 이름을 확인한 뒤 등록된 학교 이메일로 인증번호를 보냅니다.',
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: loginIdController,
                    enabled: !codeSent,
                    decoration: const InputDecoration(
                      labelText: '학번',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!codeSent)
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '6자리 인증번호',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '새 비밀번호',
                        helperText: '영문, 숫자, 특수문자를 포함한 8자 이상',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '새 비밀번호 확인',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final loginId = loginIdController.text.trim();
                      if (loginId.isEmpty) return;
                      if (!codeSent && nameController.text.trim().isEmpty) {
                        return;
                      }
                      if (codeSent &&
                          (codeController.text.trim().isEmpty ||
                              newPasswordController.text.isEmpty)) {
                        return;
                      }
                      if (codeSent &&
                          newPasswordController.text !=
                              confirmPasswordController.text) {
                        _showErrorSnackBar('새 비밀번호가 서로 다릅니다.');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        if (!codeSent) {
                          await ref
                              .read(authProvider.notifier)
                              .requestPasswordReset(
                                loginId,
                                nameController.text.trim(),
                              );
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              codeSent = true;
                              isSubmitting = false;
                            });
                          }
                        } else {
                          await ref
                              .read(authProvider.notifier)
                              .confirmPasswordReset(
                                loginId,
                                codeController.text.trim(),
                                newPasswordController.text,
                              );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            _loginIdController.text = loginId;
                            _passwordController.clear();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '비밀번호가 재설정되었습니다. 새 비밀번호로 로그인해 주세요.',
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        _showErrorSnackBar(
                          e.toString().replaceAll('Exception: ', ''),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(codeSent ? '비밀번호 변경' : '인증번호 받기'),
            ),
          ],
        ),
      ),
    );

    loginIdController.dispose();
    nameController.dispose();
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _showSocialLoginComingSoon() async {
    // 💡 비활성화된 소셜 인증 API를 호출하지 않고 향후 지원 예정임을 안내합니다.
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          '소셜 로그인 준비 중',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Google 로그인은 추후 업데이트에서 제공할 예정입니다.\n지금은 학번으로 로그인해 주세요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 기존 계정 연결 예외 흐름을 위해 유지합니다.
  // ignore: unused_element
  void _showSocialSignupBottomSheet(String socialId, String provider) {
    final studentIdController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    bool requirePassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${provider == "KAKAO" ? "카카오" : "구글"} 계정 연결',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    requirePassword
                        ? '본인 확인을 위해 기존 계정의 비밀번호를 입력해주세요.'
                        : 'Y-Sync 서비스 이용을 위해 학번과 이름을 입력해주세요.',
                    style: TextStyle(
                      color: requirePassword ? Colors.redAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: studentIdController,
                    enabled: !requirePassword,
                    decoration: InputDecoration(
                      labelText: '학번',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    enabled: !requirePassword,
                    decoration: InputDecoration(
                      labelText: '이름',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (requirePassword) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (studentIdController.text.isEmpty ||
                                nameController.text.isEmpty) {
                              return;
                            }
                            if (requirePassword &&
                                passwordController.text.isEmpty) {
                              return;
                            }

                            final navigator = Navigator.of(context);
                            final parentNavigator = Navigator.of(this.context);

                            setSheetState(() => isSubmitting = true);
                            try {
                              await ref
                                  .read(authProvider.notifier)
                                  .socialSignup(
                                    studentIdController.text.trim(),
                                    nameController.text.trim(),
                                    socialId,
                                    provider,
                                    password: requirePassword
                                        ? passwordController.text
                                        : null,
                                  );
                              if (mounted) {
                                navigator.pop(); // close bottom sheet
                                parentNavigator.pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const SplashScreen(),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (e.toString().contains('REQUIRE_PASSWORD')) {
                                setSheetState(() => requirePassword = true);
                              } else {
                                String errorMsg = e.toString().replaceAll(
                                  'Exception: ',
                                  '',
                                );
                                if (errorMsg == 'Exception') {
                                  errorMsg = '가입 처리 중 오류가 발생했습니다.';
                                }
                                _showErrorSnackBar(errorMsg);
                              }
                            } finally {
                              setSheetState(() => isSubmitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            '가입 완료 및 로그인',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
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
      backgroundColor: const Color(0xFF071424),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0C1C32), Color(0xFF06111F)],
              ),
            ),
          ),
          const CustomPaint(painter: _LoginBackgroundPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignTokens.blue.withValues(alpha: 0.22),
                          blurRadius: 52,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.14),
                                Colors.white.withValues(alpha: 0.07),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Semantics(
                                image: true,
                                label: 'Y-Sync 천마 로고',
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF3F7FF,
                                    ).withValues(alpha: 0.96),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppDesignTokens.blue.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 22,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/branding/cheonma_logo.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Y-Sync',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                '영남이공대 소프트웨어융합과',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFB8C3D4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildInputField(
                                controller: _loginIdController,
                                label: '학번',
                                hint: '학번을 입력하세요',
                                icon: Icons.badge_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _passwordController,
                                label: '비밀번호',
                                hint: '비밀번호를 입력하세요',
                                icon: Icons.lock_outline,
                                isPassword: true,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppDesignTokens.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          '로그인',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: _showPasswordResetDialog,
                                    child: const Text(
                                      '비밀번호를 잊으셨나요?',
                                      style: TextStyle(
                                        color: Color(0xFFB8C3D4),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SignupScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '회원가입하기',
                                      style: const TextStyle(
                                        color: Color(0xFF71A1FF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Color(0x3DFFFFFF)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '또는',
                                      style: TextStyle(
                                        color: Color(0xFF8F9CAF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Color(0x3DFFFFFF)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSocialButton(
                                iconPath: '',
                                label: 'Google로 계속',
                                color: Colors.white.withValues(alpha: 0.08),
                                textColor: Colors.white,
                                borderColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
                                onPressed: _showSocialLoginComingSoon,
                                iconFallback: Icons.g_mobiledata_rounded,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: borderColor != null
                ? BorderSide(color: borderColor)
                : BorderSide.none,
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFFDCE4EF),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF8794A8), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFFADB9CA), size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppDesignTokens.blue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  const _LoginBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bluePaint = Paint()
      ..color = AppDesignTokens.blue.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final cyanPaint = Paint()
      ..color = const Color(0xFF47D7FF).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(
      Offset(-size.width * 0.08, size.height * 0.18),
      size.width * 0.52,
      bluePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 1.04, size.height * 0.72),
      size.width * 0.58,
      cyanPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 1.04),
      size.width * 0.42,
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundPainter oldDelegate) => false;
}
