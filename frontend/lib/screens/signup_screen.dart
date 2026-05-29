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
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isIdChecked = false;
  bool _isIdDuplicate = true;

  @override
  void initState() {
    super.initState();
    _loginIdController.addListener(() {
      if (_isIdChecked) {
        setState(() {
          _isIdChecked = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showWarningSnackBar(String message) {
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

  Future<void> _checkDuplicateId() async {
    final loginId = _loginIdController.text.trim();
    if (loginId.isEmpty) {
      _showWarningSnackBar('아이디를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isDuplicate = await ref.read(authProvider.notifier).checkDuplicate(loginId);
      setState(() {
        _isIdChecked = true;
        _isIdDuplicate = isDuplicate;
      });
      if (isDuplicate) {
        _showErrorSnackBar('이미 사용 중인 아이디입니다.');
      } else {
        _showSuccessSnackBar('사용 가능한 아이디입니다!');
      }
    } catch (e) {
      _showErrorSnackBar('중복 확인 중 오류가 발생했습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signup() async {
    final loginId = _loginIdController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final passwordConfirm = _passwordConfirmController.text.trim();

    if (loginId.isEmpty || name.isEmpty || password.isEmpty || passwordConfirm.isEmpty) {
      _showWarningSnackBar('모든 항목을 입력해주세요.');
      return;
    }

    if (!_isIdChecked) {
      _showWarningSnackBar('아이디 중복확인을 진행해주세요.');
      return;
    }

    if (_isIdDuplicate) {
      _showWarningSnackBar('이미 사용 중인 아이디입니다.');
      return;
    }

    if (password != passwordConfirm) {
      _showWarningSnackBar('비밀번호와 비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).signup(loginId, password, name);
      if (mounted) {
        _showSuccessSnackBar('회원가입 완료! 로그인해주세요.');
        Navigator.pop(context); // 돌아가기
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('가입 실패: 서버 오류 또는 이미 존재하는 아이디입니다.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                        '계정 생성',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '간단한 정보 입력으로 Y-Sync를 시작하세요.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 36),
                      
                      // ID Input & Duplicate Check
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _loginIdController,
                              label: '아이디',
                              hint: '학번 (예: 2300000)',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: _isLoading ? null : _checkDuplicateId,
                              child: const Text('중복확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                      if (_isIdChecked) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              _isIdDuplicate ? '이미 존재하는 아이디입니다.' : '사용 가능한 아이디입니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isIdDuplicate ? Colors.redAccent.shade700 : Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      
                      // Name Input
                      _buildInputField(
                        controller: _nameController,
                        label: '이름',
                        hint: '실명을 입력해주세요',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Input
                      _buildInputField(
                        controller: _passwordController,
                        label: '비밀번호',
                        hint: '안전한 비밀번호 입력',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 20),

                      // Password Confirm Input
                      _buildInputField(
                        controller: _passwordConfirmController,
                        label: '비밀번호 확인',
                        hint: '비밀번호 재입력',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 36),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: _isLoading ? null : _signup,
                          child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87)) 
                              : const Text('가입 완료하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
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
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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
        ),
      ],
    );
  }
}
