// lib/screens/bantuan/bantuan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../models/bantuan_model.dart';
import '../../services/bantuan_service.dart';
import '../../services/deep_link_service.dart';
import '../../widgets/rating_dialog.dart';

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

  // ✅ Live snapshot of bantuan so UI reflects real-time Firestore changes
  late BantuanModel _bantuan;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == _bantuan.postedByUid;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ✅ True if the current user is the assigned helper
  bool get _isAssignedHelper => _currentUid != null && _bantuan.helperUid == _currentUid;

  @override
  void initState() {
    super.initState();
    _bantuan = widget.bantuan;
    _loadPosterPhone();
    // ✅ Check auto-close setiap kali detail screen dibuka
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

  // ─── Status helpers ──────────────────────────────────────────────────────────

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

  // ─── Phone / WhatsApp ────────────────────────────────────────────────────────

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

  // ─── Share ───────────────────────────────────────────────────────────────────

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

  Widget _buildShareOption(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
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

  // ─── Actions ─────────────────────────────────────────────────────────────────

  /// Non-owner: "Saya Nak Bantu" — set status to in_progress, save helperUid
  Future<void> _acceptHelp(bool isMalay) async {
    if (!widget.isLoggedIn) {
      widget.onLoginRequired(
          isMalay ? 'menawarkan bantuan' : 'offer help');
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    // Fetch helper's display name from Firestore
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(isMalay ? 'Ya, Saya Bantu' : 'Yes, I\'ll Help',
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

      // Refresh local state
      final updated = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .get();
      if (mounted && updated.exists) {
        setState(() {
          _bantuan =
              BantuanModel.fromMap(updated.data()!, updated.id);
        });
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// Non-owner (assigned helper): "Saya Dah Bantu" — rate owner, set helperConfirmed
  Future<void> _helperConfirmDone(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isMalay ? 'Ya, Dah Bantu' : 'Yes, Done',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      // ✅ Guna service method — simpan helper_confirmed_at timestamp sekali
      final result = await _bantuanService.helperConfirm(_bantuan.id);
      if (result['success'] != true) throw result['message'];

      // Refresh local state
      final updated = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .get();
      if (mounted && updated.exists) {
        setState(() {
          _bantuan = BantuanModel.fromMap(updated.data()!, updated.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }

    if (!mounted) return;

    // ✅ Helper rates owner
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

  /// Owner: "Selesai & Rate Helper" — rate helper, close post
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

    // ✅ Owner rates helper first
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

    // Close the post
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isMalay ? 'Gagal memadam' : 'Failed to delete'}: $e')));
    }
  }

  /// Owner: "Tukar Helper" — reset post back to open, clear helper fields
  Future<void> _resetToOpen(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

      // Refresh local state
      final updated = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(_bantuan.id)
          .get();
      if (mounted && updated.exists) {
        setState(() {
          _bantuan = BantuanModel.fromMap(updated.data()!, updated.id);
        });
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

  // ─── Build ───────────────────────────────────────────────────────────────────

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
                  // ── Type / Category / Status chips ──────────────────────
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
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon,
                                size: 12, color: statusColor),
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
                  )),

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
                      Row(children: [
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
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bantuan.postedBy,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark)),
                              Text(bantuan.area,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textGrey)),
                            ]),
                      ]),
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
                                isMalay ? 'Login untuk lihat' : 'Login to view',
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
                              Text(
                                  isMalay ? 'Kawasan' : 'Location',
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
                  )),

                  const SizedBox(height: 24),

                  // ── Share button ────────────────────────────────────────
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

                  // ── Action buttons based on role & status ───────────────
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

  /// Returns the contextual action buttons based on who is viewing and the post status.
  List<Widget> _buildActionButtons(bool isMalay) {
    final status = _bantuan.status;
    final widgets = <Widget>[];

    if (_isOwner) {
      // ── Owner view ──────────────────────────────────────────────────────
      if (status == 'open') {
        // No helper yet — owner can delete
        widgets.addAll([
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isActionLoading ? null : () => _deletePost(isMalay),
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
        // Helper assigned — owner waits for helperConfirmed, then can close
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
            Column(
              children: [
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
                        style: TextStyle(
                            fontSize: 13, color: Colors.orange.shade700),
                      ),
                    ),
                  ]),
                ),
                // ✅ Reset to open — only when helper NOT yet confirmed
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _resetToOpen(isMalay),
                    icon: const Icon(Icons.refresh,
                        color: Colors.orange, size: 18),
                    label: Text(
                        isMalay ? 'Tukar Helper' : 'Change Helper',
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ]);
      }
    } else {
      // ── Non-owner view ──────────────────────────────────────────────────
      if (status == 'open' && widget.isLoggedIn) {
        // Anyone can offer to help
        widgets.addAll([
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isActionLoading ? null : () => _acceptHelp(isMalay),
              icon: const Icon(Icons.handshake, color: Colors.white),
              label: Text(
                  isMalay ? 'Saya Nak Bantu' : 'I Want to Help',
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
        // Only the assigned helper sees this
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
                    isMalay ? 'Saya Dah Bantu' : 'I\'ve Helped',
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
          // Helper already confirmed — waiting for owner
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
                        ? 'Anda telah sahkan selesai. Menunggu owner menutup post...'
                        : 'You confirmed done. Waiting for owner to close...',
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

    return widgets;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

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