// lib/screens/bantuan/post_bantuan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../models/bantuan_model.dart';
import '../../models/location_model.dart';
import '../../services/bantuan_service.dart';
import '../map/map_picker_screen.dart';

class PostBantuanScreen extends StatefulWidget {
  final BantuanModel? existingPost;
  const PostBantuanScreen({Key? key, this.existingPost}) : super(key: key);

  @override
  State<PostBantuanScreen> createState() => _PostBantuanScreenState();
}

class _PostBantuanScreenState extends State<PostBantuanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _slotsController = TextEditingController(text: '10');
  final _bantuanService = BantuanService();
  final _imagePicker = ImagePicker();

  String _selectedType = 'request';
  String _selectedCategory = 'makanan';
  String _selectedAreaId = '';
  String _selectedAreaName = '';
  bool _isLoading = false;
  bool _isLoadingPhone = true;
  File? _selectedImage;
  String? _existingImageUrl;
  bool _removeExistingImage = false;

  // ── Pin lokasi tepat ───────────────────────────────────────────────
  double? _pinLat;
  double? _pinLon;
  String _pinAddress = '';

  // ── Slot system ────────────────────────────────────────────────────
  // 'single' = Satu Orang | 'multiple' = Ramai Orang (Ada Slot)
  String _offerType = 'single';
  // Track sama ada user dah manually override atau masih ikut auto-set
  bool _userOverrideOfferType = false;

  bool get _isEditMode => widget.existingPost != null;
  bool get _hasPinLocation => _pinLat != null && _pinLon != null;
  // Slot section hanya relevan untuk type == 'offer'
  bool get _showSlotSection => _selectedType == 'offer';

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _prefillExistingData();
    } else {
      _loadUserData();
      // Set default offerType berdasarkan kategori default
      _offerType = BantuanCategories.getDefaultOfferType(_selectedCategory);
    }
  }

  void _prefillExistingData() {
    final post = widget.existingPost!;
    _titleController.text = post.title;
    _descController.text = post.description;
    _whatsappController.text = post.whatsapp ?? '';
    _selectedType = post.type;
    _selectedCategory = post.category;
    _selectedAreaId = post.areaId;
    _selectedAreaName = post.area;
    _existingImageUrl = post.imageUrl;
    _pinLat = post.pinLat;
    _pinLon = post.pinLon;
    _pinAddress = post.pinAddress ?? '';
    // Prefill slot data
    _offerType = post.offerType;
    if (post.totalSlots != null) {
      _slotsController.text = post.totalSlots.toString();
    }
    _userOverrideOfferType = true; // edit mode = treat as manual
    setState(() => _isLoadingPhone = false);
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAreaId = prefs.getString('user_area_id') ?? '';
      _selectedAreaName = prefs.getString('user_area_name') ?? '';
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final phone = doc.data()?['num_phone'] ?? '';
          setState(() => _whatsappController.text = _formatWhatsApp(phone));
        }
      }
    } catch (_) {} finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  // ── Auto-set offerType bila category bertukar ──────────────────────
  void _onCategoryChanged(String? newCat) {
    if (newCat == null) return;
    setState(() {
      _selectedCategory = newCat;
      // Hanya auto-set kalau user belum manually override
      if (!_userOverrideOfferType) {
        _offerType = BantuanCategories.getDefaultOfferType(newCat);
        // Reset slots ke default 10 bila auto-set ke multiple
        if (_offerType == 'multiple') {
          _slotsController.text = '10';
        }
      }
    });
  }

  // ── User manually tukar offerType ─────────────────────────────────
  void _onOfferTypeChanged(String newType) {
    setState(() {
      _offerType = newType;
      _userOverrideOfferType = true;
      if (newType == 'multiple' && _slotsController.text.isEmpty) {
        _slotsController.text = '10';
      }
    });
  }

  String _formatWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) cleaned = '6$cleaned';
    if (!cleaned.startsWith('60')) cleaned = '60$cleaned';
    return cleaned;
  }

  // ── Buka map picker ────────────────────────────────────────────────
  Future<void> _openMapPicker(bool isMalay) async {
    if (_selectedAreaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isMalay
            ? 'Sila pilih kawasan dahulu sebelum pin lokasi'
            : 'Please select area first before pinning location'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final areaData = KualaTerengganuAreas.getAreaById(_selectedAreaId);
    final initialLat = _pinLat ?? areaData?.latitude ?? 5.3296;
    final initialLon = _pinLon ?? areaData?.longitude ?? 103.1370;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: initialLat,
          initialLon: initialLon,
          areaName: _selectedAreaName,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _pinLat = result['lat'] as double;
        _pinLon = result['lon'] as double;
        _pinAddress = result['address'] as String? ?? '';
      });
    }
  }

  void _clearPin() {
    setState(() {
      _pinLat = null;
      _pinLon = null;
      _pinAddress = '';
    });
  }

  // ── Image picker ───────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source, bool isMalay) async {
    try {
      final picked = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 80);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _removeExistingImage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${isMalay ? 'Gagal pilih gambar' : 'Failed to pick image'}: $e'),
        ));
      }
    }
  }

  void _showImagePicker(bool isMalay) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isMalay ? 'Pilih Gambar' : 'Select Image',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildImageSourceOption(
                        icon: Icons.camera_alt,
                        label: isMalay ? 'Kamera' : 'Camera',
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.camera, isMalay);
                        })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildImageSourceOption(
                        icon: Icons.photo_library,
                        label: isMalay ? 'Galeri' : 'Gallery',
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.gallery, isMalay);
                        })),
              ],
            ),
            if (_selectedImage != null ||
                (_existingImageUrl != null && !_removeExistingImage)) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _removeExistingImage = true;
                  });
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(isMalay ? 'Buang Gambar' : 'Remove Image',
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
            color: AppColors.backgroundBlue,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, size: 32, color: AppColors.primaryBlue),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue)),
        ]),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────
  Future<void> _submit(bool isMalay) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isMalay ? 'Sila pilih kawasan' : 'Please select area')));
      return;
    }

    // Validate slot count kalau multiple
    int? totalSlots;
    if (_selectedType == 'offer' && _offerType == 'multiple') {
      final parsed = int.tryParse(_slotsController.text.trim());
      if (parsed == null || parsed < 2 || parsed > 100) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? 'Bilangan slot mesti antara 2 hingga 100'
              : 'Slot count must be between 2 and 100'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
      totalSlots = parsed;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl =
          await _bantuanService.uploadImage(_selectedImage!, user.uid);
    } else if (!_removeExistingImage) {
      imageUrl = _existingImageUrl;
    }

    final areaData = KualaTerengganuAreas.getAreaById(_selectedAreaId);

    String posterAvailability = 'available';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        posterAvailability =
            userDoc.data()?['availability_status'] ?? 'available';
      }
    } catch (_) {}

    // offerType hanya apply untuk type == 'offer'
    // Untuk 'request', kita simpan 'single' sebagai default
    final finalOfferType =
        _selectedType == 'offer' ? _offerType : 'single';
    final finalTotalSlots =
        _selectedType == 'offer' && _offerType == 'multiple'
            ? totalSlots
            : null;

    if (_isEditMode) {
      try {
        await FirebaseFirestore.instance
            .collection('bantuan')
            .doc(widget.existingPost!.id)
            .update({
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'category': _selectedCategory,
          'area': _selectedAreaName,
          'area_id': _selectedAreaId,
          'type': _selectedType,
          'whatsapp': _whatsappController.text.trim(),
          'image_url': imageUrl,
          'latitude': areaData?.latitude,
          'longitude': areaData?.longitude,
          'poster_availability': posterAvailability,
          'offer_type': finalOfferType,
          if (finalTotalSlots != null) 'total_slots': finalTotalSlots,
          if (finalTotalSlots == null) 'total_slots': FieldValue.delete(),
          if (_pinLat != null) 'pin_lat': _pinLat,
          if (_pinLon != null) 'pin_lon': _pinLon,
          if (_pinAddress.isNotEmpty) 'pin_address': _pinAddress,
          if (_pinLat == null) 'pin_lat': FieldValue.delete(),
          if (_pinLon == null) 'pin_lon': FieldValue.delete(),
          if (_pinAddress.isEmpty) 'pin_address': FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoading = false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? '✅ Post berjaya dikemaskini!'
              : '✅ Post updated successfully!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal kemaskini: $e'),
            backgroundColor: AppColors.error));
      }
    } else {
      final bantuan = BantuanModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        area: _selectedAreaName,
        areaId: _selectedAreaId,
        status: 'open',
        type: _selectedType,
        postedBy: user.displayName ?? user.email ?? 'User',
        postedByUid: user.uid,
        whatsapp: _whatsappController.text.trim(),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        latitude: areaData?.latitude,
        longitude: areaData?.longitude,
        pinLat: _pinLat,
        pinLon: _pinLon,
        pinAddress: _pinAddress.isNotEmpty ? _pinAddress : null,
        posterAvailability: posterAvailability,
        offerType: finalOfferType,
        totalSlots: finalTotalSlots,
        acceptedSlots: 0,
      );

      final result = await _bantuanService.addBantuan(bantuan);
      setState(() => _isLoading = false);
      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isMalay
              ? '✅ Bantuan berjaya dipost!'
              : '✅ Help posted successfully!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMalay = context.watch<LanguageProvider>().isMalay;
    final showExistingImage = _existingImageUrl != null &&
        !_removeExistingImage &&
        _selectedImage == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: Text(
          _isEditMode
              ? (isMalay ? 'Edit Post' : 'Edit Post')
              : (isMalay ? 'Post Bantuan' : 'Post Help'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Jenis Bantuan ──────────────────────────────────────
              _buildSectionLabel(
                  isMalay ? 'Jenis Bantuan' : 'Type of Help',
                  Icons.category),
              const SizedBox(height: 10),
              Row(children: [
                _buildTypeChip(
                  label: isMalay ? '🙋 Minta Bantuan' : '🙋 Request Help',
                  subtitle:
                      isMalay ? 'Saya perlukan bantuan' : 'I need help',
                  value: 'request',
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _buildTypeChip(
                  label: isMalay ? '🤲 Tawar Bantuan' : '🤲 Offer Help',
                  subtitle: isMalay ? 'Saya boleh bantu' : 'I can help',
                  value: 'offer',
                  color: Colors.green,
                ),
              ]),

              const SizedBox(height: 24),

              // ── Gambar ─────────────────────────────────────────────
              _buildSectionLabel(
                  isMalay ? 'Gambar' : 'Image', Icons.image_outlined),
              const SizedBox(height: 4),
              Text(
                isMalay
                    ? 'Pilihan — tambah gambar untuk menarik perhatian'
                    : 'Optional — add image to attract attention',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showImagePicker(isMalay),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: (_selectedImage != null || showExistingImage)
                            ? AppColors.primaryBlue
                            : AppColors.lightGrey,
                        width:
                            (_selectedImage != null || showExistingImage)
                                ? 2
                                : 1),
                  ),
                  child: _selectedImage != null
                      ? Stack(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(_selectedImage!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover)),
                          Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedImage = null),
                                child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16)),
                              )),
                        ])
                      : showExistingImage
                          ? Stack(children: [
                              ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(11),
                                  child: Image.network(_existingImageUrl!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover)),
                              Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _removeExistingImage = true),
                                    child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.close,
                                            color: Colors.white,
                                            size: 16)),
                                  )),
                            ])
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: AppColors.primaryBlue
                                        .withOpacity(0.5)),
                                const SizedBox(height: 8),
                                Text(
                                    isMalay
                                        ? 'Tekan untuk tambah gambar'
                                        : 'Tap to add image',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textGrey)),
                                const SizedBox(height: 4),
                                Text(
                                    isMalay
                                        ? 'Kamera atau Galeri'
                                        : 'Camera or Gallery',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey
                                            .withOpacity(0.7))),
                              ]),
                ),
              ),

              const SizedBox(height: 24),

              // ── Kategori ───────────────────────────────────────────
              _buildSectionLabel(
                  isMalay ? 'Kategori' : 'Category',
                  Icons.label_outline),
              const SizedBox(height: 10),
              _buildDropdownField(
                value: _selectedCategory,
                items: BantuanCategories.categories
                    .map((c) => DropdownMenuItem<String>(
                          value: c['id'],
                          child: Row(children: [
                            Text(c['icon']!,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Text(c['name']!,
                                style: const TextStyle(fontSize: 14)),
                          ]),
                        ))
                    .toList(),
                onChanged: _onCategoryChanged,
              ),

              // ── SLOT SECTION (hanya untuk Offer) ───────────────────
              if (_showSlotSection) ...[
                const SizedBox(height: 24),
                _buildSlotSection(isMalay),
              ],

              const SizedBox(height: 24),

              // ── Tajuk ──────────────────────────────────────────────
              _buildSectionLabel(
                  isMalay ? 'Tajuk' : 'Title', Icons.title),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _titleController,
                hint: isMalay
                    ? 'Contoh: Perlukan tumpang ke hospital...'
                    : 'Example: Need a ride to hospital...',
                maxLines: 1,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return isMalay
                        ? 'Sila masukkan tajuk'
                        : 'Please enter title';
                  if (val.length < 10)
                    return isMalay
                        ? 'Tajuk terlalu pendek (min 10 huruf)'
                        : 'Title too short (min 10 chars)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Penerangan ─────────────────────────────────────────
              _buildSectionLabel(
                  isMalay ? 'Penerangan' : 'Description',
                  Icons.description_outlined),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _descController,
                hint: isMalay
                    ? 'Terangkan dengan lebih lanjut...'
                    : 'Describe in more detail...',
                maxLines: 5,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return isMalay
                        ? 'Sila masukkan penerangan'
                        : 'Please enter description';
                  if (val.length < 20)
                    return isMalay
                        ? 'Penerangan terlalu pendek (min 20 huruf)'
                        : 'Description too short (min 20 chars)';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Kawasan ────────────────────────────────────────────
              _buildSectionLabel(
                  isMalay ? 'Kawasan' : 'Area',
                  Icons.location_on_outlined),
              const SizedBox(height: 10),
              _buildDropdownField(
                value:
                    _selectedAreaId.isEmpty ? null : _selectedAreaId,
                hint: isMalay
                    ? 'Pilih kawasan anda'
                    : 'Select your area',
                items: KualaTerengganuAreas.areas
                    .map((area) => DropdownMenuItem<String>(
                          value: area.id,
                          child: Text(area.name,
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAreaId = val;
                      _selectedAreaName =
                          KualaTerengganuAreas.getAreaName(val);
                      _pinLat = null;
                      _pinLon = null;
                      _pinAddress = '';
                    });
                  }
                },
              ),

              const SizedBox(height: 24),

              // ── PIN LOKASI TEPAT ───────────────────────────────────
              _buildSectionLabel(
                isMalay ? 'Pin Lokasi Tepat' : 'Exact Pin Location',
                Icons.pin_drop_outlined,
              ),
              const SizedBox(height: 4),
              Text(
                isMalay
                    ? 'Pilihan — pin lokasi tepat pada peta untuk memudahkan orang jumpa anda'
                    : 'Optional — pin your exact location on map so people can find you easier',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 10),

              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _hasPinLocation
                      ? AppColors.primaryBlue.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasPinLocation
                        ? AppColors.primaryBlue
                        : AppColors.lightGrey,
                    width: _hasPinLocation ? 2 : 1,
                  ),
                ),
                child: _hasPinLocation
                    ? _buildPinPreview(isMalay)
                    : _buildPinPlaceholder(isMalay),
              ),

              const SizedBox(height: 24),

              // ── WhatsApp ───────────────────────────────────────────
              _buildSectionLabel(
                  isMalay ? 'Nombor WhatsApp' : 'WhatsApp Number',
                  Icons.phone_outlined),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    isMalay
                        ? 'Nombor ini akan jadi butang WhatsApp untuk orang hubungi anda terus.'
                        : 'This number will be the WhatsApp button for people to contact you.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.green.shade700),
                  )),
                ]),
              ),
              const SizedBox(height: 10),
              _isLoadingPhone
                  ? Container(
                      height: 54,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.lightGrey)),
                      child: const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))),
                    )
                  : _buildTextField(
                      controller: _whatsappController,
                      hint: 'Contoh: 60123456789',
                      maxLines: 1,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return isMalay
                              ? 'Sila masukkan nombor WhatsApp'
                              : 'Please enter WhatsApp number';
                        if (val.length < 10)
                          return isMalay
                              ? 'Nombor tidak sah'
                              : 'Invalid number';
                        return null;
                      },
                    ),

              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : () => _submit(isMalay),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : Text(
                          _isEditMode
                              ? (isMalay ? 'Kemaskini Post' : 'Update Post')
                              : (isMalay ? 'Post Bantuan' : 'Post Help'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SLOT SECTION WIDGET ──────────────────────────────────────────────────

  Widget _buildSlotSection(bool isMalay) {
    final autoLabel = _userOverrideOfferType
        ? null
        : (isMalay ? 'Auto-set berdasarkan kategori' : 'Auto-set by category');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_alt_outlined,
                size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 6),
            Text(
              isMalay ? 'Jenis Tawaran' : 'Offer Type',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
            ),
            if (autoLabel != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  autoLabel,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // ── Toggle: Satu Orang vs Ramai Orang ─────────────────────────
        Row(children: [
          _buildOfferTypeChip(
            icon: Icons.person,
            label: isMalay ? 'Satu Orang' : 'One Person',
            value: 'single',
            isMalay: isMalay,
          ),
          const SizedBox(width: 12),
          _buildOfferTypeChip(
            icon: Icons.groups,
            label: isMalay ? 'Ramai Orang' : 'Multiple',
            sublabel: isMalay ? '(Ada Slot)' : '(Has Slots)',
            value: 'multiple',
            isMalay: isMalay,
          ),
        ]),

        // ── Input slot — hanya tunjuk kalau multiple ──────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _offerType == 'multiple'
              ? _buildSlotInput(isMalay)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildOfferTypeChip({
    required IconData icon,
    required String label,
    String? sublabel,
    required String value,
    required bool isMalay,
  }) {
    final isSelected = _offerType == value;
    final color = value == 'single' ? AppColors.primaryBlue : Colors.purple;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onOfferTypeChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.lightGrey,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 18,
                  color: isSelected ? color : AppColors.textGrey),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppColors.textDark),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? color : AppColors.textGrey),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 16, color: color),
          ]),
        ),
      ),
    );
  }

  Widget _buildSlotInput(bool isMalay) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.purple.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 15, color: Colors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMalay
                      ? 'Tetapkan berapa ramai yang boleh accept tawaran ini.'
                      : 'Set how many people can accept this offer.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.purple.shade700),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isMalay ? 'Bilangan Slot' : 'Number of Slots',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark),
              ),
              const Spacer(),
              // Stepper: kurang
              _buildStepperButton(
                icon: Icons.remove,
                onTap: () {
                  final current =
                      int.tryParse(_slotsController.text) ?? 10;
                  if (current > 2) {
                    _slotsController.text = (current - 1).toString();
                    setState(() {});
                  }
                },
              ),
              const SizedBox(width: 8),
              // Input field
              Container(
                width: 64,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.purple.withOpacity(0.4), width: 1.5),
                ),
                child: TextFormField(
                  controller: _slotsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              // Stepper: tambah
              _buildStepperButton(
                icon: Icons.add,
                onTap: () {
                  final current =
                      int.tryParse(_slotsController.text) ?? 10;
                  if (current < 100) {
                    _slotsController.text = (current + 1).toString();
                    setState(() {});
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            isMalay ? 'Min: 2  •  Max: 100' : 'Min: 2  •  Max: 100',
            style: TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 18, color: Colors.purple.shade700),
      ),
    );
  }

  // ─── Pin widgets ──────────────────────────────────────────────────────────

  Widget _buildPinPreview(bool isMalay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(10)),
          child: SizedBox(
            height: 180,
            child: Stack(children: [
              AbsorbPointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(_pinLat!, _pinLon!),
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bantunow.app',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(_pinLat!, _pinLon!),
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: _buildPinMarker(size: 32),
                      ),
                    ]),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _openMapPicker(isMalay),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6)
                      ],
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit,
                              size: 13, color: AppColors.primaryBlue),
                          const SizedBox(width: 4),
                          Text(
                            isMalay ? 'Tukar Pin' : 'Change Pin',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
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
                      '${_pinLat!.toStringAsFixed(6)}, '
                      '${_pinLon!.toStringAsFixed(6)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryBlue,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              if (_pinAddress.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _pinAddress,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDark,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _clearPin,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline,
                        size: 15, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      isMalay
                          ? 'Buang pin lokasi'
                          : 'Remove pin location',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinPlaceholder(bool isMalay) {
    return GestureDetector(
      onTap: () => _openMapPicker(isMalay),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_location_alt,
                size: 30, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMalay ? 'Tambah Pin Lokasi' : 'Add Pin Location',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 3),
                Text(
                  isMalay
                      ? 'Tekan untuk pin lokasi tepat pada peta'
                      : 'Tap to pin exact location on map',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textGrey),
        ]),
      ),
    );
  }

  Widget _buildPinMarker({double size = 36}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
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
          child: Icon(Icons.location_on,
              color: Colors.white, size: size * 0.55),
        ),
        CustomPaint(
          size: Size(size * 0.33, size * 0.22),
          painter: _PinTailPainter(color: AppColors.primaryBlue),
        ),
      ],
    );
  }

  // ─── Helper widgets ───────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primaryBlue),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark)),
    ]);
  }

  Widget _buildTypeChip({
    required String label,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedType = value;
          // Reset override supaya auto-set boleh apply semula
          if (!_isEditMode) _userOverrideOfferType = false;
          // Re-apply auto-set berdasarkan kategori semasa
          if (value == 'offer' && !_userOverrideOfferType) {
            _offerType =
                BantuanCategories.getDefaultOfferType(_selectedCategory);
          }
        }),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? color : AppColors.lightGrey,
                width: isSelected ? 2 : 1),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppColors.textDark)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textGrey)),
              ]),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey)),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: AppColors.textGrey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? hint,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: hint != null
              ? Text(hint,
                  style: TextStyle(color: AppColors.textGrey))
              : null,
          icon: Icon(Icons.keyboard_arrow_down,
              color: AppColors.primaryBlue),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _whatsappController.dispose();
    _slotsController.dispose();
    super.dispose();
  }
}

// ── Pin tail painter ───────────────────────────────────────────────────────
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
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