import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tenant_provider.dart';
import '../../services/firestore_reads.dart';
import 'repository.dart';
import 'models.dart';

final billingSettingsRepositoryProvider = Provider(
    (ref) => BillingSettingsRepository(ref.watch(tenantStoreProvider)));
final billingSettingsProvider = StreamProvider<BillingSettings>((ref) => ref
    .watch(billingSettingsRepositoryProvider)
    .document(ref.watch(tenantIdProvider))
    .autoSnapshots(ref)
    .map((d) => d.exists
        ? BillingSettings.fromMap(d.data()!)
        : const BillingSettings(minimumUnitsMilli: 1500)));
