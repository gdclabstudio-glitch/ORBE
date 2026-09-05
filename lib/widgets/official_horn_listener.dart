import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/notifications/services/official_horn_service.dart';
import 'app_feedback.dart';

class OfficialHornListener extends StatefulWidget {
  const OfficialHornListener({super.key});

  @override
  State<OfficialHornListener> createState() => _OfficialHornListenerState();
}

class _OfficialHornListenerState extends State<OfficialHornListener> {
  final OfficialHornService _service = OfficialHornService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (_service.isAvailable) {
      _subscription = _service.announcementsStream().listen(_handleSnapshot);
    } else {
      _ready = true;
    }
  }

  void _handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_ready) {
      _ready = true;
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added || !mounted) continue;
      final announcement = OfficialAnnouncement.fromDocument(change.doc);
      AppFeedback.showAnnouncement(context, announcement);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
