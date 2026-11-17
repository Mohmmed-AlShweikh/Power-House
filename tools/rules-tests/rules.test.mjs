import {before,beforeEach,after,test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,collection,getDocs,query,where,writeBatch,runTransaction,serverTimestamp} from 'firebase/firestore';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8089')throw new Error('Local demo Firestore required');
let env;
const profile=(role,generatorId,status='approved',uid='test')=>({name:role,email:uid+'@example.test',credentialVersion:2,phone:'0591234567',idNumber:'',role,generatorId,status,subscriptionStatus:'active',ampereLimit:0,createdAt:1});
const generator=(ownerUid,status='approved')=>({name:'مولد',sector:'غزة',ownerUid,status,subscriptionStatus:'active',rejectionReason:'',createdAt:1,isOn:false,pricePerKwh:2});
const directory=g=>({name:g.name,sector:g.sector,status:g.status,subscriptionStatus:g.subscriptionStatus});
const db=(uid,verified=true)=>env.authenticatedContext(uid,{email:uid+'@example.test',email_verified:verified,auth_time:Math.floor(Date.now()/1000)}).firestore();
const pay=()=>({amountMinor:10000,date:Date.now(),reference:'test-reference',method:'cash',submittedAt:Date.now(),version:1});
const submission=(version=1)=>({payment:{...pay(),version},status:'pendingReview'});
const decision=(uid,status,reason='')=>({status,reviewedBy:uid,reviewedAt:Date.now(),reviewReason:reason,reviewedVersion:1});
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-generator-portal',firestore:{host:'127.0.0.1',port:8089,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async context=>{
 const f=context.firestore();
 for(const [id,role,gid,status] of [['sa','super_admin',null,'approved'],['oa','generator_owner','a','approved'],['ob','generator_owner','b','approved'],['ca','user','a','approved'],['cb','user','b','approved'],['pending','user','a','pending']])await setDoc(doc(f,'users',id),profile(role,gid,status,id));
 for(const id of ['a','b']){const g=generator('o'+id);await setDoc(doc(f,'generators',id),g);await setDoc(doc(f,'generatorDirectory',id),directory(g));}
 for(const [id,userId,generatorId] of [['ba','ca','a'],['bb','cb','b'],['forged','ca','b']])await setDoc(doc(f,'bills',id),{userId,generatorId,status:'pending',amount:100,kwh:50});
 await setDoc(doc(f,'complaints','qa'),{userId:'ca',generatorId:'a',text:'اختبار',status:'open'});
});});
test('anonymous and unverified users cannot read data, even with a privileged profile',async()=>{
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users','ca')));
 for(const uid of ['ca','oa','sa']){await assertFails(getDoc(doc(db(uid,false),'users',uid)));await assertFails(getDocs(collection(db(uid,false),'generatorDirectory')));}
});
test('verified fresh account can pick approved active directory without a profile; no owner personal data',async()=>{
 const f=db('fresh');await assertSucceeds(getDocs(query(collection(f,'generatorDirectory'),where('status','==','approved'),where('subscriptionStatus','==','active'))));
 await assertFails(getDoc(doc(f,'users','oa')));await assertFails(getDocs(collection(f,'users')));
 assert.deepEqual(Object.keys((await getDoc(doc(db('ca'),'generatorDirectory','a'))).data()).sort(),['name','sector','status','subscriptionStatus']);
 await assertFails(updateDoc(doc(db('sa'),'generatorDirectory','a'),{phone:'contact'}));
});
test('owner registration is atomic pending pair, contact phone is required and never verified login identity',async()=>{
 const f=db('new'),u=profile('generator_owner','new-gen','pending','new'),g=generator('new','pending');
 await assertFails(setDoc(doc(f,'users','new'),u));const b=writeBatch(f);b.set(doc(f,'users','new'),u);b.set(doc(f,'generators','new-gen'),g);await assertSucceeds(b.commit());
 await assertFails(updateDoc(doc(f,'users','new'),{status:'approved'}));await assertFails(updateDoc(doc(f,'generators','new-gen'),{status:'approved'}));
});
test('consumer registration always pending, cannot join suspended or inactive generator',async()=>{
 const f=db('new');await assertSucceeds(setDoc(doc(f,'users','new'),{...profile('user','a','pending','new'),subscriptionStatus:'inactive'}));
 await assertFails(setDoc(doc(db('elevated'),'users','elevated'),profile('super_admin','a','approved','elevated')));
 await updateDoc(doc(db('sa'),'generators','b'),{status:'suspended',rejectionReason:'سبب الإيقاف'});
 await assertFails(setDoc(doc(db('blocked'),'users','blocked'),{...profile('user','b','pending','blocked'),subscriptionStatus:'inactive'}));
});
test('registration rejects unverified or mismatched email and synthetic identities',async()=>{
 await assertFails(setDoc(doc(db('new',false),'users','new'),{...profile('user','a','pending','new'),subscriptionStatus:'inactive'}));
 await assertFails(setDoc(doc(db('new'),'users','new'),{...profile('user','a','pending','other'),subscriptionStatus:'inactive'}));
 const fake=env.authenticatedContext('fake',{email:'123456789@powershare.app',email_verified:true}).firestore();await assertFails(getDocs(collection(fake,'generatorDirectory')));
});
test('self edits cannot approve, escalate, change generator or paid subscription',async()=>{
 const f=db('ca');for(const data of [{role:'super_admin'},{status:'suspended'},{generatorId:'b'},{subscriptionStatus:'inactive'}])await assertFails(updateDoc(doc(f,'users','ca'),data));
 await assertSucceeds(updateDoc(doc(f,'users','ca'),{name:'اسم',phone:'0591234567',idNumber:'123456789'}));
 await assertFails(getDocs(collection(f,'idIndex')));await assertFails(getDoc(doc(f,'idIndex','123456789')));
 for(const uid of ['ca','oa','sa'])await assertFails(updateDoc(doc(db(uid),'users','ca'),{password:'never-store'}));
});
test('owners read/approve only consumers from their generator, suspension/rejection require reason',async()=>{
 const f=db('oa');await assertSucceeds(getDocs(query(collection(f,'users'),where('generatorId','==','a'),where('role','in',['user','consumer']))));
 await assertFails(getDoc(doc(f,'users','cb')));await assertFails(updateDoc(doc(f,'users','cb'),{status:'approved'}));
 await assertFails(updateDoc(doc(f,'users','ca'),{status:'suspended',subscriptionStatus:'inactive'}));
 await assertSucceeds(updateDoc(doc(f,'users','ca'),{status:'suspended',subscriptionStatus:'inactive',rejectionReason:'سبب الإيقاف'}));
 await assertFails(getDoc(doc(db('ca'),'bills','ba')));await assertSucceeds(getDoc(doc(db('ca'),'users','ca')));
 await assertSucceeds(updateDoc(doc(f,'users','ca'),{status:'approved',subscriptionStatus:'active',rejectionReason:''}));
});
test('cross-generator bill and complaint reads are denied, own queries succeed',async()=>{
 const f=db('ca');await assertSucceeds(getDocs(query(collection(f,'bills'),where('generatorId','==','a'),where('userId','==','ca'))));
 for(const id of ['bb','forged'])await assertFails(getDoc(doc(f,'bills',id)));await assertFails(getDoc(doc(db('ob'),'complaints','qa')));
});
test('consumer records full payment but cannot approve it or submit for another user',async()=>{
 const f=db('ca');await assertSucceeds(updateDoc(doc(f,'bills','ba'),submission()));
 await assertFails(updateDoc(doc(f,'bills','ba'),decision('ca','paid')));await assertFails(updateDoc(doc(f,'bills','bb'),submission()));
 await assertFails(updateDoc(doc(f,'bills','ba'),submission()));
});
test('payment validation blocks images, wrong amounts, invalid method, future dates and oversized reference',async()=>{
 const f=db('ca');for(const change of [{amountMinor:10},{method:'gateway'},{date:Date.now()+172800000},{reference:'x'.repeat(81)}])await assertFails(updateDoc(doc(f,'bills','ba'),{status:'pendingReview',payment:{...pay(),...change}}));
 await assertFails(updateDoc(doc(f,'bills','ba'),{status:'pendingReview',receiptBase64:'image'}));await assertFails(updateDoc(doc(f,'bills','ba'),{...submission(),amount:1}));
});
test('owner approval is immutable and cannot be repeated or reversed after payment',async()=>{
 await updateDoc(doc(db('ca'),'bills','ba'),submission());const f=db('oa');await assertSucceeds(updateDoc(doc(f,'bills','ba'),decision('oa','paid')));
 await assertFails(updateDoc(doc(f,'bills','ba'),decision('oa','paid')));await assertFails(updateDoc(doc(f,'bills','ba'),decision('oa','rejected','late')));await assertFails(updateDoc(doc(db('ca'),'bills','ba'),submission()));
});
test('rejection requires reason; consumer can correct and resubmit; cross-tenant reviewer denied',async()=>{
 await updateDoc(doc(db('ca'),'bills','ba'),submission());await assertFails(updateDoc(doc(db('ob'),'bills','ba'),decision('ob','paid')));
 await assertFails(updateDoc(doc(db('oa'),'bills','ba'),decision('oa','rejected')));await assertSucceeds(updateDoc(doc(db('oa'),'bills','ba'),decision('oa','rejected','رقم غير صحيح')));
 await assertSucceeds(updateDoc(doc(db('ca'),'bills','ba'),submission(2)));await assertFails(updateDoc(doc(db('oa'),'bills','ba'),decision('oa','paid')));await assertSucceeds(updateDoc(doc(db('oa'),'bills','ba'),{...decision('oa','paid'),reviewedVersion:2}));
});
test('direct paid status without a submitted payment and forged reviewer are denied',async()=>{
 await assertFails(updateDoc(doc(db('oa'),'bills','ba'),decision('oa','paid')));await updateDoc(doc(db('ca'),'bills','ba'),submission());await assertFails(updateDoc(doc(db('oa'),'bills','ba'),decision('ob','paid')));
});
test('super-admin suspension blocks operational reads and directory projection follows private document',async()=>{
 const f=db('sa');const b=writeBatch(f);b.update(doc(f,'generators','a'),{status:'suspended',rejectionReason:'سبب'});b.update(doc(f,'generatorDirectory','a'),{status:'suspended'});await assertSucceeds(b.commit());
 await assertFails(getDoc(doc(db('oa'),'bills','ba')));await assertFails(getDoc(doc(db('ca'),'bills','ba')));await assertSucceeds(getDoc(doc(db('ca'),'generators','a')));
});

test('concurrent owner reviews commit one decision and one feedback record',async()=>{
 await updateDoc(doc(db('ca'),'bills','ba'),submission());
 async function approve(){const f=db('oa');return runTransaction(f,async tx=>{
  const ref=doc(f,'bills','ba'),snapshot=await tx.get(ref);
  if(snapshot.data().status==='paid')return false;
  tx.update(ref,decision('oa','paid'));
  tx.set(doc(f,'alerts','race-ba-v1'),{generatorId:'a',userId:'ca',title:'تم اعتماد الدفع',body:'اختبار',type:'paymentApproved',read:false,createdAt:Date.now()});
  return true;
 });}
 const results=await Promise.allSettled([approve(),approve()]);
 assert.equal(results.filter(r=>r.status==='fulfilled'&&r.value===true).length,1);
 for(const result of results){if(result.status==='rejected')assert.equal(result.reason.code,'permission-denied');}
 // A late commit can be denied by the immutable paid-state rule instead of
 // being retried as ABORTED; either outcome must leave exactly one approval.
 assert.equal((await getDoc(doc(db('ca'),'bills','ba'))).data().status,'paid');
 const feedback=await getDocs(query(collection(db('ca'),'alerts'),where('generatorId','==','a'),where('userId','==','ca')));assert.equal(feedback.size,1);
});
test('billing settings owner only, validated integer money, cross-tenant denied',async()=>{
 const settings={generatorId:'a',priceAgorot:2800,minimumUnitsMilli:1500,cycleDays:10,roundingThresholdAgorot:50,unitName:'وحدة',updatedBy:'oa',updatedAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(db('oa'),'billingSettings','a'),settings));
 await assertSucceeds(getDoc(doc(db('oa'),'billingSettings','a')));
 await assertSucceeds(getDoc(doc(db('ca'),'billingSettings','a')));
 for(const uid of ['ca','ob','pending','sa']){if(uid!=='ca')await assertFails(getDoc(doc(db(uid),'billingSettings','a')));await assertFails(setDoc(doc(db(uid),'billingSettings','a'),settings));}
 await assertFails(updateDoc(doc(db('oa'),'billingSettings','a'),{priceAgorot:1.5,updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('oa'),'billingSettings','a'),{roundingThresholdAgorot:0,updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('oa'),'billingSettings','a'),{unitName:'',updatedAt:serverTimestamp()}));
});
test('new invoice snapshot is retained and cannot be edited by payment actors',async()=>{
 const f=db('oa'),snapshot={amountAgorot:28000,denominator:1000,rawNumerator:28000000,minimumNumerator:4200000,settings:{priceAgorot:2800,minimumUnitsMilli:1500,roundingThresholdAgorot:50,unitName:'وحدة'}};
 const bill={userId:'ca',generatorId:'a',status:'pending',amount:280,kwh:10,month:'نوفمبر',year:2026,createdAt:Date.now(),amountAgorot:28000,billingSnapshot:snapshot};
 await assertSucceeds(setDoc(doc(f,'bills','frozen'),bill));
 await assertFails(setDoc(doc(f,'bills','mismatch'),{...bill,amountAgorot:1}));
 await assertFails(updateDoc(doc(f,'bills','frozen'),{'billingSnapshot.settings.priceAgorot':1}));
 await assertFails(updateDoc(doc(db('ca'),'bills','frozen'),{billingSnapshot:{...snapshot,amountAgorot:1}}));
 await assertFails(getDoc(doc(db('cb'),'bills','frozen')));
});
async function seedReader(){await env.withSecurityRulesDisabled(async c=>{const f=c.firestore();await setDoc(doc(f,'users','ra'),profile('meter_reader','a','approved','ra'));await setDoc(doc(f,'meterStaff','ra'),{name:'عامل',generatorId:'a',active:true,inviteCode:'code'});await setDoc(doc(f,'readerRounds','a'),{generatorId:'a',roundId:'round',status:'open',date:1,cycleDays:10});await setDoc(doc(f,'meterAssignments','round_ca'),{generatorId:'a',readerUid:'ra',roundId:'round',name:'مشترك',address:'حي',number:'1',previousMilli:20000,averageMilli:1000});});}
test('meter invite consumed atomically once, forged self-approval and expired invite denied',async()=>{
 const code='a'.repeat(32),f=db('oa');await assertSucceeds(setDoc(doc(f,'meterInvites',code),{generatorId:'a',createdBy:'oa',createdAt:serverTimestamp(),expiresAt:0,revoked:false,usedBy:''}));
 const r=db('newreader'),user={...profile('meter_reader','a','approved','newreader'),inviteCode:code};await assertFails(setDoc(doc(r,'users','newreader'),user));
 const b=writeBatch(r);b.set(doc(r,'users','newreader'),user);b.set(doc(r,'meterStaff','newreader'),{name:'meter_reader',generatorId:'a',active:true,inviteCode:code});b.update(doc(r,'meterInvites',code),{usedBy:'newreader'});await assertSucceeds(b.commit());
 await assertFails(updateDoc(doc(db('other'),'meterInvites',code),{usedBy:'other'}));await assertFails(getDocs(collection(r,'meterInvites')));
 await assertFails(setDoc(doc(db('ob'),'meterInvites','b'.repeat(32)),{generatorId:'a',createdBy:'ob',createdAt:serverTimestamp(),expiresAt:0,revoked:false,usedBy:''}));
});
test('reader cannot see prices, money, past rounds or other generator; current row writes only',async()=>{
 await seedReader();const r=db('ra');await assertSucceeds(getDoc(doc(r,'meterAssignments','round_ca')));for(const [col,id] of [['bills','ba'],['billingSettings','a'],['generators','a'],['complaints','qa'],['users','ca']])await assertFails(getDoc(doc(r,col,id)));
 const value={generatorId:'a',roundId:'round',subscriberId:'ca',readerUid:'ra',currentMilli:21000,previousMilli:20000,confirmedJump:false,updatedBy:'ra',updatedAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(r,'meterReadings','round_ca'),value));await assertFails(updateDoc(doc(r,'meterReadings','round_ca'),{currentMilli:19000,updatedAt:serverTimestamp()}));await assertFails(updateDoc(doc(r,'meterReadings','round_ca'),{priceAgorot:1,updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(r,'meterReadings','round_ca'),{currentMilli:24000,updatedAt:serverTimestamp()}));await assertSucceeds(updateDoc(doc(r,'meterReadings','round_ca'),{currentMilli:24000,confirmedJump:true,updatedAt:serverTimestamp()}));
 await assertFails(getDoc(doc(db('cb'),'meterReadings','round_ca')));await assertFails(getDoc(doc(db('ob'),'meterReadings','round_ca')));
 await updateDoc(doc(db('oa'),'readerRounds','a'),{status:'closed'});await assertFails(getDoc(doc(r,'meterReadings','round_ca')));await assertFails(setDoc(doc(r,'meterReadings','round_ca'),value));
});
test('owner revocation immediately blocks reader and cannot be self-reversed',async()=>{await seedReader();const f=db('oa'),b=writeBatch(f);b.update(doc(f,'meterStaff','ra'),{active:false});b.update(doc(f,'users','ra'),{status:'suspended',rejectionReason:'إلغاء الصلاحية'});await assertSucceeds(b.commit());await assertFails(getDoc(doc(db('ra'),'readerRounds','a')));await assertFails(updateDoc(doc(db('ra'),'meterStaff','ra'),{active:true}));});
const cycleData=()=>({generatorId:'a',roundId:'round',subscriberId:'ca',userId:'ca',name:'مشترك',date:Date.now(),snapshot:{amountAgorot:10000},amountAgorot:10000,paidAgorot:0,paymentSequence:0,pendingPaymentId:'',published:false,status:'unpaid',revision:0});
async function seedCycle(){await seedReader();await env.withSecurityRulesDisabled(async c=>{const f=c.firestore();await setDoc(doc(f,'cycleBills','round_ca'),cycleData());await setDoc(doc(f,'accountBalances','ca'),{generatorId:'a',subscriberId:'ca',userId:'ca',billedAgorot:10000,collectedAgorot:0});await setDoc(doc(f,'billingSubscribers','ca'),{generatorId:'a',userId:'ca',name:'مشترك',phone:'',address:'حي',number:'1',previousMilli:20000,averageMilli:1000,recentDifferences:[1000],readerUid:'ra',active:true,lastRoundId:''});});}
test('new round collections owner only and isolated; no reader money or past/private subscriber data',async()=>{await seedCycle();const f=db('oa');const round={generatorId:'a',status:'open',date:Date.now(),cycleDays:10,settings:{priceAgorot:100},subscriberIds:['ca'],createdBy:'oa'};await assertSucceeds(setDoc(doc(f,'billingRounds','round'),round));await assertSucceeds(setDoc(doc(f,'billingLinks','ca'),{generatorId:'a',subscriberId:'ca'}));await assertSucceeds(setDoc(doc(f,'readingCorrections','x'),{generatorId:'a',billId:'round_ca',before:{},after:{},reason:'تصحيح',by:'oa',at:serverTimestamp()}));for(const [col,id]of [['billingRounds','round'],['billingSubscribers','ca'],['readingCorrections','x'],['accountBalances','ca'],['cycleBills','round_ca']]){await assertSucceeds(getDoc(doc(f,col,id)));for(const uid of ['ra','ob','cb']){await assertFails(getDoc(doc(db(uid),col,id)));await assertFails(setDoc(doc(db(uid),col,id),{...round}));}}await assertSucceeds(getDoc(doc(db('ca'),'accountBalances','ca')));await assertFails(getDoc(doc(db('ca'),'cycleBills','round_ca')));await assertFails(updateDoc(doc(db('ca'),'accountBalances','ca'),{collectedAgorot:10000}));await assertFails(updateDoc(doc(f,'readingCorrections','x'),{reason:'إخفاء'}));});
test('partial payment atomic submission and immutable approval cannot duplicate or exceed balance',async()=>{
 await seedCycle();const owner=db('oa'),c=db('ca');await updateDoc(doc(owner,'cycleBills','round_ca'),{published:true});await assertSucceeds(getDoc(doc(c,'cycleBills','round_ca')));
 const payment={generatorId:'a',billId:'round_ca',subscriberId:'ca',userId:'ca',roundId:'round',amountAgorot:4000,date:Date.now(),reference:'R1',method:'cash',status:'pending',sequence:1,submittedAt:serverTimestamp()};
 await assertFails(setDoc(doc(c,'cyclePayments','round_ca_1'),payment));let b=writeBatch(c);b.set(doc(c,'cyclePayments','round_ca_1'),payment);b.update(doc(c,'cycleBills','round_ca'),{pendingPaymentId:'round_ca_1',paymentSequence:1});await assertSucceeds(b.commit());await assertFails(updateDoc(doc(c,'cyclePayments','round_ca_1'),{status:'approved'}));
 b=writeBatch(owner);b.update(doc(owner,'cyclePayments','round_ca_1'),{status:'approved',reason:'',reviewedBy:'oa',reviewedAt:serverTimestamp()});b.update(doc(owner,'cycleBills','round_ca'),{paidAgorot:4000,pendingPaymentId:'',status:'partial'});b.update(doc(owner,'accountBalances','ca'),{collectedAgorot:4000});await assertSucceeds(b.commit());
 await assertFails(updateDoc(doc(owner,'cyclePayments','round_ca_1'),{status:'approved',reviewedAt:serverTimestamp()}));
 b=writeBatch(c);b.set(doc(c,'cyclePayments','round_ca_2'),{...payment,sequence:2,amountAgorot:6001});b.update(doc(c,'cycleBills','round_ca'),{pendingPaymentId:'round_ca_2',paymentSequence:2});await assertFails(b.commit());
 for(const uid of ['ra','cb','ob']){await assertFails(getDoc(doc(db(uid),'cyclePayments','round_ca_1')));await assertFails(setDoc(doc(db(uid),'cyclePayments','attack'),payment));}
});
test('offline reader write queues one row and reconciles after reconnect',async()=>{await seedReader();const r=db('ra');await getDoc(doc(r,'meterAssignments','round_ca'));await getDoc(doc(r,'readerRounds','a'));await getDoc(doc(r,'users','ra'));const {disableNetwork,enableNetwork,getDocFromCache}=await import('firebase/firestore');await disableNetwork(r);const pending=setDoc(doc(r,'meterReadings','round_ca'),{generatorId:'a',roundId:'round',subscriberId:'ca',readerUid:'ra',currentMilli:21000,previousMilli:20000,confirmedJump:false,updatedBy:'ra',updatedAt:serverTimestamp()});await new Promise(resolve=>setTimeout(resolve,20));assert.equal((await getDocFromCache(doc(r,'meterReadings','round_ca'))).metadata.hasPendingWrites,true);await enableNetwork(r);await assertSucceeds(pending);assert.equal((await getDoc(doc(r,'meterReadings','round_ca'))).data().currentMilli,21000);});
test('finance summaries, control and expense history owner-only; cross-tenant and reader denied',async()=>{
 await seedCycle();const f=db('oa'),summary={generatorId:'a',generation:'x',kind:'total',key:'all',billedAgorot:10000,collectedAgorot:0,outstandingAgorot:10000,costAgorot:0,fuelAgorot:0,maintenanceAgorot:0,wagesAgorot:0,equipmentAgorot:0,otherAgorot:0};
 await assertSucceeds(setDoc(doc(f,'financeControl','a'),{generatorId:'a',generation:'x',locked:false,token:'x',startedAt:1}));await assertSucceeds(setDoc(doc(f,'financeSummaries','a_x_total_all'),summary));const expense={generatorId:'a',amountAgorot:100,date:Date.now(),roundId:'round',category:'fuel',note:'وقود',deleted:false,createdBy:'oa',createdAt:serverTimestamp(),updatedBy:'oa',updatedAt:serverTimestamp()};await assertSucceeds(setDoc(doc(f,'expenses','e'),expense));await assertSucceeds(setDoc(doc(f,'expenseChanges','h'),{generatorId:'a',expenseId:'e',before:null,after:expense,by:'oa',at:serverTimestamp()}));
 for(const uid of ['ca','cb','ob','ra'])for(const [col,id,data]of [['financeControl','a',{generatorId:'a',generation:'x',locked:false,token:'x',startedAt:1}],['financeSummaries','a_x_total_all',summary],['expenses','e',expense],['expenseChanges','h',{generatorId:'a',expenseId:'e',by:uid,at:serverTimestamp()}]]){await assertFails(getDoc(doc(db(uid),col,id)));await assertFails(setDoc(doc(db(uid),col,id),data));}
 await assertFails(updateDoc(doc(f,'expenses','e'),{amountAgorot:1.5,updatedAt:serverTimestamp()}));await assertFails(updateDoc(doc(f,'expenseChanges','h'),{by:'other'}));
 await updateDoc(doc(f,'financeControl','a'),{locked:true});await assertFails(updateDoc(doc(f,'expenses','e'),{amountAgorot:200,updatedAt:serverTimestamp()}));await assertFails(updateDoc(doc(f,'cycleBills','round_ca'),{amountAgorot:20000}));
});
test('approved cycle payment reversal requires reason and matching bill balance once',async()=>{await seedCycle();await env.withSecurityRulesDisabled(async c=>{await updateDoc(doc(c.firestore(),'cycleBills','round_ca'),{paidAgorot:4000,status:'partial'});await setDoc(doc(c.firestore(),'cyclePayments','p'),{generatorId:'a',billId:'round_ca',userId:'ca',subscriberId:'ca',roundId:'round',amountAgorot:4000,status:'approved'});});const f=db('oa'),b=writeBatch(f);b.update(doc(f,'cyclePayments','p'),{status:'reversed',reversalReason:'تصحيح',reversedBy:'oa',reversedAt:serverTimestamp()});b.update(doc(f,'cycleBills','round_ca'),{paidAgorot:0,status:'unpaid'});await assertSucceeds(b.commit());await assertFails(updateDoc(doc(f,'cyclePayments','p'),{status:'reversed',reversedAt:serverTimestamp()}));});
test('publication and share markers are owner-only; linked bill and alert publish atomically',async()=>{await seedCycle();const f=db('oa');const b=writeBatch(f);b.update(doc(f,'cycleBills','round_ca'),{published:true,publicationRecipient:'ca'});b.set(doc(f,'alerts','cycle_round_ca'),{generatorId:'a',userId:'ca',title:'فاتورة جديدة',body:'راجع الكشف',type:'newBill',read:false,createdAt:Date.now()});await assertSucceeds(b.commit());await assertSucceeds(getDoc(doc(db('ca'),'cycleBills','round_ca')));await assertSucceeds(getDoc(doc(db('ca'),'alerts','cycle_round_ca')));const marker={generatorId:'a',billId:'round_ca',roundId:'round',status:'marked',by:'oa',at:serverTimestamp()};await assertSucceeds(setDoc(doc(f,'billShares','round_ca'),marker));for(const uid of ['ra','ca','cb','ob']){await assertFails(getDoc(doc(db(uid),'billShares','round_ca')));await assertFails(setDoc(doc(db(uid),'billShares','round_ca'),marker));await assertFails(updateDoc(doc(db(uid),'cycleBills','round_ca'),{published:false}));}});
test('expired and revoked invitations never create a reader; unauthenticated codes are private',async()=>{for(const variant of ['expired','revoked']){const code=(variant=='expired'?'c':'d').repeat(32);await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'meterInvites',code),{generatorId:'a',createdBy:'oa',createdAt:serverTimestamp(),expiresAt:variant=='expired'?1:0,revoked:variant=='revoked',usedBy:''}));const f=db('fresh'),b=writeBatch(f);b.set(doc(f,'users','fresh'),{...profile('meter_reader','a','approved','fresh'),inviteCode:code});b.set(doc(f,'meterStaff','fresh'),{name:'meter_reader',generatorId:'a',active:true,inviteCode:code});b.update(doc(f,'meterInvites',code),{usedBy:'fresh'});await assertFails(b.commit());await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'meterInvites',code)));}});
test('summary updates remain exact under concurrent transactions',async()=>{const f=db('oa'),ref=doc(f,'financeSummaries','a_x_total_all');await setDoc(ref,{generatorId:'a',generation:'x',kind:'total',key:'all',billedAgorot:10000,collectedAgorot:0,outstandingAgorot:10000,costAgorot:0,fuelAgorot:0,maintenanceAgorot:0,wagesAgorot:0,equipmentAgorot:0,otherAgorot:0});async function increment(){await runTransaction(f,async tx=>{const d=(await tx.get(ref)).data();tx.update(ref,{collectedAgorot:d.collectedAgorot+100,outstandingAgorot:d.outstandingAgorot-100});});}await Promise.all([increment(),increment()]);assert.equal((await getDoc(ref)).data().collectedAgorot,200);assert.equal((await getDoc(ref)).data().outstandingAgorot,9800);});
test('manual account linking can repair payment ownership without altering amounts',async()=>{await seedCycle();await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'cyclePayments','manual'),{generatorId:'a',billId:'round_ca',userId:'',status:'approved',amountAgorot:1000});});const f=db('oa');await assertSucceeds(updateDoc(doc(f,'cyclePayments','manual'),{userId:'ca'}));await assertSucceeds(getDoc(doc(db('ca'),'cyclePayments','manual')));await assertFails(updateDoc(doc(f,'cyclePayments','manual'),{userId:'cb'}));await assertFails(updateDoc(doc(db('ca'),'cyclePayments','manual'),{amountAgorot:1}));});
test('own plain contacts editable for consumers owners readers without credential escalation',async()=>{await seedReader();for(const uid of ['ca','oa','ra']){const f=db(uid);await assertSucceeds(updateDoc(doc(f,'users',uid),{phone:'0561234567',idNumber:'123456789',address:'عنوان جديد'}));for(const data of [{role:'super_admin'},{status:'approved',generatorId:'b'},{subscriptionStatus:'inactive'},{credentialVersion:3},{email:'other@example.test'},{phone:'123'},{idNumber:'abc'}])await assertFails(updateDoc(doc(f,'users',uid),data));}await assertFails(updateDoc(doc(db('cb'),'users','ca'),{phone:'0591234567'}));});
test('owner and consumer enrollment require mobile; legacy missing contact remains editable',async()=>{const f=db('new');await assertFails(setDoc(doc(f,'users','new'),{...profile('user','a','pending','new'),phone:'',subscriptionStatus:'inactive'}));await assertFails(setDoc(doc(f,'users','new'),{...profile('user','a','pending','new'),phone:'123',subscriptionStatus:'inactive'}));await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users','ca'),{phone:''}));await assertSucceeds(updateDoc(doc(db('ca'),'users','ca'),{address:'بلا إغلاق الحساب'}));});
