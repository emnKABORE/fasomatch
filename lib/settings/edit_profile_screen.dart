import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/app_colors.dart';
import '../ui/app_logo.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditablePhoto {
  String? remoteUrl;
  XFile? file;
  Uint8List? webBytes;

  _EditablePhoto({
    this.remoteUrl,
    this.file,
    this.webBytes,
  });

  bool get hasContent {
    return (remoteUrl != null && remoteUrl!.trim().isNotEmpty) || file != null;
  }
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final _bioCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _selectedCity;
  String? _selectedLookingFor;

  final _photo1 = _EditablePhoto();
  final _photo2 = _EditablePhoto();
  final _photo3 = _EditablePhoto();

  static const List<String> burkinaCities = [
    "Arbinda",
    "Banfora",
    "Batié",
    "Bobo-Dioulasso",
    "Bogandé",
    "Boromo",
    "Dano",
    "Dédougou",
    "Diapaga",
    "Diébougou",
    "Djibo",
    "Dori",
    "Fada N'Gourma",
    "Gaoua",
    "Gorom-Gorom",
    "Gourcy",
    "Houndé",
    "Kantchari",
    "Kaya",
    "Kombissiri",
    "Kongoussi",
    "Koudougou",
    "Koupéla",
    "Léo",
    "Manga",
    "Nouna",
    "Orodara",
    "Ouagadougou",
    "Ouahigouya",
    "Pama",
    "Pô",
    "Pouytenga",
    "Réo",
    "Sapouy",
    "Sebba",
    "Solenzo",
    "Tenkodogo",
    "Tiao",
    "Titao",
    "Tougan",
    "Yako",
    "Ziniaré",
    "Zorgho",
  ];

  static const List<Map<String, String>> lookingForItems = [
    {'value': 'amour', 'label': '❤️ Amour'},
    {'value': 'amitie', 'label': '🤝 Amitié'},
    {'value': 'les_deux', 'label': '❤️🤝 Les deux'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _normalizeLookingFor(String raw) {
    final v = raw.trim().toLowerCase();

    if (v == 'amour' || v.contains('amour')) return 'amour';
    if (v == 'amitie' || v.contains('amitié') || v.contains('amitie')) {
      return 'amitie';
    }
    if (v == 'les_deux' || v.contains('les deux')) return 'les_deux';

    return raw;
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final row = await _supabase
          .from('profiles')
          .select('bio, city, looking_for, photos, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      _bioCtrl.text = (row?['bio'] ?? '').toString();
      _selectedCity = row?['city']?.toString();

      final rawLookingFor = (row?['looking_for'] ?? '').toString();
      _selectedLookingFor =
      rawLookingFor.isEmpty ? null : _normalizeLookingFor(rawLookingFor);

      final photos = row?['photos'];
      final avatarUrl = row?['avatar_url']?.toString();

      final parsedPhotos = <String>[];
      if (photos is List) {
        for (final p in photos) {
          final s = p.toString().trim();
          if (s.isNotEmpty) parsedPhotos.add(s);
        }
      }

      if (parsedPhotos.isNotEmpty) {
        _photo1.remoteUrl = parsedPhotos.length > 0 ? parsedPhotos[0] : null;
        _photo2.remoteUrl = parsedPhotos.length > 1 ? parsedPhotos[1] : null;
        _photo3.remoteUrl = parsedPhotos.length > 2 ? parsedPhotos[2] : null;
      } else if ((avatarUrl ?? '').trim().isNotEmpty) {
        _photo1.remoteUrl = avatarUrl!.trim();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible de charger le profil : $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<ImageSource?> _chooseSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Choisir une photo",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Ajoute ou remplace une photo de ton profil.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _sourceTile(
                icon: Icons.photo_camera_outlined,
                title: "Prendre une photo",
                subtitle: "Utiliser la caméra",
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _sourceTile(
                icon: Icons.photo_library_outlined,
                title: "Choisir depuis la galerie",
                subtitle: "Importer une image existante",
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto(_EditablePhoto slot) async {
    final source = await _chooseSource();
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked == null) return;

      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await picked.readAsBytes();
      }

      if (!mounted) return;
      setState(() {
        slot.file = picked;
        slot.webBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de choisir la photo : $e")),
      );
    }
  }

  Future<String?> _uploadIfNeeded({
    required String userId,
    required _EditablePhoto slot,
    required int index,
  }) async {
    if (slot.file == null) {
      final existing = slot.remoteUrl?.trim();
      return (existing == null || existing.isEmpty) ? null : existing;
    }

    final bytes = await slot.file!.readAsBytes();
    final ext = slot.file!.name.contains('.')
        ? slot.file!.name.split('.').last.toLowerCase()
        : 'jpg';

    final path =
        '$userId/profile_${index}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage.from('profile-photos').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    return _supabase.storage.from('profile-photos').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _saving = true);

      final photo1Url =
      await _uploadIfNeeded(userId: user.id, slot: _photo1, index: 1);
      final photo2Url =
      await _uploadIfNeeded(userId: user.id, slot: _photo2, index: 2);
      final photo3Url =
      await _uploadIfNeeded(userId: user.id, slot: _photo3, index: 3);

      final photos = <String>[
        if ((photo1Url ?? '').trim().isNotEmpty) photo1Url!.trim(),
        if ((photo2Url ?? '').trim().isNotEmpty) photo2Url!.trim(),
        if ((photo3Url ?? '').trim().isNotEmpty) photo3Url!.trim(),
      ];

      await _supabase.from('profiles').update({
        'bio': _bioCtrl.text.trim(),
        'city': _selectedCity,
        'looking_for': _selectedLookingFor,
        'photos': photos,
        'avatar_url': photos.isNotEmpty ? photos.first : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil mis à jour avec succès ✅"),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l’enregistrement : $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.92),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: Colors.black38,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.primaryBlue,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _sourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _photoCard({
    required String label,
    required _EditablePhoto slot,
    required VoidCallback onTap,
  }) {
    Widget content;

    if (slot.file != null) {
      if (kIsWeb && slot.webBytes != null) {
        content = Image.memory(
          slot.webBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        content = Image.file(
          File(slot.file!.path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    } else if ((slot.remoteUrl ?? '').trim().isNotEmpty) {
      content = Image.network(
        slot.remoteUrl!.trim(),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) {
          return Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              size: 28,
              color: Colors.black45,
            ),
          );
        },
      );
    } else {
      content = Container(
        color: Colors.white.withOpacity(0.92),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              size: 28,
              color: Colors.black54,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 110,
        height: 110,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F5FF);
    const blush = Color(0xFFFFE5E8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            const AppLogo(size: 75),
            const SizedBox(height: 2),
            const Text(
              "Modifier mon profil",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                fontSize: 20,
              ),
            ),
          ],
        ),
        toolbarHeight: 110,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Photos",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Ajoute ou remplace tes photos. La première photo sera utilisée comme photo principale.",
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              _photoCard(
                                label: "Photo 1",
                                slot: _photo1,
                                onTap: () => _pickPhoto(_photo1),
                              ),
                              _photoCard(
                                label: "Photo 2",
                                slot: _photo2,
                                onTap: () => _pickPhoto(_photo2),
                              ),
                              _photoCard(
                                label: "Photo 3",
                                slot: _photo3,
                                onTap: () => _pickPhoto(_photo3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _bioCtrl,
                            minLines: 4,
                            maxLines: 6,
                            decoration: _dec(
                              "Bio",
                              hint: "Parle un peu de toi...",
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedCity,
                            decoration: _dec("Ville"),
                            items: burkinaCities
                                .map(
                                  (city) => DropdownMenuItem(
                                value: city,
                                child: Text(
                                  city,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedCity = value);
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedLookingFor,
                            decoration: _dec("Je recherche"),
                            items: lookingForItems
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                value: item['value']!,
                                child: Text(
                                  item['label']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedLookingFor = value);
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Choix obligatoire";
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF111111),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          "Enregistrer",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: blush.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Text(
                        "Astuce : touche une photo pour la remplacer depuis la caméra ou la galerie.",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.08),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}