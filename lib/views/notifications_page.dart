import 'package:flutter/material.dart';

import '../features/notifications/services/notification_service.dart';
import '../features/notifications/services/broadcast_service.dart';
import '../features/notifications/models/broadcast.dart';
import '../widgets/labomba_explosion_overlay.dart';
import '../widgets/user_appbar_actions.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    final broadcastService = BroadcastService();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificações'),
          actions: [UserAppBarActions()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Avisos do Bloco'),
              Tab(text: 'Interações'),
            ],
            indicatorColor: Colors.deepOrange,
            labelColor: Colors.black,
          ),
        ),
        body: TabBarView(
          children: [
            // Broadcasts tab
            StreamBuilder<List<BroadcastMessage>>(
              stream: broadcastService.streamAllBroadcasts(),
              builder: (context, snap) {
                if (snap.hasError)
                  return const Center(child: Text('Falha ao carregar avisos.'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                if (items.isEmpty)
                  return const Center(child: Text('Sem avisos no momento.'));
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final b = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          b.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(b.body),
                        trailing: Text(
                          _shortDate(b.createdAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () async {
                          if (context.mounted)
                            await LaBombaExplosionOverlay.show(
                              context,
                              message: b.title,
                            );
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // Interactions tab
            StreamBuilder<List<AppNotification>>(
              stream: service.streamForCurrentUser(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Não foi possível carregar notificações.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = snapshot.data!;
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text('Você não tem notificações novas.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          notification.read
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: notification.read
                              ? Colors.grey
                              : Theme.of(context).colorScheme.secondary,
                        ),
                        title: Text(notification.title),
                        subtitle: Text(notification.body),
                        onTap: () async {
                          if (!notification.read) {
                            await service.markAsRead(notification.id);
                          }
                          if (context.mounted) {
                            await LaBombaExplosionOverlay.show(
                              context,
                              message: notification.title,
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'agora';
  }
}
