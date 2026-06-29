import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../screens/notification_center_screen.dart';

class NotificationActionButton extends ConsumerWidget {
  const NotificationActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Semantics(
      label: '알림 센터',
      hint: '수신한 알림 내역을 조회합니다.',
      button: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded, 
              size: 26, 
              color: Colors.black87,
            ),
            tooltip: '알림',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationCenterScreen(),
                ),
              );
            },
          ),
          if (unreadCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30), // 세련된 iOS 스타일 Red
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
