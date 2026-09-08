/// Represents a stored or recently used credential (username & password).
class SavedCredential {
  final String id;
  final String username;
  final String password;
  final String? label;
  final DateTime lastUsed;

  SavedCredential({
    required this.id,
    required this.username,
    required this.password,
    this.label,
    DateTime? lastUsed,
  }) : lastUsed = lastUsed ?? DateTime.now();

  String get displayTitle {
    if (label != null && label!.trim().isNotEmpty) {
      return '$username ($label)';
    }
    return username;
  }

  SavedCredential copyWith({
    String? id,
    String? username,
    String? password,
    String? label,
    DateTime? lastUsed,
  }) {
    return SavedCredential(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      label: label ?? this.label,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password': password,
    'label': label,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory SavedCredential.fromJson(Map<String, dynamic> json) {
    return SavedCredential(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      username: json['username'] as String? ?? 'Administrator',
      password: json['password'] as String? ?? '',
      label: json['label'] as String?,
      lastUsed: json['lastUsed'] != null
          ? DateTime.tryParse(json['lastUsed'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
