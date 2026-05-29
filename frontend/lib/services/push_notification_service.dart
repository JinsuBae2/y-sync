import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import '../screens/deep_link_loading_screen.dart'; // 💡 딥링크 라우팅용

// 💡 백그라운드에서 메시지를 수신했을 때 호출되는 전역 콜백 (반드시 최상단 포지션으로!)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 💡 앱 내 어디서든 라우팅을 제어할 수 있도록 전역 Nav Key 사용
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    // 1. 초기 권한 요청 (Web, iOS, Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('FCM 권한 승인됨');
    }

    // 2. 백그라운드 메시지 수신 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. 로컬 알림 초기화 설정 (Web이 아닐 때만)
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );
      
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            _handleNotificationClick(response.payload!);
          }
        },
      );

      // 4. 안드로이드 Foreground 알림 채널 세팅 (Y-Sync 브랜드 #164687 테마 채택)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'ysync_high_importance_channel', 
        'Y-Sync 알림', 
        description: 'Y-Sync 앱 공지사항 및 커뮤니티 알림 채널입니다.',
        importance: Importance.max,
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 5. 앱이 켜져 있을 때(Foreground) FCM을 받는 경우 처리기
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      
      if (notification != null) {
        if (kIsWeb) {
          // 💡 웹 환경에서는 브라우저의 ScaffoldMessenger SnackBar를 활용해 인앱 알림을 노출합니다.
          _showWebForegroundNotification(notification.title ?? '', notification.body ?? '', message.data);
        } else {
          AndroidNotification? android = message.notification?.android;
          if (android != null) {
            _localNotificationsPlugin.show(
              id: notification.hashCode,
              title: notification.title,
              body: notification.body,
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'ysync_high_importance_channel',
                  'Y-Sync 알림',
                  channelDescription: 'Y-Sync 앱 공지사항 및 커뮤니티 알림 채널입니다.',
                  color: Color(0xFF164687), // Y-Sync 블루 테마 적용
                  importance: Importance.max,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                ),
              ),
              payload: jsonEncode(message.data),
            );
          }
        }
      }
    });

    // 6. 앱이 완전히 종료된 상태에서 푸시 배너를 눌러 앱을 켰을 때
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        _handleRemoteMessageClick(initialMessage);
      });
    }

    // 7. 앱이 백그라운드에 있다가 배너를 눌러 가져와진 경우
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageClick);

    // 8. 공지사항 일괄 수신 처리를 위해 'all' 토픽 구독 (모바일 전용)
    if (!kIsWeb) {
      try {
        await _fcm.subscribeToTopic('all');
      } catch (e) {
        print('FCM 토픽 구독 실패: $e');
      }
    }
  }

  void _showWebForegroundNotification(String title, String body, Map<String, dynamic> data) {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(body),
            ],
          ),
          action: SnackBarAction(
            label: '보기',
            onPressed: () {
              _handleNotificationClick(jsonEncode(data));
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _handleRemoteMessageClick(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      _handleNotificationClick(jsonEncode(message.data));
    }
  }

  void _handleNotificationClick(String payload) {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final targetType = data['targetType'];
      final targetId = data['targetId'];
      
      print('FCM Routing -> Type: $targetType, ID: $targetId');
      
      if (targetType != null && targetId != null && navigatorKey.currentState != null) {
         // 💡 화면 텔레포트
         navigatorKey.currentState!.push(
           MaterialPageRoute(
             builder: (context) => DeepLinkLoadingScreen(
               targetType: targetType,
               targetId: targetId,
             ),
           ),
         );
      }
    } catch (e) {
      print('FCM Payload Parse Error: $e');
    }
  }

  // 백엔드로 전달하기 위한 토큰 발급
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        // 💡 웹 푸시(Web Push) 발급 시 VAPID 키 필요
        // 아래 키 값은 파이어베이스 콘솔의 '웹 푸시 인증서(Web Push certificates)' 키 쌍 값입니다.
        const String vapidKey = String.fromEnvironment(
          'FCM_VAPID_KEY',
          defaultValue: 'BCLfIOmGAfT_qvHfk5hNp7PvFcucikSfAbiqg2qlPkJqizxTy0oZ7AJ1ZIpQuKD6vSuDaOiJUPHuNJBauhL2VCk', // 사용자 파이어베이스 VAPID Key 반영
        );
        
        // VAPID 키가 비어있는 경우
        if (vapidKey.isEmpty) {
          print('FCM 웹 VAPID Key가 비어있어, 웹 브라우저 토큰 요청을 건너뜁니다.');
          return null;
        }
        
        return await _fcm.getToken(vapidKey: vapidKey);
      }
      return await _fcm.getToken();
    } catch (e) {
      print('FCM 토큰 발급 실패: $e');
      return null;
    }
  }
}
