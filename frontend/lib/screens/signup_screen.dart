import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _loginIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); // 💡 이메일 아이디 입력 컨트롤러 추가
  final _verificationCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _isStudentInfoVerified = false; // 1차 정보 대조 확인 완료 여부
  bool _isEmailSent = false;          // 2차 이메일 인증코드 발송 여부
  bool _isVerified = false;           // 이메일 인증 최종 통과 여부

  Timer? _timer;
  int _timerSeconds = 300; // 5분

  @override
  void dispose() {
    _loginIdController.dispose();
    _nameController.dispose();
    _emailController.dispose(); // 💡 이메일 컨트롤러 해제 추가
    _verificationCodeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timerSeconds = 300;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isEmailSent = false;
        });
        _showErrorSnackBar('인증 시간이 만료되었습니다. 인증 코드를 재발송해 주세요.');
      }
    });
  }

  String _formatTimerText() {
    final minutes = (_timerSeconds / 60).floor();
    final seconds = _timerSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
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
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  // 1단계: 학번 및 이름 1차 대조 확인
  Future<void> _verifyStudentInfo() async {
    final loginId = _loginIdController.text.trim();
    final name = _nameController.text.trim();

    if (loginId.isEmpty || name.isEmpty) {
      _showWarningSnackBar('학번과 이름을 모두 입력해주세요.');
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(loginId)) {
      _showWarningSnackBar('학번은 숫자만 입력 가능합니다.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).verifyStudent(loginId, name);
      setState(() {
        _isStudentInfoVerified = true;
      });
      _showSuccessSnackBar('학생 정보가 확인되었습니다. 본인 인증을 진행해 주세요.');
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2단계: 인증 코드 메일 발송
  Future<void> _sendVerificationCode() async {
    final loginId = _loginIdController.text.trim();
    final name = _nameController.text.trim();
    final emailLocal = _emailController.text.trim();

    if (emailLocal.isEmpty) {
      _showWarningSnackBar('이메일 아이디를 입력해주세요.');
      return;
    }

    final fullEmail = '$emailLocal@ync.ac.kr';

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).sendVerificationCode(loginId, name, fullEmail);
      setState(() {
        _isEmailSent = true;
      });
      _startTimer();
      _showSuccessSnackBar('학생 메일($fullEmail)로 인증 코드를 전송했습니다.');
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2-1단계: 인증 코드 일치 확인
  Future<void> _verifyCode() async {
    final loginId = _loginIdController.text.trim();
    final code = _verificationCodeController.text.trim();

    if (code.isEmpty) {
      _showWarningSnackBar('인증 코드를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isSuccess = await ref.read(authProvider.notifier).verifyCode(loginId, code);
      if (isSuccess) {
        _timer?.cancel();
        setState(() {
          _isVerified = true;
        });
        _showSuccessSnackBar('본인 이메일 인증에 성공했습니다!');
      } else {
        _showErrorSnackBar('인증 코드가 올바르지 않습니다.');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3단계: 가입 완료
  Future<void> _signup() async {
    final loginId = _loginIdController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final passwordConfirm = _passwordConfirmController.text.trim();

    if (loginId.isEmpty || name.isEmpty || password.isEmpty || passwordConfirm.isEmpty) {
      _showWarningSnackBar('모든 항목을 입력해주세요.');
      return;
    }

    if (!_isVerified) {
      _showWarningSnackBar('이메일 인증을 완료해주세요.');
      return;
    }

    if (password != passwordConfirm) {
      _showWarningSnackBar('비밀번호와 비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    if (password.length < 4) {
      _showWarningSnackBar('비밀번호는 최소 4자 이상이어야 합니다.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).signup(loginId, password, name);
      if (mounted) {
        _showSuccessSnackBar('회원가입이 완료되었습니다. 로그인해 주세요.');
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
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
                      const Text(
                        '학생 인증 회원가입',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '학적 대조 후 학교 이메일을 이용해 가입을 진행합니다.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // 1단계: 학번 및 이름 입력 영역
                      _buildInputField(
                        controller: _loginIdController,
                        label: '학번',
                        hint: '학번 입력 (예: 2305009)',
                        icon: Icons.badge_outlined,
                        enabled: !_isStudentInfoVerified,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _nameController,
                        label: '이름',
                        hint: '실명 입력',
                        icon: Icons.person_outline,
                        enabled: !_isStudentInfoVerified,
                      ),
                      const SizedBox(height: 20),

                      if (!_isStudentInfoVerified) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            onPressed: _isLoading ? null : _verifyStudentInfo,
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('학생 정보 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],

                      // 1차 정보 대조 통과 완료 시
                      if (_isStudentInfoVerified) ...[
                        // 학생 인증 완료 배지
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '학생 정보가 확인되었습니다.',
                                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2단계: 이메일 전송 패널 및 본인 인증
                        if (!_isVerified) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '이메일 본인 인증',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 48,
                                        child: TextField(
                                          controller: _emailController,
                                          enabled: !_isEmailSent,
                                          style: const TextStyle(fontSize: 14),
                                          decoration: InputDecoration(
                                            hintText: '이메일 아이디 입력',
                                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                            prefixIcon: const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade200),
                                            ),
                                            disabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: primaryColor, width: 1.5),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        '@ync.ac.kr',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor.withOpacity(0.1),
                                      foregroundColor: primaryColor,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _isLoading ? null : _sendVerificationCode,
                                    child: Text(
                                      _isEmailSent ? '인증 코드 재전송' : '인증 코드 전송',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 이메일 코드가 발송되었고 아직 검증되지 않은 상태
                        if (_isEmailSent && !_isVerified) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  controller: _verificationCodeController,
                                  label: '인증 번호 (6자리)',
                                  hint: '인증 번호 입력',
                                  icon: Icons.lock_open_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  onPressed: _isLoading ? null : _verifyCode,
                                  child: const Text('인증확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '남은 시간: ${_formatTimerText()}',
                              style: TextStyle(
                                color: Colors.redAccent.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 2단계 완료 (이메일 인증 성공 시)
                        if (_isVerified) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '이메일 본인인증이 완료되었습니다.',
                                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 3단계: 최종 비밀번호 입력 폼
                          _buildInputField(
                            controller: _passwordController,
                            label: '비밀번호 설정',
                            hint: '비밀번호 입력 (최소 4자)',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: _passwordConfirmController,
                            label: '비밀번호 확인',
                            hint: '비밀번호 재입력',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 28),

                          // 가입 버튼
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
                              onPressed: _isLoading ? null : _signup,
                              child: _isLoading 
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                  : const Text('가입 완료하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
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
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            enabled: enabled,
            style: TextStyle(fontSize: 15, color: enabled ? Colors.black87 : Colors.grey.shade600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
              filled: true,
              fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
