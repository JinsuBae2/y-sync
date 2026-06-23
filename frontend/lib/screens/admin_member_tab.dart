import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/admin_member_provider.dart';
import '../models/member.dart';
import '../utils/csv_picker.dart';

class AdminMemberTab extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminMemberTab({super.key, this.isDesktop = false});

  @override
  ConsumerState<AdminMemberTab> createState() => _AdminMemberTabState();
}

class _AdminMemberTabState extends ConsumerState<AdminMemberTab> {
  final _searchController = TextEditingController();
  int _currentPage = 0;
  final int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminMemberProvider.notifier).fetchMembers(page: 0, size: _pageSize);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _currentPage = 0;
    });
    ref.read(adminMemberProvider.notifier).fetchMembers(
          page: 0,
          size: _pageSize,
          search: _searchController.text.trim(),
        );
  }

  void _loadPage(int page) {
    setState(() {
      _currentPage = page;
    });
    ref.read(adminMemberProvider.notifier).fetchMembers(
          page: page,
          size: _pageSize,
          search: _searchController.text.trim(),
        );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 💡 단건 학생 사전등록 다이얼로그
  void _showCreateDialog() {
    final studentIdController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'USER';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('학생 단건 등록', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: studentIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '학번',
                      hintText: '숫자만 입력 (예: 2305009)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '실명 입력',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: '권한',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USER', child: Text('학생 (USER)')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('조교/관리자 (ADMIN)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedRole = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final studentId = studentIdController.text.trim();
                    final name = nameController.text.trim();
                    if (studentId.isEmpty || name.isEmpty) return;

                    try {
                      await ref.read(adminMemberProvider.notifier).createMember(studentId, name, selectedRole);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showSuccessSnackBar('학생 사전 등록이 완료되었습니다.');
                      }
                    } catch (e) {
                      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF164687),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💡 CSV 일괄 등록 다이얼로그 (파일 업로드 & 붙여넣기 투트랙 지원)
  void _showCsvUploadDialog() {
    final textController = TextEditingController();
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('대량 학생 일괄 등록', style: TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: 450,
                  height: 350,
                  child: Column(
                    children: [
                      const TabBar(
                        indicatorColor: Color(0xFF164687),
                        labelColor: Color(0xFF164687),
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(text: 'CSV 파일 업로드'),
                          Tab(text: '직접 붙여넣기'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 탭 1: 파일 업로드
                            Center(
                              child: isUploading
                                  ? const CircularProgressIndicator(color: Color(0xFF164687))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.cloud_upload_outlined, size: 64, color: Color(0xFF164687)),
                                        const SizedBox(height: 16),
                                        const Text(
                                          '엑셀에서 CSV 형식으로 저장한\n파일을 선택해주세요.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '형식: 학번,이름,역할(선택)',
                                          style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.search_rounded, size: 18),
                                          label: const Text('CSV 파일 선택'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF164687),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          ),
                                          onPressed: () async {
                                            try {
                                              final result = await CsvPicker.pickCsv();
                                              if (result != null) {
                                                setDialogState(() => isUploading = true);
                                                await ref.read(adminMemberProvider.notifier).uploadCsv(result.bytes, result.name);
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                  _showSuccessSnackBar('CSV 파일 내 학생들이 성공적으로 등록되었습니다.');
                                                }
                                              }
                                            } catch (e) {
                                              _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
                                            } finally {
                                              setDialogState(() => isUploading = false);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                            ),
                            // 탭 2: 직접 붙여넣기
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  '줄바꿈으로 구분하고 쉼표(,)로 학번과 이름을 나누어 입력해주세요.',
                                  style: TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: TextField(
                                    controller: textController,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: '예시:\n2305001,홍길동,USER\n2305002,김철수,ADMIN',
                                      hintStyle: TextStyle(color: Colors.grey.shade400),
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;
                            
                            setDialogState(() => isUploading = true);
                            try {
                              final bytes = utf8.encode(text);
                              await ref.read(adminMemberProvider.notifier).uploadCsv(bytes, 'import.csv');
                              if (context.mounted) {
                                Navigator.pop(context);
                                _showSuccessSnackBar('입력하신 학생들이 성공적으로 등록되었습니다.');
                              }
                            } catch (e) {
                              _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
                            } finally {
                              setDialogState(() => isUploading = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF164687),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('일괄 등록'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 💡 정보 수정 다이얼로그
  void _showEditDialog(Member member) {
    final nameController = TextEditingController(text: member.name);
    String selectedRole = member.role;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('${member.loginId} 정보 수정', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: '권한',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USER', child: Text('학생 (USER)')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('조교/관리자 (ADMIN)')),
                      DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('슈퍼 관리자 (SUPER_ADMIN)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedRole = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    try {
                      await ref.read(adminMemberProvider.notifier).updateMember(member.id, name, selectedRole);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showSuccessSnackBar('정보가 정상적으로 수정되었습니다.');
                      }
                    } catch (e) {
                      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF164687),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💡 계정 리셋(비밀번호 초기화 및 비활성화) 확인 다이얼로그
  void _showResetConfirm(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 초기화 및 리셋'),
        content: Text(
          '정말 ${member.name} (${member.loginId}) 학생의 비밀번호를 지우고 가입 대기 상태로 리셋하시겠습니까?\n\n'
          '이 작업을 완료하면 기존 패스워드는 유실되며, 학생은 이메일 인증 가입 절차를 다시 밟아야 로그인이 가능해집니다.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(adminMemberProvider.notifier).resetPassword(member.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('계정이 가입 대기 상태로 초기화되었습니다.');
                }
              } catch (e) {
                _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            child: const Text('계정 리셋'),
          ),
        ],
      ),
    );
  }

  // 💡 삭제 확인 다이얼로그
  void _showDeleteConfirm(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 정보 삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('정말 ${member.name} (${member.loginId}) 학생을 목록에서 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(adminMemberProvider.notifier).deleteMember(member.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('학생이 성공적으로 삭제되었습니다.');
                }
              } catch (e) {
                _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminMemberProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // 투명으로 처리해 부모 카드의 회색 배경에 융합되게 유도
      body: Column(
        children: [
          // 검색창 영역
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '학번 또는 이름으로 검색',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF164687),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _search,
                    child: const Text('검색'),
                  ),
                ),
              ],
            ),
          ),

          // 학생 추가 제어 패널
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('대량 일괄 등록 (CSV)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF164687),
                    side: const BorderSide(color: Color(0xFF164687)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _showCsvUploadDialog,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('학생 등록'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF164687),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _showCreateDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 결과 목록 리스트 또는 데이터 테이블
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF164687)))
                : state.members.isEmpty
                    ? const Center(child: Text('등록된 학생이 없습니다.'))
                    : widget.isDesktop
                        ? _buildDesktopTable(state)
                        : _buildMobileList(state),
          ),

          // 하단 페이징 네비게이션 컨트롤러
          if (state.totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    onPressed: _currentPage > 0 ? () => _loadPage(_currentPage - 1) : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentPage + 1} / ${state.totalPages}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onPressed: _currentPage < state.totalPages - 1 ? () => _loadPage(_currentPage + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 📱 모바일용 리스트 뷰
  Widget _buildMobileList(AdminMemberState state) {
    return ListView.builder(
      itemCount: state.members.length,
      itemBuilder: (context, index) {
        final member = state.members[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: member.role == 'USER'
                      ? Colors.grey.shade100
                      : const Color(0xFF164687).withOpacity(0.1),
                  child: Icon(
                    member.role == 'USER' ? Icons.person : Icons.admin_panel_settings,
                    color: member.role == 'USER' ? Colors.grey : const Color(0xFF164687),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          _buildActivatedBadge(member.isActivated),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '학번: ${member.loginId}   |   권한: ${member.role}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditDialog(member);
                    } else if (action == 'reset') {
                      _showResetConfirm(member);
                    } else if (action == 'delete') {
                      _showDeleteConfirm(member);
                    }
                  },
                  itemBuilder: (context) => _buildPopupMenuItems(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 💻 데스크톱용 표(Table) 뷰
  Widget _buildDesktopTable(AdminMemberState state) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              dataRowMaxHeight: 65,
              columns: const [
                DataColumn(label: Text('학번', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('이름', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('권한 역할', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('가입 상태', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('관리 기능', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
              rows: state.members.map((member) {
                return DataRow(
                  cells: [
                    DataCell(Text(member.loginId, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(member.role, style: TextStyle(color: member.role == 'USER' ? Colors.black87 : const Color(0xFF164687), fontWeight: member.role == 'USER' ? FontWeight.normal : FontWeight.bold))),
                    DataCell(_buildActivatedBadge(member.isActivated)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                            tooltip: '정보 수정',
                            onPressed: () => _showEditDialog(member),
                          ),
                          IconButton(
                            icon: const Icon(Icons.lock_reset_rounded, color: Colors.orange, size: 18),
                            tooltip: '계정 초기화/리셋',
                            onPressed: () => _showResetConfirm(member),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                            tooltip: '학생 삭제',
                            onPressed: () => _showDeleteConfirm(member),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivatedBadge(bool isActivated) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActivated ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActivated ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Text(
        isActivated ? '가입완료' : '가입대기',
        style: TextStyle(
          fontSize: 10,
          color: isActivated ? Colors.green.shade800 : Colors.grey.shade600,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems() {
    return [
      const PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 20),
            SizedBox(width: 8),
            Text('정보 수정'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'reset',
        child: Row(
          children: [
            Icon(Icons.lock_reset_rounded, size: 20, color: Colors.orange),
            SizedBox(width: 8),
            Text('계정 초기화/리셋', style: TextStyle(color: Colors.orange)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('학생 삭제', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }
}
