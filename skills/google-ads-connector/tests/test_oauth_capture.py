import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SKILL = Path(__file__).resolve().parents[1]


class CreationCaptureTests(unittest.TestCase):
    def runFixture(self, mode):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'capture.json'
            descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            os.close(descriptor)
            command = ['node', str(SKILL / 'tests/oauth_capture_fixture.cjs'), str(SKILL / 'scripts/capture_oauth_client.js'), mode, str(output)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            summary = json.loads(result.stdout)
            self.assertEqual(summary['clicks'], 1)
            self.assertGreaterEqual(summary['snapshots_checked'], 1)

    def testDelayedModalCreatedAndCapturedWithinProtectedOperation(self):
        self.runFixture('delayed')

    def testExplicitVisibleChildCannotOverrideRootConcealment(self):
        self.runFixture('explicit-visible')

    def testOutputFailureRetryUsesSameCredentialWithoutAnotherClick(self):
        self.runFixture('output-retry')

    def testSameDocumentUrlChangeCanDeliverSavedResultWithoutRecreating(self):
        self.runFixture('spa-output-retry')

    def testTimedOutCreationRemainsHiddenAndLateResultResumes(self):
        self.runFixture('uncertain-late')

    def testReloadAfterUncertainDeliveryCannotCreateAgain(self):
        self.runFixture('reload')

    def testAmbiguousFieldsPreserveClientWithoutReturningSecret(self):
        self.runFixture('ambiguous')


if __name__ == '__main__':
    unittest.main()
