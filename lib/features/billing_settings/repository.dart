import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/tenant_store.dart';
import 'models.dart';

class BillingSettingsRepository {
  final TenantStore store;
  BillingSettingsRepository(this.store);
  DocumentReference<Map<String, dynamic>> document(String gid) =>
      store.db.collection('billingSettings').doc(gid);
  Future<void> save(BillingSettings settings) async {
    settings.validate();
    final actor = await store.requireOwner();
    if (actor.superAdmin) {
      throw StateError('إعدادات الفوترة لصاحب المولد');
    }
    await document(actor.generatorId).set({
      ...settings.toMap(),
      'generatorId': actor.generatorId,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp()
    });
  }
}
