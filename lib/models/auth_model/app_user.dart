// lib/models/auth_model/app_user.dart
class AppUser {
  final String id;
  final String name; // Mapped to 'username' from backend
  final String email;
  final String? token; 
  
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.token,
  });

  factory AppUser.fromJson(Map<String, dynamic> json, {String? token}) {
    return AppUser(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      // Backend uses 'username', App uses 'name'
      name: json['username'] ?? json['name'] ?? 'User',
      email: json['email'] ?? '',
      token: token ?? json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': name, 
      'email': email,
      'token': token,
    };
  }
}