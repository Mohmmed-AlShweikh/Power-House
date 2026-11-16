import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:generator_portal/features/metering/repository.dart';
import 'package:generator_portal/features/metering/models.dart';
import 'package:generator_portal/services/tenant_store.dart';
import 'package:generator_portal/models/user_model.dart';
import 'package:generator_portal/config/auth_redirect.dart';
void main(){test('one-use invitation and revocation retain worker identity without money',()async{
 final db=FakeFirebaseFirestore();await db.collection('users').doc('o').set({'role':'generator_owner','status':'approved','generatorId':'g'});await db.collection('generators').doc('g').set({'status':'approved','subscriptionStatus':'active'});
 final owner=MeteringRepository(TenantStore(db,()=> 'o'));final code=await owner.invite();expect(code.length,32);
 await MeteringRepository(TenantStore(db,()=> 'r')).join(uid:'r',email:'r@example.test',code:code,name:'عامل');
 expect((await db.collection('users').doc('r').get()).data()!['role'],'meter_reader');
 await expectLater(MeteringRepository(TenantStore(db,()=> 'r2')).join(uid:'r2',email:'x@example.test',code:code,name:'عامل'),throwsStateError);
 await owner.revokeReader('r');expect((await db.collection('users').doc('r').get()).data()!['status'],'suspended');
 });
 test('reader routing and abnormal reading validation',(){final p=UserProfile(uid:'r',name:'عامل',generatorId:'g',role:UserRole.meterReader,createdAt:DateTime(2026));expect(authRedirect(path:'/consumer',startupResolved:true,loading:false,loggedIn:true,profile:p),'/reader');const row=MeterAssignment(id:'x',generatorId:'g',readerUid:'r',roundId:'q',name:'اسم',address:'حي',number:'1',previousMilli:20000,averageMilli:1000);expect(row.abnormal(23000),false);expect(row.abnormal(23001),true);expect(row.toMap().containsKey('priceAgorot'),false);});
}
