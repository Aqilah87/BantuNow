// lib/screens/chat/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserUid;
  final String bantuanTitle;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserUid,
    required this.bantuanTitle,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isSendingLocation = false;

  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Mark as read bila masuk screen
    _chatService.markAsRead(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal hantar mesej: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendLocation() async {
    setState(() => _isSendingLocation = true);

    try {
      // Check permission
      LocationPermission permission =
          await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Kebenaran lokasi ditolak')));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Kebenaran lokasi dihalang. Sila buka Settings.')));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Reverse geocode guna nominatim (free)
      String address =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');
        // Guna http package kalau ada, kalau tak guna coordinate je
        // Simple fallback — guna coordinate format
        address =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      } catch (_) {}

      await _chatService.sendLocation(
        conversationId: widget.conversationId,
        lat: position.latitude,
        lon: position.longitude,
        address: address,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal hantar lokasi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingLocation = false);
    }
  }

  Future<void> _openLocationInMaps(double lat, double lon) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Context banner (post yang dibincangkan) ────────────────
          _buildContextBanner(),
          // ── Messages list ──────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _chatService.markAsRead(widget.conversationId);
              },
              child: _buildMessagesList(),
            ),
          ),
          // ── Input area ─────────────────────────────────────────────
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryBlue,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withOpacity(0.2),
          child: Text(
            widget.otherUserName.isNotEmpty
                ? widget.otherUserName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUserName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'BantuNow',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildContextBanner() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.backgroundBlue,
      child: Row(children: [
        Icon(Icons.article_outlined,
            size: 14, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.bantuanTitle,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream:
          _chatService.getMessagesStream(widget.conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 60,
                    color: AppColors.textGrey.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(
                  'Belum ada mesej.\nMulakan perbualan!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textGrey),
                ),
              ],
            ),
          );
        }

        // Auto scroll bila ada message baru
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg['sender_uid'] == _currentUid;
            final prevMsg =
                index > 0 ? messages[index - 1] : null;
            final showDateDivider = _shouldShowDate(msg, prevMsg);

            return Column(
              children: [
                if (showDateDivider) _buildDateDivider(msg),
                _buildMessageBubble(msg, isMe),
              ],
            );
          },
        );
      },
    );
  }

  bool _shouldShowDate(
      Map<String, dynamic> current, Map<String, dynamic>? prev) {
    if (prev == null) return true;
    final currentTs = current['created_at'] as Timestamp?;
    final prevTs = prev['created_at'] as Timestamp?;
    if (currentTs == null || prevTs == null) return false;
    final currentDate = currentTs.toDate();
    final prevDate = prevTs.toDate();
    return currentDate.day != prevDate.day ||
        currentDate.month != prevDate.month ||
        currentDate.year != prevDate.year;
  }

  Widget _buildDateDivider(Map<String, dynamic> msg) {
    final ts = msg['created_at'] as Timestamp?;
    if (ts == null) return const SizedBox.shrink();
    final date = ts.toDate();
    final now = DateTime.now();
    String label;
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      label = 'Hari Ini';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      label = 'Semalam';
    } else {
      final months = [
        'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
        'Jul', 'Ogs', 'Sep', 'Okt', 'Nov', 'Dis'
      ];
      label = '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: AppColors.textGrey)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ]),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> msg, bool isMe) {
    final type = msg['type'] as String? ?? 'text';
    final ts = msg['created_at'] as Timestamp?;
    final timeStr = ts != null
        ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  AppColors.primaryBlue.withOpacity(0.12),
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: type == 'location'
                  ? const EdgeInsets.all(0)
                  : const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primaryBlue
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: type == 'location'
                  ? _buildLocationMessage(msg, isMe, timeStr)
                  : _buildTextMessage(msg, isMe, timeStr),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTextMessage(
      Map<String, dynamic> msg, bool isMe, String timeStr) {
    final text = msg['text'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          text,
          style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : AppColors.textDark,
              height: 1.4),
        ),
        const SizedBox(height: 4),
        Text(
          timeStr,
          style: TextStyle(
              fontSize: 10,
              color: isMe
                  ? Colors.white.withOpacity(0.7)
                  : AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _buildLocationMessage(
      Map<String, dynamic> msg, bool isMe, String timeStr) {
    final location =
        msg['location'] as Map<String, dynamic>? ?? {};
    final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
    final lon = (location['lon'] as num?)?.toDouble() ?? 0.0;
    final address =
        location['address'] as String? ?? 'Lokasi dikongsi';

    return GestureDetector(
      onTap: () => _openLocationInMaps(lat, lon),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map preview placeholder
            Container(
              height: 120,
              color: AppColors.backgroundBlue,
              child: Stack(children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on,
                          size: 36,
                          color: AppColors.primaryBlue),
                      const SizedBox(height: 4),
                      Text(
                        '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new,
                              size: 11, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Buka Maps',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
              ]),
            ),
            // Address + time
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.location_on,
                        size: 13,
                        color: isMe
                            ? AppColors.primaryBlue
                            : AppColors.textGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(
                            fontSize: 12,
                            color: isMe
                                ? AppColors.primaryBlue
                                : AppColors.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(timeStr,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textGrey)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(children: [
        // ── Location button ──────────────────────────────────────
        _isSendingLocation
            ? Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(8),
                child: const CircularProgressIndicator(
                    strokeWidth: 2),
              )
            : IconButton(
                onPressed: _sendLocation,
                icon: Icon(Icons.location_on,
                    color: AppColors.primaryBlue),
                tooltip: 'Hantar lokasi',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
              ),

        const SizedBox(width: 4),

        // ── Text input ───────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Taip mesej...',
                hintStyle: TextStyle(
                    color: AppColors.textGrey, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ── Send button ──────────────────────────────────────────
        GestureDetector(
          onTap: _isSending ? null : _sendMessage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isSending
                  ? AppColors.primaryBlue.withOpacity(0.5)
                  : AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}