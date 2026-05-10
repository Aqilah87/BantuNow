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
import 'package:latlong2/latlong.dart' hide Path; // ← FIX: hide Path dari latlong2
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../models/bantuan_model.dart';
import '../../services/bantuan_service.dart';
import '../../services/deep_link_service.dart';
import '../../widgets/rating_dialog.dart';
import '../profile/user_profile_screen.dart';

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
  String _posterPhone = '';
  bool _isLoadingPhone = true;
  bool _isActionLoading = false;

  late BantuanModel _bantuan;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == _bantuan.postedByUid;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  bool get _isAssignedHelper =>
      _currentUid != null && _bantuan.helperUid == _currentUid;

  @override
  void initState() {
    super.initState();
    _bantuan = widget.bantuan;
    _loadPosterPhone();
    _bantuanService.checkAndAutoClose();
  }

  Future<void> _loadPosterPhone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_bantuan.postedByUid)
          .get();
      if (doc.exists) {
        setState(() => _posterPhone = doc.data()?['num_phone'] ?? '');
      }
    } catch (e) {
      setState(() => _posterPhone = _bantuan.whatsapp ?? '');
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  // ─── Status helpers ───────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
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
      default:
        return Icons.task_alt;
    }
  }

  // ─── Phone / WhatsApp ─────────────────────────────────────────────────────────

  String _formatPhoneDisplay(String phone) {
    if (phone.isEmpty) return '';
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('60') && cleaned.length >= 11) {
      return '0${cleaned.substring(2)}';
    }
    return phone;
  }

  String _formatWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) cleaned = '6$cleaned';
    if (!cleaned.startsWith('60')) cleaned = '60$cleaned';
    return cleaned;
  }

  Future<void> _openWhatsApp(bool isMalay) async {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired(
          isMalay ? 'menghubungi melalui WhatsApp' : 'contact via WhatsApp');
      return;
    }
    final phone = _bantuan.whatsapp ?? _posterPhone;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? 'Nombor WhatsApp tidak tersedia'
            : 'WhatsApp number not available'),
      ));
      return;
    }
    final formatted = _formatWhatsApp(phone);
    final message = Uri.encodeComponent(
        '${isMalay ? 'Salam' : 'Hello'}, ${isMalay ? 'saya berminat dengan post anda bertajuk' : 'I am interested in your post titled'} "${_bantuan.title}" ${isMalay ? 'di' : 'on'} BantuNow.');
    final url = Uri.parse('https://wa.me/$formatted?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? 'Tidak dapat membuka WhatsApp'
              : 'Cannot open WhatsApp'),
        ));
      }
    }
  }

  // ─── Navigation (Google Maps & Waze) ─────────────────────────────────────────

  /// Buka bottom sheet untuk pilih Google Maps atau Waze
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
            // Handle bar
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
              isMalay
                  ? 'Pilih aplikasi navigasi'
                  : 'Choose navigation app',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 24),

            // Butang Google Maps & Waze
            Row(
              children: [
                // Google Maps
                Expanded(
                  child: _buildNavOption(
                    svgAsset: null,
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
                // Waze
                Expanded(
                  child: _buildNavOption(
                    svgAsset: null,
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
    String? svgAsset,
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
            Text(
              label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: iconColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Buka Google Maps dengan koordinat
  Future<void> _openGoogleMaps(
      double lat, double lon, String label, bool isMalay) async {
    // goo.gl/maps URL — buka app Google Maps kalau ada, browser kalau tak ada
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? 'Tidak dapat membuka Google Maps'
              : 'Cannot open Google Maps'),
        ));
      }
    }
  }

  /// Buka Waze dengan koordinat
  Future<void> _openWaze(double lat, double lon, bool isMalay) async {
    final uri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isMalay ? 'Tidak dapat membuka Waze' : 'Cannot open Waze'),
        ));
      }
    }
  }

  // ─── Share ────────────────────────────────────────────────────────────────────

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
    final bantuan = _bantuan;
    final message =
        Uri.encodeComponent('🙌 *${bantuan.title}*\n📍 ${bantuan.area}\n\n$link');
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
                  style: TextStyle(fontSize: 11, color: AppColors.primaryBlue),
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

  // ─── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _acceptHelp(bool isMalay) async {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired(isMalay ? 'menawarkan bantuan' : 'offer help');
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    String helperName = user.displayName ?? '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) helperName = doc.data()?['name'] ?? helperName;
    } catch (_) {}

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Nak Bantu?' : 'Offer Help?'),
        content: Text(isMalay
            ? 'Anda akan ditandakan sebagai helper untuk post ini. Pastikan anda bersedia untuk membantu.'
            : 'You will be marked as the helper for this post. Make sure you are ready to help.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(isMalay ? 'Ya, Saya Bantu' : "Yes, I'll Help",
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
        'status': 'in_progress',
        'helper_uid': user.uid,
        'helper_name': helperName,
        'helper_confirmed': false,
      });

      final updated = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .get();
      if (mounted && updated.exists) {
        setState(
            () => _bantuan = BantuanModel.fromMap(updated.data()!, updated.id));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? '🤝 Anda telah menjadi helper!'
              : '🤝 You are now the helper!'),
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

  Future<void> _helperConfirmDone(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Dah Selesai Bantu?' : 'Done Helping?'),
        content: Text(isMalay
            ? 'Sahkan bahawa anda telah berjaya membantu. Owner akan dimaklumkan untuk mengesahkan.'
            : 'Confirm that you have successfully helped. The owner will be notified to confirm.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isMalay ? 'Ya, Dah Bantu' : 'Yes, Done',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final result = await _bantuanService.helperConfirm(_bantuan.id);
      if (result['success'] != true) throw result['message'];

      final updated = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .get();
      if (mounted && updated.exists) {
        setState(
            () => _bantuan = BantuanModel.fromMap(updated.data()!, updated.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }

    if (!mounted) return;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
            ? '✅ Post ditutup. Terima kasih kerana menggunakan BantuNow!'
            : '✅ Post closed. Thank you for using BantuNow!'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    }
  }

  Future<void> _deletePost(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Padam Post?' : 'Delete Post?'),
        content: Text(isMalay
            ? 'Adakah anda pasti mahu memadam post ini? Tindakan ini tidak boleh dibatalkan.'
            : 'Are you sure you want to delete this post? This action cannot be undone.'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${isMalay ? 'Gagal memadam' : 'Failed to delete'}: $e')));
    }
  }

  Future<void> _resetToOpen(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Tukar Helper?' : 'Change Helper?'),
        content: Text(isMalay
            ? 'Helper semasa akan dibuang dan post akan dibuka semula untuk helper lain. Tindakan ini tidak boleh dibatalkan.'
            : 'The current helper will be removed and the post will be reopened for others. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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

      final updated = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .get();
      if (mounted && updated.exists) {
        setState(
            () => _bantuan = BantuanModel.fromMap(updated.data()!, updated.id));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? '🔄 Post dibuka semula untuk helper lain.'
              : '🔄 Post reopened for other helpers.'),
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

  // ─── Open full map view ───────────────────────────────────────────────────────

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

  // ─── Build ────────────────────────────────────────────────────────────────────

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
      body: CustomScrollView(
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
                  child:
                      const Icon(Icons.share, color: Colors.white, size: 20),
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
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder())
                  : _buildImagePlaceholder(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Type / Category / Status chips ──────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: typeColor.withOpacity(0.3)),
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
                        border:
                            Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
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

                  // ── In-progress banner ──────────────────────────────────
                  if (bantuan.status == 'in_progress') ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
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
                                isMalay
                                    ? 'Sedang dibantu oleh:'
                                    : 'Currently being helped by:',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700),
                              ),
                              Text(
                                bantuan.helperName ??
                                    (isMalay ? 'Helper' : 'Helper'),
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

                  // ── Unavailable warning banner ──────────────────────────
                  if (bantuan.posterAvailability == 'unavailable') ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.4)),
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
                                    ? 'Poster mungkin lambat respon. Cuba WhatsApp untuk kepastian.'
                                    : 'Poster may respond slowly. Try WhatsApp to confirm.',
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

                  // ── Description card ────────────────────────────────────
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

                  // ── Pin lokasi map card ─────────────────────────────────
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

                          // Mini map preview
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 200,
                              child: Stack(children: [
                                AbsorbPointer(
                                  child: FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(
                                          bantuan.pinLat!, bantuan.pinLon!),
                                      initialZoom: 16,
                                      interactionOptions:
                                          const InteractionOptions(
                                        flags: InteractiveFlag.none,
                                      ),
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

                                // ── Overlay buttons (Navigate + Buka Peta) ──
                                Positioned(
                                  bottom: 10,
                                  left: 10,
                                  right: 10,
                                  child: Row(
                                    children: [
                                      // Navigate button
                                      GestureDetector(
                                        onTap: () => _showNavigationSheet(
                                            context,
                                            bantuan.pinLat!,
                                            bantuan.pinLon!,
                                            bantuan.title,
                                            isMalay),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
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
                                                Text(
                                                  isMalay
                                                      ? 'Navigate'
                                                      : 'Navigate',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ]),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Buka Peta button
                                      GestureDetector(
                                        onTap: () => _openFullMap(isMalay),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
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
                                                      color:
                                                          AppColors.primaryBlue,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Koordinat pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.gps_fixed,
                                    size: 11, color: AppColors.primaryBlue),
                                const SizedBox(width: 4),
                                Text(
                                  '${bantuan.pinLat!.toStringAsFixed(6)}, '
                                  '${bantuan.pinLon!.toStringAsFixed(6)}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primaryBlue,
                                      fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),

                          // Alamat
                          if (bantuan.pinAddress != null &&
                              bantuan.pinAddress!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on,
                                    size: 14, color: AppColors.textGrey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    bantuan.pinAddress!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textDark,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Navigate button bawah card ──────────────────
                          const SizedBox(height: 12),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── User info card ──────────────────────────────────────
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(
                            isMalay ? 'Maklumat Pengguna' : 'User Info',
                            Icons.person_outline),
                        const SizedBox(height: 14),
                        // ── Tappable profile row ──────────────────────
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userUid: bantuan.postedByUid,
                                userName: bantuan.postedBy,
                              ),
                            ),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.backgroundBlue,
                              child: Text(
                                bantuan.postedBy.isNotEmpty
                                    ? bantuan.postedBy[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(bantuan.postedBy,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark)),
                                    const SizedBox(height: 3),
                                    // ── Average rating inline ─────────
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(bantuan.postedByUid)
                                          .get(),
                                      builder: (ctx, snap) {
                                        if (!snap.hasData || !snap.data!.exists) {
                                          return Text(bantuan.area,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textGrey));
                                        }
                                        final data = snap.data!.data()
                                            as Map<String, dynamic>;
                                        final avg = (data['rating'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        final count =
                                            (data['rating_count'] as num?)
                                                    ?.toInt() ??
                                                0;
                                        return Row(children: [
                                          if (count > 0) ...[
                                            Icon(Icons.star_rounded,
                                                size: 14,
                                                color: Colors.amber),
                                            const SizedBox(width: 3),
                                            Text(
                                              avg.toStringAsFixed(1),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textDark),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '($count)',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textGrey),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: AppColors.textGrey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(bantuan.area,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textGrey)),
                                        ]);
                                      },
                                    ),
                                  ]),
                            ),
                            // Arrow hint
                            Icon(Icons.chevron_right,
                                color: AppColors.textGrey, size: 20),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.phone,
                                size: 18, color: Colors.green),
                          ),
                          const SizedBox(width: 12),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    isMalay
                                        ? 'Nombor Telefon'
                                        : 'Phone Number',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey)),
                                _isLoadingPhone
                                    ? const SizedBox(
                                        width: 80,
                                        height: 16,
                                        child: LinearProgressIndicator())
                                    : Text(
                                        widget.isLoggedIn
                                            ? (_formatPhoneDisplay(_posterPhone)
                                                    .isEmpty
                                                ? (isMalay
                                                    ? 'Tidak tersedia'
                                                    : 'Not available')
                                                : _formatPhoneDisplay(
                                                    _posterPhone))
                                            : '••••••••••',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: widget.isLoggedIn
                                                ? AppColors.textDark
                                                : AppColors.textGrey),
                                      ),
                              ]),
                          if (!widget.isLoggedIn) ...[
                            const Spacer(),
                            TextButton(
                              onPressed: () => widget.onLoginRequired(isMalay
                                  ? 'melihat nombor telefon'
                                  : 'view phone number'),
                              child: Text(
                                  isMalay
                                      ? 'Login untuk lihat'
                                      : 'Login to view',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primaryBlue)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 12),
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
                                        fontSize: 12,
                                        color: AppColors.textGrey)),
                                Text(bantuan.area,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark)),
                              ]),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Share button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _showShareSheet(isMalay),
                      icon: Icon(Icons.share,
                          color: AppColors.primaryBlue, size: 18),
                      label: Text(isMalay ? 'Kongsi Post' : 'Share Post',
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

                  // ── WhatsApp button ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isActionLoading
                          ? null
                          : () => _openWhatsApp(isMalay),
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: Text(
                          isMalay
                              ? 'Hubungi via WhatsApp'
                              : 'Contact via WhatsApp',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  // ── Action buttons ──────────────────────────────────────
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
      ),
    );
  }

  // ── Pin marker widget ──────────────────────────────────────────────────────
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
          child: const Icon(Icons.location_on, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: AppColors.primaryBlue),
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons(bool isMalay) {
    final status = _bantuan.status;
    final widgets = <Widget>[];

    if (_isOwner) {
      if (status == 'open') {
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
      } else if (status == 'in_progress') {
        widgets.addAll([
          const SizedBox(height: 12),
          if (_bantuan.helperConfirmed)
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
            )
          else
            Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                      style:
                          TextStyle(fontSize: 13, color: Colors.orange.shade700),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isActionLoading ? null : () => _resetToOpen(isMalay),
                  icon: const Icon(Icons.refresh,
                      color: Colors.orange, size: 18),
                  label: Text(isMalay ? 'Tukar Helper' : 'Change Helper',
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
        ]);
      }
    } else {
      if (status == 'open' && widget.isLoggedIn) {
        widgets.addAll([
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  _isActionLoading ? null : () => _acceptHelp(isMalay),
              icon: const Icon(Icons.handshake, color: Colors.white),
              label: Text(isMalay ? 'Saya Nak Bantu' : 'I Want to Help',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
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
                label: Text(isMalay ? 'Saya Dah Bantu' : "I've Helped",
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
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.hourglass_top,
                    color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMalay
                        ? 'Anda telah sahkan selesai. Menunggu owner menutup post...'
                        : 'You confirmed done. Waiting for owner to close...',
                    style: const TextStyle(fontSize: 13, color: Colors.green),
                  ),
                ),
              ]),
            ),
          ]);
        }
      }
    }

    return widgets;
  }

  // ─── Helper widgets ───────────────────────────────────────────────────────────

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
              size: 60, color: AppColors.primaryBlue.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text('Tiada Gambar',
              style: TextStyle(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  fontSize: 14)),
        ],
      )),
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

// ─── Full map view screen ─────────────────────────────────────────────────────

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
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? 'Tidak dapat membuka Google Maps'
              : 'Cannot open Google Maps'),
        ));
      }
    }
  }

  Future<void> _openWaze(BuildContext context) async {
    final uri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isMalay ? 'Tidak dapat membuka Waze' : 'Cannot open Waze'),
        ));
      }
    }
  }

  void _showNavigationSheet(BuildContext context) {
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
                // Google Maps
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openGoogleMaps(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF4285F4).withOpacity(0.3)),
                      ),
                      child: Column(children: [
                        const Icon(Icons.map,
                            size: 36, color: Color(0xFF4285F4)),
                        const SizedBox(height: 10),
                        Text(
                          'Google Maps',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4285F4)),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Waze
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openWaze(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF05C8F7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF05C8F7).withOpacity(0.3)),
                      ),
                      child: Column(children: [
                        const Icon(Icons.navigation,
                            size: 36, color: Color(0xFF05C8F7)),
                        const SizedBox(height: 10),
                        Text(
                          'Waze',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF05C8F7)),
                        ),
                      ]),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final pinLocation = LatLng(lat, lon);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: Text(
          isMalay ? 'Lokasi Tepat' : 'Exact Location',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // Navigate button dalam AppBar
        actions: [
          TextButton.icon(
            onPressed: () => _showNavigationSheet(context),
            icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
            label: Text(
              isMalay ? 'Navigate' : 'Navigate',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full interactive map
          FlutterMap(
            options: MapOptions(
              initialCenter: pinLocation,
              initialZoom: 16,
            ),
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
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.4),
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

          // Info + Navigate panel bawah
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
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed,
                            size: 11, color: AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryBlue,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
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

                  // ── Navigate buttons row ────────────────────────────
                  Row(children: [
                    // Google Maps
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openGoogleMaps(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4285F4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    const Color(0xFF4285F4).withOpacity(0.3)),
                          ),
                          child: Column(children: [
                            const Icon(Icons.map,
                                size: 26, color: Color(0xFF4285F4)),
                            const SizedBox(height: 6),
                            const Text('Google Maps',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4285F4))),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Waze
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openWaze(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFF05C8F7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    const Color(0xFF05C8F7).withOpacity(0.3)),
                          ),
                          child: Column(children: [
                            const Icon(Icons.navigation,
                                size: 26, color: Color(0xFF05C8F7)),
                            const SizedBox(height: 6),
                            const Text('Waze',
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
        ],
      ),
    );
  }
}

// ─── Pin tail painter ─────────────────────────────────────────────────────────
// FIX: import 'package:latlong2/latlong.dart' hide Path — elak conflict
// Guna ui.Path() yang explicit dari dart:ui

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