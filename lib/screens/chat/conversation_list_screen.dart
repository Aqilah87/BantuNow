// lib/screens/chat/conversation_list_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({Key? key}) : super(key: key);

  @override
  State<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends State<ConversationListScreen> {
  final _chatService = ChatService();

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Row(children: [
          Icon(Icons.chat_bubble_outline,
              color: Colors.white, size: 22),
          SizedBox(width: 10),
          Text(
            'Mesej',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20),
          ),
        ]),
      ),
      body: FirebaseAuth.instance.currentUser == null
          ? _buildNotLoggedIn()
          : _buildConversationList(),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline,
              size: 60,
              color: AppColors.textGrey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'Log masuk untuk melihat mesej',
            style:
                TextStyle(fontSize: 15, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getConversationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 72,
                    color: AppColors.textGrey.withOpacity(0.25)),
                const SizedBox(height: 16),
                Text(
                  'Tiada perbualan lagi',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mulakan perbualan dengan menekan\n"Hubungi" pada mana-mana post.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: conversations.length,
          itemBuilder: (context, index) =>
              _buildConversationTile(conversations[index]),
        );
      },
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final otherUid = _chatService.getOtherUid(conversation);
    final otherName = _chatService.getOtherName(conversation);
    final bantuanTitle =
        conversation['bantuan_title'] as String? ?? '';
    final lastMessage =
        conversation['last_message'] as String? ?? '';
    final lastSenderUid =
        conversation['last_message_sender'] as String? ?? '';
    final unreadCount =
        _chatService.getUnreadCount(conversation);
    final conversationId =
        conversation['conversation_id'] as String? ??
            conversation['id'] as String? ?? '';

    final ts = conversation['last_message_at'] as Timestamp?;
    final timeStr = ts != null ? _formatTime(ts.toDate()) : '';

    final isLastMessageMine = lastSenderUid == _currentUid;
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              otherUserName: otherName,
              otherUserUid: otherUid,
              bantuanTitle: bantuanTitle,
            ),
          ),
        ).then((_) {
          // Mark as read bila balik dari chat
          _chatService.markAsRead(conversationId);
        });
      },
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.primaryBlue.withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread
                ? AppColors.primaryBlue.withOpacity(0.2)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          // ── Avatar ─────────────────────────────────────────────
          Stack(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
                  AppColors.primaryBlue.withOpacity(0.12),
              child: Text(
                otherName.isNotEmpty
                    ? otherName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue),
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                      minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadCount > 99
                        ? '99+'
                        : unreadCount.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ]),

          const SizedBox(width: 12),

          // ── Content ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      otherName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasUnread
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: AppColors.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                        fontSize: 11,
                        color: hasUnread
                            ? AppColors.primaryBlue
                            : AppColors.textGrey,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.normal),
                  ),
                ]),
                const SizedBox(height: 3),

                // Post context
                if (bantuanTitle.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.article_outlined,
                        size: 11, color: AppColors.textGrey),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        bantuanTitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                ],

                // Last message
                Row(children: [
                  if (isLastMessageMine && lastMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Anda: ',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      lastMessage.isEmpty
                          ? 'Mulakan perbualan...'
                          : lastMessage,
                      style: TextStyle(
                          fontSize: 13,
                          color: hasUnread
                              ? AppColors.textDark
                              : AppColors.textGrey,
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Baru';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) return '${diff.inDays}h';

    final months = [
      'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ogs', 'Sep', 'Okt', 'Nov', 'Dis'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}