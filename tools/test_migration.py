import importlib.machinery
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT=Path(__file__).with_name('migrate_to_multi_generator')
loader=importlib.machinery.SourceFileLoader('migration',str(SCRIPT))
spec=importlib.util.spec_from_loader(loader.name,loader)
migration=importlib.util.module_from_spec(spec);loader.exec_module(migration)
class MigrationTests(unittest.TestCase):
    def backup(self):
        return {'projectId':'demo-local','documents':[
            {'path':'system/generator','data':{'isOn':True,'pricePerKwh':3,'phone':'must-not-publish'}},
            {'path':'users/owner','data':{'role':'generator_owner','status':'approved'}},
            {'path':'users/consumer','data':{'role':'user'}},
            {'path':'users/sa','data':{'role':'super_admin'}},
            {'path':'bills/old','data':{'userId':'consumer','amount':200}},
            {'path':'consumption/consumer','data':{'weeklyUsage':[{'kwh':10}]}},
            {'path':'users/other','data':{'role':'user','generatorId':'other-tenant'}},
        ]}
    def test_default_scope_projection_and_preserve_explicit_tenants(self):
        plan=migration.plan_backup(self.backup());self.assertEqual(plan['blockers'],[])
        changes={c['path']:c for c in plan['changes']}
        self.assertNotIn('users/sa',changes);self.assertNotIn('users/other',changes)
        self.assertEqual(changes['users/consumer']['data'],{'generatorId':'default'})
        self.assertTrue(changes['generators/default']['data']['isOn'])
        self.assertEqual(set(changes['generatorDirectory/default']['data']),{'name','sector','status','subscriptionStatus'})
        self.assertNotIn('phone',changes['generators/default']['data'])
        self.assertEqual(changes['consumption/consumer']['data']['weeklyUsage'][0]['generatorId'],'default')
    def test_idempotent_after_applying_local_plan(self):
        backup=self.backup();plan=migration.plan_backup(backup)
        docs={r['path']:r['data'] for r in backup['documents']}
        for c in plan['changes']:
            if c['operation']=='create':docs[c['path']]=c['data']
            else:docs[c['path']].update(c['data'])
        backup['documents']=[{'path':p,'data':d} for p,d in docs.items()]
        self.assertEqual(migration.plan_backup(backup)['changes'],[])
    def test_cross_tenant_ambiguous_record_blocks_apply(self):
        b=self.backup();b['documents'].append({'path':'bills/ambiguous','data':{'userId':'other'}})
        self.assertTrue(migration.plan_backup(b)['blockers'])
    def test_default_cli_is_offline_dry_run(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'backup.json';p.write_text(json.dumps(self.backup()))
            result=subprocess.run([str(SCRIPT),'--backup',str(p)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(json.loads(result.stdout)['defaultOwnerUid'],'owner')
            self.assertNotIn('firebase_admin',result.stderr)
    def test_apply_requires_explicit_matching_project_confirmation(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'backup.json';p.write_text(json.dumps(self.backup()))
            result=subprocess.run([str(SCRIPT),'--backup',str(p),'--apply'],capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0);self.assertIn('confirm-project',result.stderr)
if __name__=='__main__':unittest.main()
