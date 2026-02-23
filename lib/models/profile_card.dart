class ProfileCardData {
  final String id;
  final String firstName;
  final String city;
  final DateTime? birthdate;
  final bool isVerified;
  final String? photoUrl; // on stocke direct une URL exploitable

  ProfileCardData({
    required this.id,
    required this.firstName,
    required this.city,
    required this.birthdate,
    required this.isVerified,
    required this.photoUrl,
  });

  int? get age {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthdate!.year;
    final hadBirthday = (now.month > birthdate!.month) ||
        (now.month == birthdate!.month && now.day >= birthdate!.day);
    if (!hadBirthday) years--;
    return years;
  }

  factory ProfileCardData.fromRpc(Map<String, dynamic> json) {
    // photo1_url est jsonb dans ta table. Souvent on met: {"url":"https://..."}
    String? url;
    final p = json['photo1_url'];
    if (p is Map && p['url'] != null) {
      url = p['url'].toString();
    } else if (p is String && p.isNotEmpty) {
      url = p;
    }

    DateTime? bd;
    final birth = json['birthdate'];
    if (birth != null) {
      bd = DateTime.tryParse(birth.toString());
    }

    return ProfileCardData(
      id: json['id'].toString(),
      firstName: (json['first_name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      birthdate: bd,
      isVerified: (json['is_verified'] ?? false) == true,
      photoUrl: url,
    );
  }
}