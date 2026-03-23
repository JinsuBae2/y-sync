import 'package:flutter/material.dart';

class DeletionReasonDialog extends StatefulWidget {
  const DeletionReasonDialog({super.key});

  @override
  State<DeletionReasonDialog> createState() => _DeletionReasonDialogState();
}

class _DeletionReasonDialogState extends State<DeletionReasonDialog> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();

  final List<String> _reasons = [
    '비방/욕설',
    '광고/스팸',
    '게시판 성격 부적합',
    '도배',
    '기타',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('관리자 권한 삭제', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('삭제 사유를 선택해주세요:'),
            const SizedBox(height: 12),
            ..._reasons.map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) {
                setState(() {
                  _selectedReason = value;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
            if (_selectedReason == '기타')
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
                child: TextField(
                  controller: _customReasonController,
                  decoration: const InputDecoration(
                    hintText: '직접 사유 입력',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
          onPressed: _selectedReason == null ? null : () {
            String finalReason = _selectedReason!;
            if (finalReason == '기타') {
              final custom = _customReasonController.text.trim();
              if (custom.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('사유를 입력해주세요.')),
                );
                return;
              }
              finalReason = '기타($custom)';
            }
            Navigator.pop(context, finalReason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('삭제'),
        ),
      ],
    );
  }
}
