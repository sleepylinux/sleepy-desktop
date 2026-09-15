import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class CaptureWrapperTests(unittest.TestCase):
    def test_fixed_arguments_private_mode_and_separate_protocol_stream(self):
        self.assertTrue(self.wrapper.is_file(), "capture helper wrapper is missing")
        result = self.run_wrapper(self.arguments)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"state": "awaitingConsent"})
        self.assertIn("ordinary Qt diagnostic", result.stderr)
        record = json.loads(self.record.read_text())
        self.assertEqual(record["argv"], ["-p", str(self.qml)])
        self.assertEqual(record["job"], self.job)
        self.assertEqual(record["output"], "output:DP-1")
        self.assertEqual(record["path"], self.path)
        self.assertEqual(record["fd"], "4")
        self.assertEqual(record["umask"], 0o077)

    def test_rejected_arguments_never_start_the_renderer(self):
        self.assertTrue(self.wrapper.is_file(), "capture helper wrapper is missing")
        invalid = [
            [], self.arguments[:-1], self.arguments + ["--unknown", "value"],
            self.arguments + ["--job-id", self.job],
            ["--job-id", "../escape", *self.arguments[2:]],
            [*self.arguments[:3], "output:DP-1;touch /tmp/never", *self.arguments[4:]],
            [*self.arguments[:5], "/tmp/unconfined.png", *self.arguments[6:]],
            [*self.arguments[:-1], "1"],
        ]
        for arguments in invalid:
            with self.subTest(arguments=arguments):
                result = self.run_wrapper(arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.record.exists())
                self.assertEqual(result.stdout, "")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        directory = Path(self.temp.name)
        self.wrapper = Path(__file__).resolve().parents[1] / "scripts/capture-job-helper.sh"
        self.job = "a52c8e24-52c5-434b-b59a-a7c0338b2c1f"
        self.path = f"/run/user/{os.geteuid()}/sleepy/captures/screenshot-{self.job}.png"
        self.qml = directory / "CaptureJob.qml"
        self.qml.write_text("// launcher fixture; no pixel capture claimed\n")
        self.record = directory / "invocation.json"
        runner = directory / "qs"
        runner.write_text("#!/usr/bin/env python3\n" + '''
import json, os, sys
from pathlib import Path
Path(os.environ['TEST_RECORD']).write_text(json.dumps({
    'argv': sys.argv[1:], 'job': os.environ['SLEEPY_CAPTURE_JOB_ID'],
    'output': os.environ['SLEEPY_CAPTURE_OUTPUT_ID'],
    'path': os.environ['SLEEPY_CAPTURE_OUTPUT_PATH'], 'fd': os.environ['SLEEPY_CAPTURE_OUTPUT_FD'],
    'umask': os.umask(0o077),
}))
print('ordinary Qt diagnostic', flush=True)
os.write(3, b'{"state":"awaitingConsent"}\\n')
''')
        runner.chmod(0o755)
        self.environment = dict(os.environ, SLEEPY_CAPTURE_RUNNER=str(runner),
                                SLEEPY_CAPTURE_QML=str(self.qml), TEST_RECORD=str(self.record))
        self.arguments = ["--job-id", self.job, "--output-id", "output:DP-1", "--output", self.path,
                          "--output-fd", "4"]

    def run_wrapper(self, arguments):
        return subprocess.run(["bash", str(self.wrapper), *arguments], env=self.environment,
                              text=True, capture_output=True, timeout=5)


if __name__ == "__main__":
    unittest.main()
