// lib/screens/profile/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../location/select_location_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ✅ Notification toggles (saved in SharedPreferences)
  bool _notifEnabled = true;
  bool _notifNewRequest = true;
  bool _notifMatchFound = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _notifNewRequest = prefs.getBool('notif_new_request') ?? true;
      _notifMatchFound = prefs.getBool('notif_match_found') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Keluar?'),
        content: const Text('Adakah anda pasti mahu log keluar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Keluar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _sendPasswordReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email reset dihantar ke ${user.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'BantuNow',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.volunteer_activism,
            color: Colors.white, size: 32),
      ),
      children: [
        const Text(
          'BantuNow adalah platform komuniti untuk menghubungkan '
          'mereka yang memerlukan bantuan dengan mereka yang sedia '
          'membantu di sekitar Kuala Terengganu.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terma & Syarat'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('1. Penggunaan Aplikasi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'Pengguna bertanggungjawab ke atas semua aktiviti yang dilakukan melalui akaun mereka.'),
              SizedBox(height: 12),
              Text('2. Privasi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'Maklumat peribadi anda akan disimpan dengan selamat dan tidak akan dikongsi kepada pihak ketiga tanpa kebenaran anda.'),
              SizedBox(height: 12),
              Text('3. Kandungan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'Pengguna dilarang memuat naik kandungan yang menyalahi undang-undang, berbahaya, atau mengelirukan.'),
              SizedBox(height: 12),
              Text('4. Penafian',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'BantuNow tidak bertanggungjawab ke atas sebarang pertikaian antara pengguna.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue),
            child: const Text('Faham', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Dasar Privasi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Maklumat yang Dikumpul',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'Kami mengumpul nama, email, nombor telefon, dan lokasi kawasan anda untuk tujuan menyambungkan komuniti.'),
              SizedBox(height: 12),
              Text('Penggunaan Maklumat',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'Maklumat anda digunakan untuk memaparkan profil dan post bantuan kepada pengguna lain dalam komuniti yang sama.'),
              SizedBox(height: 12),
              Text('Keselamatan Data',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'Data anda disimpan dengan selamat menggunakan Firebase yang mematuhi piawaian keselamatan antarabangsa.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue),
            child: const Text('Tutup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFAQ() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: AppColors.primaryBlue),
                  const SizedBox(width: 10),
                  Text('FAQ / Soalan Lazim',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildFAQItem(
                    'Macam mana nak post bantuan?',
                    'Tekan butang "+" di bawah, pilih jenis (minta atau tawar), isi maklumat dan tekan Post.',
                  ),
                  _buildFAQItem(
                    'Kenapa post saya tak keluar di peta?',
                    'Pastikan anda memilih kawasan semasa membuat post. Koordinat akan ditetapkan secara automatik.',
                  ),
                  _buildFAQItem(
                    'Bagaimana nak hubungi pemilik post?',
                    'Tekan butang WhatsApp pada halaman detail post. Anda akan dibawa terus ke WhatsApp.',
                  ),
                  _buildFAQItem(
                    'Boleh ke tukar kawasan saya?',
                    'Ya. Pergi ke Profil → Kawasan dan pilih kawasan baru.',
                  ),
                  _buildFAQItem(
                    'Apa itu role "Both"?',
                    'Role "Both" bermaksud anda pernah membuat post minta bantuan DAN post tawar bantuan.',
                  ),
                  _buildFAQItem(
                    'Bagaimana nak padam post?',
                    'Pergi ke "My Posts" dan tekan ikon padam pada post berkenaan.',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(question,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
        iconColor: AppColors.primaryBlue,
        collapsedIconColor: AppColors.primaryBlue,
        children: [
          Text(answer,
              style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tetapan / Settings',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Notification Settings ─────────────────────────────
                  _buildSectionLabel('🔔 Tetapan Notifikasi'),
                  _buildCard(children: [
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.notifications_outlined,
                            size: 18, color: AppColors.primaryBlue),
                      ),
                      title: Text('Aktifkan Notifikasi',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark)),
                      subtitle: Text('Hidupkan/matikan semua notifikasi',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGrey)),
                      value: _notifEnabled,
                      activeColor: AppColors.primaryBlue,
                      onChanged: (val) {
                        setState(() => _notifEnabled = val);
                        _savePref('notif_enabled', val);
                      },
                    ),
                    const Divider(height: 1, indent: 16),
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pan_tool,
                            size: 18, color: Colors.orange),
                      ),
                      title: Text('Alert Request Baru',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _notifEnabled
                                  ? AppColors.textDark
                                  : AppColors.textGrey)),
                      subtitle: Text('Notifikasi bila ada request baru',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGrey)),
                      value: _notifEnabled && _notifNewRequest,
                      activeColor: Colors.orange,
                      onChanged: _notifEnabled
                          ? (val) {
                              setState(() => _notifNewRequest = val);
                              _savePref('notif_new_request', val);
                            }
                          : null,
                    ),
                    const Divider(height: 1, indent: 16),
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.handshake_outlined,
                            size: 18, color: Colors.green),
                      ),
                      title: Text('Alert Match Dijumpai',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _notifEnabled
                                  ? AppColors.textDark
                                  : AppColors.textGrey)),
                      subtitle: Text('Notifikasi bila ada match untuk post anda',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGrey)),
                      value: _notifEnabled && _notifMatchFound,
                      activeColor: Colors.green,
                      onChanged: _notifEnabled
                          ? (val) {
                              setState(() => _notifMatchFound = val);
                              _savePref('notif_match_found', val);
                            }
                          : null,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── Location Settings ─────────────────────────────────
                  _buildSectionLabel('📍 Tetapan Lokasi'),
                  _buildCard(children: [
                    _buildTile(
                      icon: Icons.edit_location_alt_outlined,
                      label: 'Tukar Kawasan',
                      subtitle: 'Kemaskini kawasan rumah anda',
                      color: AppColors.primaryBlue,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('user_area_id');
                        await prefs.remove('user_area_name');
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SelectLocationScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildTile(
                      icon: Icons.gps_fixed,
                      label: 'Kebenaran Lokasi',
                      subtitle: 'Uruskan akses GPS peranti',
                      color: Colors.teal,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Pergi ke Tetapan Peranti → App → BantuNow → Kebenaran')),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── Privacy Settings ──────────────────────────────────
                  _buildSectionLabel('🔒 Privasi & Keselamatan'),
                  _buildCard(children: [
                    _buildTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Dasar Privasi',
                      subtitle: 'Cara kami melindungi data anda',
                      color: Colors.indigo,
                      onTap: _showPrivacyDialog,
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildTile(
                      icon: Icons.lock_reset,
                      label: 'Tukar Kata Laluan',
                      subtitle: 'Hantar email reset kata laluan',
                      color: Colors.deepOrange,
                      onTap: _sendPasswordReset,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── About & Help ──────────────────────────────────────
                  _buildSectionLabel('ℹ️ Tentang & Bantuan'),
                  _buildCard(children: [
                    _buildTile(
                      icon: Icons.help_outline,
                      label: 'Bantuan / FAQ',
                      subtitle: 'Soalan yang kerap ditanya',
                      color: Colors.purple,
                      onTap: _showFAQ,
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildTile(
                      icon: Icons.article_outlined,
                      label: 'Terma & Syarat',
                      subtitle: 'Syarat penggunaan BantuNow',
                      color: Colors.brown,
                      onTap: _showTermsDialog,
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildTile(
                      icon: Icons.info_outline,
                      label: 'Tentang BantuNow',
                      subtitle: 'Versi 1.0.0 — Community Assistance App',
                      color: AppColors.primaryBlue,
                      onTap: _showAboutDialog,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── Logout ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Log Keluar / Logout',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey)),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
      trailing:
          Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
    );
  }
}