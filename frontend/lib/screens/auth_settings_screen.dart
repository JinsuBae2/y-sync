import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../theme/app_design_tokens.dart';

class AuthSettingsScreen extends ConsumerStatefulWidget {
  const AuthSettingsScreen({super.key});

  @override
  ConsumerState<AuthSettingsScreen> createState() => _AuthSettingsScreenState();
}

class _AuthSettingsScreenState extends ConsumerState<AuthSettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  bool _isLoading = true;
  bool _useBiometric = false;
  bool _usePin = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final values = await Future.wait([
        _storage.read(key: 'use_biometric'),
        _storage.read(key: 'user_pin'),
      ]);
      if (!mounted) return;
      setState(() {
        _useBiometric = values[0] == 'true';
        _usePin = values[1] != null;
      });
    } catch (_) {
      if (mounted) _showSnackBar('보안 설정을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _isLoading = true);
    try {
      if (value) {
        final supported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        if (!supported || !canCheck) {
          _showSnackBar('이 기기에서 생체 인식을 사용할 수 없습니다.');
          return;
        }
        final authenticated = await _localAuth.authenticate(
          localizedReason: '생체 인식 로그인을 활성화합니다.',
        );
        if (!authenticated) return;
        await _storage.write(key: 'use_biometric', value: 'true');
        if (!mounted) return;
        setState(() => _useBiometric = true);
        _showSnackBar('생체 인식 로그인을 켰습니다.');
      } else {
        await _storage.delete(key: 'use_biometric');
        if (!mounted) return;
        setState(() => _useBiometric = false);
        _showSnackBar('생체 인식 로그인을 껐습니다.');
      }
    } on PlatformException {
      _showSnackBar('생체 인식을 완료하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setupPin() async {
    if (_usePin) {
      await _storage.delete(key: 'user_pin');
      if (!mounted) return;
      setState(() => _usePin = false);
      _showSnackBar('PIN 로그인을 해제했습니다.');
      return;
    }

    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'PIN 설정',
          style: TextStyle(
            color: AppDesignTokens.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'PIN',
            hintText: '4~6자리 숫자',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppDesignTokens.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppDesignTokens.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length >= 4) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (pin == null || pin.isEmpty) return;
    await _storage.write(key: 'user_pin', value: pin);
    if (!mounted) return;
    setState(() => _usePin = true);
    _showSnackBar('PIN 로그인을 설정했습니다.');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '보안 및 간편 로그인',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppDesignTokens.blue,
                  backgroundColor: AppDesignTokens.paleBlue,
                ),
              )
            : null,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Text(
                '간편 인증',
                style: TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '로그인 정보를 기기에 안전하게 저장해 빠르게 인증합니다.',
                style: TextStyle(color: AppDesignTokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: AppDesignTokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDesignTokens.divider),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _useBiometric,
                      onChanged: _isLoading ? null : _toggleBiometric,
                      activeTrackColor: AppDesignTokens.blue,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      secondary: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppDesignTokens.navy,
                      ),
                      title: const Text(
                        '생체 인식',
                        style: TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        '지문 또는 Face ID로 로그인합니다.',
                        style: TextStyle(
                          color: AppDesignTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 62,
                      color: AppDesignTokens.divider,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      leading: const Icon(
                        Icons.pin_outlined,
                        color: AppDesignTokens.navy,
                      ),
                      title: const Text(
                        'PIN 로그인',
                        style: TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _usePin ? '사용 중' : '사용 안 함',
                        style: const TextStyle(
                          color: AppDesignTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: _isLoading ? null : _setupPin,
                        child: Text(_usePin ? '해제' : '설정'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: AppDesignTokens.subtle,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '생체 정보와 PIN은 서버로 전송되지 않고 이 기기의 보안 저장소에서만 사용됩니다.',
                      style: TextStyle(
                        color: AppDesignTokens.muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
