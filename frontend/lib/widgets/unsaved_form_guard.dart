import 'package:flutter/material.dart';

import 'app_confirmation_dialog.dart';

class UnsavedFormGuard extends StatefulWidget {
  const UnsavedFormGuard({
    super.key,
    required this.controllers,
    required this.hasChanges,
    required this.child,
    this.saving = false,
    this.onDiscard,
    this.discardMessage,
  });

  final List<TextEditingController> controllers;
  final bool Function() hasChanges;
  final bool saving;
  final bool Function()? onDiscard;
  final String? discardMessage;
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
      barrierColor: AppConfirmationDialog.barrierColor,
      builder: (context) => AppConfirmationDialog(
        icon: Icons.edit_note_rounded,
        title: '작성을 그만할까요?',
        content: Text(widget.discardMessage ?? '아직 저장하지 않은 내용이 있어요.\n지금 나가면 변경 내용이 사라집니다.'),
        primaryActionIndex: 0,
        autofocusPrimary: true,
        onClose: () => Navigator.pop(context, false),
        closeLabel: '계속 작성',
        actions: [
          AppDialogAction(
            label: '계속 작성',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDialogAction(
            label: '변경 내용 버리기',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted || discard != true) return;
    if (widget.onDiscard?.call() == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경 내용을 버리지 못했습니다. 다시 시도해주세요.')),
      );
      return;
    }
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
