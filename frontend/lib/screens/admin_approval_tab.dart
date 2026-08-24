import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../models/admin_request.dart';

class AdminApprovalTab extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminApprovalTab({super.key, this.isDesktop = false});

  @override
  ConsumerState<AdminApprovalTab> createState() => _AdminApprovalTabState();
}

class _AdminApprovalTabState extends ConsumerState<AdminApprovalTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminProvider.notifier).fetchPendingRequests();
    });
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminRequests = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: adminRequests.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '승인 대기 중인 관리자 신청이 없습니다.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(adminProvider.notifier).fetchPendingRequests(),
            color: const Color(0xFF164687),
            child: widget.isDesktop
                ? _buildDesktopTable(requests)
                : _buildMobileList(requests),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF164687))),
        error: (error, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '오류가 발생했습니다: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }

  // 📱 모바일용 리스트 뷰
  Widget _buildMobileList(List<AdminRequest> requests) {
    return ListView.builder(
      itemCount: requests.length,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemBuilder: (context, index) {
        final req = requests[index];
        final requestedDate = req.requestedAt.contains('T')
            ? req.requestedAt.split('T')[0]
            : req.requestedAt;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF164687).withOpacity(0.1),
                  child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF164687)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${req.requesterName} (${req.loginId})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '신청 사유:',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        req.reason,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '신청일자: $requestedDate',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        try {
                          await ref.read(adminProvider.notifier).approveRequest(req.id);
                          _showSuccessSnackBar('${req.requesterName}님의 관리자 권한을 승인하였습니다.');
                        } catch (e) {
                          _showErrorSnackBar('승인 처리 중 오류 발생: $e');
                        }
                      },
                      child: const Text('승인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        try {
                          await ref.read(adminProvider.notifier).rejectRequest(req.id);
                          _showSuccessSnackBar('${req.requesterName}님의 관리자 신청을 거절하였습니다.');
                        } catch (e) {
                          _showErrorSnackBar('거절 처리 중 오류 발생: $e');
                        }
                      },
                      child: const Text('거절', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 💻 데스크톱용 표(Table) 뷰
  Widget _buildDesktopTable(List<AdminRequest> requests) {
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
              dataRowMaxHeight: 70,
              columns: const [
                DataColumn(label: Text('학번', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('이름', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('신청 사유', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('신청 날짜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('승인 처리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
              rows: requests.map((req) {
                final requestedDate = req.requestedAt.contains('T')
                    ? req.requestedAt.split('T')[0]
                    : req.requestedAt;
                return DataRow(
                  cells: [
                    DataCell(Text(req.loginId, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(req.requesterName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(req.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    DataCell(Text(requestedDate)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () async {
                              try {
                                await ref.read(adminProvider.notifier).approveRequest(req.id);
                                _showSuccessSnackBar('${req.requesterName}님의 관리자 권한을 승인하였습니다.');
                              } catch (e) {
                                _showErrorSnackBar('승인 처리 중 오류 발생: $e');
                              }
                            },
                            child: const Text('승인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () async {
                              try {
                                await ref.read(adminProvider.notifier).rejectRequest(req.id);
                                _showSuccessSnackBar('${req.requesterName}님의 관리자 신청을 거절하였습니다.');
                              } catch (e) {
                                _showErrorSnackBar('거절 처리 중 오류 발생: $e');
                              }
                            },
                            child: const Text('거절', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
}
