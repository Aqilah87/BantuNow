// lib/screens/profile/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../../utils/app_strings.dart';
import '../../providers/language_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../location/select_location_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _logout(AppStrings s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.logoutTitle),
        content: Text(s.logoutConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(s.logout, style: const TextStyle(color: Colors.white)),
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

  Future<void> _sendPasswordReset(AppStrings s) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.passwordResetSent} ${user.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${s.error}: $e')));
      }
    }
  }

  void _showAboutDialog(AppStrings s) {
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
        Text(
          s.isMalay
              ? 'BantuNow adalah platform komuniti untuk menghubungkan mereka yang memerlukan bantuan dengan mereka yang sedia membantu di sekitar Kuala Terengganu.'
              : 'BantuNow is a community platform connecting those who need help with those who are ready to assist around Kuala Terengganu.',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  void _showTermsDialog(AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.termsConditions),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.isMalay ? '1. Penggunaan Aplikasi' : '1. App Usage',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.isMalay
                  ? 'Pengguna bertanggungjawab ke atas semua aktiviti yang dilakukan melalui akaun mereka.'
                  : 'Users are responsible for all activities performed through their accounts.'),
              const SizedBox(height: 12),
              Text(s.isMalay ? '2. Privasi' : '2. Privacy',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.isMalay
                  ? 'Maklumat peribadi anda akan disimpan dengan selamat dan tidak akan dikongsi kepada pihak ketiga tanpa kebenaran anda.'
                  : 'Your personal information will be stored securely and will not be shared with third parties without your consent.'),
              const SizedBox(height: 12),
              Text(s.isMalay ? '3. Kandungan' : '3. Content',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.isMalay
                  ? 'Pengguna dilarang memuat naik kandungan yang menyalahi undang-undang, berbahaya, atau mengelirukan.'
                  : 'Users are prohibited from uploading illegal, harmful, or misleading content.'),
              const SizedBox(height: 12),
              Text(s.isMalay ? '4. Penafian' : '4. Disclaimer',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.isMalay
                  ? 'BantuNow tidak bertanggungjawab ke atas sebarang pertikaian antara pengguna.'
                  : 'BantuNow is not responsible for any disputes between users.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue),
            child: Text(s.isMalay ? 'Faham' : 'Understood',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.privacyPolicy),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  s.isMalay
                      ? 'Maklumat yang Dikumpul'
                      : 'Information Collected',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.isMalay
                  ? 'Kami mengumpul nama, email, nombor telefon, dan lokasi kawasan anda untuk tujuan menyambungkan komuniti.'
                  : 'We collect your name, email, phone number, and area location for community connection purposes.'),
              const SizedBox(height: 12),
              Text(s.isMalay ? 'Penggunaan Maklumat' : 'Use of Information',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.isMalay
                  ? 'Maklumat anda digunakan untuk memaparkan profil dan post bantuan kepada pengguna lain dalam komuniti yang sama.'
                  : 'Your information is used to display your profile and help posts to other users in the same community.'),
              const SizedBox(height: 12),
              Text(s.isMalay ? 'Keselamatan Data' : 'Data Security',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.isMalay
                  ? 'Data anda disimpan dengan selamat menggunakan Firebase yang mematuhi piawaian keselamatan antarabangsa.'
                  : 'Your data is stored securely using Firebase which complies with international security standards.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue),
            child: Text(s.close, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFAQ(AppStrings s) {
    final faqs = s.isMalay
        ? [
            ['Macam mana nak post bantuan?', 'Tekan butang "+" di bawah, pilih jenis (minta atau tawar), isi maklumat dan tekan Post.'],
            ['Kenapa post saya tak keluar di peta?', 'Pastikan anda memilih kawasan semasa membuat post. Koordinat akan ditetapkan secara automatik.'],
            ['Bagaimana nak hubungi pemilik post?', 'Tekan butang WhatsApp pada halaman detail post. Anda akan dibawa terus ke WhatsApp.'],
            ['Boleh ke tukar kawasan saya?', 'Ya. Pergi ke Profil → Kawasan dan pilih kawasan baru.'],
            ['Apa itu role "Both"?', 'Role "Both" bermaksud anda pernah membuat post minta bantuan DAN post tawar bantuan.'],
            ['Bagaimana nak padam post?', 'Pergi ke "Post Saya" dan tekan ikon padam pada post berkenaan.'],
          ]
        : [
            ['How do I post help?', 'Tap the "+" button below, choose type (request or offer), fill in details and tap Post.'],
            ['Why is my post not showing on the map?', 'Make sure you select an area when posting. Coordinates will be assigned automatically.'],
            ['How do I contact the post owner?', 'Tap the WhatsApp button on the post detail page. You will be redirected to WhatsApp.'],
            ['Can I change my area?', 'Yes. Go to Profile → Area and select a new area.'],
            ['What is the "Both" role?', '"Both" role means you have made both a help request post AND a help offer post.'],
            ['How do I delete a post?', 'Go to "My Posts" and tap the delete icon on the relevant post.'],
          ];

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
                  Text(s.helpFAQ,
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
                  ...faqs.map((faq) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          title: Text(faq[0],
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark)),
                          iconColor: AppColors.primaryBlue,
                          collapsedIconColor: AppColors.primaryBlue,
                          children: [
                            Text(faq[1],
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textGrey)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final s = langProvider.strings;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.settingsTitle,
            style: const TextStyle(
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

                  // ── Language Toggle ───────────────────────────────────
                  _buildSectionLabel(s.language),
                  _buildCard(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.language,
                                size: 18, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.language.replaceAll('🌐 ', ''),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textDark)),
                                Text(s.languageDesc,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                          // ✅ Language toggle chips
                          Row(
                            children: [
                              _buildLangChip(
                                label: 'BM',
                                isSelected: langProvider.isMalay,
                                onTap: () => langProvider.setMalay(),
                              ),
                              const SizedBox(width: 8),
                              _buildLangChip(
                                label: 'EN',
                                isSelected: !langProvider.isMalay,
                                onTap: () => langProvider.setEnglish(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── Notification Settings ─────────────────────────────
                  _buildSectionLabel(s.notificationSettings),
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
                      title: Text(s.enableNotifications,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark)),
                      subtitle: Text(s.enableNotificationsDesc,
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
                      title: Text(s.newRequestAlert,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _notifEnabled
                                  ? AppColors.textDark
                                  : AppColors.textGrey)),
                      subtitle: Text(s.newRequestAlertDesc,
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
                      title: Text(s.matchFoundAlert,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _notifEnabled
                                  ? AppColors.textDark
                                  : AppColors.textGrey)),
                      subtitle: Text(s.matchFoundAlertDesc,
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
                  _buildSectionLabel(s.locationSettings),
                  _buildCard(children: [
                    _buildTile(
                      icon: Icons.edit_location_alt_outlined,
                      label: s.changeHomeArea,
                      subtitle: s.changeHomeAreaDesc,
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
                      label: s.locationPermission,
                      subtitle: s.locationPermissionDesc,
                      color: Colors.teal,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.locationPermissionMsg)),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── Privacy ───────────────────────────────────────────
                  _buildSectionLabel(s.privacySecurity),
                  _buildCard(children: [
                    _buildTile(
                      icon: Icons.privacy_tip_outlined,
                      label: s.privacyPolicy,
                      subtitle: s.privacyPolicyDesc,
                      color: Colors.indigo,
                      onTap: () => _showPrivacyDialog(s),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildTile(
                      icon: Icons.lock_reset,
                      label: s.changePassword,
                      subtitle: s.changePasswordDesc,
                      color: Colors.deepOrange,
                      onTap: () => _sendPasswordReset(s),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── About & Help ──────────────────────────────────────
                  _buildSectionLabel(s.aboutHelp),
                  _buildCard(children: [
                    _buildTile(
                      icon: Icons.help_outline,
                      label: s.helpFAQ,
                      subtitle: s.helpFAQDesc,
                      color: Colors.purple,
                      onTap: () => _showFAQ(s),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildTile(
                      icon: Icons.article_outlined,
                      label: s.termsConditions,
                      subtitle: s.termsConditionsDesc,
                      color: Colors.brown,
                      onTap: () => _showTermsDialog(s),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildTile(
                      icon: Icons.info_outline,
                      label: s.aboutApp,
                      subtitle: s.aboutAppDesc,
                      color: AppColors.primaryBlue,
                      onTap: () => _showAboutDialog(s),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── Logout ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () => _logout(s),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: Text(s.logout,
                          style: const TextStyle(
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

  Widget _buildLangChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textGrey)),
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