import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/memories/services/heat_explosion_service.dart';
import '../providers/google_auth_provider.dart';
import '../theme/app_theme.dart';
import 'app_feedback.dart';
import 'labomba_explosion_overlay.dart';

class HeatExplosionWidget extends StatefulWidget {
  const HeatExplosionWidget({super.key});

  @override
  State<HeatExplosionWidget> createState() => _HeatExplosionWidgetState();
}

class _HeatExplosionWidgetState extends State<HeatExplosionWidget> {
  final HeatExplosionService _service = HeatExplosionService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  final Set<String> _localEventIds = <String>{};
  bool _readyForRemoteEvents = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (_service.isAvailable) {
      _subscription = _service.eventsStream().listen(_handleEvents);
    } else {
      _readyForRemoteEvents = true;
    }
  }

  void _handleEvents(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_readyForRemoteEvents) {
      _readyForRemoteEvents = true;
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added || !mounted) continue;
      if (_localEventIds.remove(change.doc.id)) continue;
      final name = change.doc.data()?['displayName'] as String? ?? 'Alguém';
      unawaited(
        LaBombaExplosionOverlay.show(context, message: '$name mandou calor!'),
      );
    }
  }

  Future<void> _trigger() async {
    if (_sending) return;
    final user = context.read<GoogleAuthProvider>().currentUserData;
    final userId = user?.uid;
    if (userId == null || userId.isEmpty) {
      AppFeedback.showWarning(
        context,
        'Entre para enviar uma explosão de calor.',
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final eventId = await _service.trigger(
        userId: userId,
        displayName: user?.displayName ?? 'Folião',
      );
      _localEventIds.add(eventId);
      if (!mounted) return;
      await LaBombaExplosionOverlay.show(context, message: 'LA BOMBA!');
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(context, 'Não foi possível enviar a explosão.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'heat-explosion',
      onPressed: _sending ? null : _trigger,
      tooltip: 'Enviar explosão de calor',
      backgroundColor: AppTheme.accent,
      foregroundColor: Colors.white,
      child: _sending
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.local_fire_department_outlined),
    );
  }
}
