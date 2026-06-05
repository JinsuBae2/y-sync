import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member.dart';
import 'notice_provider.dart'; // dioProvider가 있는 곳

class AdminMemberState {
  final List<Member> members;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final bool isLoading;
  final String? errorMessage;

  AdminMemberState({
    required this.members,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.isLoading,
    this.errorMessage,
  });

  factory AdminMemberState.initial() {
    return AdminMemberState(
      members: [],
      totalElements: 0,
      totalPages: 0,
      currentPage: 0,
      isLoading: false,
    );
  }

  AdminMemberState copyWith({
    List<Member>? members,
    int? totalElements,
    int? totalPages,
    int? currentPage,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AdminMemberState(
      members: members ?? this.members,
      totalElements: totalElements ?? this.totalElements,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AdminMemberNotifier extends Notifier<AdminMemberState> {
  @override
  AdminMemberState build() {
    return AdminMemberState.initial();
  }

  // 💡 회원 목록 페이징 & 검색 조회
  Future<void> fetchMembers({int page = 0, int size = 15, String? search}) async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/admin/members',
        queryParameters: {
          'page': page,
          'size': size,
          if (search != null && search.trim().isNotEmpty) 'search': search,
        },
      );

      final data = response.data;
      final List<dynamic> content = data['content'] ?? [];
      final list = content.map((json) => Member.fromJson(json)).toList();

      state = AdminMemberState(
        members: list,
        totalElements: data['totalElements'] ?? 0,
        totalPages: data['totalPages'] ?? 0,
        currentPage: data['number'] ?? 0,
        isLoading: false,
      );
    } catch (e) {
      String msg = '회원 목록을 불러오는 중 오류가 발생했습니다.';
      if (e is DioException && e.response?.data is Map && e.response?.data['message'] != null) {
        msg = e.response?.data['message'];
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  // 💡 학생 단건 사전 등록
  Future<void> createMember(String loginId, String name, String role) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/admin/members', data: {
        'loginId': loginId,
        'name': name,
        'role': role,
      });
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException && e.response?.data is Map && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('학생 사전 등록 중 오류가 발생했습니다.');
    }
  }

  // 💡 CSV 일괄 등록
  Future<void> uploadCsv(List<int> bytes, String filename) async {
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });

      await dio.post('/admin/members/csv', data: formData);
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException && e.response?.data is Map && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('CSV 파일 업로드 중 오류가 발생했습니다.');
    }
  }

  // 💡 학생 정보 수정 (이름, 권한)
  Future<void> updateMember(int id, String name, String role) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/admin/members/$id', data: {
        'name': name,
        'role': role,
      });
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException && e.response?.data is Map && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('정보 수정 중 오류가 발생했습니다.');
    }
  }

  // 💡 비밀번호 초기화 및 계정 리셋
  Future<void> resetPassword(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/admin/members/$id/reset-password');
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException && e.response?.data is Map && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('비밀번호 초기화 중 오류가 발생했습니다.');
    }
  }

  // 💡 회원 삭제
  Future<void> deleteMember(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/admin/members/$id');
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException && e.response?.data is Map && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('회원 삭제 중 오류가 발생했습니다.');
    }
  }
}

final adminMemberProvider = NotifierProvider<AdminMemberNotifier, AdminMemberState>(() {
  return AdminMemberNotifier();
});
