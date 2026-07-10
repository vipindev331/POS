import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Permission key: allows a staff user to add, edit, and delete products.
/// Managers have it implicitly (see [AuthUser.can]).
const String kPermManageProducts = 'manage_products';

class AuthUser extends Equatable {
  final String id;
  final String username;
  final String fullName;
  final String role; // 'manager' | 'staff'
  final List<String> permissions;

  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.permissions = const [],
  });

  bool get isManager => role == 'manager';

  /// Restricted back-office role: manages users + company details only.
  bool get isAdmin => role == 'admin';

  /// Managers can do everything; staff only what their permissions grant.
  /// (Admin is a restricted role — it does not get blanket store permissions.)
  bool can(String permission) => isManager || permissions.contains(permission);

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        username: j['username'] as String,
        fullName: (j['fullName'] ?? '') as String,
        role: j['role'] as String,
        permissions: ((j['permissions'] as List?) ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'role': role,
        'permissions': permissions,
      };

  String encode() => jsonEncode(toJson());
  static AuthUser decode(String s) => AuthUser.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  List<Object?> get props => [id, username, role];
}
