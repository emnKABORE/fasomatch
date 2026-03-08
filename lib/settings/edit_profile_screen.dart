import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _bioCtrl = TextEditingController();
  final _lookingForCtrl = TextEditingController();
  final _photo1Ctrl = TextEditingController();
  final _photo2Ctrl = TextEditingController();
  final _photo3Ctrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _selectedCity;

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final row = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      _bioCtrl.text = (row?['bio'] ?? '').toString();
      _lookingForCtrl.text = (row?['looking_for'] ?? '').toString();
      _selectedCity = row?['city']?.toString();

      final photos = row?['photos'];
      if (photos is List) {
        if (photos.isNotEmpty) _photo1Ctrl.text = photos[0].toString();
        if (photos.length > 1) _photo2Ctrl.text = photos[1].toString();
        if (photos.length > 2) _photo3Ctrl.text = photos[2].toString();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _photosToSave() {
    return [
      _photo1Ctrl.text.trim(),
      _photo2Ctrl.text.trim(),
      _photo3Ctrl.text.trim(),
    ].where((e) => e.isNotEmpty).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _saving = true);

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final photos = _photosToSave();

      await _supabase.from('profiles').update({
        'bio': _bioCtrl.text.trim(),
        'city': _selectedCity,
        'looking_for': _lookingForCtrl.text.trim(),
        'photos': photos,
        'avatar_url': photos.isNotEmpty ? photos.first : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
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
    _lookingForCtrl.dispose();
    _photo1Ctrl.dispose();
    _photo2Ctrl.dispose();
    _photo3Ctrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FF),
        title: const Text(
          "Modifier mon profil",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 4,
                  decoration: _dec("Bio"),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  items: burkinaCities
                      .map(
                        (city) => DropdownMenuItem(
                      value: city,
                      child: Text(city),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedCity = value);
                  },
                  decoration: _dec("Ville"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lookingForCtrl,
                  decoration: _dec("Recherche"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photo1Ctrl,
                  decoration: _dec("Photo 1 (URL)"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photo2Ctrl,
                  decoration: _dec("Photo 2 (URL)"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photo3Ctrl,
                  decoration: _dec("Photo 3 (URL)"),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Enregistrer",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.08),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}