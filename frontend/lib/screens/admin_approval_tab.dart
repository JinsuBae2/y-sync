import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_request.dart';
import '../providers/admin_provider.dart';
import '../theme/app_design_tokens.dart';

class AdminApprovalTab extends ConsumerStatefulWidget {
  const AdminApprovalTab({super.key, this.isDesktop = false});

  final bool isDesktop;

  @override
  ConsumerState<AdminApprovalTab> createState() => _AdminApprovalTabState();
}

class _AdminApprovalTabState extends ConsumerState<AdminApprovalTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(adminProvider.notifier).fetchPendingRequests(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: requestsAsync.when(
        data: (requests) => requests.isEmpty
            ? const _EmptyRequests()
            : RefreshIndicator(
                color: AppDesignTokens.blue,
                onRefresh: () =>
                    ref.read(adminProvider.notifier).fetchPendingRequests(),
                child: widget.isDesktop
                    ? _DesktopRequestTable(
                        requests: requests,
                        onApprove: _approve,
                        onReject: _reject,
                      )
                    : _MobileRequestList(
                        requests: requests,
                        onApprove: _approve,
                        onReject: _reject,
                      ),
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppDesignTokens.blue),
        ),
        error: (_, _) => _RequestError(
          onRetry: () =>
              ref.read(adminProvider.notifier).fetchPendingRequests(),
        ),
      ),
    );
  }

  Future<void> _approve(AdminRequest request) async {
    try {
      await ref.read(adminProvider.notifier).approveRequest(request.id);
      _showMessage('${request.requesterName}님의 권한을 승인했습니다.');
    } catch (_) {
      _showMessage('승인 처리에 실패했습니다.');
    }
  }

  Future<void> _reject(AdminRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          '관리자 신청 거절',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('${request.requesterName}님의 신청을 거절하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '거절',
              style: TextStyle(color: AppDesignTokens.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminProvider.notifier).rejectRequest(request.id);
      _showMessage('${request.requesterName}님의 신청을 거절했습니다.');
    } catch (_) {
      _showMessage('거절 처리에 실패했습니다.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MobileRequestList extends StatelessWidget {
  const _MobileRequestList({
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  final List<AdminRequest> requests;
  final ValueChanged<AdminRequest> onApprove;
  final ValueChanged<AdminRequest> onReject;

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    itemCount: requests.length,
    separatorBuilder: (_, _) =>
        const Divider(height: 1, color: AppDesignTokens.divider),
    itemBuilder: (context, index) {
      final request = requests[index];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.requesterName,
                    style: const TextStyle(
                      color: AppDesignTokens.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _formatDate(request.requestedAt),
                  style: const TextStyle(
                    color: AppDesignTokens.subtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              request.loginId,
              style: const TextStyle(
                color: AppDesignTokens.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              request.reason,
              style: const TextStyle(
                color: AppDesignTokens.navy,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => onReject(request),
                  child: const Text(
                    '거절',
                    style: TextStyle(color: AppDesignTokens.coral),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: () => onApprove(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('승인'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _DesktopRequestTable extends StatelessWidget {
  const _DesktopRequestTable({
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  final List<AdminRequest> requests;
  final ValueChanged<AdminRequest> onApprove;
  final ValueChanged<AdminRequest> onReject;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      Container(
        decoration: BoxDecoration(
          color: AppDesignTokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppDesignTokens.divider),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(
              AppDesignTokens.background,
            ),
            columns: const [
              DataColumn(label: Text('신청자')),
              DataColumn(label: Text('학번')),
              DataColumn(label: Text('신청 사유')),
              DataColumn(label: Text('신청일')),
              DataColumn(label: Text('처리')),
            ],
            rows: requests
                .map(
                  (request) => DataRow(
                    cells: [
                      DataCell(Text(request.requesterName)),
                      DataCell(Text(request.loginId)),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: Text(
                            request.reason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_formatDate(request.requestedAt))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '신청 거절',
                              onPressed: () => onReject(request),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppDesignTokens.coral,
                              ),
                            ),
                            IconButton(
                              tooltip: '신청 승인',
                              onPressed: () => onApprove(request),
                              icon: const Icon(
                                Icons.check_rounded,
                                color: AppDesignTokens.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ],
  );
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 42,
          color: AppDesignTokens.subtle,
        ),
        SizedBox(height: 14),
        Text(
          '대기 중인 권한 신청이 없습니다',
          style: TextStyle(
            color: AppDesignTokens.navy,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _RequestError extends StatelessWidget {
  const _RequestError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('승인 목록 다시 불러오기'),
    ),
  );
}

String _formatDate(String value) => value.contains('T')
    ? value.split('T').first.replaceAll('-', '.')
    : value.replaceAll('-', '.');
