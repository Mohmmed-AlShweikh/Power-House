import 'generator_model.dart';

enum UserRole { superAdmin, admin, consumer, meterReader }

enum SubscriptionStatus { active, inactive, pending }

enum ApprovalStatus { pending, approved, rejected, suspended }

class UserProfile {
  final String uid;
  final String? generatorId;
  final String rejectionReason;
  final String idNumber;
  final String phone;
  final String name;
  final String address;
  final UserRole role;
  final ApprovalStatus approvalStatus;
  final SubscriptionStatus subscriptionStatus;
  final int ampereLimit;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    this.generatorId = defaultGeneratorId,
    this.rejectionReason = '',
    this.idNumber = '',
    this.phone = '',
    required this.name,
    this.address = '',
    required this.role,
    this.approvalStatus = ApprovalStatus.approved,
    this.subscriptionStatus = SubscriptionStatus.active,
    this.ampereLimit = 0,
    required this.createdAt,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      generatorId: _parseRole(map['role']) == UserRole.superAdmin
          ? null
          : normalizedGeneratorId(map['generatorId']),
      rejectionReason: map['rejectionReason'] as String? ?? '',
      idNumber: map['idNumber'] ?? '',
      phone: map['phone'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      role: _parseRole(map['role']),
      approvalStatus: _parseApproval(map['status']),
      subscriptionStatus:
          _parseSubStatus(map['subscriptionStatus'] ?? 'active'),
      ampereLimit: map['ampereLimit'] ?? 0,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        if (role != UserRole.superAdmin)
          'generatorId': generatorId ?? defaultGeneratorId,
        'rejectionReason': rejectionReason,
        'idNumber': idNumber,
        'phone': phone,
        'name': name,
        'address': address,
        'role': _roleToString(role),
        'status': approvalStatus.name,
        'subscriptionStatus': subscriptionStatus.name,
        'ampereLimit': ampereLimit,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  UserProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? idNumber,
    ApprovalStatus? approvalStatus,
    SubscriptionStatus? subscriptionStatus,
    int? ampereLimit,
  }) =>
      UserProfile(
        uid: uid,
        generatorId: generatorId,
        rejectionReason: rejectionReason,
        idNumber: idNumber ?? this.idNumber,
        phone: phone ?? this.phone,
        name: name ?? this.name,
        address: address ?? this.address,
        role: role,
        approvalStatus: approvalStatus ?? this.approvalStatus,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        ampereLimit: ampereLimit ?? this.ampereLimit,
        createdAt: createdAt,
      );

  static UserRole _parseRole(dynamic v) {
    final role = (v as String?)?.trim().toLowerCase() ?? '';
    if (role == 'meter_reader') return UserRole.meterReader;
    if (role == 'super_admin') return UserRole.superAdmin;
    if (role == 'generator_owner' || role == 'admin') {
      return UserRole.admin;
    }
    return UserRole.consumer;
  }

  static String _roleToString(UserRole r) {
    switch (r) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'generator_owner';
      case UserRole.consumer:
        return 'user';
      case UserRole.meterReader:
        return 'meter_reader';
    }
  }

  static ApprovalStatus _parseApproval(dynamic v) {
    switch (v) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      case 'suspended':
        return ApprovalStatus.suspended;
      default:
        return ApprovalStatus.pending;
    }
  }

  static SubscriptionStatus _parseSubStatus(dynamic v) {
    if (v == 'active') return SubscriptionStatus.active;
    if (v == 'inactive') return SubscriptionStatus.inactive;
    return SubscriptionStatus.pending;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }
}
