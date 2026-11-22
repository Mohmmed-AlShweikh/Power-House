import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/services/tenant_store.dart';
import 'package:generator_portal/features/rounds/repository.dart';
import 'package:generator_portal/features/billing_settings/models.dart';
class BillingFixture {
 final db=FakeFirebaseFirestore();
 late final owner=RoundsRepository(TenantStore(db,()=> 'o'));
 late final consumer=RoundsRepository(TenantStore(db,()=> 'c'));
 Future<void> seed()async{
  for(final row in [('o','generator_owner'),('c','user')]){await db.collection('users').doc(row.$1).set({'name':row.$1,'role':row.$2,'status':'approved','subscriptionStatus':'active','generatorId':'g'});}
  await db.collection('generators').doc('g').set({'status':'approved','subscriptionStatus':'active'});
  await db.collection('billingSettings').doc('g').set(const BillingSettings(priceAgorot:2800,minimumUnitsMilli:1500).toMap());
 }
 Future<String> closed()async{await owner.addSubscriber(name:'مشترك',phone:'',address:'حي',number:'1',startingMilli:20000,userId:'c');final rid=await owner.openRound(DateTime.utc(2026,11,15));await owner.ownerReading(rid,'c',30000);await owner.closeRound(rid);return rid;}
}
