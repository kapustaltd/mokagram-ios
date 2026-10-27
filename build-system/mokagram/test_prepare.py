"""Tests for prepare.py. Run: python3 -I build-system/mokagram/test_prepare.py"""
import base64
import contextlib
import io
import os
import shutil
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import prepare  # noqa: E402

PROFILES = ['Telegram', 'Intents', 'NotificationContent', 'NotificationService', 'Share', 'Widget', 'BroadcastUpload']
SIGNING_ENV = ['MOKAGRAM_SIGNING_P12_BASE64', 'MOKAGRAM_SIGNING_P12_PASSWORD', 'MOKAGRAM_PROFILES_ZIP_BASE64', 'MOKAGRAM_TEAM_ID', 'MOKAGRAM_BUNDLE_ID']


class PrepareTests(unittest.TestCase):
    def setUp(self):
        self.saved_cwd = os.getcwd()
        self.saved_env = {k: os.environ.get(k) for k in SIGNING_ENV + ['TELEGRAM_API_ID', 'TELEGRAM_API_HASH']}
        for k in self.saved_env:
            os.environ.pop(k, None)
        self.work = Path(tempfile.mkdtemp())
        (self.work / 'build-system/mokagram').mkdir(parents=True)
        shutil.copy(HERE / 'configuration.json', self.work / 'build-system/mokagram/configuration.json')
        os.chdir(self.work)

    def tearDown(self):
        os.chdir(self.saved_cwd)
        for k, v in self.saved_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        shutil.rmtree(self.work)

    def real_signing_env(self, profiles):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            for name in profiles:
                archive.writestr(f'{name}.mobileprovision', f'profile {name}')
        os.environ.update({
            'MOKAGRAM_SIGNING_P12_BASE64': base64.b64encode(b'p12 bytes').decode(),
            'MOKAGRAM_SIGNING_P12_PASSWORD': 'secret',
            'MOKAGRAM_PROFILES_ZIP_BASE64': base64.b64encode(buffer.getvalue()).decode(),
            'MOKAGRAM_TEAM_ID': 'ABCDE12345',
            'MOKAGRAM_BUNDLE_ID': 'ltd.example.moka',
        })

    def test_placeholder_mode_unchanged(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            prepare.prepare()
        self.assertIn('Prepared Mokagram configuration and placeholder signing material', output.getvalue())
        self.assertTrue((self.work / 'build-input/mokagram/signing/certs/Placeholder.p12').exists())
        self.assertTrue((self.work / 'build-input/mokagram/signing/profiles/Share.mobileprovision').exists())

    def test_real_signing_installs_certificate_and_profiles(self):
        self.real_signing_env(PROFILES)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            prepare.prepare()
        signing = self.work / 'build-input/mokagram/signing'
        self.assertEqual((signing / 'certs/Distribution.p12').read_bytes(), b'p12 bytes')
        self.assertFalse((signing / 'certs/Placeholder.p12').exists())
        for name in PROFILES:
            self.assertEqual((signing / f'profiles/{name}.mobileprovision').read_text(), f'profile {name}')
        self.assertIn('Prepared Mokagram configuration and signing material for team ABCDE12345', output.getvalue())
        config = (self.work / 'build-input/mokagram/configuration.json').read_text()
        self.assertIn('"bundle_id": "ltd.example.moka"', config)

    def test_real_signing_reports_missing_profile(self):
        self.real_signing_env([name for name in PROFILES if name != 'Share'])
        with self.assertRaises(SystemExit) as raised:
            prepare.prepare()
        self.assertEqual(str(raised.exception), 'missing provisioning profile: Share')

    def test_real_signing_requires_every_variable(self):
        self.real_signing_env(PROFILES)
        os.environ.pop('MOKAGRAM_SIGNING_P12_PASSWORD')
        with self.assertRaises(SystemExit) as raised:
            prepare.prepare()
        self.assertIn('MOKAGRAM_SIGNING_P12_PASSWORD', str(raised.exception))


if __name__ == '__main__':
    unittest.main()
