class User {
  final int? id;
  final String name;
  final String username;
  final String password;
  final String rights;
  final String email;
  final String phone;
  final bool? updated;

  const User({
    this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.rights,
    required this.email,
    required this.phone,
    this.updated,
  });

  User copyWith({
    int? id,
    String? name,
    String? username,
    String? password,
    String? rights,
    String? email,
    String? phone,
    bool? updated,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      rights: rights ?? this.rights,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      updated: updated ?? this.updated,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password': password,
      'Type': rights,
      'email': email,
      'phone': phone,
      'Updated': (updated ?? false) ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      rights: map['Type'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      updated: _intToBool(map['Updated']) ?? false,
    );
  }

  static bool? _intToBool(Object? value) {
    if (value == null) return null;
    if (value is int) return value == 1;
    if (value is bool) return value;
    return null;
  }
}
