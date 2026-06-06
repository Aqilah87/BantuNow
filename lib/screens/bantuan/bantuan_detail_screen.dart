// lib/screens/bantuan/bantuan_detail_screen.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../models/bantuan_model.dart';
import '../../services/bantuan_service.dart';
import '../../services/deep_link_service.dart';
import '../../widgets/rating_dialog.dart';
import '../profile/user_profile_screen.dart';
import '../chat/chat_screen.dart';       
import '../../services/chat_service.dart';

class BantuanDetailScreen extends StatefulWidget {
  final BantuanModel bantuan;
  final Function(String action) onLoginRequired;
  final bool isLoggedIn;

  const BantuanDetailScreen({
    Key? key,
    required this.bantuan,
    required this.onLoginRequired,
    required this.isLoggedIn,
  }) : super(key: key);

  @override
  State<BantuanDetailScreen> createState() => _BantuanDetailScreenState();
}

class _BantuanDetailScreenState extends State<BantuanDetailScreen> {
  final _bantuanService = BantuanService();
  bool _isActionLoading = false;

  late BantuanModel _bantuan;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == _bantuan.postedByUid;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // Untuk single: check helper_uid
  // Untuk multiple: check dalam helper_uids array
  bool get _isAssignedHelper {
    if (_currentUid == null) return false;
    if (_bantuan.isMultipleSlot) {
      return _bantuan.helperUids.contains(_currentUid);
    }
    return _bantuan.helperUid == _currentUid;
  }

  // Semak kalau current user dah join (multiple)
  bool get _hasAlreadyJoined {
    if (_currentUid == null) return false;
    if (_bantuan.isMultipleSlot) {
      return _bantuan.helperUids.contains(_currentUid);
    }
    return false;
  }

  // Semak kalau current user (multiple) dah confirm selesai
  bool get _currentHelperConfirmed {
    if (_currentUid == null) return false;
    return _bantuan.helperConfirmations[_currentUid] == true;
  }
  /// true kalau post ni guna completionType 'group'
  bool get _isGroupCompletion => _bantuan.completionType == 'group';

  @override
  void initState() {
    super.initState();
    _bantuan = widget.bantuan;
    _bantuanService.checkAndAutoClose();
  }

  // ─── Refresh bantuan dari Firestore ───────────────────────────────
  Future<void> _refreshBantuan() async {
    final updated = await FirebaseFirestore.instance
        .collection('bantuan')
        .doc(_bantuan.id)
        .get();
    if (mounted && updated.exists) {
      setState(
          () => _bantuan = BantuanModel.fromMap(updated.data()!, updated.id));
    }
  }

  // ─── Status helpers ────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'full':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status, bool isMalay) {
    switch (status) {
      case 'open':
        return isMalay ? 'Aktif' : 'Active';
      case 'in_progress':
        return isMalay ? 'Sedang Dibantu' : 'In Progress';
      case 'full':
        return isMalay ? 'Slot Penuh' : 'Full';
      default:
        return isMalay ? 'Selesai' : 'Completed';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.handshake_outlined;
      case 'full':
        return Icons.people_alt;
      default:
        return Icons.task_alt;
    }
  }

  Future<void> _openChat(bool isMalay) async {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired(
          isMalay ? 'menghantar mesej' : 'send a message');
      return;
    }

    // Tak boleh chat dengan diri sendiri
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? 'Ini adalah post anda sendiri'
            : 'This is your own post'),
      ));
      return;
    }

    try {
      final chatService = ChatService();
      final conversationId = await chatService.getOrCreateConversation(
        otherUid: _bantuan.postedByUid,
        otherName: _bantuan.postedBy,
        bantuanId: _bantuan.id,
        bantuanTitle: _bantuan.title,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserName: _bantuan.postedBy,
            otherUserUid: _bantuan.postedByUid,
            bantuanTitle: _bantuan.title,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? 'Gagal membuka mesej: $e'
              : 'Failed to open chat: $e'),
        ));
      }
    }
  }

  // ─── Navigation ────────────────────────────────────────────────────

  void _showNavigationSheet(BuildContext context, double lat, double lon,
      String title, bool isMalay) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              isMalay ? 'Navigate ke Lokasi' : 'Navigate to Location',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              isMalay ? 'Pilih aplikasi navigasi' : 'Choose navigation app',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildNavOption(
                    icon: Icons.map,
                    iconColor: const Color(0xFF4285F4),
                    bgColor: const Color(0xFF4285F4).withOpacity(0.1),
                    label: 'Google Maps',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _openGoogleMaps(lat, lon, title, isMalay);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNavOption(
                    icon: Icons.navigation,
                    iconColor: const Color(0xFF05C8F7),
                    bgColor: const Color(0xFF05C8F7).withOpacity(0.1),
                    label: 'Waze',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _openWaze(lat, lon, isMalay);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildNavOption({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: iconColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: iconColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(
      double lat, double lon, String label, bool isMalay) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWaze(double lat, double lon, bool isMalay) async {
    final uri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Share ─────────────────────────────────────────────────────────

  void _sharePost(bool isMalay) {
    final bantuan = _bantuan;
    final link = DeepLinkService.generatePostLink(bantuan.id);
    final isRequest = bantuan.type == 'request';
    final typeEmoji = isRequest ? '🙋' : '🤲';
    final typeLabel = isRequest
        ? (isMalay ? 'Minta Bantuan' : 'Request Help')
        : (isMalay ? 'Tawar Bantuan' : 'Offer Help');
    final categoryName =
        BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0];
    final desc = bantuan.description.length > 100
        ? '${bantuan.description.substring(0, 100)}...'
        : bantuan.description;

    final shareText = isMalay
        ? '$typeEmoji *$typeLabel di BantuNow!*\n\n📌 *${bantuan.title}*\n🏷️ Kategori: $categoryName\n📍 Kawasan: ${bantuan.area}\n\n$desc\n\n🔗 Lihat selengkapnya:\n$link\n\n_Dikongsi melalui BantuNow — Aplikasi Bantuan Komuniti Kuala Terengganu_'
        : '$typeEmoji *$typeLabel on BantuNow!*\n\n📌 *${bantuan.title}*\n🏷️ Category: $categoryName\n📍 Area: ${bantuan.area}\n\n$desc\n\n🔗 View more:\n$link\n\n_Shared via BantuNow — Kuala Terengganu Community Assistance App_';

    Share.share(shareText, subject: bantuan.title);
  }

  void _copyLink(bool isMalay) {
    final link = DeepLinkService.generatePostLink(_bantuan.id);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(isMalay ? 'Link berjaya disalin!' : 'Link copied!'),
      ]),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _shareViaWhatsApp() async {
    final link = DeepLinkService.generatePostLink(_bantuan.id);
    final message = Uri.encodeComponent(
        '🙌 *${_bantuan.title}*\n📍 ${_bantuan.area}\n\n$link');
    final url = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showShareSheet(bool isMalay) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(isMalay ? 'Kongsi Post' : 'Share Post',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(
                isMalay
                    ? 'Kongsikan post ini kepada rakan anda'
                    : 'Share this post with your friends',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                    icon: Icons.share,
                    label: isMalay ? 'Kongsi' : 'Share',
                    color: AppColors.primaryBlue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _sharePost(isMalay);
                    }),
                _buildShareOption(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareViaWhatsApp();
                    }),
                _buildShareOption(
                    icon: Icons.link,
                    label: isMalay ? 'Salin Link' : 'Copy Link',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(ctx);
                      _copyLink(isMalay);
                    }),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.backgroundBlue,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.link, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  DeepLinkService.generatePostLink(_bantuan.id),
                  style:
                      TextStyle(fontSize: 11, color: AppColors.primaryBlue),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark)),
      ]),
    );
  }

  // ─── ACTIONS ───────────────────────────────────────────────────────

  Future<void> _acceptHelp(bool isMalay) async {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired(isMalay ? 'menawarkan bantuan' : 'offer help');
      return;
    }

    final isOffer = _bantuan.type == 'offer';
    final isMultiple = _bantuan.isMultipleSlot;
    final user = FirebaseAuth.instance.currentUser!;

    // Ambil nama user
    String helperName = user.displayName ?? '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) helperName = doc.data()?['name'] ?? helperName;
    } catch (_) {}

    // ── Dialog confirm ─────────────────────────────────────────────
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isOffer
              ? (isMultiple
                  ? (isMalay ? 'Daftar Slot Ini?' : 'Join This Slot?')
                  : (isMalay
                      ? 'Berminat dengan Tawaran Ini?'
                      : 'Interested in This Offer?'))
              : (isMalay ? 'Nak Bantu?' : 'Offer Help?'),
        ),
        content: Text(
          isOffer
              ? (isMultiple
                  ? (isMalay
                      ? 'Anda akan didaftarkan sebagai salah seorang peserta. Slot akan berkurang selepas ini.'
                      : 'You will be registered as one of the participants. A slot will be taken.')
                  : (isMalay
                      ? 'Anda akan dihubungkan dengan poster yang menawarkan bantuan ini.'
                      : 'You will be connected with the poster offering this help.'))
              : (isMalay
                  ? 'Anda akan ditandakan sebagai helper untuk post ini.'
                  : 'You will be marked as the helper for this post.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOffer
                  ? (isMultiple ? Colors.purple : AppColors.primaryBlue)
                  : Colors.orange,
            ),
            child: Text(
              isOffer
                  ? (isMultiple
                      ? (isMalay ? 'Ya, Daftar' : 'Yes, Join')
                      : (isMalay ? 'Ya, Saya Berminat' : "Yes, I'm Interested"))
                  : (isMalay ? 'Ya, Saya Bantu' : "Yes, I'll Help"),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);

    try {
      // ── MULTIPLE SLOT LOGIC ──────────────────────────────────────
        if (isMultiple) {
        final result = await _bantuanService.acceptMultipleSlot(
          postId: _bantuan.id,
          helperUid: user.uid,
          helperName: helperName,
          currentAccepted: _bantuan.acceptedSlots,
          totalSlots: _bantuan.totalSlots ?? 0,
          completionType: _bantuan.completionType,
        );

        if (result['success'] == true) {
          await _refreshBantuan();
          if (mounted) {
            final isFull = result['is_full'] == true;
            final remaining = result['remaining'] as int? ?? 0;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                isFull
                    ? (isMalay
                        ? '✅ Berjaya daftar! Slot kini penuh.'
                        : '✅ Joined! Slots are now full.')
                    : (isMalay
                        ? '✅ Berjaya daftar! $remaining slot lagi tersedia.'
                        : '✅ Joined! $remaining slot(s) remaining.'),
              ),
              backgroundColor: Colors.purple,
            ));
          }
        } else {
          final msg = result['message'] as String? ?? '';
          if (mounted) {
            String errorText;
            if (msg == 'already_joined') {
              errorText = isMalay
                  ? 'Anda sudah mendaftar untuk slot ini.'
                  : 'You have already joined this slot.';
            } else if (msg == 'slot_full') {
              errorText = isMalay
                  ? 'Maaf, semua slot telah penuh.'
                  : 'Sorry, all slots are full.';
            } else {
              errorText = 'Error: $msg';
            }
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(errorText)));
          }
        }
      } else {
        // ── SINGLE LOGIC (offer single atau request) ─────────────
        final result = await _bantuanService.acceptSingleHelp(
          postId: _bantuan.id,
          helperUid: user.uid,
          helperName: helperName,
        );

        if (result['success'] == true) {
          await _refreshBantuan();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                isOffer
                    ? (isMalay
                        ? '✅ Anda telah menyatakan minat!'
                        : '✅ You have expressed interest!')
                    : (isMalay
                        ? '🤝 Anda telah menjadi helper!'
                        : '🤝 You are now the helper!'),
              ),
              backgroundColor:
                  isOffer ? AppColors.primaryBlue : Colors.orange,
            ));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${result['message']}')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _helperConfirmDone(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Dah Selesai?' : 'Done?'),
        content: Text(isMalay
            ? 'Sahkan bahawa anda telah berjaya. Owner akan dimaklumkan.'
            : 'Confirm that you have completed. The owner will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isMalay ? 'Ya, Selesai' : 'Yes, Done',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final result = await _bantuanService.helperConfirm(
        _bantuan.id,
        helperUid: _currentUid,
        isMultiple: _bantuan.isMultipleSlot,
      );
      if (result['success'] != true) throw result['message'];
      await _refreshBantuan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }

    if (!mounted) return;

    // Rating untuk single — untuk multiple, rating dilakukan bila owner tutup post
    if (!_bantuan.isMultipleSlot) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => RatingDialog(
          bantuanId: _bantuan.id,
          ratedUserUid: _bantuan.postedByUid,
          ratedUserName: _bantuan.postedBy,
          type: 'poster',
          isMalay: isMalay,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? '✅ Terima kasih! Owner akan mengesahkan selesai.'
            : '✅ Thanks! The owner will confirm completion.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _ownerConfirmComplete(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Sahkan Selesai?' : 'Confirm Complete?'),
        content: Text(isMalay
            ? 'Sahkan bantuan telah selesai dan nilai helper anda.'
            : 'Confirm the help is done and rate your helper.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isMalay ? 'Ya, Selesai' : 'Yes, Complete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);

    if (mounted && _bantuan.helperUid != null) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => RatingDialog(
          bantuanId: _bantuan.id,
          ratedUserUid: _bantuan.helperUid!,
          ratedUserName: _bantuan.helperName ?? 'Helper',
          type: 'helper',
          isMalay: isMalay,
        ),
      );
    }

    try {
      await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .update({'status': 'closed'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? '✅ Post ditutup. Terima kasih!'
            : '✅ Post closed. Thank you!'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    }
  }

  // ─── OWNER TUTUP POST (multiple) ──────────────────────────────────
  // Owner boleh tutup bila-bila masa — tak perlu tunggu semua confirm

  Future<void> _ownerCloseMultiplePost(bool isMalay) async {
    final allDone = _bantuan.allHelpersConfirmed;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Tutup Post?' : 'Close Post?'),
        content: Text(
          allDone
              ? (isMalay
                  ? 'Semua helper telah sahkan selesai. Tutup post ini?'
                  : 'All helpers confirmed done. Close this post?')
              : (isMalay
                  ? 'Belum semua helper confirm selesai. Tutup post ini lebih awal?'
                  : 'Not all helpers confirmed yet. Close this post early?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: allDone ? Colors.green : Colors.orange),
            child: Text(isMalay ? 'Ya, Tutup' : 'Yes, Close',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final result = await _bantuanService.closeBantuan(_bantuan.id);
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isMalay
                ? '✅ Post berjaya ditutup!'
                : '✅ Post closed successfully!'),
            backgroundColor: Colors.green,
          ));
          Navigator.pop(context);
        }
      } else {
        throw result['message'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deletePost(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Padam Post?' : 'Delete Post?'),
        content: Text(isMalay
            ? 'Adakah anda pasti? Tindakan ini tidak boleh dibatalkan.'
            : 'Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isMalay ? 'Padam' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? '🗑️ Post berjaya dipadam'
            : '🗑️ Post deleted successfully'),
        backgroundColor: Colors.red,
      ));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isActionLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isMalay ? 'Gagal' : 'Failed'}: $e')));
    }
  }

  Future<void> _resetToOpen(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Tukar Helper?' : 'Change Helper?'),
        content: Text(isMalay
            ? 'Helper semasa akan dibuang dan post akan dibuka semula.'
            : 'The current helper will be removed and the post reopened.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(isMalay ? 'Ya, Buka Semula' : 'Yes, Reopen',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .update({
        'status': 'open',
        'helper_uid': FieldValue.delete(),
        'helper_name': FieldValue.delete(),
        'helper_confirmed': false,
        'helper_confirmed_at': FieldValue.delete(),
      });
      await _refreshBantuan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? '🔄 Post dibuka semula.'
              : '🔄 Post reopened.'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // ─── OWNER CANCEL / REJECT HELPER ─────────────────────────────────
    Future<void> _ownerCancelHelper(
      bool isMalay, String helperUid, String helperName) async {
    // ── Step 1: Pilih sebab ──────────────────────────────────────
    final reasons = isMalay
        ? ['Helper tidak sesuai', 'Sudah ada helper lain', 'Post dah tidak diperlukan', 'Lain-lain']
        : ['Helper not suitable', 'Already have another helper', 'Post no longer needed', 'Other'];

    String? selectedReason;
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.person_remove_outlined, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(
              isMalay ? 'Sebab Tolak "$helperName"?' : 'Reason to Reject "$helperName"?',
              style: const TextStyle(fontSize: 15),
            )),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMalay
                      ? 'Sila pilih sebab anda menolak helper ini:'
                      : 'Please select your reason for rejecting:',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                const SizedBox(height: 12),
                ...reasons.map((r) => GestureDetector(
                  onTap: () => setDialogState(() => selectedReason = r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedReason == r
                          ? Colors.red.withOpacity(0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedReason == r ? Colors.red : Colors.grey.shade200,
                        width: selectedReason == r ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        selectedReason == r
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: selectedReason == r ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Text(r, style: TextStyle(
                        fontSize: 13,
                        color: selectedReason == r ? Colors.red : AppColors.textDark,
                        fontWeight: selectedReason == r ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ]),
                  ),
                )),
                if (selectedReason == reasons.last) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: isMalay ? 'Nyatakan sebab...' : 'State your reason...',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textGrey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      final finalReason = selectedReason == reasons.last && reasonController.text.isNotEmpty
                          ? reasonController.text.trim()
                          : selectedReason!;
                      Navigator.pop(ctx, finalReason);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(isMalay ? 'Ya, Tolak' : 'Yes, Reject',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (reason == null) return;

    setState(() => _isActionLoading = true);
    try {
      final result = await _bantuanService.ownerCancelHelper(
        postId: _bantuan.id,
        helperUid: helperUid,
        helperName: helperName,
        isMultiple: _bantuan.isMultipleSlot,
        isIndividual: !_isGroupCompletion,
        reason: reason,
      );
      if (result['success'] == true) {
        await _refreshBantuan();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isMalay
                ? '🔄 Helper dibuang. Post aktif semula.'
                : '🔄 Helper removed. Post is active again.'),
            backgroundColor: Colors.orange,
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${result['message']}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // ─── HELPER WITHDRAW ──────────────────────────────────────────────
    Future<void> _helperWithdraw(bool isMalay) async {
    // ── Step 1: Pilih sebab ──────────────────────────────────────
    final reasons = isMalay
        ? ['Tidak sengaja tertekan', 'Dah tak available', 'Ada hal kecemasan', 'Lain-lain']
        : ['Accidentally pressed', 'No longer available', 'Emergency came up', 'Other'];

    String? selectedReason;
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.exit_to_app, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text(isMalay ? 'Sebab Tarik Diri?' : 'Reason to Withdraw?'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMalay
                      ? 'Sila pilih sebab anda tarik diri:'
                      : 'Please select your reason:',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                const SizedBox(height: 12),
                ...reasons.map((r) => GestureDetector(
                  onTap: () => setDialogState(() => selectedReason = r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedReason == r
                          ? Colors.red.withOpacity(0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedReason == r ? Colors.red : Colors.grey.shade200,
                        width: selectedReason == r ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        selectedReason == r
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: selectedReason == r ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Text(r, style: TextStyle(
                        fontSize: 13,
                        color: selectedReason == r ? Colors.red : AppColors.textDark,
                        fontWeight: selectedReason == r ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ]),
                  ),
                )),
                // Text field untuk "Lain-lain"
                if (selectedReason == reasons.last) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: isMalay ? 'Nyatakan sebab...' : 'State your reason...',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textGrey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      final finalReason = selectedReason == reasons.last && reasonController.text.isNotEmpty
                          ? reasonController.text.trim()
                          : selectedReason!;
                      Navigator.pop(ctx, finalReason);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(isMalay ? 'Ya, Tarik Diri' : 'Yes, Withdraw',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (reason == null) return;

    setState(() => _isActionLoading = true);
    try {
      final helperUid = _currentUid!;

      String helperName = '';
      if (_bantuan.isMultipleSlot) {
        final idx = _bantuan.helperUids.indexOf(helperUid);
        if (idx != -1 && idx < _bantuan.helperNames.length) {
          helperName = _bantuan.helperNames[idx];
        }
      } else {
        helperName = _bantuan.helperName ?? '';
      }

      final result = await _bantuanService.helperWithdraw(
        postId: _bantuan.id,
        helperUid: helperUid,
        helperName: helperName,
        isMultiple: _bantuan.isMultipleSlot,
        isIndividual: !_isGroupCompletion,
        reason: reason,
      );

      if (result['success'] == true) {
        await _refreshBantuan();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isMalay
                ? '↩️ Anda telah tarik diri.'
                : '↩️ You have withdrawn.'),
            backgroundColor: Colors.grey.shade700,
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${result['message']}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _openFullMap(bool isMalay) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullMapViewScreen(
          lat: _bantuan.pinLat!,
          lon: _bantuan.pinLon!,
          title: _bantuan.title,
          address: _bantuan.pinAddress ?? '',
          isMalay: isMalay,
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMalay = context.watch<LanguageProvider>().isMalay;
    final bantuan = _bantuan;
    final isRequest = bantuan.type == 'request';
    final typeColor = isRequest ? Colors.orange : Colors.green;
    final typeLabel = isRequest
        ? (isMalay ? 'Minta Bantuan' : 'Request Help')
        : (isMalay ? 'Tawar Bantuan' : 'Offer Help');
    final statusColor = _statusColor(bantuan.status);
    final statusLabel = _statusLabel(bantuan.status, isMalay);
    final statusIcon = _statusIcon(bantuan.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
          body: RefreshIndicator(
          onRefresh: _refreshBantuan,
          child: CustomScrollView(
            slivers: [
          SliverAppBar(
            expandedHeight: bantuan.imageUrl != null ? 280 : 120,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.share,
                      color: Colors.white, size: 20),
                ),
                onPressed: () => _showShareSheet(isMalay),
              ),
              if (_isOwner)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.more_vert,
                        color: Colors.white, size: 20),
                  ),
                  onSelected: (val) {
                    if (val == 'delete') _deletePost(isMalay);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(isMalay ? 'Padam Post' : 'Delete Post',
                              style: const TextStyle(color: Colors.red)),
                        ])),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: bantuan.imageUrl != null
                  ? Image.network(bantuan.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildImagePlaceholder())
                  : _buildImagePlaceholder(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Type / Category / Status chips ─────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: typeColor.withOpacity(0.3)),
                      ),
                      child: Text(typeLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: typeColor)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${BantuanCategories.getCategoryIcon(bantuan.category)} ${BantuanCategories.getCategoryName(bantuan.category).split(' / ')[0]}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primaryBlue),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withOpacity(0.3)),
                      ),
                      child:
                          Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusLabel,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ]),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  Text(bantuan.title,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),

                  const SizedBox(height: 8),

                  Row(children: [
                    Icon(Icons.access_time,
                        size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text(
                        '${isMalay ? 'Dipost' : 'Posted'}: ${_timeAgo(bantuan.createdAt, isMalay)}',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textGrey)),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    Text(bantuan.area,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.primaryBlue)),
                  ]),

                  // ── SLOT PROGRESS BANNER (multiple offer) ──────────
                    if (bantuan.isMultipleSlot) ...[
                    const SizedBox(height: 16),
                    _buildSlotProgressBanner(bantuan, isMalay),
                  ],

                  // ── In-progress banner (single only) ───────────────
                  if (bantuan.status == 'in_progress' &&
                      !bantuan.isMultipleSlot) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.handshake_outlined,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bantuan.type == 'offer'
                                    ? (isMalay
                                        ? 'Diminati oleh:'
                                        : 'Interested party:')
                                    : (isMalay
                                        ? 'Sedang dibantu oleh:'
                                        : 'Being helped by:'),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700),
                              ),
                              Text(
                                bantuan.helperName ?? 'Helper',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                        if (bantuan.helperConfirmed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isMalay
                                  ? '✅ Helper sahkan selesai'
                                  : '✅ Helper confirmed done',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.green),
                            ),
                          ),
                      ]),
                    ),
                  ],

                  // ── Unavailable banner ─────────────────────────────
                  if (bantuan.posterAvailability == 'unavailable') ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.withOpacity(0.4)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.do_not_disturb_on_outlined,
                              color: Colors.grey,
                              size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMalay
                                    ? '⚫ Poster sedang Tidak Available'
                                    : '⚫ Poster is currently Unavailable',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isMalay
                                    ? 'Cuba hubungi melalui chat untuk kepastian.'
                                    : 'Try contacting via chat to confirm.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Description card ───────────────────────────────
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(
                            isMalay ? 'Penerangan' : 'Description',
                            Icons.description_outlined),
                        const SizedBox(height: 10),
                        Text(bantuan.description,
                            style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textDark,
                                height: 1.6)),
                      ],
                    ),
                  ),

                  // ── Pin lokasi map card ────────────────────────────
                  if (bantuan.pinLat != null && bantuan.pinLon != null) ...[
                    const SizedBox(height: 16),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCardTitle(
                            isMalay ? 'Lokasi Tepat' : 'Exact Location',
                            Icons.pin_drop,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 200,
                              child: Stack(children: [
                                AbsorbPointer(
                                  child: FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(
                                          bantuan.pinLat!,
                                          bantuan.pinLon!),
                                      initialZoom: 16,
                                      interactionOptions:
                                          const InteractionOptions(
                                              flags:
                                                  InteractiveFlag.none),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.bantunow.app',
                                      ),
                                      MarkerLayer(markers: [
                                        Marker(
                                          point: LatLng(bantuan.pinLat!,
                                              bantuan.pinLon!),
                                          width: 50,
                                          height: 50,
                                          alignment: Alignment.topCenter,
                                          child: _buildPinMarker(),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  left: 10,
                                  right: 10,
                                  child: Row(children: [
                                    GestureDetector(
                                      onTap: () => _showNavigationSheet(
                                          context,
                                          bantuan.pinLat!,
                                          bantuan.pinLon!,
                                          bantuan.title,
                                          isMalay),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 7),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlue,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.18),
                                                blurRadius: 6)
                                          ],
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.navigation,
                                                  size: 13,
                                                  color: Colors.white),
                                              const SizedBox(width: 5),
                                              const Text('Navigate',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ]),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => _openFullMap(isMalay),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 7),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.12),
                                                blurRadius: 6)
                                          ],
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.open_in_full,
                                                  size: 13,
                                                  color:
                                                      AppColors.primaryBlue),
                                              const SizedBox(width: 5),
                                              Text(
                                                  isMalay
                                                      ? 'Buka Peta'
                                                      : 'Open Map',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .primaryBlue,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ]),
                                      ),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (bantuan.pinAddress != null &&
                              bantuan.pinAddress!.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on,
                                    size: 14, color: AppColors.textGrey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(bantuan.pinAddress!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textDark,
                                          height: 1.4)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showNavigationSheet(
                                  context,
                                  bantuan.pinLat!,
                                  bantuan.pinLon!,
                                  bantuan.title,
                                  isMalay),
                              icon: const Icon(Icons.navigation,
                                  color: Colors.white, size: 18),
                              label: Text(
                                isMalay
                                    ? 'Navigate ke Sini'
                                    : 'Navigate Here',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── User info card ─────────────────────────────────────────────
                  _buildUserInfoCard(bantuan, isMalay),

                  const SizedBox(height: 24),

                  // ── Share button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _showShareSheet(isMalay),
                      icon: Icon(Icons.share,
                          color: AppColors.primaryBlue, size: 18),
                      label: Text(
                          isMalay ? 'Kongsi Post' : 'Share Post',
                          style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Hubungi button (in-app chat) ───────────────────
                  if (!_isOwner)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isActionLoading
                            ? null
                            : () => _openChat(isMalay),
                        icon: const Icon(Icons.message_outlined,
                            color: Colors.white),
                        label: Text(
                            isMalay ? 'Hubungi' : 'Contact',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),

                  // ── Action buttons ─────────────────────────────────
                  ..._buildActionButtons(isMalay),

                  if (_isActionLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
        ), // CustomScrollView
      ), // RefreshIndicator
    ); // Scaffold
  }

  // ─── USER INFO CARD ──────────────────────────────────────────────
  // Owner tengok → tunjuk helper info
  // Orang lain tengok → tunjuk owner info

  Widget _buildUserInfoCard(BantuanModel bantuan, bool isMalay) {
    // CASE 1: Owner tengok, multiple slot, ada helpers
    if (_isOwner && bantuan.isMultipleSlot && bantuan.helperUids.isNotEmpty) {
      return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(
              isMalay ? 'Maklumat Helper' : 'Helper Info',
              Icons.people_alt_outlined,
            ),
            const SizedBox(height: 14),
            ...bantuan.helperUids.asMap().entries.map((entry) {
              final index = entry.key;
              final uid = entry.value;
              final name = index < bantuan.helperNames.length
                  ? bantuan.helperNames[index]
                  : 'Helper ${index + 1}';
              return Column(
                children: [
                  if (index > 0) const Divider(height: 20),
                  _buildSingleUserTile(uid: uid, name: name, isMalay: isMalay),
                ],
              );
            }),
          ],
        ),
      );
    }

    // CASE 2: Owner tengok, single slot, ada helper
    if (_isOwner &&
        !bantuan.isMultipleSlot &&
        bantuan.helperUid != null &&
        bantuan.helperUid!.isNotEmpty) {
      return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(
              isMalay ? 'Maklumat Helper' : 'Helper Info',
              Icons.person_outline,
            ),
            const SizedBox(height: 14),
            _buildSingleUserTile(
              uid: bantuan.helperUid!,
              name: bantuan.helperName ?? 'Helper',
              isMalay: isMalay,
            ),
          ],
        ),
      );
    }

    // CASE 3: Owner belum ada helper, atau orang lain tengok → tunjuk owner
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            isMalay ? 'Maklumat Pengguna' : 'User Info',
            Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _buildSingleUserTile(
            uid: bantuan.postedByUid,
            name: bantuan.postedBy,
            isMalay: isMalay,
            area: bantuan.area,
            showArea: true,
          ),
        ],
      ),
    );
  }

  // ─── SINGLE USER TILE ─────────────────────────────────────────────
  // Reusable tile — nama, rating, kawasan

  Widget _buildSingleUserTile({
    required String uid,
    required String name,
    required bool isMalay,
    String? area,
    bool showArea = false,
  }) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (ctx, snap) {
        final data = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : null;
        final avgRating = (data?['rating'] as num?)?.toDouble() ?? 0.0;
        final ratingCount = (data?['rating_count'] as num?)?.toInt() ?? 0;
        final userArea = data?['area_name'] as String? ??
            data?['area'] as String? ??
            area ?? '';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userUid: uid, userName: name),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.backgroundBlue,
                  backgroundImage: data?['photo_url'] != null
                      ? NetworkImage(data!['photo_url'] as String)
                      : null,
                  child: data?['photo_url'] == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      const SizedBox(height: 3),
                      ratingCount > 0
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 3),
                              Text(avgRating.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark)),
                              const SizedBox(width: 3),
                              Text(
                                  '($ratingCount ${isMalay ? 'ulasan' : 'reviews'})',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textGrey)),
                            ])
                          : Text(
                              isMalay ? 'Belum ada rating' : 'No rating yet',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ]),
              if (userArea.isNotEmpty || showArea) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.backgroundBlue,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.location_on,
                        size: 18, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isMalay ? 'Kawasan' : 'Location',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGrey)),
                      Text(
                        userArea.isNotEmpty
                            ? userArea
                            : (isMalay ? 'Tidak ditetapkan' : 'Not set'),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark),
                      ),
                    ],
                  ),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── ACTION BUTTONS ────────────────────────────────────────────────

  // ─── SLOT PROGRESS BANNER ─────────────────────────────────────────

  Widget _buildSlotProgressBanner(BantuanModel bantuan, bool isMalay) {
    final total = bantuan.totalSlots ?? 0;
    final accepted = bantuan.acceptedSlots;
    final remaining = bantuan.remainingSlots;
    final isFull = bantuan.status == 'full';
    final progress = total > 0 ? accepted / total : 0.0;
    final color = isFull ? Colors.purple : Colors.teal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.people_alt_outlined, size: 18, color: color),
            const SizedBox(width: 8),
              Text(
              isMalay ? 'Slot Bantuan' : 'Help Slots',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$accepted / $total',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ]),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isGroupCompletion
                  ? Colors.indigo.withOpacity(0.08)
                  : Colors.cyan.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _isGroupCompletion
                  ? (isMalay ? '👥 Serentak (datang sama-sama)' : '👥 Group (attend together)')
                  : (isMalay ? '👤 Satu-satu (berasingan)' : '👤 Individual (separately)'),
              style: TextStyle(
                fontSize: 11,
                color: _isGroupCompletion
                    ? Colors.indigo.shade600
                    : Colors.cyan.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isFull
                ? (isMalay
                    ? '🔴 Semua slot telah penuh'
                    : '🔴 All slots are full')
                : (isMalay
                    ? '🟢 $remaining slot lagi tersedia'
                    : '🟢 $remaining slot(s) remaining'),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    isFull ? Colors.red.shade700 : Colors.teal.shade700),
          ),
          if (_hasAlreadyJoined) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  isMalay
                      ? 'Anda telah mendaftar slot ini'
                      : 'You have joined this slot',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ─── HELPER STATUS LIST (visible to all joined helpers) ──────────

  Widget _buildHelperStatusList(bool isMalay) {
    final helpers = _bantuan.helperUids;
    if (helpers.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.groups_outlined, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 6),
            Text(
              isMalay ? 'Status Helper' : 'Helper Status',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey),
            ),
            const Spacer(),
            if (!_isGroupCompletion)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _bantuan.allHelpersConfirmed
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_bantuan.confirmedCount}/${helpers.length} ✅',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _bantuan.allHelpersConfirmed
                          ? Colors.green.shade700
                          : Colors.orange.shade700),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...helpers.asMap().entries.map((entry) {
            final index = entry.key;
            final uid = entry.value;
            final name = index < _bantuan.helperNames.length
                ? _bantuan.helperNames[index]
                : 'Helper ${index + 1}';
            final isMe = uid == _currentUid;
            final isDone = _isGroupCompletion
                ? false
                : _bantuan.helperConfirmations[uid] == true;
            final dotColor = _isGroupCompletion
                ? Colors.indigo
                : (isDone ? Colors.green : Colors.orange);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: dotColor.withOpacity(0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'H',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: dotColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(children: [
                    Text(
                      name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.textDark),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isMalay ? 'Saya' : 'Me',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ]),
                ),
                _isGroupCompletion
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isMalay ? '👥 Serentak' : '👥 Group',
                          style: TextStyle(
                              fontSize: 11, color: Colors.indigo.shade600),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: dotColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(isDone ? '✅' : '⏳',
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            isDone
                                ? (isMalay ? 'Selesai' : 'Done')
                                : (isMalay ? 'Belum' : 'Pending'),
                            style: TextStyle(
                                fontSize: 11,
                                color: dotColor,
                                fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ─── HELPER LIST CARD (owner, multiple slot) ──────────────────────
  // Tunjuk senarai helpers + status confirm setiap satu (✅/⏳) + butang reject
  // + butang "Tutup Post" di bawah

  Widget _buildHelperListCard(bool isMalay) {
    final confirmed = _bantuan.confirmedCount;
    final total = _bantuan.helperUids.length;
    final allDone = _isGroupCompletion ? true : _bantuan.allHelpersConfirmed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + progress count ──────────────────────
          Row(children: [
            Icon(Icons.people_alt_outlined,
                size: 16, color: Colors.purple.shade700),
            const SizedBox(width: 6),
            Text(
              isMalay ? 'Senarai Helper' : 'Helper List',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700),
            ),
            const Spacer(),
            // Badge: berapa dah confirm
          if (!_isGroupCompletion)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: allDone
                      ? Colors.green.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$confirmed/$total ✅',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: allDone
                          ? Colors.green.shade700
                          : Colors.orange.shade700),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total 👥',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade600),
                ),
              ),
          ]),

          const SizedBox(height: 12),

          // ── Senarai helper dengan status confirm ─────────────────
          ..._bantuan.helperUids.asMap().entries.map((entry) {
            final index = entry.key;
            final uid = entry.value;
            final name = index < _bantuan.helperNames.length
                ? _bantuan.helperNames[index]
                : 'Helper ${index + 1}';
            final hasConfirmed =
                _bantuan.helperConfirmations[uid] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: hasConfirmed
                      ? Colors.green.withOpacity(0.12)
                      : Colors.purple.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'H',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: hasConfirmed
                            ? Colors.green.shade700
                            : Colors.purple.shade700),
                  ),
                ),
                const SizedBox(width: 10),
                // Nama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      // Status badge ✅/⏳
                      if (!_isGroupCompletion)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            hasConfirmed ? '✅' : '⏳',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasConfirmed
                                ? (isMalay ? 'Selesai' : 'Done')
                                : (isMalay ? 'Belum selesai' : 'Pending'),
                            style: TextStyle(
                                fontSize: 11,
                                color: hasConfirmed
                                    ? Colors.green.shade600
                                    : Colors.orange.shade600),
                          ),
                        ])
                      else
                        Text(
                          isMalay ? '👥 Hadir serentak' : '👥 Group attendee',
                          style: TextStyle(
                              fontSize: 11, color: Colors.indigo.shade400),
                        ),
                    ],
                  ),
                ),
                // Butang reject
                GestureDetector(
                  onTap: _isActionLoading
                      ? null
                      : () => _ownerCancelHelper(isMalay, uid, name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_remove_outlined,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        isMalay ? 'Tolak' : 'Reject',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ),
              ]),
            );
          }),

          const Divider(height: 20),

          // ── Butang Tutup Post ─────────────────────────────────────
          // Hijau terang bila semua confirm, orange bila belum semua
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isActionLoading
                  ? null
                  : () => _ownerCloseMultiplePost(isMalay),
              icon: Icon(
                allDone ? Icons.task_alt : Icons.lock_outline,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isGroupCompletion
                    ? (isMalay ? '🎉 Semua Hadir — Tutup Post' : '🎉 All Attended — Close Post')
                    : (allDone
                        ? (isMalay ? '🎉 Tutup Post — Semua Selesai!' : '🎉 Close Post — All Done!')
                        : (isMalay ? 'Tutup Post' : 'Close Post')),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: allDone ? Colors.green : Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACTION BUTTONS ────────────────────────────────────────────────

  List<Widget> _buildActionButtons(bool isMalay) {
    final status = _bantuan.status;
    final isOffer = _bantuan.type == 'offer';
    final isMultiple = _bantuan.isMultipleSlot;
    final widgets = <Widget>[];

    if (_isOwner) {
      // ── OWNER ──────────────────────────────────────────────────────

      if (status == 'open' || status == 'full') {
        // Multiple: tunjuk helper list dengan status confirm + butang tutup post
        if (isMultiple && _bantuan.helperUids.isNotEmpty) {
          widgets.addAll([
            const SizedBox(height: 16),
            _buildHelperListCard(isMalay),
          ]);
        } else {
          // Tiada helper lagi — tunjuk delete je
          widgets.addAll([
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isActionLoading ? null : () => _deletePost(isMalay),
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
                label: Text(isMalay ? 'Padam Post' : 'Delete Post',
                    style:
                        const TextStyle(color: Colors.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]);
        }
      } else if (status == 'in_progress') {
        // Single in_progress
        widgets.add(const SizedBox(height: 12));

        if (_bantuan.helperConfirmed) {
          // Helper dah confirm — owner boleh complete
          widgets.add(
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _ownerConfirmComplete(isMalay),
                icon: const Icon(Icons.task_alt, color: Colors.white),
                label: Text(
                    isMalay
                        ? 'Selesai & Rate Helper'
                        : 'Complete & Rate Helper',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          );
        } else {
          // Tunggu helper confirm
          widgets.addAll([
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.hourglass_top,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMalay
                        ? 'Menunggu helper mengesahkan selesai...'
                        : 'Waiting for helper to confirm done...',
                    style: TextStyle(
                        fontSize: 13, color: Colors.orange.shade700),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            // Tukar Helper + Tolak Helper side by side
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _ownerCancelHelper(
                          isMalay,
                          _bantuan.helperUid ?? '',
                          _bantuan.helperName ?? '',
                        ),
                icon: const Icon(Icons.person_remove_outlined,
                    color: Colors.red, size: 16),
                label: Text(
                    isMalay ? 'Tolak & Tukar Helper' : 'Reject & Change Helper',
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]);
        }
      }
    } else {
      // ── NON-OWNER ──────────────────────────────────────────────────

        if (isMultiple) {
        // ── Multiple slot (offer & request) ──
            if (_hasAlreadyJoined) {
            if (_isGroupCompletion) {
              // Group: info banner + tarik diri je
                    widgets.addAll([
                    const SizedBox(height: 12),
                    _buildHelperStatusList(isMalay),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.groups_outlined, color: Colors.indigo, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMalay ? '👥 Anda terdaftar — mod serentak' : '👥 You\'re registered — group mode',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMalay
                                ? 'Hadir bersama peserta lain. Owner akan tutup post selepas semua selesai.'
                                : 'Attend together with other participants. Owner will close the post when all done.',
                            style: TextStyle(fontSize: 11, color: Colors.indigo.shade400, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isActionLoading ? null : () => _helperWithdraw(isMalay),
                    icon: const Icon(Icons.exit_to_app, color: Colors.red, size: 18),
                    label: Text(
                      isMalay ? 'Tarik Diri dari Slot' : 'Withdraw from Slot',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]);
          } else {
            // Belum confirm — tunjuk "Saya Dah Selesai" + "Tarik Diri"
                  widgets.addAll([
                  const SizedBox(height: 12),
                  _buildHelperStatusList(isMalay),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isActionLoading
                          ? null
                          : () => _helperConfirmDone(isMalay),
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white),
                  label: Text(
                      isMalay ? 'Saya Dah Selesai' : "I'm Done",
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () => _helperWithdraw(isMalay),
                  icon: const Icon(Icons.exit_to_app,
                      color: Colors.red, size: 18),
                  label: Text(
                      isMalay
                          ? 'Tarik Diri dari Slot'
                          : 'Withdraw from Slot',
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]);
          }
          } else if (status == 'open' &&
            _bantuan.hasAvailableSlot &&
            widget.isLoggedIn) {
          // Boleh join
          widgets.addAll([
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _isActionLoading ? null : () => _acceptHelp(isMalay),
                icon: Icon(
                    isOffer ? Icons.group_add : Icons.volunteer_activism,
                    color: Colors.white),
                label: Text(
                    isMalay
                        ? (isOffer ? 'Daftar Slot Ini' : 'Saya Nak Bantu')
                        : (isOffer ? 'Join This Slot' : 'I Want to Help'),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOffer ? Colors.purple : Colors.teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ]);
        } else if (status == 'full') {
          widgets.addAll([
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.people_alt,
                    color: Colors.purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMalay
                        ? 'Slot telah penuh. Hubungi poster melalui WhatsApp.'
                        : 'All slots are full. Contact poster via WhatsApp.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.purple.shade700),
                  ),
                ),
              ]),
            ),
          ]);
        }
      } else {
        // ── Single offer atau request ────────────────────────────
        if (status == 'open' && widget.isLoggedIn) {
          widgets.addAll([
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _isActionLoading ? null : () => _acceptHelp(isMalay),
                icon: Icon(
                  isOffer ? Icons.volunteer_activism : Icons.handshake,
                  color: Colors.white,
                ),
                label: Text(
                  isOffer
                      ? (isMalay ? 'Saya Berminat' : "I'm Interested")
                      : (isMalay ? 'Saya Nak Bantu' : 'I Want to Help'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isOffer ? AppColors.primaryBlue : Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ]);
        } else if (status == 'in_progress' && _isAssignedHelper) {
          if (!_bantuan.helperConfirmed) {
            widgets.addAll([
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () => _helperConfirmDone(isMalay),
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white),
                  label: Text(
                      isMalay ? 'Saya Dah Bantu' : "I've Helped",
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () => _helperWithdraw(isMalay),
                  icon: const Icon(Icons.exit_to_app,
                      color: Colors.red, size: 18),
                  label: Text(isMalay ? 'Tarik Diri' : 'Withdraw',
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]);
          } else {
            widgets.addAll([
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.hourglass_top,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMalay
                          ? 'Menunggu owner menutup post...'
                          : 'Waiting for owner to close...',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.green),
                    ),
                  ),
                ]),
              ),
            ]);
          }
        }
      }
    }

    return widgets;
  }

  // ─── Helper widgets ────────────────────────────────────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primaryBlue),
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey)),
    ]);
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.backgroundBlue,
      child: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined,
              size: 60,
              color: AppColors.primaryBlue.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text('Tiada Gambar',
              style: TextStyle(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  fontSize: 14)),
        ],
      )),
    );
  }

  Widget _buildPinMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child:
              const Icon(Icons.location_on, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: AppColors.primaryBlue),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dateTime, bool isMalay) {
    final diff = DateTime.now().difference(dateTime);
    if (isMalay) {
      if (diff.inMinutes < 60) return '${diff.inMinutes} minit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      return '${diff.inDays} hari lalu';
    } else {
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
  }
}

// ─── Full map view screen ──────────────────────────────────────────────────────

class _FullMapViewScreen extends StatelessWidget {
  final double lat;
  final double lon;
  final String title;
  final String address;
  final bool isMalay;

  const _FullMapViewScreen({
    required this.lat,
    required this.lon,
    required this.title,
    required this.address,
    required this.isMalay,
  });

  Future<void> _openGoogleMaps(BuildContext context) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWaze(BuildContext context) async {
    final uri =
        Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinLocation = LatLng(lat, lon);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: Text(isMalay ? 'Lokasi Tepat' : 'Exact Location',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _openGoogleMaps(context),
            icon: const Icon(Icons.navigation,
                color: Colors.white, size: 18),
            label: const Text('Navigate',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
              initialCenter: pinLocation, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bantunow.app',
            ),
            MarkerLayer(markers: [
              Marker(
                point: pinLocation,
                width: 60,
                height: 60,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.primaryBlue.withOpacity(0.4),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.location_on,
                          color: Colors.white, size: 22),
                    ),
                    CustomPaint(
                      size: const Size(14, 9),
                      painter:
                          _PinTailPainter(color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
            ]),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -2))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(address,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textDark,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openGoogleMaps(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF4285F4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF4285F4)
                                  .withOpacity(0.3)),
                        ),
                        child: const Column(children: [
                          Icon(Icons.map,
                              size: 26, color: Color(0xFF4285F4)),
                          SizedBox(height: 6),
                          Text('Google Maps',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4285F4))),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openWaze(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF05C8F7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF05C8F7)
                                  .withOpacity(0.3)),
                        ),
                        child: const Column(children: [
                          Icon(Icons.navigation,
                              size: 26, color: Color(0xFF05C8F7)),
                          SizedBox(height: 6),
                          Text('Waze',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF05C8F7))),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Pin tail painter ──────────────────────────────────────────────────────────

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}