import {test} from 'node:test';
import assert from 'node:assert/strict';
if(process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw new Error('Local demo Auth required');
const base='http://127.0.0.1:9099';
async function post(method,body){const r=await fetch(`${base}/identitytoolkit.googleapis.com/v1/accounts:${method}?key=emulator-only`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await r.json();if(!r.ok)throw new Error(data.error?.message?.split(' : ')[0]??'AUTH_ERROR');return data;}
async function oob(type,email){const data=await(await fetch(`${base}/emulator/v1/projects/demo-generator-portal/oobCodes`)).json();return data.oobCodes.filter(c=>c.requestType===type&&c.email===email).at(-1).oobCode;}
test('real email signup starts unverified; email action verifies the same UID',async()=>{
 const email='register@example.test';const account=await post('signUp',{email,password:'Strong123',returnSecureToken:true});
 const before=await post('lookup',{idToken:account.idToken});assert.equal(before.users[0].emailVerified,false);
 await post('sendOobCode',{requestType:'VERIFY_EMAIL',idToken:account.idToken});await post('update',{oobCode:await oob('VERIFY_EMAIL',email)});
 const signed=await post('signInWithPassword',{email,password:'Strong123',returnSecureToken:true});assert.equal(signed.localId,account.localId);
 const after=await post('lookup',{idToken:signed.idToken});assert.equal(after.users[0].emailVerified,true);
});
test('email password reset retains UID and invalidates old password',async()=>{
 const email='reset@example.test',account=await post('signUp',{email,password:'Strong123',returnSecureToken:true});
 await post('sendOobCode',{requestType:'PASSWORD_RESET',email});await post('resetPassword',{oobCode:await oob('PASSWORD_RESET',email),newPassword:'Changed123'});
 const signed=await post('signInWithPassword',{email,password:'Changed123',returnSecureToken:true});assert.equal(signed.localId,account.localId);
 await assert.rejects(post('signInWithPassword',{email,password:'Strong123',returnSecureToken:true}));
});
