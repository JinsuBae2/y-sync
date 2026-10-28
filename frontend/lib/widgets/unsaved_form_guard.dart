import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class UnsavedFormGuard extends StatefulWidget {
  const UnsavedFormGuard({
    super.key,
    required this.controllers,
    required this.hasChanges,
    required this.child,
    this.saving = false,
  });

  final List<TextEditingController> controllers;
  final bool Function() hasChanges;
  final bool saving;
  final Widget child;

  @override
  State<UnsavedFormGuard> createState() => _UnsavedFormGuardState();
}

class _UnsavedFormGuardState extends State<UnsavedFormGuard> {
  bool _discard = false;
  bool _asking = false;

  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop || _asking) return;
    if (widget.saving) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장 중입니다. 잠시만 기다려주세요.')));
      return;
    }
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      barrierColor: AppDesignTokens.navy.withValues(alpha: 0.38),
      builder: (context) => Dialog(
        backgroundColor: AppDesignTokens.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppDesignTokens.paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: AppDesignTokens.blue,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '계속 작성',
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppDesignTokens.muted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '작성을 그만할까요?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppDesignTokens.navy,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '아직 저장하지 않은 내용이 있어요.\n지금 나가면 변경 내용이 사라집니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppDesignTokens.muted,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  autofocus: true,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('계속 작성'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesignTokens.muted,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('변경 내용 버리기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _asking = false;
    if (!mounted || discard != true) return;
    setState(() => _discard = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(widget.controllers),
    builder: (context, child) => PopScope<Object?>(
      canPop: _discard || (!widget.saving && !widget.hasChanges()),
      onPopInvokedWithResult: _onPop,
      child: child!,
    ),
    child: widget.child,
  );
}
