import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/server_availability_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/brand_logo.dart';

class ServerMaintenanceScreen extends ConsumerStatefulWidget {
  const ServerMaintenanceScreen({super.key});

  @override
  ConsumerState<ServerMaintenanceScreen> createState() =>
      _ServerMaintenanceScreenState();
}

class _ServerMaintenanceScreenState
    extends ConsumerState<ServerMaintenanceScreen> {
  Timer? _retryTimer;
  bool _isChecking = false;
  DateTime? _lastCheckedAt;

  @override
  void initState() {
    super.initState();
    _retryTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_checkServer()),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkServer() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);
    await ref.read(serverHealthCheckProvider)();

    if (mounted) {
      setState(() {
        _isChecking = false;
        _lastCheckedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastCheckedText = _lastCheckedAt == null
        ? '서버 응답을 기다리고 있어요'
        : '마지막 확인: ${_formatKoreanTime(_lastCheckedAt!)}';

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
          const CustomPaint(painter: _MaintenanceBackgroundPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignTokens.blue.withValues(
                                alpha: 0.22,
                              ),
                              blurRadius: 52,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandLogo(
                              size: 76,
                              padding: 6,
                              borderRadius: 22,
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
                            const SizedBox(height: 30),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppDesignTokens.blue.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.build_circle_outlined,
                                size: 43,
                                color: Color(0xFF71A1FF),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              '잠시 점검 중이에요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '더 안정적인 서비스를 위해 서버를 점검하고 있습니다.\n'
                              '잠시 후 자동으로 다시 연결할게요.\n'
                              '인터넷 연결도 함께 확인해 주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.65,
                                color: Color(0xFFB8C3D4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _isChecking
                                          ? const Color(0xFF71A1FF)
                                          : const Color(0xFFB8C3D4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Flexible(
                                    child: Text(
                                      '서버 연결 확인 중…',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFFD5DEEC),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                key: const Key('maintenanceRetryButton'),
                                onPressed: _isChecking ? null : _checkServer,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppDesignTokens.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _isChecking ? '확인 중…' : '지금 다시 확인',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              lastCheckedText,
                              key: const Key('maintenanceLastChecked'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8492A6),
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
          ),
        ],
      ),
    );
  }

  String _formatKoreanTime(DateTime dateTime) {
    final period = dateTime.hour < 12 ? '오전' : '오후';
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }
}

class _MaintenanceBackgroundPainter extends CustomPainter {
  const _MaintenanceBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppDesignTokens.blue.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final points = <Offset>[
      Offset(size.width * 0.04, size.height * 0.12),
      Offset(size.width * 0.23, size.height * 0.07),
      Offset(size.width * 0.34, size.height * 0.18),
      Offset(size.width * 0.72, size.height * 0.83),
      Offset(size.width * 0.91, size.height * 0.77),
      Offset(size.width * 0.96, size.height * 0.92),
    ];
    canvas.drawLine(points[0], points[1], paint);
    canvas.drawLine(points[1], points[2], paint);
    canvas.drawLine(points[3], points[4], paint);
    canvas.drawLine(points[4], points[5], paint);

    paint.color = const Color(0xFF71A1FF).withValues(alpha: 0.45);
    for (final point in points) {
      canvas.drawCircle(point, 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
