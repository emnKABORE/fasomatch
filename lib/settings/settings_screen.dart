import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Adapte ces imports si besoin selon ton arborescence
import '../login_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'legal_notice_screen.dart';
import 'support_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String currentPlan;
  final VoidCallback onUpgradeTap;

  const SettingsScreen({
    super.key,
    required this.currentPlan,
    required this.onUpgradeTap,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _localAuth = LocalAuthentication();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _busy = false;

  String _plan = 'gratuit';
  bool _isActive = true;

  // ⚠️ Ces 2 champs sont les mêmes que ceux à utiliser à la 1ère connexion
  bool _biometricEnabled = false;
  String _biometricPreference = 'auto'; // auto | fingerprint | face

  String _displayName = 'Mon compte';
  String? _email;

  String _verificationStatus = 'non_verifie';
  String? _verificationDocumentType;
  String? _verificationDocumentUrl;

  String? _avatarUrl;
  List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _email = user.email;

      final row = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final metadata = user.userMetadata ?? {};

      setState(() {
        _displayName = (row?['first_name'] ??
            row?['name'] ??
            metadata['first_name'] ??
            metadata['name'] ??
            'Mon compte')
            .toString();

        _plan = (row?['plan'] ??
            row?['subscription_plan'] ??
            widget.currentPlan)
            .toString();

        _isActive = (row?['is_active'] as bool?) ?? true;

        // ✅ Liaison directe avec le choix fait à la 1ère connexion
        _biometricEnabled = (row?['biometric_enabled'] as bool?) ?? false;
        _biometricPreference =
            (row?['biometric_preference'] ?? 'auto').toString();

        _verificationStatus =
            (row?['verification_status'] ?? 'non_verifie').toString();
        _verificationDocumentType =
            row?['verification_document_type']?.toString();
        _verificationDocumentUrl = row?['verification_document_url']?.toString();

        _avatarUrl = row?['avatar_url']?.toString();
        _photos = _extractPhotos(row?['photos']);
      });
    } catch (e) {
      _snack("Impossible de charger les paramètres : $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _extractPhotos(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }
    return [];
  }

  String? get _mainPhoto {
    if (_photos.isNotEmpty && _photos.first.trim().isNotEmpty) {
      return _photos.first.trim();
    }
    if ((_avatarUrl ?? '').trim().isNotEmpty) {
      return _avatarUrl!.trim();
    }
    return null;
  }

  String _prettyPlan(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'free':
      case 'gratuit':
        return 'Gratuit';
      case 'premium':
        return 'Premium';
      case 'ultra':
      case 'ultra premium':
      case 'ultrapremium':
        return 'Ultra';
      default:
        return raw;
    }
  }

  String _biometricPreferenceLabel(String value) {
    switch (value) {
      case 'fingerprint':
        return 'Empreinte digitale';
      case 'face':
        return 'Reconnaissance faciale';
      default:
        return 'Automatique selon l’appareil';
    }
  }

  String _verificationLabel() {
    switch (_verificationStatus) {
      case 'verifie':
        return 'Profil vérifié';
      case 'en_attente':
        return 'Vérification en attente';
      case 'refuse':
        return 'Vérification refusée';
      default:
        return 'Non vérifié';
    }
  }

  Color _verificationColor() {
    switch (_verificationStatus) {
      case 'verifie':
        return Colors.green.shade700;
      case 'en_attente':
        return Colors.orange.shade800;
      case 'refuse':
        return Colors.red.shade700;
      default:
        return Colors.black54;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) {
      _snack("Aucun email lié à ce compte.");
      return;
    }

    try {
      setState(() => _busy = true);

      await _supabase.auth.resetPasswordForEmail(
        user.email!,
        redirectTo: kIsWeb ? null : 'fasomatch://reset-password',
      );

      _snack("Un email de réinitialisation a été envoyé.");
    } catch (e) {
      _snack("Erreur : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBiometricConfig({
    required bool enabled,
    required String preference,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('profiles').update({
      'biometric_enabled': enabled,
      'biometric_preference': preference,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    if (!mounted) return;
    setState(() {
      _biometricEnabled = enabled;
      _biometricPreference = preference;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (kIsWeb) {
      _snack(
        "La biométrie n’est pas disponible sur Chrome Web. Teste cette option sur Android ou iPhone.",
      );
      return;
    }

    try {
      setState(() => _busy = true);

      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        _snack("La biométrie n’est pas disponible sur cet appareil.");
        return;
      }

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        _snack("Aucune biométrie configurée sur cet appareil.");
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: value
            ? 'Active la connexion biométrique pour FasoMatch'
            : 'Confirme la désactivation de la biométrie',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        _snack("Action annulée.");
        return;
      }

      // ✅ Si l’utilisateur active depuis les paramètres
      // on garde sa préférence actuelle si elle existe déjà
      await _saveBiometricConfig(
        enabled: value,
        preference: _biometricPreference,
      );

      _snack(
        value
            ? "Connexion biométrique activée."
            : "Connexion biométrique désactivée.",
      );
    } on MissingPluginException {
      _snack(
        "Plugin biométrique indisponible ici. Lance l’app sur Android ou iPhone avec un vrai redémarrage complet.",
      );
    } catch (e) {
      _snack("Erreur biométrique : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseBiometricPreference() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String tempValue = _biometricPreference;

        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    "Méthode biométrique préférée",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Choisis la méthode que tu préfères pour tes prochaines connexions.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _radioChoice(
                    title: "Automatique",
                    subtitle: "Selon l’appareil disponible",
                    value: 'auto',
                    groupValue: tempValue,
                    onChanged: (v) => setModalState(() => tempValue = v),
                  ),
                  _radioChoice(
                    title: "Empreinte digitale",
                    subtitle: "Priorité à l’empreinte",
                    value: 'fingerprint',
                    groupValue: tempValue,
                    onChanged: (v) => setModalState(() => tempValue = v),
                  ),
                  _radioChoice(
                    title: "Reconnaissance faciale",
                    subtitle: "Priorité au visage",
                    value: 'face',
                    groupValue: tempValue,
                    onChanged: (v) => setModalState(() => tempValue = v),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, tempValue),
                      child: const Text(
                        "Enregistrer",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;

    try {
      setState(() => _busy = true);

      // ✅ Si l’utilisateur choisit une méthode dans les paramètres,
      // on garde l’état ON/OFF actuel mais on met à jour la préférence.
      await _saveBiometricConfig(
        enabled: _biometricEnabled,
        preference: selected,
      );

      _snack("Préférence biométrique mise à jour.");
    } catch (e) {
      _snack("Erreur : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAccountVisibility() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final nextValue = !_isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          nextValue
              ? "Réactiver mon compte"
              : "Désactiver mon compte",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          nextValue
              ? "Ton profil redeviendra visible et tu pourras reprendre l’application normalement."
              : "Ton profil sera masqué et ne sera plus visible par les autres utilisateurs jusqu’à réactivation.",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nextValue
                  ? const Color(0xFF111111)
                  : const Color(0xFFB00020),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(nextValue ? "Réactiver" : "Désactiver"),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _busy = true);

      await _supabase.from('profiles').update({
        'is_active': nextValue,
        'hidden_at': nextValue ? null : DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;
      setState(() => _isActive = nextValue);

      _snack(
        nextValue ? "Compte réactivé." : "Compte désactivé temporairement.",
      );
    } catch (e) {
      _snack("Erreur : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestDeleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          "Supprimer mon compte",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Cette action va masquer ton profil immédiatement et enregistrer une demande de suppression.",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB00020),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _busy = true);

      await _supabase.from('profiles').update({
        'is_active': false,
        'deletion_requested_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      _snack("Erreur : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() => _busy = true);

      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      _snack("Erreur lors de la déconnexion : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showVerificationSheet() async {
    final selectedType = await showModalBottomSheet<String>(
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
                "Vérifier mon profil",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choisis ton document d’identité pour lancer la vérification.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _selectDocumentTile(
                icon: Icons.badge_outlined,
                title: "Carte d’identité",
                subtitle: "Document national",
                onTap: () => Navigator.pop(context, 'carte_id'),
              ),
              _selectDocumentTile(
                icon: Icons.book_outlined,
                title: "Passeport",
                subtitle: "Document de voyage",
                onTap: () => Navigator.pop(context, 'passeport'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedType == null) return;
    await _pickAndUploadVerificationDocument(selectedType);
  }

  Future<void> _pickAndUploadVerificationDocument(String documentType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _snack("Utilisateur non connecté.");
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
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
                "Ajouter un document",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choisis comment envoyer ton document d’identité.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _selectDocumentTile(
                icon: Icons.photo_camera_outlined,
                title: "Prendre une photo",
                subtitle: "Utiliser la caméra",
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _selectDocumentTile(
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

    if (source == null) return;

    try {
      setState(() => _busy = true);

      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        _snack("Aucun document sélectionné.");
        return;
      }

      final Uint8List bytes = await pickedFile.readAsBytes();
      final extension = pickedFile.path.split('.').last.toLowerCase();
      final safeExtension = extension.isEmpty ? 'jpg' : extension;

      final fileName =
          '${documentType}_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
      final storagePath = '${user.id}/$fileName';

      await _supabase.storage.from('kyc-documents').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: pickedFile.mimeType ?? 'image/jpeg',
        ),
      );

      final signedUrl = await _supabase.storage
          .from('kyc-documents')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 7);

      await _supabase.from('profiles').update({
        'verification_status': 'en_attente',
        'verification_document_type': documentType,
        'verification_document_path': storagePath,
        'verification_document_url': signedUrl,
        'verification_submitted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _verificationStatus = 'en_attente';
        _verificationDocumentType = documentType;
        _verificationDocumentUrl = signedUrl;
      });

      _snack(
        documentType == 'carte_id'
            ? "Carte d’identité envoyée avec succès."
            : "Passeport envoyé avec succès.",
      );
    } catch (e) {
      _snack("Erreur lors de l’envoi du document : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (result == true) {
      await _loadSettings();
    }
  }

  Widget _radioChoice({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _selectDocumentTile({
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

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.black12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF5A4B4B)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: subtitleColor ?? Colors.black54,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF5A4B4B)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: _busy ? null : onChanged,
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final photo = _mainPhoto;

    if (photo == null || photo.isEmpty) {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFF9DDE2),
        child: Icon(Icons.person, color: Colors.black87),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFF9DDE2),
      child: ClipOval(
        child: Image.network(
          photo,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const Icon(Icons.person, color: Colors.black87);
          },
        ),
      ),
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
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Image.asset(
              'assets/images/fasomatch_logo.png',
              width: 75,
              height: 75,
              errorBuilder: (_, __, ___) => const SizedBox(height: 8),
            ),
            const SizedBox(height: 2),
            const Text(
              "Paramètres",
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
          ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _card(
                child: Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Abonnement : ${_prettyPlan(_plan)}",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isActive
                                ? "Compte visible"
                                : "Compte désactivé temporairement",
                            style: TextStyle(
                              color: _isActive
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: widget.onUpgradeTap,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: blush,
                        foregroundColor: Colors.red.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "Upgrade",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _sectionTitle("Profil"),
              _tile(
                icon: Icons.verified_outlined,
                title: "Vérifier mon profil",
                subtitle: _verificationLabel(),
                subtitleColor: _verificationColor(),
                onTap: _showVerificationSheet,
              ),
              _tile(
                icon: Icons.edit_outlined,
                title: "Modifier mon profil",
                subtitle: "Bio, ville, recherche, photos",
                onTap: _openEditProfile,
              ),

              const SizedBox(height: 12),
              _sectionTitle("Sécurité"),
              _tile(
                icon: Icons.lock_outline,
                title: "Changer le mot de passe",
                subtitle: "Renforcer la sécurité",
                onTap: _sendPasswordReset,
              ),
              _switchTile(
                icon: Icons.fingerprint,
                title: "Connexion biométrique",
                subtitle:
                _biometricEnabled ? "Activée" : "Désactivée",
                value: _biometricEnabled,
                onChanged: _toggleBiometric,
              ),
              _tile(
                icon: Icons.shield_outlined,
                title: "Méthode biométrique",
                subtitle:
                _biometricPreferenceLabel(_biometricPreference),
                onTap: _chooseBiometricPreference,
              ),

              const SizedBox(height: 12),
              _sectionTitle("Conformité & confidentialité"),
              _tile(
                icon: Icons.privacy_tip_outlined,
                title: "Politique de confidentialité",
                subtitle: "Lire",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              _tile(
                icon: Icons.gavel_outlined,
                title: "CGU",
                subtitle: "Lire",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsScreen(),
                    ),
                  );
                },
              ),
              _tile(
                icon: Icons.business_outlined,
                title: "Mentions légales",
                subtitle: "Lire",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalNoticeScreen(),
                    ),
                  );
                },
              ),
              _tile(
                icon: Icons.visibility_off_outlined,
                title: _isActive
                    ? "Désactiver mon compte"
                    : "Réactiver mon compte",
                subtitle: _isActive
                    ? "Masquer temporairement mon profil"
                    : "Rendre mon profil visible à nouveau",
                onTap: _toggleAccountVisibility,
              ),
              _tile(
                icon: Icons.delete_forever_outlined,
                title: "Supprimer mon compte",
                subtitle: "Droit à l’effacement",
                onTap: _requestDeleteAccount,
              ),
              _tile(
                icon: Icons.logout,
                title: "Déconnexion",
                subtitle: "Se déconnecter de l’application",
                onTap: _signOut,
              ),

              const SizedBox(height: 12),
              _sectionTitle("Support"),
              _tile(
                icon: Icons.help_outline,
                title: "Centre d’aide",
                subtitle: "FAQ / Assistance",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          if (_busy)
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