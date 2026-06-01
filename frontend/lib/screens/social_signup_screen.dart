import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'splash_screen.dart';

class SocialSignupScreen extends ConsumerStatefulWidget {
  final String socialId;
  final String provider;

  const SocialSignupScreen({
    super.key,
    required this.socialId,
    required this.provider,
  });

  @override
  ConsumerState<SocialSignupScreen> createState() => _SocialSignupScreenState();
}

class _SocialSignupScreenState extends ConsumerState<SocialSignupScreen> {
  // 💡 컨트롤러 정의
  final _studentIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  // 💡 상태 변수 정의
  bool _isLoading = false;
  bool _requirePassword = false;
  bool _isIdChecked = false;
  bool _isIdDuplicate = true;

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 💡 경고 메시지 표시용 스낵바
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

  // 💡 에러 메시지 표시용 스낵바
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

  // 💡 성공 메시지 표시용 스낵바
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

  // 💡 학번 중복 확인 처리
  Future<void> _checkDuplicateId() async {
    final studentId = _studentIdController.text.trim();
    if (studentId.isEmpty) {
      _showWarningSnackBar('학번을 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isDuplicate = await ref.read(authProvider.notifier).checkDuplicate(studentId);
      setState(() {
        _isIdChecked = true;
        _isIdDuplicate = isDuplicate;
      });
      if (isDuplicate) {
        _showWarningSnackBar('이미 가입된 학번입니다. 본인 계정 연동을 위해 비밀번호 입력이 요구됩니다.');
        setState(() => _requirePassword = true);
      } else {
        _showSuccessSnackBar('사용 가능한 학번입니다! 신규 연동을 진행합니다.');
        setState(() => _requirePassword = false);
      }
    } catch (e) {
      _showErrorSnackBar('중복 확인 중 오류가 발생했습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 💡 회원가입 및 연동 최종 제출 처리
  Future<void> _submit() async {
    final studentId = _studentIdController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (studentId.isEmpty || name.isEmpty) {
      _showWarningSnackBar('학번과 이름을 모두 입력해주세요.');
      return;
    }

    if (!_isIdChecked) {
      _showWarningSnackBar('학번 중복확인을 진행해주세요.');
      return;
    }

    if (_requirePassword && password.isEmpty) {
      _showWarningSnackBar('연동 완료를 위해 기존 계정의 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).socialSignup(
        studentId,
        name,
        widget.socialId,
        widget.provider,
        password: _requirePassword ? password : null,
      );
      if (mounted) {
        _showSuccessSnackBar('성공적으로 계정이 연결되었습니다!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (e.toString().contains('REQUIRE_PASSWORD')) {
        setState(() => _requirePassword = true);
        _showWarningSnackBar('기존 가입 정보가 존재합니다. 비밀번호를 입력해주세요.');
      } else {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg == 'Exception') errorMsg = '소셜 가입 처리 중 오류가 발생했습니다.';
        _showErrorSnackBar(errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerName = widget.provider == 'KAKAO' ? '카카오' : '구글';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('$providerName 계정 연동', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            colors: [Colors.white, theme.colorScheme.primaryContainer.withOpacity(0.3)],
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
                      // 💡 아이콘 영역
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.provider == 'KAKAO' ? Icons.chat_bubble_rounded : Icons.g_mobiledata_rounded,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '추가 정보 입력',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _requirePassword 
                            ? '본인 확인을 위해 기존 계정의 비밀번호를 입력해주세요.' 
                            : 'Y-Sync 서비스 이용을 위해 학번과 이름을 입력해주세요.',
                        style: TextStyle(
                          fontSize: 14, 
                          color: _requirePassword ? Colors.redAccent.shade700 : Colors.grey,
                          fontWeight: _requirePassword ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // 💡 학번 입력 필드 및 중복확인 버튼
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _studentIdController,
                              label: '학번',
                              hint: '학번 입력 (예: 2300000)',
                              icon: Icons.badge_outlined,
                              enabled: !_requirePassword,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                foregroundColor: theme.colorScheme.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: _isLoading || _requirePassword ? null : _checkDuplicateId,
                              child: const Text('중복확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 💡 이름 입력 필드
                      _buildInputField(
                        controller: _nameController,
                        label: '이름',
                        hint: '실명을 입력해주세요',
                        icon: Icons.person_outline,
                        enabled: !_requirePassword,
                      ),
                      
                      // 💡 기존 가입 계정 비밀번호 확인 영역 (연동 요구 시 노출)
                      if (_requirePassword) ...[
                        const SizedBox(height: 20),
                        _buildInputField(
                          controller: _passwordController,
                          label: '기존 비밀번호 입력',
                          hint: '비밀번호를 입력해주세요',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                      ],
                      const SizedBox(height: 36),

                      // 💡 제출 버튼 영역
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('가입 완료 및 로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                        child: const Text('이전 화면으로'),
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

  // 💡 입력 필드 빌더 헬퍼
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
            style: const TextStyle(fontSize: 15),
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
