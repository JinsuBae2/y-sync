import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/server_availability_provider.dart';
import '../screens/server_maintenance_screen.dart';

class ServerAvailabilityGate extends ConsumerStatefulWidget {
  const ServerAvailabilityGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ServerAvailabilityGate> createState() =>
      _ServerAvailabilityGateState();
}

class _ServerAvailabilityGateState extends ConsumerState<ServerAvailabilityGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(serverHealthCheckProvider)());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(serverHealthCheckProvider)());
    }
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(serverAvailabilityProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (availability == ServerAvailability.unavailable)
          const Positioned.fill(child: ServerMaintenanceScreen()),
      ],
    );
  }
}
