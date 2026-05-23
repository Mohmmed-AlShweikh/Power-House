enum ComplaintStatus { open, inProgress, resolved }

class Complaint {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final ComplaintStatus status;
  final DateTime createdAt;

  const Complaint({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.status,
    required this.createdAt,
  });

  factory Complaint.fromMap(String id, Map<String, dynamic> map) {
    return Complaint(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      text: map['text'] ?? '',
      status: _parseStatus(map['status']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  static ComplaintStatus _parseStatus(dynamic v) {
    if (v == 'resolved') return ComplaintStatus.resolved;
    if (v == 'inProgress') return ComplaintStatus.inProgress;
    return ComplaintStatus.open;
  }
}
