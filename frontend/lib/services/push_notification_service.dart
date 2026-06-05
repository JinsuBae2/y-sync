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
    try {
      // 1. 초기 권한 요청 (Web, iOS, Android 13+)
      // 💡 모바일 사파리 등에서 requestPermission()이 블로킹/예외 발생할 수 있으므로 개별 방어
      try {
        NotificationSettings settings = await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          print('FCM 권한 승인됨');
        } else {
          print('FCM 권한 거부 또는 미지원 (status: ${settings.authorizationStatus}). 알림 기능을 건너뜁니다.');
        }
      } catch (e) {
        // 💡 모바일 사파리(비-PWA) 등에서 권한 요청 자체가 예외를 던질 수 있음 → 로그만 남기고 진행
        print('FCM 권한 요청 실패 (브라우저 미지원 가능): $e');
      }

      // 2. 백그라운드 메시지 수신 등록
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

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
            // 💡 웹 환경에서는 브라우저 시스템 네이티브 알림을 통해 알림이 자동으로 노출되며,
            // 클릭 시의 웹 딥링크 처리 또한 서비스 워커에서 동작하므로
            // 포그라운드 인앱 알림 배너를 중복 노출하지 않습니다.
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
      try {
        RemoteMessage? initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          Future.delayed(const Duration(seconds: 1), () {
            _handleRemoteMessageClick(initialMessage);
          });
        }
      } catch (e) {
        print('FCM 초기 메시지 조회 실패: $e');
      }

      // 7. 앱이 백그라운드에 있다가 배너를 눌러 가져와진 경우
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageClick);

      // 💡 [웹앱 환경 개선] 브라우저 및 하이브리드 환경의 제약으로 인해 FCM 토픽 구독 방식은 사용하지 않습니다.
      // 💡 공지사항 알림은 백엔드에서 활성 유저 기기 토큰 목록을 조회하여 멀티캐스트(Multicast) 방식으로 발송합니다.
      /*
      if (!kIsWeb) {
        try {
          await _fcm.subscribeToTopic('all');
        } catch (e) {
          print('FCM 토픽 구독 실패: $e');
        }
      }
      */
    } catch (e) {
      // 💡 최상위 방어: 어떤 예외가 발생해도 앱 자체는 절대 멈추지 않습니다.
      print('PushNotificationService 초기화 중 예외 발생 (앱 실행에 영향 없음): $e');
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
      
      // 💡 targetType 및 targetId 외에 type 및 postId가 페이로드에 있는 경우를 대비한 Fallback 파싱
      final targetType = data['targetType'] ?? data['type'];
      final targetId = data['targetId'] ?? data['postId'];
      
      print('FCM Routing -> Type: $targetType, ID: $targetId');
      
      if (targetType != null && targetId != null && navigatorKey.currentState != null) {
         // 💡 화면 텔레포트 (원하는 상세 화면으로 라우팅 처리)
         navigatorKey.currentState!.push(
           MaterialPageRoute(
             builder: (context) => DeepLinkLoadingScreen(
               targetType: targetType.toString(),
               targetId: targetId.toString(),
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
