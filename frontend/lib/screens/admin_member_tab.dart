import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_member_provider.dart';
import '../models/member.dart';
import '../theme/app_design_tokens.dart';
import '../utils/csv_picker.dart';

class AdminMemberTab extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminMemberTab({super.key, this.isDesktop = false});

  @override
  ConsumerState<AdminMemberTab> createState() => _AdminMemberTabState();
}

class _RegistrationDialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RegistrationDialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppDesignTokens.blue, Color(0xFF164687)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppDesignTokens.blue.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppDesignTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImportResultCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ImportResultCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppDesignTokens.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvUploadingIndicator extends StatelessWidget {
  const _CsvUploadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppDesignTokens.blue,
            ),
          ),
          SizedBox(height: 18),
          Text(
            '학생 정보를 등록하고 있어요',
            style: TextStyle(
              color: AppDesignTokens.navy,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '파일 크기에 따라 잠시 시간이 걸릴 수 있습니다.',
            style: TextStyle(color: AppDesignTokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AdminMemberTabState extends ConsumerState<AdminMemberTab> {
  final _searchController = TextEditingController();
  int _currentPage = 0;
  final int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(adminMemberProvider.notifier)
          .fetchMembers(page: 0, size: _pageSize);
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
    ref
        .read(adminMemberProvider.notifier)
        .fetchMembers(
          page: 0,
          size: _pageSize,
          search: _searchController.text.trim(),
        );
  }

  void _loadPage(int page) {
    setState(() {
      _currentPage = page;
    });
    ref
        .read(adminMemberProvider.notifier)
        .fetchMembers(
          page: page,
          size: _pageSize,
          search: _searchController.text.trim(),
        );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppDesignTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: const _RegistrationDialogHeader(
                icon: Icons.person_add_alt_1_rounded,
                title: '학생 등록',
                subtitle: '가입 전에 사용할 학번과 이름을 등록해 주세요.',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: studentIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '학번',
                      hintText: '예: 2305009',
                      prefixIcon: Icon(Icons.badge_outlined),
                      filled: true,
                      fillColor: AppDesignTokens.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '실명 입력',
                      prefixIcon: Icon(Icons.person_outline),
                      filled: true,
                      fillColor: AppDesignTokens.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: '권한',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      filled: true,
                      fillColor: AppDesignTokens.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USER', child: Text('학생 (USER)')),
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('조교/관리자 (ADMIN)'),
                      ),
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
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final studentId = studentIdController.text.trim();
                          final name = nameController.text.trim();
                          if (studentId.isEmpty || name.isEmpty) {
                            _showErrorSnackBar('학번과 이름을 모두 입력해 주세요.');
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await ref
                                .read(adminMemberProvider.notifier)
                                .createMember(studentId, name, selectedRole);
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showSuccessSnackBar('학생 사전 등록이 완료되었습니다.');
                            }
                          } catch (e) {
                            _showErrorSnackBar(
                              e.toString().replaceAll('Exception: ', ''),
                            );
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF164687),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('학생 등록'),
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
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: AppDesignTokens.surface,
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                title: const _RegistrationDialogHeader(
                  icon: Icons.group_add_rounded,
                  title: '학생 일괄 등록',
                  subtitle: 'CSV 파일을 선택하거나 명단을 직접 붙여넣으세요.',
                ),
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
                          Tab(text: '명단 파일 업로드'),
                          Tab(text: '직접 붙여넣기'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: isUploading
                            ? const _CsvUploadingIndicator()
                            : TabBarView(
                                children: [
                                  // 탭 1: 파일 업로드
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 64,
                                          color: Color(0xFF164687),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          '학교에서 받은 Excel 또는 CSV\n명단 파일을 선택해 주세요.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '지원 형식: XLSX, XLS, CSV',
                                          style: TextStyle(
                                            color: Colors.blueGrey,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          icon: const Icon(
                                            Icons.search_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('명단 파일 선택'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF164687,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                          ),
                                          onPressed: () async {
                                            try {
                                              final result =
                                                  await CsvPicker.pickCsv();
                                              if (result != null) {
                                                setDialogState(
                                                  () => isUploading = true,
                                                );
                                                final importResult = await ref
                                                    .read(
                                                      adminMemberProvider
                                                          .notifier,
                                                    )
                                                    .uploadCsv(
                                                      result.bytes,
                                                      result.name,
                                                    );
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                  _showCsvImportResult(
                                                    importResult,
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              _showErrorSnackBar(
                                                e.toString().replaceAll(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              );
                                            } finally {
                                              setDialogState(
                                                () => isUploading = false,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 탭 2: 직접 붙여넣기
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        '첫 줄에 학번과 이름 헤더를 포함해 주세요. 다른 열은 자동으로 제외됩니다.',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: textController,
                                          maxLines: null,
                                          keyboardType: TextInputType.multiline,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                '예시:\n2305001,홍길동,USER\n2305002,김철수,ADMIN',
                                            hintStyle: TextStyle(
                                              color: Colors.grey.shade400,
                                            ),
                                            border: const OutlineInputBorder(),
                                            contentPadding:
                                                const EdgeInsets.all(12),
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
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                              final importResult = await ref
                                  .read(adminMemberProvider.notifier)
                                  .uploadCsv(bytes, 'import.csv');
                              if (context.mounted) {
                                Navigator.pop(context);
                                _showCsvImportResult(importResult);
                              }
                            } catch (e) {
                              _showErrorSnackBar(
                                e.toString().replaceAll('Exception: ', ''),
                              );
                            } finally {
                              setDialogState(() => isUploading = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF164687),
                      foregroundColor: Colors.white,
                    ),
                    child: isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('일괄 등록'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCsvImportResult(CsvImportResult result) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppDesignTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: _RegistrationDialogHeader(
          icon: result.errorCount == 0
              ? Icons.check_circle_rounded
              : Icons.fact_check_rounded,
          title: '등록 결과',
          subtitle: '총 ${result.totalCount}개 행의 처리가 완료되었습니다.',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ImportResultCard(
                      label: '신규 등록',
                      count: result.createdCount,
                      color: const Color(0xFF1F9D68),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ImportResultCard(
                      label: '중복 제외',
                      count: result.duplicateCount,
                      color: AppDesignTokens.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ImportResultCard(
                      label: '오류',
                      count: result.errorCount,
                      color: AppDesignTokens.coral,
                    ),
                  ),
                ],
              ),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  '확인이 필요한 행',
                  style: TextStyle(
                    color: AppDesignTokens.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppDesignTokens.coral.withValues(alpha: 0.22),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: result.errors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final error = result.errors[index];
                        final id = error.loginId.isEmpty
                            ? ''
                            : ' · ${error.loginId}';
                        return Text(
                          '${error.row}행$id  ${error.message}',
                          style: const TextStyle(
                            color: Color(0xFF8B2D28),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                '${member.loginId} 정보 수정',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: '권한',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USER', child: Text('학생 (USER)')),
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('조교/관리자 (ADMIN)'),
                      ),
                      DropdownMenuItem(
                        value: 'SUPER_ADMIN',
                        child: Text('슈퍼 관리자 (SUPER_ADMIN)'),
                      ),
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
                      await ref
                          .read(adminMemberProvider.notifier)
                          .updateMember(member.id, name, selectedRole);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showSuccessSnackBar('정보가 정상적으로 수정되었습니다.');
                      }
                    } catch (e) {
                      _showErrorSnackBar(
                        e.toString().replaceAll('Exception: ', ''),
                      );
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

  void _showPasswordResetEmailConfirm(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 재설정 안내'),
        content: Text(
          '${member.name} (${member.loginId}) 학생의 등록된 학교 이메일로 '
          '비밀번호 재설정 인증번호를 보낼까요?\n\n'
          '계정, 권한, 게시글과 댓글은 변경되지 않습니다.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(adminMemberProvider.notifier)
                    .sendPasswordResetEmail(member.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('등록된 이메일로 인증번호를 발송했습니다.');
                }
              } catch (e) {
                _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('인증번호 발송'),
          ),
        ],
      ),
    );
  }

  void _showRegistrationResetConfirm(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 재등록 초기화'),
        content: Text(
          '정말 ${member.name} (${member.loginId}) 학생의 비밀번호를 지우고 가입 대기 상태로 리셋하시겠습니까?\n\n'
          '이 작업을 완료하면 등록 이메일과 비밀번호가 삭제되고, '
          '학생은 이메일 인증 가입 절차를 다시 진행해야 합니다.\n\n'
          '게시글, 댓글, 권한과 정지 상태는 유지됩니다.',
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
                await ref
                    .read(adminMemberProvider.notifier)
                    .resetRegistration(member.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('계정이 가입 대기 상태로 초기화되었습니다.');
                }
              } catch (e) {
                _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('재등록 초기화'),
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
        title: const Text(
          '학생 정보 삭제',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '정말 ${member.name} (${member.loginId}) 학생을 목록에서 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(adminMemberProvider.notifier)
                    .deleteMember(member.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('학생이 성공적으로 삭제되었습니다.');
                }
              } catch (e) {
                _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 검색창 영역
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isDesktop ? 24 : 16,
              16,
              widget.isDesktop ? 24 : 16,
              12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDesignTokens.divider),
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
                      backgroundColor: AppDesignTokens.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
            padding: EdgeInsets.symmetric(
              horizontal: widget.isDesktop ? 24 : 16,
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('CSV 등록'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppDesignTokens.blue,
                    side: const BorderSide(color: AppDesignTokens.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _showCsvUploadDialog,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('학생 등록'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignTokens.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppDesignTokens.blue,
                    ),
                  )
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
                color: AppDesignTokens.surface,
                border: const Border(
                  top: BorderSide(color: AppDesignTokens.divider),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    onPressed: _currentPage > 0
                        ? () => _loadPage(_currentPage - 1)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentPage + 1} / ${state.totalPages}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onPressed: _currentPage < state.totalPages - 1
                        ? () => _loadPage(_currentPage + 1)
                        : null,
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
          color: AppDesignTokens.surface,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppDesignTokens.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: member.role == 'USER'
                      ? AppDesignTokens.background
                      : AppDesignTokens.paleBlue,
                  child: Icon(
                    member.role == 'USER'
                        ? Icons.person
                        : Icons.admin_panel_settings,
                    color: member.role == 'USER'
                        ? AppDesignTokens.muted
                        : AppDesignTokens.blue,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildActivatedBadge(member.isActivated),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '학번: ${member.loginId}   |   권한: ${member.role}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditDialog(member);
                    } else if (action == 'passwordReset') {
                      _showPasswordResetEmailConfirm(member);
                    } else if (action == 'registrationReset') {
                      _showRegistrationResetConfirm(member);
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
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(
                AppDesignTokens.background,
              ),
              dataRowMaxHeight: 65,
              columns: const [
                DataColumn(
                  label: Text(
                    '학번',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '이름',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '권한 역할',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '가입 상태',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '관리 기능',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
              rows: state.members.map((member) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        member.loginId,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        member.role,
                        style: TextStyle(
                          color: member.role == 'USER'
                              ? Colors.black87
                              : const Color(0xFF164687),
                          fontWeight: member.role == 'USER'
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(_buildActivatedBadge(member.isActivated)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.mark_email_read_outlined,
                              color: Colors.blue,
                              size: 18,
                            ),
                            tooltip: '비밀번호 재설정 안내',
                            onPressed: () =>
                                _showPasswordResetEmailConfirm(member),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.blue,
                              size: 18,
                            ),
                            tooltip: '정보 수정',
                            onPressed: () => _showEditDialog(member),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.lock_reset_rounded,
                              color: Colors.orange,
                              size: 18,
                            ),
                            tooltip: '계정 재등록 초기화',
                            onPressed: () =>
                                _showRegistrationResetConfirm(member),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
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
        value: 'passwordReset',
        child: Row(
          children: [
            Icon(Icons.mark_email_read_outlined, size: 20, color: Colors.blue),
            SizedBox(width: 8),
            Text('비밀번호 재설정 안내'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'registrationReset',
        child: Row(
          children: [
            Icon(Icons.lock_reset_rounded, size: 20, color: Colors.orange),
            SizedBox(width: 8),
            Text('재등록 초기화', style: TextStyle(color: Colors.orange)),
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
