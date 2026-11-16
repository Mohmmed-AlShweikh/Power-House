import {test} from 'node:test';
import assert from 'node:assert/strict';
// No production fallback, real phone numbers, credentials or payload logging.
if (process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') throw new Error('Local Auth emulator required');
const base='http://127.0.0.1:9099';
async function post(method, body) {
 const r=await fetch(`${base}/identitytoolkit.googleapis.com/v1/accounts:${method}?key=emulator-only`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
 const result=await r.json(); if(!r.ok) throw new Error(result.error?.message?.split(' : ')[0]??'AUTH_ERROR');return result;
}
async function otp(phoneNumber,idToken) {
 const session=await post('sendVerificationCode',{phoneNumber,recaptchaToken:'emulator-only'});
 const codes=await(await fetch(`${base}/emulator/v1/projects/demo-generator-portal/verificationCodes`)).json();
 const code=codes.verificationCodes.find(c=>c.sessionInfo===session.sessionInfo).code;
 return post('signInWithPhoneNumber',{sessionInfo:session.sessionInfo,code,...(idToken?{idToken}:{})});
}
test('phone-first linked password and both logins retain a single UID',async()=>{
 const first=await otp('+16505550101');
 await post('update',{idToken:first.idToken,email:'123456781@powershare.app',password:'Strong123',returnSecureToken:true});
 const password=await post('signInWithPassword',{email:'123456781@powershare.app',password:'Strong123',returnSecureToken:true});
 const phone=await otp('+16505550101');
 assert.equal(password.localId,first.localId);assert.equal(phone.localId,first.localId);
});
test('ID-first phone linking retains UID, duplicate phone cannot steal account',async()=>{
 const first=await post('signUp',{email:'123456782@powershare.app',password:'Strong123',returnSecureToken:true});
 const linked=await otp('+16505550102',first.idToken);assert.equal(linked.localId,first.localId);
 const phone=await otp('+16505550102');assert.equal(phone.localId,first.localId);
 const other=await post('signUp',{email:'123456783@powershare.app',password:'Strong123',returnSecureToken:true});
 const collision=await otp('+16505550102',other.idToken);
 assert.ok(collision.temporaryProof);assert.equal(collision.idToken,undefined);
 assert.equal((await otp('+16505550102')).localId,first.localId);
});
test('OTP password update invalidates old password and retains UID',async()=>{
 const first=await post('signUp',{email:'123456784@powershare.app',password:'Strong123',returnSecureToken:true});
 await otp('+16505550104',first.idToken);
 const verified=await otp('+16505550104');
 await post('update',{idToken:verified.idToken,password:'Changed123',returnSecureToken:true});
 const next=await post('signInWithPassword',{email:'123456784@powershare.app',password:'Changed123',returnSecureToken:true});assert.equal(next.localId,first.localId);
 await assert.rejects(post('signInWithPassword',{email:'123456784@powershare.app',password:'Strong123',returnSecureToken:true}));
});
