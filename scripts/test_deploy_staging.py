"""Test the launcher with fake gh/scp/ssh. Never contact or mutate a VPS."""
from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SHA = 'a' * 40


class DeployStaging(unittest.TestCase):
    def run_launcher(self, bad_sha=False):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            commands = folder / 'commands'
            commands.mkdir()
            gh = commands / 'gh'
            gh.write_text('''#!/usr/bin/env python3
import base64,json,os,sys
args=sys.argv[1:]
with open(os.environ['QA_TRACE'],'a') as stream:stream.write(json.dumps(args)+'\\n')
if args[:2]==['auth','status'] or args[:2]==['run','list']:raise SystemExit(0)
if args[0]!='api':raise SystemExit(2)
endpoint=args[1] if args[1]!='-X' else args[3]
if '/commits/' in endpoint:
 print('bad' if os.environ.get('QA_BAD_SHA') else 'a'*40)
elif '/contents/' in endpoint:
 if not endpoint.endswith('?ref='+'a'*40):raise SystemExit(3)
 text='#!/usr/bin/env bash\\nexit 0\\n' if '.sh?' in endpoint else 'pass\\n'
 print(base64.b64encode(text.encode()).decode())
elif endpoint.endswith('/actions/runners/registration-token'):print('fake-one-time-registration-token')
elif endpoint.endswith('/actions/runners'):print('fake runner status')
else:raise SystemExit(4)
''')
            gh.chmod(0o755)
            for name in ['ssh', 'scp']:
                script = commands / name
                script.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "' + name + '" >> "$QA_TRANSPORT"\n')
                script.chmod(0o755)
            trace, transport = folder / 'trace', folder / 'transport'
            env = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ['PATH'],
                       QA_TRACE=str(trace), QA_TRANSPORT=str(transport))
            env.pop('REINA_RTS_DEPLOY_REF', None)
            if bad_sha:
                env['QA_BAD_SHA'] = '1'
            result = subprocess.run(['bash', str(ROOT / 'ops/vienna/deploy-one-shot-termux.sh')],
                                    env=env, capture_output=True, text=True, timeout=10)
            calls = [json.loads(line) for line in trace.read_text().splitlines()]
            return result, calls, transport.read_text().splitlines() if transport.exists() else []

    def test_one_commit_is_used_for_every_staged_file(self):
        result, calls, transports = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        files = [call[1] for call in calls if call[0] == 'api' and '/contents/' in call[1]]
        self.assertEqual(len(files), 5)
        self.assertTrue(all(item.endswith('?ref=' + SHA) for item in files))
        self.assertEqual(transports, ['scp', 'ssh'])

    def test_invalid_commit_stops_before_registration_or_upload(self):
        result, calls, transports = self.run_launcher(bad_sha=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(transports, [])
        self.assertFalse(any('registration-token' in str(call) for call in calls))


if __name__ == '__main__':
    unittest.main()
