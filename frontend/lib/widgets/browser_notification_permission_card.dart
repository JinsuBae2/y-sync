import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_design_tokens.dart';
import '../utils/browser_notification_permission_stub.dart'
    if (dart.library.js_interop) '../utils/browser_notification_permission_web.dart'
    as platform;

final browserNotificationPermissionProvider = Provider<String>(
  (ref) => platform.readNotificationPermission(),
);

class BrowserNotificationPermissionCard extends ConsumerStatefulWidget {
  const BrowserNotificationPermissionCard({super.key});

  @override
  ConsumerState<BrowserNotificationPermissionCard> createState() =>
      _BrowserNotificationPermissionCardState();
}

class _BrowserNotificationPermissionCardState
    extends ConsumerState<BrowserNotificationPermissionCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.invalidate(browserNotificationPermissionProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(browserNotificationPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(browserNotificationPermissionProvider);
    final (title, description, icon) = switch (permission) {
      'granted' => (
        '브라우저 알림 허용됨',
        '이 브라우저의 알림 권한이 허용되어 있습니다. 위 수신 설정과 기기의 알림·집중 모드 설정에 따라 알림이 표시됩니다.',
        Icons.notifications_active_outlined,
      ),
      'denied' => (
        '브라우저 알림 차단됨',
        '위 수신 설정을 켜도 푸시 알림이 표시되지 않습니다. 브라우저의 이 사이트 설정에서 알림을 허용한 뒤 다시 확인해주세요.',
        Icons.notifications_off_outlined,
      ),
      'default' => (
        '브라우저 알림 허용 필요',
        '아직 알림 권한이 결정되지 않았습니다. 브라우저의 이 사이트 설정에서 알림을 허용해주세요. 권한을 변경한 뒤 페이지를 새로고침하면 푸시 등록을 다시 시도합니다.',
        Icons.notification_add_outlined,
      ),
      'unsupported' => (
        '이 환경에서는 알림을 지원하지 않습니다',
        '알림을 지원하는 브라우저에서 HTTPS로 접속해주세요. iPhone·iPad에서는 홈 화면에 추가한 웹 앱으로 실행해야 할 수 있습니다.',
        Icons.info_outline_rounded,
      ),
      _ => (
        '브라우저 알림 상태를 확인하지 못했습니다',
        '브라우저의 이 사이트 알림 설정을 확인한 뒤 다시 시도해주세요.',
        Icons.info_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignTokens.paleBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: AppDesignTokens.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppDesignTokens.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AppDesignTokens.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (permission == 'denied') ...[
            const SizedBox(height: 6),
            const Text(
              '허용 후 페이지를 새로고침하면 푸시 등록을 다시 시도합니다.',
              style: TextStyle(color: AppDesignTokens.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              ref.invalidate(browserNotificationPermissionProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('브라우저 알림 권한 상태를 다시 확인했습니다.')),
              );
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('권한 상태 다시 확인'),
            style: TextButton.styleFrom(foregroundColor: AppDesignTokens.blue),
          ),
        ],
      ),
    );
  }
}
