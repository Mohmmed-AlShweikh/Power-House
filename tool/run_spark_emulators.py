"""Local demo emulators only; suppress the CLI's automatic test email action links."""
import os, subprocess, sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
env = os.environ.copy()
env.update(JAVA_HOME='/workspace/toolchains/jdk21', XDG_CONFIG_HOME='/workspace/toolchains/config', FIREBASE_EMULATORS_PATH='/workspace/toolchains/firebase-emulators', FIREBASE_CLI_DISABLE_UPDATE_CHECK='1', CI='1')
env['PATH'] = env['JAVA_HOME'] + '/bin:' + env['PATH']
command = [str(root / 'tools/rules-tests/node_modules/.bin/firebase'), 'emulators:exec', '--project', 'demo-generator-portal', '--config', 'firebase.auth-test.json', '--only', 'auth,firestore', 'node --test tools/rules-tests/rules.test.mjs tools/rules-tests/auth.test.mjs']
with subprocess.Popen(command, cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
    for line in process.stdout:
        if 'To verify' in line or 'emulator/action' in line or 'To reset' in line:
            continue
        sys.stdout.write(line)
    sys.exit(process.wait())
