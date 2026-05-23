enum UserRole { admin, consumer }

enum SubscriptionStatus { active, inactive, pending }

class UserProfile {
  final String uid;
  final String phone;
  final String name;
  final String address;
  final UserRole role;
  final SubscriptionStatus subscriptionStatus;
  final int ampereLimit;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.phone,
    required this.name,
    required this.address,
    required this.role,
    required this.subscriptionStatus,
    required this.ampereLimit,
    required this.createdAt,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      phone: map['phone'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      role: _parseRole(map['role']),
      subscriptionStatus: _parseStatus(map['subscriptionStatus']),
      ampereLimit: map['ampereLimit'] ?? 0,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'phone': phone,
    'name': name,
    'address': address,
    'role': role.name,
    'subscriptionStatus': subscriptionStatus.name,
    'ampereLimit': ampereLimit,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  UserProfile copyWith({
    String? name,
    String? address,
    SubscriptionStatus? subscriptionStatus,
    int? ampereLimit,
  }) => UserProfile(
    uid: uid,
    phone: phone,
    name: name ?? this.name,
    address: address ?? this.address,
    role: role,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    ampereLimit: ampereLimit ?? this.ampereLimit,
    createdAt: createdAt,
  );

  static UserRole _parseRole(dynamic v) {
    if (v == 'admin') return UserRole.admin;
    return UserRole.consumer;
  }

  static SubscriptionStatus _parseStatus(dynamic v) {
    if (v == 'active') return SubscriptionStatus.active;
    if (v == 'inactive') return SubscriptionStatus.inactive;
    return SubscriptionStatus.pending;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }
}
