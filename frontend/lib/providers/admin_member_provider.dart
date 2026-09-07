import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/member.dart';
import 'notice_provider.dart'; // dioProvider가 있는 곳

class CsvImportError {
  final int row;
  final String loginId;
  final String message;

  const CsvImportError({
    required this.row,
    required this.loginId,
    required this.message,
  });

  factory CsvImportError.fromJson(Map<String, dynamic> json) {
    return CsvImportError(
      row: json['row'] ?? 0,
      loginId: json['loginId'] ?? '',
      message: json['message'] ?? '알 수 없는 오류',
    );
  }
}

class CsvImportResult {
  final int totalCount;
  final int createdCount;
  final int duplicateCount;
  final List<CsvImportError> errors;

  const CsvImportResult({
    required this.totalCount,
    required this.createdCount,
    required this.duplicateCount,
    required this.errors,
  });

  int get errorCount => errors.length;

  factory CsvImportResult.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'] as List<dynamic>? ?? const [];
    return CsvImportResult(
      totalCount: json['totalCount'] ?? 0,
      createdCount: json['createdCount'] ?? 0,
      duplicateCount: json['duplicateCount'] ?? 0,
      errors: rawErrors
          .map((item) => CsvImportError.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

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
  Future<void> fetchMembers({
    int page = 0,
    int size = 15,
    String? search,
  }) async {
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
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        msg = e.response?.data['message'];
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  // 💡 학생 단건 사전 등록
  Future<void> createMember(String loginId, String name, String role) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/admin/members',
        data: {'loginId': loginId, 'name': name, 'role': role},
      );
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('학생 사전 등록 중 오류가 발생했습니다.');
    }
  }

  // 💡 CSV 일괄 등록
  Future<CsvImportResult> uploadCsv(List<int> bytes, String filename) async {
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final response = await dio.post('/admin/members/csv', data: formData);
      final result = CsvImportResult.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await fetchMembers(); // 목록 갱신
      return result;
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('학생 명단 파일 업로드 중 오류가 발생했습니다.');
    }
  }

  // 💡 학생 정보 수정 (이름, 권한)
  Future<void> updateMember(int id, String name, String role) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/admin/members/$id', data: {'name': name, 'role': role});
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('정보 수정 중 오류가 발생했습니다.');
    }
  }

  // 등록된 이메일로 비밀번호 재설정 안내 발송
  Future<void> sendPasswordResetEmail(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/admin/members/$id/password-reset-email');
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('비밀번호 재설정 안내 발송 중 오류가 발생했습니다.');
    }
  }

  // 이메일과 비밀번호를 지우고 재가입 대기 상태로 전환
  Future<void> resetRegistration(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/admin/members/$id/reset-registration');
      await fetchMembers();
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('계정 재등록 초기화 중 오류가 발생했습니다.');
    }
  }

  // 💡 회원 삭제
  Future<void> deleteMember(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/admin/members/$id');
      await fetchMembers(); // 목록 갱신
    } catch (e) {
      if (e is DioException &&
          e.response?.data is Map &&
          e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      throw Exception('회원 삭제 중 오류가 발생했습니다.');
    }
  }
}

final adminMemberProvider =
    NotifierProvider<AdminMemberNotifier, AdminMemberState>(() {
      return AdminMemberNotifier();
    });
