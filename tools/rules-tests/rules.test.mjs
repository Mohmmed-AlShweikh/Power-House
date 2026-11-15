import {before, beforeEach, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where, writeBatch} from 'firebase/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')) throw new Error('Local Firestore emulator required; production is forbidden');
let env;
const profile=(role,generatorId,status='approved')=>({name:role,phone:'+970591234567',role,generatorId,status,subscriptionStatus:'active',ampereLimit:0,createdAt:1});
const generator=(ownerUid,status='approved')=>({name:'مولد '+ownerUid,sector:'غزة',ownerUid,status,subscriptionStatus:'active',rejectionReason:'',createdAt:1,isOn:false,pricePerKwh:2});
const directory=g=>({name:g.name,sector:g.sector,status:g.status,subscriptionStatus:g.subscriptionStatus});
const db=uid=>env.authenticatedContext(uid,{phone_number:'+970591234567'}).firestore();
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-generator-portal',firestore:{host:'127.0.0.1',port:8089,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async(context)=>{
  const f=context.firestore();
  for(const [id,data] of Object.entries({sa:{role:'super_admin'},oa:profile('generator_owner','a'),ob:profile('generator_owner','b'),ca:profile('user','a'),cb:profile('user','b'),pending:profile('user','a','pending'),legacy:profile('generator_owner','default')})) await setDoc(doc(f,'users',id),data);
  for(const id of ['a','b']){const g=generator('o'+id);await setDoc(doc(f,'generators',id),g);await setDoc(doc(f,'generatorDirectory',id),directory(g));}
  for(const [id,userId,generatorId] of [['ba','ca','a'],['bb','cb','b'],['forged','ca','b']]) await setDoc(doc(f,'bills',id),{userId,generatorId,status:'pending',amount:100,kwh:50});
  await setDoc(doc(f,'consumption','ca'),{generatorId:'a',userId:'ca',monthlyUsage:50,dailyUsage:2});
  await setDoc(doc(f,'alerts','aa'),{generatorId:'a',userId:'ca',read:false});
  await setDoc(doc(f,'complaints','qa'),{generatorId:'a',userId:'ca',userName:'user',status:'open',text:'شكوى',createdAt:1});
  await setDoc(doc(f,'system','generator'),{isOn:true,pricePerKwh:2});
 });
});

test('anonymous has no access; signed-in directory does not require a profile',async()=>{
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users','ca')));
 await assertSucceeds(getDocs(query(collection(db('fresh'),'generatorDirectory'),where('status','==','approved'),where('subscriptionStatus','==','active'))));
 await assertFails(getDocs(collection(db('fresh'),'users')));
});
test('public projection never accepts private data, even from super-admin',async()=>{
 await assertFails(updateDoc(doc(db('sa'),'generatorDirectory','a'),{phone:'secret'}));
 await assertFails(updateDoc(doc(db('oa'),'generatorDirectory','a'),{status:'approved'}));
 const data=(await getDoc(doc(db('ca'),'generatorDirectory','a'))).data();
 assert.deepEqual(Object.keys(data).sort(),['name','sector','status','subscriptionStatus']);
});
test('self edits cannot promote, approve, reassign tenant or subscription',async()=>{
 for(const payload of [{role:'super_admin'},{status:'approved',role:'generator_owner'},{generatorId:'b'},{subscriptionStatus:'inactive'}]) await assertFails(updateDoc(doc(db('ca'),'users','ca'),payload));
 await assertSucceeds(updateDoc(doc(db('ca'),'users','ca'),{name:'اسم جديد',address:'غزة'}));
 await assertFails(deleteDoc(doc(db('ca'),'users','ca')));
 await assertFails(setDoc(doc(db('new'),'users','new'),{...profile('super_admin','a'),phone:'+970591234567'}));
});
test('owner enrollment must be a verified-phone atomic pair with pending state',async()=>{
 const f=db('new-owner'),g=generator('new-owner','pending'),u=profile('generator_owner','random-generator','pending');
 await assertFails(setDoc(doc(f,'users','new-owner'),u));
 const b=writeBatch(f);b.set(doc(f,'users','new-owner'),u);b.set(doc(f,'generators','random-generator'),g);await assertSucceeds(b.commit());
 await assertFails(updateDoc(doc(f,'generators','random-generator'),{status:'approved'}));
 await assertFails(updateDoc(doc(f,'users','new-owner'),{status:'approved'}));
});
test('unverified phone and owner impersonation are denied',async()=>{
 const f=env.authenticatedContext('unverified').firestore();
 const b=writeBatch(f);b.set(doc(f,'users','unverified'),profile('generator_owner','unverified','pending'));b.set(doc(f,'generators','unverified'),generator('unverified','pending'));await assertFails(b.commit());
 const f2=db('new'),c=writeBatch(f2);c.set(doc(f2,'users','new'),profile('generator_owner','other','pending'));c.set(doc(f2,'generators','other'),generator('someone-else','pending'));await assertFails(c.commit());
});
test('consumer enrollment only into approved AND active directory, always pending',async()=>{
 const f=db('new-consumer');
 await assertSucceeds(setDoc(doc(f,'users','new-consumer'),{...profile('user','a','pending'),subscriptionStatus:'inactive'}));
 await assertFails(setDoc(doc(db('bad'),'users','bad'),{...profile('user','a'),subscriptionStatus:'active'}));
 await updateDoc(doc(db('sa'),'generators','b'),{subscriptionStatus:'inactive'});
 await assertFails(setDoc(doc(db('stale'),'users','stale'),{...profile('user','b','pending'),subscriptionStatus:'inactive'}));
 await updateDoc(doc(db('sa'),'generatorDirectory','b'),{subscriptionStatus:'inactive'});
 await assertFails(setDoc(doc(db('blocked'),'users','blocked'),{...profile('user','b','pending'),subscriptionStatus:'inactive'}));
});
test('consumer reads own profile/data only and cannot cross generator even with same userId',async()=>{
 await assertSucceeds(getDoc(doc(db('ca'),'users','ca')));
 await assertFails(getDoc(doc(db('ca'),'users','cb')));
 await assertSucceeds(getDocs(query(collection(db('ca'),'bills'),where('generatorId','==','a'),where('userId','==','ca'))));
 await assertFails(getDoc(doc(db('ca'),'bills','bb')));
 await assertFails(getDoc(doc(db('ca'),'bills','forged')));
 await assertFails(getDocs(collection(db('ca'),'bills')));
 await assertFails(getDoc(doc(db('cb'),'consumption','ca')));
});
test('owner queries require tenant and consumer-role constraints; cross-tenant writes fail',async()=>{
 await assertSucceeds(getDocs(query(collection(db('oa'),'users'),where('generatorId','==','a'),where('role','in',['user','consumer']))));
 await assertFails(getDocs(collection(db('oa'),'users')));
 await assertSucceeds(getDocs(query(collection(db('oa'),'bills'),where('generatorId','==','a'))));
 await assertFails(getDocs(collection(db('oa'),'bills')));
 await assertFails(updateDoc(doc(db('ob'),'users','pending'),{status:'approved'}));
 await assertSucceeds(updateDoc(doc(db('oa'),'users','pending'),{status:'approved',subscriptionStatus:'active'}));
 await assertFails(updateDoc(doc(db('oa'),'users','pending'),{generatorId:'b'}));
 await assertFails(updateDoc(doc(db('oa'),'bills','bb'),{status:'paid'}));
});
test('receipts cannot change amounts, approve payment, change user or tenant',async()=>{
 const f=db('ca');
 for(const change of [{amount:0},{status:'paid'},{userId:'cb'},{generatorId:'b'}]) await assertFails(updateDoc(doc(f,'bills','ba'),change));
 await assertSucceeds(updateDoc(doc(f,'bills','ba'),{status:'pendingReview',receiptBase64:'YWJj'}));
 await assertFails(updateDoc(doc(f,'bills','ba'),{receiptBase64:'cmVwbGFjZQ=='}));
 await assertFails(setDoc(doc(f,'bills','made-up'),{generatorId:'a',userId:'ca',status:'pending',amount:1,kwh:1,month:'نوفمبر',year:2026,createdAt:1}));
});
test('billing cannot target a different tenant member, even with matching payload gid',async()=>{
 await assertFails(setDoc(doc(db('oa'),'bills','new'),{generatorId:'a',userId:'cb',status:'pending',amount:1,kwh:1}));
 await assertSucceeds(setDoc(doc(db('oa'),'bills','new'),{generatorId:'a',userId:'ca',status:'pending',amount:1,kwh:1,month:'نوفمبر',year:2026,createdAt:1}));
});
test('complaints and replies remain own-tenant and preserve immutable bindings',async()=>{
 await assertSucceeds(setDoc(doc(db('ca'),'complaints','new'),{generatorId:'a',userId:'ca',userName:'user',status:'open',text:'نص',createdAt:1}));
 await assertFails(setDoc(doc(db('ca'),'complaints','foreign'),{generatorId:'b',userId:'ca',userName:'user',status:'open',text:'نص',createdAt:1}));
 await assertSucceeds(updateDoc(doc(db('oa'),'complaints','qa'),{status:'resolved',reply:'تم',replyAt:2}));
 await assertFails(updateDoc(doc(db('ob'),'complaints','qa'),{reply:'رد'}));
});
test('suspension blocks operational access immediately; own status remains readable',async()=>{
 await updateDoc(doc(db('sa'),'generators','a'),{status:'suspended'});
 await assertFails(getDoc(doc(db('oa'),'bills','ba')));
 await assertFails(getDoc(doc(db('ca'),'bills','ba')));
 await assertSucceeds(getDoc(doc(db('ca'),'users','ca')));
 await assertSucceeds(getDoc(doc(db('ca'),'generators','a')));
});
test('pending accounts cannot access operational records',async()=>{
 await assertSucceeds(getDoc(doc(db('pending'),'users','pending')));
 await assertFails(getDocs(query(collection(db('pending'),'bills'),where('generatorId','==','a'),where('userId','==','pending'))));
 await assertFails(updateDoc(doc(db('pending'),'generators','a'),{isOn:true}));
});
test('alerts are tenant+recipient scoped, including read flags',async()=>{
 await assertSucceeds(updateDoc(doc(db('ca'),'alerts','aa'),{read:true}));
 await assertFails(updateDoc(doc(db('cb'),'alerts','aa'),{read:true}));
 await assertFails(updateDoc(doc(db('ca'),'alerts','aa'),{generatorId:'b'}));
 await assertSucceeds(setDoc(doc(db('ca'),'alerts','complaint'),{generatorId:'a',userId:'oa',title:'شكوى',body:'نص',type:'complaint',read:false,createdAt:1}));
 await assertFails(setDoc(doc(db('ca'),'alerts','fake'),{generatorId:'b',userId:'ob',title:'x',body:'x',type:'complaint',read:false,createdAt:1}));
});
test('legacy generator configuration is reserved for default membership',async()=>{
 await updateDoc(doc(db('sa'),'users','legacy'),{subscriptionStatus:'inactive'});
 await assertSucceeds(getDoc(doc(db('legacy'),'system','generator')));
 await assertFails(getDoc(doc(db('oa'),'system','generator')));
 await assertFails(updateDoc(doc(db('ob'),'system','generator'),{isOn:true}));
});
test('super-admin can review tenant records and atomically publish projection',async()=>{
 const f=db('sa'),b=writeBatch(f);b.update(doc(f,'generators','a'),{status:'rejected',rejectionReason:'سبب'});b.update(doc(f,'users','oa'),{status:'rejected'});b.set(doc(f,'generatorDirectory','a'),{...directory(generator('oa')),status:'rejected'});await assertSucceeds(b.commit());
 await assertSucceeds(getDocs(collection(f,'users')));await assertSucceeds(getDocs(collection(f,'generators')));
});

test('malformed member-controlled payloads cannot poison owner feeds',async()=>{
 await assertFails(updateDoc(doc(db('ca'),'users','ca'),{phone:{bad:true}}));
 await assertFails(setDoc(doc(db('ca'),'alerts','malformed'),{generatorId:'a',userId:'oa',title:{bad:true},body:'نص',type:'complaint',read:false,createdAt:1}));
 await assertFails(setDoc(doc(db('ca'),'complaints','malformed'),{generatorId:'a',userId:'ca',userName:'user',status:'open',text:'نص',createdAt:'bad'}));
 await assertFails(updateDoc(doc(db('oa'),'generators','a'),{isOn:{bad:true}}));
 await assertFails(setDoc(doc(db('ca'),'complaints','bad-date'),{generatorId:'a',userId:'ca',userName:'user',status:'open',text:'نص',createdAt:1e18}));
});

test('new owners cannot reserve or hijack the legacy default namespace',async()=>{
 const f=db('hijacker'),batch=writeBatch(f);
 batch.set(doc(f,'users','hijacker'),profile('generator_owner','default','pending'));
 batch.set(doc(f,'generators','default'),generator('hijacker','pending'));
 await assertFails(batch.commit());
});

test('super-admin has no implicit default tenant or owner-readable mailbox',async()=>{
 await setDoc(doc(db('sa'),'alerts','private-admin'),{userId:'sa',generatorId:'default',title:'خاص',body:'خاص',type:'newOwnerRequest',read:false,createdAt:1});
 await assertSucceeds(getDoc(doc(db('sa'),'alerts','private-admin')));
 await assertFails(getDoc(doc(db('legacy'),'alerts','private-admin')));
 await assertFails(setDoc(doc(db('legacy'),'alerts','to-admin'),{userId:'sa',generatorId:'default',title:'x',body:'x',type:'complaint',read:false,createdAt:1}));
});
