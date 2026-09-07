import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error


SKILL_DIR = Path(__file__).resolve().parents[1]
HELPER = SKILL_DIR / 'scripts' / 'ads_request.py'
spec = importlib.util.spec_from_file_location('ads_request', HELPER)
ads = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ads)


class FakeHttp:
    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []

    def open(self, request, timeout):
        self.requests.append(request)
        if not self.responses:
            raise AssertionError('Unexpected HTTP request')
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return io.BytesIO(json.dumps(response).encode())


def credentials(**changes):
    values = {
        'access_token': 'private-oauth-fixture',
        'developer_token': 'private-developer-fixture',
        'customer_id': '1234567890',
        'manager_customer_id': '987-654-3210',
        'mode': 'test',
        'target_mode': 'test',
        'developer_token_access_level': 'explorer',
    }
    values.update(changes)
    return values


def identity(**changes):
    customer = {'id': '1234567890', 'descriptiveName': 'Fixture', 'manager': False, 'testAccount': True}
    customer.update(changes)
    return {'results': [{'customer': customer}]}


class AdsRequestTests(unittest.TestCase):
    def client(self, responses, **changes):
        client = ads.AdsClient(credentials(**changes))
        client.opener = FakeHttp(responses)
        return client

    def testDiscoveryRequiresBothTokensBeforeAnyRequest(self):
        for field in ('developer_token', 'access_token'):
            for value in (None, '', ' '):
                with self.subTest(field=field, value=value):
                    with patch.object(ads.urllib.request, 'build_opener') as opener:
                        with self.assertRaisesRegex(ads.AdsError, 'REQUIRED_BEFORE_DISCOVERY'):
                            ads.AdsClient(credentials(**{field: value}))
                        opener.assert_not_called()

    def testListCustomersSendsRequiredHeadersWithoutManager(self):
        client = self.client([{'resourceNames': ['customers/9876543210']}])
        self.assertEqual(client.listCustomers()['resourceNames'], ['customers/9876543210'])
        request = client.opener.requests[0]
        self.assertEqual(request.full_url, 'https://googleads.googleapis.com/v25/customers:listAccessibleCustomers')
        self.assertEqual(request.get_method(), 'GET')
        self.assertEqual(request.get_header('Authorization'), 'Bearer private-oauth-fixture')
        self.assertEqual(request.get_header('Developer-token'), 'private-developer-fixture')
        self.assertIsNone(request.get_header('Login-customer-id'))

    def testManagerDiscoveryUsesExplicitNormalizedHierarchy(self):
        client = self.client([{'results': []}])
        client.listClients('555-666-7777')
        request = client.opener.requests[0]
        self.assertIn('/customers/5556667777/googleAds:search', request.full_url)
        self.assertEqual(request.get_header('Login-customer-id'), '5556667777')
        self.assertIn('customer_client.test_account', json.loads(request.data)['query'])

    def testTestReportsAndMutationsInspectBeforeOperation(self):
        for operation in ('search', 'mutate'):
            with self.subTest(operation=operation):
                client = self.client([identity(), {'results': []}])
                client.operate(operation, query='SELECT campaign.id FROM campaign', resource='campaigns', payload={'operations': []})
                first, second = client.opener.requests
                self.assertIn('customer.test_account', json.loads(first.data)['query'])
                self.assertEqual(first.get_header('Login-customer-id'), '9876543210')
                self.assertEqual(second.get_header('Developer-token'), 'private-developer-fixture')
                self.assertEqual(second.get_header('Login-customer-id'), '9876543210')
                self.assertNotIn('customer.test_account', json.loads(second.data).get('query', ''))
                self.assertEqual(second.get_method(), 'POST')

    def testProductionCannotMasqueradeAsTestEvenWithApprovalFlag(self):
        for mode in ('test', 'pending-basic'):
            for tier in ('test', 'explorer', 'basic', 'standard'):
                for operation in ('search', 'mutate'):
                    with self.subTest(mode=mode, tier=tier, operation=operation):
                        client = self.client([identity(testAccount=False)], mode=mode, target_mode=None, developer_token_access_level=tier)
                        with self.assertRaisesRegex(ads.AdsError, 'TEST_TARGET_REQUIRED'):
                            client.operate(operation, True, query='SELECT campaign.id FROM campaign', resource='campaigns', payload={})
                        self.assertEqual(len(client.opener.requests), 1)

    def testActualProductionRequiresApprovalRegardlessOfSavedModeOrTier(self):
        for mode in ('test', 'pending-basic', 'basic'):
            for tier in ('explorer', 'basic', 'standard'):
                with self.subTest(mode=mode, tier=tier):
                    client = self.client([identity(testAccount=False)], mode=mode, target_mode='production', developer_token_access_level=tier)
                    with self.assertRaisesRegex(ads.AdsError, 'PRODUCTION_TARGET_REQUIRES_APPROVAL'):
                        client.operate('search', query='SELECT campaign.id FROM campaign')
                    self.assertEqual(len(client.opener.requests), 1)

    def testAuthorizedProductionOperationRunsAfterIdentity(self):
        client = self.client([identity(testAccount=False), {'results': []}], target_mode='production')
        client.operate('mutate', True, resource='campaignBudgets', payload={'operations': []})
        self.assertEqual(len(client.opener.requests), 2)
        self.assertTrue(client.opener.requests[1].full_url.endswith('/campaignBudgets:mutate'))

    def testIdentityIsRecheckedForEveryOperation(self):
        client = self.client([identity(), {'results': []}, identity(testAccount=False)])
        client.operate('search', query='SELECT campaign.id FROM campaign')
        with self.assertRaisesRegex(ads.AdsError, 'TEST_TARGET_REQUIRED'):
            client.operate('mutate', resource='campaigns', payload={})
        self.assertEqual(len(client.opener.requests), 3)

    def testUnknownMismatchedOrManagerIdentityStops(self):
        unknown = identity()
        del unknown['results'][0]['customer']['testAccount']
        responses = [unknown, identity(manager=None), identity(testAccount='true'), identity(testAccount=1), identity(id='9999999999'), identity(manager=True), {'results': []}]
        for response in responses:
            with self.subTest(response=response):
                client = self.client([response])
                with self.assertRaises(ads.AdsError):
                    client.operate('search', query='SELECT campaign.id FROM campaign')
                self.assertEqual(len(client.opener.requests), 1)

    def testDirectClientOmitsManagerHeader(self):
        client = self.client([identity()], manager_customer_id='')
        client.identity()
        self.assertIsNone(client.opener.requests[0].get_header('Login-customer-id'))

    def testInvalidIdsNeverReachNetwork(self):
        for value in ('123', '1234567890/other', '1234567890?secret=x'):
            client = self.client([], customer_id=value)
            with self.assertRaises(ads.AdsError):
                client.identity()
            self.assertEqual(client.opener.requests, [])

    def testHttpErrorDoesNotPrintSecrets(self):
        error = urllib.error.HTTPError('https://example.invalid/private-oauth-fixture', 401, 'private-developer-fixture', {}, io.BytesIO(b'private-oauth-fixture'))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'credentials.json'
            path.write_text(json.dumps(credentials()))
            output = io.StringIO()
            fake = FakeHttp([error])
            with patch.object(ads.urllib.request, 'build_opener', return_value=fake):
                with patch('sys.argv', ['ads_request', '--credentials', str(path), 'inspect']):
                    with contextlib.redirect_stdout(output):
                        self.assertEqual(ads.main(), 1)
            self.assertEqual(output.getvalue(), 'GOOGLE_ADS_HTTP_401\n')
            self.assertNotIn('private-', output.getvalue())

    def testRedirectNeverForwardsCredentials(self):
        with self.assertRaisesRegex(ads.AdsError, 'UNEXPECTED_REDIRECT'):
            ads.NoRedirect().redirect_request(None, io.BytesIO(), 302, '', {}, 'https://example.invalid')

    def testDiscoveryRecipeBuildsPrivateCompleteRequestBeforeHelper(self):
        skill = (SKILL_DIR / 'SKILL.md').read_text()
        section = skill.split('### Step 10 -', 1)[1].split('### Step 1T', 1)[0]
        recipe = re.search(r'```bash\n(.*?)```', section, re.S).group(1)
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory)
            (capture / 'developer.json').write_text(json.dumps({'dev_token': 'private-developer-fixture'}))
            fake_helper = capture / 'fake_helper.py'
            fake_helper.write_text("import json, pathlib, stat, sys\np = pathlib.Path(sys.argv[2])\nd = json.loads(p.read_text())\nassert sys.argv[1] == '--credentials'\nassert sys.argv[3] == 'list-customers'\nassert d == {'access_token': 'private-oauth-fixture', 'developer_token': 'private-developer-fixture'}\nassert stat.S_IMODE(p.stat().st_mode) == 0o600\nprint('discovery-ready')\n")
            env = dict(os.environ)
            env.update(ADS_CAPTURE_DIR=directory, ADS_REQUEST_HELPER=str(fake_helper), RESP=json.dumps({'access_token': 'private-oauth-fixture'}))
            result = subprocess.run(['bash', '-eu', '-c', recipe], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, 'discovery-ready\n')
            self.assertNotIn('private-', result.stdout + result.stderr)

    def testPersistenceRecipeSavesTargetSeparatelyFromTokenTier(self):
        skill = (SKILL_DIR / 'SKILL.md').read_text()
        section = skill.split('**1T.3 - Save credentials.json', 1)[1]
        recipe = re.search(r'```bash\n(.*?)```', section, re.S).group(1)
        for mode, target_mode in [('test', 'test'), ('basic', 'production')]:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                capture = Path(directory)
                (capture / 'client.json').write_text(json.dumps({'client_id': 'fixture-client', 'client_secret': 'private-client-fixture'}))
                (capture / 'developer.json').write_text(json.dumps({'dev_token': 'private-developer-fixture'}))
                env = dict(os.environ)
                env.update(HOME=directory, ADS_CAPTURE_DIR=directory, MODE=mode, DEV_ACCESS_LEVEL='explorer', MANAGER_CUSTOMER_ID='9876543210', CUSTOMER_ID='1234567890', PROJECT_ID='fixture-project', RESP=json.dumps({'access_token': 'private-oauth-fixture', 'refresh_token': 'private-refresh-fixture', 'expires_in': 3600}))
                result = subprocess.run(['bash', '-eu', '-c', recipe], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                saved = capture / '.config/google-ads/credentials.json'
                data = json.loads(saved.read_text())
                self.assertEqual(data['target_mode'], target_mode)
                self.assertEqual(data['mode'], mode)
                self.assertEqual(data['developer_token_access_level'], 'explorer')
                self.assertEqual(data['manager_customer_id'], '9876543210')
                self.assertEqual(saved.stat().st_mode & 0o777, 0o600)
                self.assertEqual(result.stdout, '')
                self.assertNotIn('private-', result.stderr)

    def testTransportAndApiErrorsWithholdDetails(self):
        responses = [urllib.error.URLError('private-oauth-fixture'), {'error': {'message': 'private-developer-fixture'}}]
        for response in responses:
            client = self.client([response])
            with self.assertRaises(ads.AdsError) as raised:
                client.identity()
            self.assertNotIn('private-', str(raised.exception))
            self.assertEqual(len(client.opener.requests), 1)

    def testSupportedVersionAndNoRetiredExecutableRecipes(self):
        result = subprocess.run(['python3', str(HELPER), 'version'], capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), 'v25')
        skill = (SKILL_DIR / 'SKILL.md').read_text()
        self.assertIsNone(re.search(r'googleads\.googleapis\.com/v17\b', skill))
        self.assertIn('scripts/ads_request.py', skill)


if __name__ == '__main__':
    unittest.main()
