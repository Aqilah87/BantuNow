// lib/screens/profile/profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../location/select_location_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _userArea = '';
  int _requestCount = 0;
  int _offerCount = 0;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  File? _newProfileImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        FirebaseFirestore.instance.collection('bantuan').where('posted_by_uid', isEqualTo: user.uid).get(),
        SharedPreferences.getInstance(),
      ]);
      final doc = results[0] as DocumentSnapshot;
      final posts = results[1] as QuerySnapshot;
      final prefs = results[2] as SharedPreferences;
      int requests = 0, offers = 0;
      for (final p in posts.docs) {
        final type = (p.data() as Map<String, dynamic>)['type'] ?? '';
        if (type == 'request') requests++;
        if (type == 'offer') offers++;
      }
      setState(() {
        _userData = doc.data() as Map<String, dynamic>? ?? {};
        _userArea = prefs.getString('user_area_name') ?? '';
        _nameController.text = _userData['name'] ?? user.displayName ?? '';
        _phoneController.text = _userData['num_phone'] ?? '';
        _requestCount = requests;
        _offerCount = offers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String get _roleEmoji {
    if (_requestCount > 0 && _offerCount > 0) return '🤝';
    if (_offerCount > 0) return '🤲';
    if (_requestCount > 0) return '🙋';
    return '👤';
  }

  Color get _roleColor {
    if (_requestCount > 0 && _offerCount > 0) return Colors.purple;
    if (_offerCount > 0) return Colors.blue;
    if (_requestCount > 0) return Colors.orange;
    return Colors.grey;
  }

  Future<void> _pickProfileImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked != null) setState(() => _newProfileImage = File(picked.path));
  }

  Future<void> _saveProfile(bool isMalay) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      String? photoUrl = _userData['photo_url'];
      if (_newProfileImage != null) {
        final ref = FirebaseStorage.instance.ref().child('profiles/${user.uid}.jpg');
        await ref.putFile(_newProfileImage!);
        photoUrl = await ref.getDownloadURL();
        await user.updatePhotoURL(photoUrl);
      }
      await user.updateDisplayName(_nameController.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'num_phone': _phoneController.text.trim(),
        if (photoUrl != null) 'photo_url': photoUrl,
      });
      await _loadUserData();
      setState(() { _isEditing = false; _newProfileImage = null; _isSaving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay ? '✅ Profil berjaya dikemaskini!' : '✅ Profile updated successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isMalay ? 'Gagal kemaskini' : 'Update failed'}: $e'),
        ));
      }
    }
  }

  Future<void> _logout(bool isMalay) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isMalay ? 'Log Keluar?' : 'Logout?'),
        content: Text(isMalay ? 'Adakah anda pasti mahu log keluar?' : 'Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isMalay ? 'Batal' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isMalay ? 'Log Keluar' : 'Logout',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final isMalay = langProvider.isMalay;
    final user = FirebaseAuth.instance.currentUser;

    final roleLabel = _requestCount > 0 && _offerCount > 0
        ? 'Both'
        : _offerCount > 0
            ? 'Helper'
            : _requestCount > 0
                ? 'Requester'
                : (isMalay ? 'Ahli Baru' : 'New Member');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(isMalay ? 'Profil' : 'Profile',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: isMalay ? 'Tetapan' : 'Settings',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
              label: Text(isMalay ? 'Edit' : 'Edit', style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ] else ...[
            TextButton(
              onPressed: () => setState(() {
                _isEditing = false;
                _newProfileImage = null;
                _nameController.text = _userData['name'] ?? '';
                _phoneController.text = _userData['num_phone'] ?? '';
              }),
              child: Text(isMalay ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: _isSaving ? null : () => _saveProfile(isMalay),
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isMalay ? 'Simpan' : 'Save',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    color: AppColors.primaryBlue,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _isEditing ? _pickProfileImage : null,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                backgroundImage: _newProfileImage != null
                                    ? FileImage(_newProfileImage!)
                                    : (_userData['photo_url'] != null
                                        ? NetworkImage(_userData['photo_url'])
                                        : null) as ImageProvider?,
                                child: (_newProfileImage == null && _userData['photo_url'] == null)
                                    ? Text(
                                        (_userData['name'] ?? user?.email ?? 'U')[0].toUpperCase(),
                                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                      )
                                    : null,
                              ),
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0, right: 0,
                                child: GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: Icon(Icons.camera_alt, size: 18, color: AppColors.primaryBlue),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!_isEditing) ...[
                          Text(_userData['name'] ?? user?.displayName ?? 'User',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 12),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _roleColor.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_roleEmoji, style: const TextStyle(fontSize: 15)),
                                const SizedBox(width: 6),
                                Text(roleLabel,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatChip('$_requestCount', 'Request', Colors.orange),
                              const SizedBox(width: 12),
                              _buildStatChip('$_offerCount', 'Offer', Colors.blue),
                              const SizedBox(width: 12),
                              _buildStatChip('${_requestCount + _offerCount}',
                                  isMalay ? 'Jumlah' : 'Total', Colors.white),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text(isMalay ? 'Tekan gambar untuk tukar foto' : 'Tap image to change photo',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildCard(children: [
                          _isEditing
                              ? _buildEditField(
                                  icon: Icons.person_outline,
                                  label: isMalay ? 'Nama' : 'Name',
                                  controller: _nameController,
                                  hint: isMalay ? 'Masukkan nama anda' : 'Enter your name')
                              : _buildInfoRow(
                                  icon: Icons.person_outline,
                                  label: isMalay ? 'Nama' : 'Name',
                                  value: _userData['name'] ?? user?.displayName ?? (isMalay ? 'Tidak ditetapkan' : 'Not set')),
                          const Divider(height: 1),
                          _isEditing
                              ? _buildEditField(
                                  icon: Icons.phone_outlined,
                                  label: isMalay ? 'No. Telefon' : 'Phone Number',
                                  controller: _phoneController,
                                  hint: '0123456789',
                                  keyboardType: TextInputType.phone)
                              : _buildInfoRow(
                                  icon: Icons.phone_outlined,
                                  label: isMalay ? 'No. Telefon' : 'Phone Number',
                                  value: _userData['num_phone'] ?? (isMalay ? 'Tidak ditetapkan' : 'Not set')),
                          const Divider(height: 1),
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user?.email ?? (isMalay ? 'Tidak ditetapkan' : 'Not set'),
                          ),
                          const Divider(height: 1),
                          _buildInfoRow(
                            icon: Icons.location_on_outlined,
                            label: isMalay ? 'Kawasan' : 'Area',
                            value: _userArea.isEmpty ? (isMalay ? 'Belum ditetapkan' : 'Not set') : _userArea,
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('user_area_id');
                              await prefs.remove('user_area_name');
                              if (!mounted) return;
                              Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const SelectLocationScreen()))
                                  .then((_) => _loadUserData());
                            },
                            trailing: Icon(Icons.chevron_right, color: AppColors.textGrey),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        _buildCard(children: [
                          _buildActionRow(
                            icon: Icons.settings_outlined,
                            label: isMalay ? 'Tetapan' : 'Settings',
                            subtitle: isMalay ? 'Notifikasi, privasi, tentang app' : 'Notifications, privacy, about app',
                            color: AppColors.primaryBlue,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: () => _logout(isMalay),
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: Text(isMalay ? 'Log Keluar' : 'Logout',
                                style: const TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(count, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value, VoidCallback? onTap, Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.backgroundBlue, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: AppColors.primaryBlue),
      ),
      title: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
      subtitle: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      trailing: trailing,
    );
  }

  Widget _buildActionRow({required IconData icon, required String label, required String subtitle, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textGrey),
    );
  }

  Widget _buildEditField({required IconData icon, required String label, required TextEditingController controller, required String hint, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.backgroundBlue, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryBlue)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryBlue, width: 2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}