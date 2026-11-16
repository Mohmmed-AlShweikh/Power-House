import {before,beforeEach,after,test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,collection,getDocs,query,where,writeBatch,runTransaction} from 'firebase/firestore';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8089')throw new Error('Local demo Firestore required');
let env;
const profile=(role,generatorId,status='approved',uid='test')=>({name:role,email:uid+'@example.test',credentialVersion:2,phone:'',idNumber:'',role,generatorId,status,subscriptionStatus:'active',ampereLimit:0,createdAt:1});
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
test('owner registration is atomic pending pair, contact phone is optional and never verified identity',async()=>{
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
