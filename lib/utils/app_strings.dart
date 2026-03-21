// lib/utils/app_strings.dart

class AppStrings {
  final bool isMalay;
  const AppStrings({required this.isMalay});

  // ── General ──────────────────────────────────────────────────────────────
  String get appName => 'BantuNow';
  String get cancel => isMalay ? 'Batal' : 'Cancel';
  String get confirm => isMalay ? 'Sahkan' : 'Confirm';
  String get save => isMalay ? 'Simpan' : 'Save';
  String get edit => isMalay ? 'Edit' : 'Edit';
  String get delete => isMalay ? 'Padam' : 'Delete';
  String get close => isMalay ? 'Tutup' : 'Close';
  String get yes => isMalay ? 'Ya' : 'Yes';
  String get no => isMalay ? 'Tidak' : 'No';
  String get loading => isMalay ? 'Memuatkan...' : 'Loading...';
  String get error => isMalay ? 'Ralat' : 'Error';
  String get success => isMalay ? 'Berjaya' : 'Success';
  String get comingSoon => isMalay ? 'Akan datang' : 'Coming soon';
  String get noData => isMalay ? 'Tiada data' : 'No data';
  String get retry => isMalay ? 'Cuba lagi' : 'Retry';

  // ── Auth ─────────────────────────────────────────────────────────────────
  String get login => isMalay ? 'Log Masuk' : 'Login';
  String get logout => isMalay ? 'Log Keluar' : 'Logout';
  String get signup => isMalay ? 'Daftar' : 'Sign Up';
  String get email => isMalay ? 'E-mel' : 'Email';
  String get password => isMalay ? 'Kata Laluan' : 'Password';
  String get name => isMalay ? 'Nama' : 'Name';
  String get phone => isMalay ? 'No. Telefon' : 'Phone Number';
  String get forgotPassword => isMalay ? 'Lupa kata laluan?' : 'Forgot password?';
  String get loginWithGoogle => isMalay ? 'Log masuk dengan Google' : 'Login with Google';
  String get noAccount => isMalay ? 'Belum ada akaun? ' : 'No account? ';
  String get hasAccount => isMalay ? 'Dah ada akaun? ' : 'Already have account? ';
  String get loginRequired => isMalay ? 'Login Diperlukan' : 'Login Required';
  String get loginRequiredMsg => isMalay
      ? 'Anda perlu log masuk untuk meneruskan.\n\nLog masuk sekarang?'
      : 'You need to login to continue.\n\nLogin now?';
  String get logoutConfirm =>
      isMalay ? 'Adakah anda pasti mahu log keluar?' : 'Are you sure you want to logout?';
  String get logoutTitle => isMalay ? 'Log Keluar?' : 'Logout?';

  // ── Onboarding ───────────────────────────────────────────────────────────
  String get onboardingTitle1 => isMalay ? 'Selamat Datang ke BantuNow' : 'Welcome to BantuNow';
  String get onboardingDesc1 => isMalay
      ? 'Platform komuniti untuk membantu antara satu sama lain di Kuala Terengganu'
      : 'Community platform to help each other in Kuala Terengganu';
  String get onboardingTitle2 => isMalay ? 'Minta atau Tawar Bantuan' : 'Request or Offer Help';
  String get onboardingDesc2 => isMalay
      ? 'Post permintaan bantuan atau tawarkan pertolongan kepada jiran anda'
      : 'Post help requests or offer assistance to your neighbors';
  String get onboardingTitle3 => isMalay ? 'Hubungi Terus via WhatsApp' : 'Connect via WhatsApp';
  String get onboardingDesc3 => isMalay
      ? 'Hubungi terus dengan pemilik post melalui WhatsApp dengan mudah'
      : 'Connect directly with post owners through WhatsApp easily';
  String get next => isMalay ? 'Seterusnya' : 'Next';
  String get skip => isMalay ? 'Langkau' : 'Skip';
  String get getStarted => isMalay ? 'Mulakan' : 'Get Started';

  // ── Home ─────────────────────────────────────────────────────────────────
  String get welcome => isMalay ? 'Selamat Datang' : 'Welcome';
  String get assalamualaikum => isMalay ? 'Assalamualaikum! 👋' : 'Hello! 👋';
  String get searchHint => isMalay ? 'Cari bantuan...' : 'Search help...';
  String get allCategories => isMalay ? 'Semua Kategori' : 'All Categories';
  String get all => isMalay ? 'Semua' : 'All';
  String get requestHelp => isMalay ? '🙋 Minta Bantuan' : '🙋 Request Help';
  String get offerHelp => isMalay ? '🤲 Tawar Bantuan' : '🤲 Offer Help';
  String get changeArea => isMalay ? '(Tukar)' : '(Change)';
  String get noHelpFound => isMalay ? 'Tiada bantuan dijumpai' : 'No help found';
  String get postFirst => isMalay ? 'Post Bantuan Pertama' : 'Post First Help';
  String get viewDetails => isMalay ? 'Lihat Details' : 'View Details';
  String get noImage => isMalay ? 'Tiada Gambar' : 'No Image';
  String get mapBantuan => isMalay ? 'Peta Bantuan' : 'Help Map';
  String get clearFilter => isMalay ? 'Kosongkan Filter' : 'Clear Filter';

  // ── Category Filter ───────────────────────────────────────────────────────
  String get filterCategory => isMalay ? 'Filter Kategori' : 'Filter Category';
  String get clearAll => isMalay ? 'Kosongkan Semua' : 'Clear All';
  String get applyFilter => isMalay ? 'Guna Filter' : 'Apply Filter';
  String get showAllCategories => isMalay ? 'Papar Semua Kategori' : 'Show All Categories';
  String get selectedCount => isMalay ? 'dipilih' : 'selected';

  // ── Post Bantuan ──────────────────────────────────────────────────────────
  String get postBantuan => isMalay ? 'Post Bantuan' : 'Post Help';
  String get typeOfHelp => isMalay ? 'Jenis Bantuan' : 'Type of Help';
  String get iNeedHelp => isMalay ? 'Saya perlukan bantuan' : 'I need help';
  String get iCanHelp => isMalay ? 'Saya boleh bantu' : 'I can help';
  String get category => isMalay ? 'Kategori' : 'Category';
  String get title => isMalay ? 'Tajuk' : 'Title';
  String get titleHint =>
      isMalay ? 'Contoh: Perlukan tumpang ke hospital...' : 'Example: Need a ride to hospital...';
  String get description => isMalay ? 'Penerangan' : 'Description';
  String get descriptionHint =>
      isMalay ? 'Terangkan dengan lebih lanjut...' : 'Describe in more detail...';
  String get area => isMalay ? 'Kawasan' : 'Area';
  String get selectArea => isMalay ? 'Pilih kawasan anda' : 'Select your area';
  String get whatsappNumber => isMalay ? 'Nombor WhatsApp' : 'WhatsApp Number';
  String get whatsappHint => isMalay ? 'Contoh: 60123456789' : 'Example: 60123456789';
  String get image => isMalay ? 'Gambar' : 'Image';
  String get imageOptional =>
      isMalay ? 'Pilihan — tambah gambar untuk menarik perhatian' : 'Optional — add image to attract attention';
  String get addImage => isMalay ? 'Tekan untuk tambah gambar' : 'Tap to add image';
  String get cameraOrGallery => isMalay ? 'Kamera atau Galeri' : 'Camera or Gallery';
  String get camera => isMalay ? 'Kamera' : 'Camera';
  String get gallery => isMalay ? 'Galeri' : 'Gallery';
  String get removeImage => isMalay ? 'Buang Gambar' : 'Remove Image';
  String get locationAutoAssign =>
      isMalay ? 'Lokasi pin pada peta akan ditentukan berdasarkan kawasan yang dipilih.' : 'Map pin location will be set based on selected area.';
  String get postSuccess => isMalay ? '✅ Bantuan berjaya dipost!' : '✅ Help posted successfully!';
  String get titleRequired => isMalay ? 'Sila masukkan tajuk' : 'Please enter title';
  String get titleTooShort => isMalay ? 'Tajuk terlalu pendek (min 10 huruf)' : 'Title too short (min 10 chars)';
  String get descRequired => isMalay ? 'Sila masukkan penerangan' : 'Please enter description';
  String get descTooShort =>
      isMalay ? 'Penerangan terlalu pendek (min 20 huruf)' : 'Description too short (min 20 chars)';
  String get areaRequired => isMalay ? 'Sila pilih kawasan' : 'Please select area';
  String get whatsappRequired =>
      isMalay ? 'Sila masukkan nombor WhatsApp' : 'Please enter WhatsApp number';
  String get whatsappInvalid => isMalay ? 'Nombor tidak sah' : 'Invalid number';

  // ── Bantuan Detail ────────────────────────────────────────────────────────
  String get postedBy => isMalay ? 'Dipost oleh' : 'Posted by';
  String get contactViaWhatsapp =>
      isMalay ? 'Hubungi via WhatsApp' : 'Contact via WhatsApp';
  String get markComplete => isMalay ? 'Tandakan Selesai' : 'Mark as Complete';
  String get deletePost => isMalay ? 'Padam Post' : 'Delete Post';
  String get deleteConfirm =>
      isMalay ? 'Adakah anda pasti mahu memadam post ini?' : 'Are you sure you want to delete this post?';
  String get completeConfirm =>
      isMalay ? 'Tandakan post ini sebagai selesai?' : 'Mark this post as completed?';
  String get statusActive => isMalay ? 'Aktif' : 'Active';
  String get statusCompleted => isMalay ? 'Selesai' : 'Completed';
  String get loginToContact =>
      isMalay ? 'Login untuk hubungi' : 'Login to contact';
  String get phoneBlurred =>
      isMalay ? 'Log masuk untuk lihat nombor' : 'Login to view number';

  // ── My Posts ──────────────────────────────────────────────────────────────
  String get myPosts => isMalay ? 'Post Saya' : 'My Posts';
  String get totalPosts => isMalay ? 'Jumlah' : 'Total';
  String get activePosts => isMalay ? 'Aktif' : 'Active';
  String get completedPosts => isMalay ? 'Selesai' : 'Completed';
  String get noPostsYet => isMalay ? 'Belum ada post lagi' : 'No posts yet';
  String get createFirstPost =>
      isMalay ? 'Cipta post pertama anda!' : 'Create your first post!';
  String get editPost => isMalay ? 'Edit Post' : 'Edit Post';

  // ── Map ───────────────────────────────────────────────────────────────────
  String get searchPlaceOrHelp =>
      isMalay ? 'Cari tempat atau bantuan...' : 'Search place or help...';
  String get placeName => isMalay ? 'Nama Tempat' : 'Place Name';
  String get bantuNowPosts => isMalay ? 'Post BantuNow' : 'BantuNow Posts';
  String get noResultFound => isMalay ? 'Tiada hasil dijumpai' : 'No results found';
  String get loadingPosts => isMalay ? 'Memuatkan post...' : 'Loading posts...';
  String get posts => isMalay ? 'post' : 'posts';
  String get filterPost => isMalay ? 'Filter Post' : 'Filter Posts';
  String get useFilter => isMalay ? 'Guna Filter' : 'Apply Filter';
  String get reset => isMalay ? 'Reset' : 'Reset';
  String get type => isMalay ? 'Jenis' : 'Type';

  // ── Profile ───────────────────────────────────────────────────────────────
  String get profile => isMalay ? 'Profil' : 'Profile';
  String get editProfile => isMalay ? 'Edit Profil' : 'Edit Profile';
  String get tapToChangePhoto =>
      isMalay ? 'Tekan gambar untuk tukar foto' : 'Tap image to change photo';
  String get profileUpdated =>
      isMalay ? '✅ Profil berjaya dikemaskini!' : '✅ Profile updated successfully!';
  String get updateFailed => isMalay ? 'Gagal kemaskini' : 'Update failed';
  String get settings => isMalay ? 'Tetapan' : 'Settings';
  String get settingsSubtitle =>
      isMalay ? 'Notifikasi, privasi, tentang app' : 'Notifications, privacy, about app';
  String get roleBoth => isMalay ? 'Both' : 'Both';
  String get roleHelper => isMalay ? 'Helper' : 'Helper';
  String get roleRequester => isMalay ? 'Requester' : 'Requester';
  String get roleNew => isMalay ? 'New Member' : 'New Member';

  // ── Settings ──────────────────────────────────────────────────────────────
  String get settingsTitle => isMalay ? 'Tetapan / Settings' : 'Settings';
  String get notificationSettings =>
      isMalay ? '🔔 Tetapan Notifikasi' : '🔔 Notification Settings';
  String get enableNotifications =>
      isMalay ? 'Aktifkan Notifikasi' : 'Enable Notifications';
  String get enableNotificationsDesc =>
      isMalay ? 'Hidupkan/matikan semua notifikasi' : 'Turn on/off all notifications';
  String get newRequestAlert => isMalay ? 'Alert Request Baru' : 'New Request Alert';
  String get newRequestAlertDesc =>
      isMalay ? 'Notifikasi bila ada request baru' : 'Notification when new request posted';
  String get matchFoundAlert => isMalay ? 'Alert Match Dijumpai' : 'Match Found Alert';
  String get matchFoundAlertDesc =>
      isMalay ? 'Notifikasi bila ada match untuk post anda' : 'Notification when match found for your post';
  String get locationSettings =>
      isMalay ? '📍 Tetapan Lokasi' : '📍 Location Settings';
  String get changeHomeArea => isMalay ? 'Tukar Kawasan' : 'Change Area';
  String get changeHomeAreaDesc =>
      isMalay ? 'Kemaskini kawasan rumah anda' : 'Update your home area';
  String get locationPermission =>
      isMalay ? 'Kebenaran Lokasi' : 'Location Permission';
  String get locationPermissionDesc =>
      isMalay ? 'Uruskan akses GPS peranti' : 'Manage device GPS access';
  String get locationPermissionMsg =>
      isMalay ? 'Pergi ke Tetapan Peranti → App → BantuNow → Kebenaran' : 'Go to Device Settings → App → BantuNow → Permissions';
  String get privacySecurity =>
      isMalay ? '🔒 Privasi & Keselamatan' : '🔒 Privacy & Security';
  String get privacyPolicy => isMalay ? 'Dasar Privasi' : 'Privacy Policy';
  String get privacyPolicyDesc =>
      isMalay ? 'Cara kami melindungi data anda' : 'How we protect your data';
  String get changePassword => isMalay ? 'Tukar Kata Laluan' : 'Change Password';
  String get changePasswordDesc =>
      isMalay ? 'Hantar email reset kata laluan' : 'Send password reset email';
  String get passwordResetSent =>
      isMalay ? 'Email reset dihantar ke' : 'Reset email sent to';
  String get aboutHelp => isMalay ? 'ℹ️ Tentang & Bantuan' : 'ℹ️ About & Help';
  String get helpFAQ => isMalay ? 'Bantuan / FAQ' : 'Help / FAQ';
  String get helpFAQDesc =>
      isMalay ? 'Soalan yang kerap ditanya' : 'Frequently asked questions';
  String get termsConditions => isMalay ? 'Terma & Syarat' : 'Terms & Conditions';
  String get termsConditionsDesc =>
      isMalay ? 'Syarat penggunaan BantuNow' : 'BantuNow terms of use';
  String get aboutApp => isMalay ? 'Tentang BantuNow' : 'About BantuNow';
  String get aboutAppDesc =>
      isMalay ? 'Versi 1.0.0 — Community Assistance App' : 'Version 1.0.0 — Community Assistance App';
  String get language => isMalay ? '🌐 Bahasa / Language' : '🌐 Language / Bahasa';
  String get languageDesc =>
      isMalay ? 'Tukar bahasa paparan' : 'Change display language';
  String get malay => isMalay ? 'Bahasa Melayu' : 'Malay';
  String get english => isMalay ? 'Inggeris' : 'English';

  // ── Select Location ───────────────────────────────────────────────────────
  String get selectLocation => isMalay ? 'Pilih Lokasi' : 'Select Location';
  String get chooseArea => isMalay ? 'Pilih Kawasan Anda' : 'Choose Your Area';
  String get chooseAreaDesc =>
      isMalay ? 'Pilih kawasan anda di Kuala Terengganu untuk cari bantuan berdekatan' : 'Select your area in Kuala Terengganu to find nearby help';
  String get searchArea => isMalay ? 'Cari kawasan...' : 'Search area...';
  String get noAreaFound => isMalay ? 'Tiada kawasan dijumpai' : 'No area found';
  String get confirmLocation => isMalay ? 'Sahkan Lokasi' : 'Confirm Location';
  String get selectAreaFirst => isMalay ? 'Sila pilih kawasan anda' : 'Please select your area';
  String get mainTown => isMalay ? 'Bandar Utama' : 'Main Town';
  String get mukim => isMalay ? 'Mukim' : 'Mukim';
  String get areaLabel => isMalay ? 'Kawasan' : 'Area';

  // ── Time ─────────────────────────────────────────────────────────────────
  String timeAgo(Duration diff) {
    if (isMalay) {
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      return '${diff.inDays}h lalu';
    } else {
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
  }
}