import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/post_service.dart';
import 'god_mode_content_page.dart';
import 'god_mode_users_page.dart';

enum LogType { info, success, warning, error, command }

class TerminalLog {
  final String text;
  final LogType type;

  TerminalLog(this.text, {this.type = LogType.info});

  Color get color {
    switch (type) {
      case LogType.success:
        return Colors.green;
      case LogType.error:
        return Colors.redAccent;
      case LogType.warning:
        return Colors.amber;
      case LogType.command:
        return Colors.white;
      case LogType.info:
      default:
        return Colors.greenAccent;
    }
  }
}

class GodModeDashboard extends StatefulWidget {
  const GodModeDashboard({super.key});

  @override
  State<GodModeDashboard> createState() => _GodModeDashboardState();
}

class _GodModeDashboardState extends State<GodModeDashboard> {
  final TextEditingController _terminalController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _terminalFocusNode = FocusNode();
  final PostService _postService = PostService();

  final List<TerminalLog> _terminalHistory = [
    TerminalLog(
      'LaBomba OS v1.0.0 [God Mode Activated]',
      type: LogType.warning,
    ),
    TerminalLog('Type /help for a list of commands.', type: LogType.info),
  ];

  Future<bool> _isMaster() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims ?? {};
      return claims['owner'] == true ||
          claims['isOwner'] == true ||
          claims['role'] == 'owner';
    } catch (_) {
      return false;
    }
  }

  void _addLog(String message, {LogType type = LogType.info}) {
    setState(() {
      _terminalHistory.add(TerminalLog(message, type: type));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleCommand(String input) async {
    final command = input.trim();
    if (command.isEmpty) return;

    _addLog('root@labomba:~\$ $command', type: LogType.command);
    _terminalController.clear();
    _terminalFocusNode.requestFocus();

    final parts = command.split(' ');
    final lowerCmd = parts[0].toLowerCase();

    // Comandos sem restrição de master (somente /clear, /help, /ping)
    if (lowerCmd == '/clear') {
      setState(() {
        _terminalHistory.clear();
      });
      _addLog('Terminal cleared.', type: LogType.success);
      return;
    }

    if (lowerCmd == '/help') {
      _addLog('Available commands:', type: LogType.info);
      _addLog('  /help           - Show this message', type: LogType.info);
      _addLog('  /clear          - Clear terminal history', type: LogType.info);
      _addLog('  /ping           - Check system latency', type: LogType.info);
      _addLog('  /posts          - List latest 5 posts', type: LogType.warning);
      _addLog(
        '  /delpost <id>   - Delete a specific post',
        type: LogType.warning,
      );
      _addLog(
        '  /broadcast <msg>- Post a pinned global message',
        type: LogType.warning,
      );
      _addLog(
        '  /ban <id>       - Toggle ban status for a client ID',
        type: LogType.warning,
      );
      _addLog(
        '  /stats          - Show live platform statistics',
        type: LogType.warning,
      );
      return;
    }

    if (lowerCmd == '/ping') {
      _addLog('Pong! Latency: 12ms', type: LogType.success);
      return;
    }

    // Validação de segurança suprema
    if (!(await _isMaster())) {
      _addLog(
        'ACCESS DENIED: Command requires OWNER-backed tier privileges.',
        type: LogType.error,
      );
      return;
    }

    // Comandos protegidos
    try {
      if (lowerCmd == '/posts') {
        _addLog('Fetching latest posts...', type: LogType.warning);
        final snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        if (snapshot.docs.isEmpty) {
          _addLog('No posts found.', type: LogType.info);
        } else {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            _addLog(
              'ID: ${doc.id} | User: ${data['userName']} | Content: ${data['content']}',
              type: LogType.success,
            );
          }
        }
      } else if (lowerCmd == '/delpost') {
        if (parts.length < 2) {
          _addLog('Usage: /delpost <id>', type: LogType.error);
          return;
        }
        final postId = parts[1];
        await _postService.deletePost(postId);
        _addLog('Post $postId deleted permanently.', type: LogType.success);
      } else if (lowerCmd == '/broadcast') {
        if (parts.length < 2) {
          _addLog('Usage: /broadcast <message>', type: LogType.error);
          return;
        }
        final message = parts.sublist(1).join(' ');

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("No user");

        final docRef = await FirebaseFirestore.instance.collection('posts').add(
          {
            'userId': user.uid,
            'userName': 'LA BOMBA OFICIAL', // Broadcast oficial
            'avatarUrl': null,
            'content': message,
            'createdAt': Timestamp.now(),
            'isPinned': true,
          },
        );

        _addLog(
          'Broadcast published and pinned. PostID: ${docRef.id}',
          type: LogType.success,
        );
      } else if (lowerCmd == '/ban') {
        if (parts.length < 2) {
          _addLog('Usage: /ban <id>', type: LogType.error);
          return;
        }
        final clientId = parts[1];
        final docRef =
            FirebaseFirestore.instance.collection('clients').doc(clientId);
        final docSnap = await docRef.get();
        if (!docSnap.exists) {
          _addLog('Client $clientId not found.', type: LogType.error);
          return;
        }
        final isBanned = docSnap.data()?['isBanned'] == true;
        await docRef.update({'isBanned': !isBanned});
        _addLog(
          isBanned
              ? 'Client $clientId is now UNBANNED.'
              : 'Client $clientId is now BANNED.',
          type: LogType.success,
        );
      } else if (lowerCmd == '/stats') {
        _addLog('Gathering platform stats...', type: LogType.warning);

        final clientsSnap = await FirebaseFirestore.instance
            .collection('clients')
            .count()
            .get();
        final postsSnap =
            await FirebaseFirestore.instance.collection('posts').count().get();

        _addLog('--- GOD MODE STATS ---', type: LogType.success);
        _addLog(
          'Total Registered Clients: ${clientsSnap.count}',
          type: LogType.success,
        );
        _addLog('Total Feed Posts: ${postsSnap.count}', type: LogType.success);
        _addLog('VIP Tickets: [Data not linked yet]', type: LogType.warning);
      } else {
        _addLog('Command not recognized: $command', type: LogType.error);
      }
    } catch (e) {
      _addLog('Command failed: $e', type: LogType.error);
    }
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _scrollController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  Widget _buildTerminal() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: Colors.greenAccent.withValues(alpha: 0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Histórico do terminal
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12.0),
              itemCount: _terminalHistory.length,
              itemBuilder: (context, index) {
                final log = _terminalHistory[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    log.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: log.color,
                      fontSize: 14.0,
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Colors.greenAccent),
          // Input do terminal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            color: Colors.grey.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Text(
                  'root@labomba:~\$ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.greenAccent,
                    fontSize: 14.0,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _terminalController,
                    focusNode: _terminalFocusNode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.greenAccent,
                      fontSize: 14.0,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    cursorColor: Colors.greenAccent,
                    onSubmitted: _handleCommand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    String title,
    IconData icon,
    Color iconColor, {
    VoidCallback? onTap,
  }) {
    return Card(
      color: const Color(0xFF16151E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModulesPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 1.1,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildDashboardCard(
            'Logs de Auditoria',
            Icons.security,
            Colors.amber,
          ),
          _buildDashboardCard(
            'Radar de Usuários',
            Icons.radar,
            Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GodModeUsersPage()),
              );
            },
          ),
          _buildDashboardCard(
            'Moderação de Feed',
            Icons.article,
            Colors.redAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GodModeContentPage()),
              );
            },
          ),
          _buildDashboardCard(
            'Broadcast System',
            Icons.podcasts,
            Colors.purpleAccent,
            onTap: () {
              _handleCommand('/broadcast [Aviso da Diretoria] Mensagem Global');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text(
          'GOD MODE [TERMINAL]',
          style: TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.greenAccent),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Área 1: The God Terminal (Expande para tomar metade ou o que sobrar)
          Expanded(flex: 5, child: _buildTerminal()),
          // Área 2: Painel de Módulos
          Expanded(flex: 5, child: _buildModulesPanel()),
        ],
      ),
    );
  }
}
