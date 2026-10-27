"""Prepare build-only signing material; the resulting IPA requires re-signing."""
import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import uuid


def run(*args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def prepare():
    config = json.loads(Path('build-system/mokagram/configuration.json').read_text())
    for key, name in (('bundle_id', 'MOKAGRAM_BUNDLE_ID'), ('team_id', 'MOKAGRAM_TEAM_ID')):
        if os.environ.get(name, '').strip():
            config[key] = os.environ[name].strip()
    api_id = os.environ.get('TELEGRAM_API_ID', '').strip()
    api_hash = os.environ.get('TELEGRAM_API_HASH', '').strip()
    if bool(api_id) != bool(api_hash):
        raise SystemExit('Set both TELEGRAM_API_ID and TELEGRAM_API_HASH, or neither')
    if api_id:
        if not re.fullmatch(r'[1-9][0-9]*', api_id) or not re.fullmatch(r'[a-fA-F0-9]{32}', api_hash):
            raise SystemExit('Invalid Telegram API credentials')
        config.update(api_id=api_id, api_hash=api_hash)
    base = Path('build-input/mokagram')
    certs = base / 'signing/certs'
    profiles = base / 'signing/profiles'
    certs.mkdir(parents=True, exist_ok=True)
    profiles.mkdir(parents=True, exist_ok=True)
    (base / 'configuration.json').write_text(json.dumps(config, indent=2) + '\n')
    with tempfile.TemporaryDirectory() as temporary:
        work = Path(temporary)
        key = str(work / 'key.pem')
        cert = str(work / 'cert.pem')
        extensions = work / 'certificate.cnf'
        extensions.write_text('''[req]
distinguished_name = dn
x509_extensions = extensions
prompt = no
[dn]
CN = Mokagram build placeholder
[extensions]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
''')
        run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
            '-keyout', key, '-out', cert, '-config', str(extensions), '-days', '365')
        export = ['openssl', 'pkcs12', '-export', '-inkey', key, '-in', cert,
                  '-out', str(certs / 'Placeholder.p12'), '-passout', 'pass:placeholder', '-macalg', 'sha1']
        if subprocess.run(export + ['-legacy'], capture_output=True).returncode:
            run(*export)
        certificate = run('openssl', 'x509', '-in', cert, '-outform', 'der')
        now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
        suffixes = {'': 'Telegram', '.SiriIntents': 'Intents', '.NotificationContent': 'NotificationContent',
                    '.NotificationService': 'NotificationService', '.Share': 'Share', '.Widget': 'Widget',
                    '.BroadcastUpload': 'BroadcastUpload', '.watchkitapp': 'WatchApp',
                    '.watchkitapp.watchkitextension': 'WatchExtension'}
        for suffix, name in suffixes.items():
            team = config['team_id']
            bundle = config['bundle_id']
            profile = {
                'AppIDName': 'Mokagram', 'ApplicationIdentifierPrefix': [team],
                'CreationDate': now, 'ExpirationDate': now + datetime.timedelta(days=365),
                'DeveloperCertificates': [certificate], 'UUID': str(uuid.uuid4()),
                'Name': 'Mokagram build placeholder', 'Platform': ['iOS'],
                'TeamIdentifier': [team], 'TeamName': 'Mokagram placeholder',
                'TimeToLive': 365, 'Version': 1, 'IsXcodeManaged': False,
                'Entitlements': {
                    'application-identifier': f'{team}.{bundle}{suffix}',
                    'com.apple.developer.team-identifier': team,
                    'com.apple.security.application-groups': [f'group.{bundle}'],
                    'aps-environment': 'development', 'get-task-allow': True,
                    'keychain-access-groups': [f'{team}.*'],
                },
            }
            source = work / 'profile.plist'
            source.write_bytes(plistlib.dumps(profile))
            run('openssl', 'smime', '-sign', '-binary', '-nodetach', '-outform', 'der',
                '-in', str(source), '-signer', cert, '-inkey', key,
                '-out', str(profiles / f'{name}.mobileprovision'))
    print('Prepared Mokagram configuration and placeholder signing material')


if __name__ == '__main__':
    prepare()
