enum AlertType { generatorOn, generatorOff, lowFuel, newBill, receiptApproved, receiptRejected, newSubscriber, complaint, newOwnerRequest, newConsumerRequest, requestApproved, requestRejected, passwordReset }

class AppAlert {
  final String id;
  final String title;
  final String body;
  final AlertType type;
  final DateTime createdAt;
  final bool read;

  const AppAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.read,
  });

  factory AppAlert.fromMap(String id, Map<String, dynamic> map) {
    return AppAlert(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: _parseType(map['type']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
      read: map['read'] ?? false,
    );
  }

  static AlertType _parseType(dynamic v) {
    switch (v) {
      case 'generatorOn': return AlertType.generatorOn;
      case 'generatorOff': return AlertType.generatorOff;
      case 'lowFuel': return AlertType.lowFuel;
      case 'newBill': return AlertType.newBill;
      case 'receiptApproved': return AlertType.receiptApproved;
      case 'receiptRejected': return AlertType.receiptRejected;
      case 'newSubscriber': return AlertType.newSubscriber;
      case 'complaint': return AlertType.complaint;
      case 'newOwnerRequest': return AlertType.newOwnerRequest;
      case 'newConsumerRequest': return AlertType.newConsumerRequest;
      case 'requestApproved': return AlertType.requestApproved;
      case 'requestRejected': return AlertType.requestRejected;
      case 'passwordReset': return AlertType.passwordReset;
      default: return AlertType.generatorOn;
    }
  }
}
