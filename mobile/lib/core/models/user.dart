class AppUser {
  final String id;
  final String? phone;
  final String? email;
  final String? name;
  final List<String> roles;
  final String? showroomId;
  final bool isAvailable;
  /// Server-side preference, the `language` column on User.
  final String? language;

  AppUser({
    required this.id,
    required this.phone,
    required this.email,
    required this.name,
    required this.roles,
    required this.showroomId,
    required this.isAvailable,
    this.language,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        phone: json['phone'],
        email: json['email'],
        name: json['name'],
        roles: List<String>.from(json['roles'] ?? []),
        showroomId: json['showroomId'],
        isAvailable: json['isAvailable'] ?? true,
        language: json['language'] as String?,
      );

  bool get isPoster => roles.contains('poster');
  bool get isValuer => roles.contains('valuer');
  bool get hasShowroom => showroomId != null;
}

class Showroom {
  final String id;
  final String name;
  final String joinCode;

  Showroom({required this.id, required this.name, required this.joinCode});

  factory Showroom.fromJson(Map<String, dynamic> json) =>
      Showroom(id: json['id'], name: json['name'], joinCode: json['joinCode']);
}
