"""Run with Python unittest and the Flutter SDK's bin directory on PATH."""

from pathlib import Path
import subprocess
import tempfile
import unittest


class PreCommitTest(unittest.TestCase):
    def test_checks_staged_paths_without_mutating_files_or_index(self):
        hook = Path(__file__).resolve().parents[2] / '.githooks/pre-commit'
        with tempfile.TemporaryDirectory(prefix='sorayomi-hook-test-') as directory:
            root = Path(directory)

            def run(*args, check=True):
                return subprocess.run(
                    args, cwd=root, check=check, text=True,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                )

            run('git', 'init', '-q')
            (root / 'pubspec.yaml').write_text(
                'name: hook_fixture\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n'
            )
            (root / 'analysis_options.yaml').write_text(
                'linter:\n  rules:\n    unnecessary_this: true\n'
            )
            run('dart', 'pub', 'get', '--offline')
            (root / 'unstaged.dart').write_text('This is not valid Dart.\n')
            staged = root / 'staged.dart'

            def check_hook(source, expected_success, diagnostic=None, format_code=True):
                staged.write_text(source)
                if format_code:
                    run('dart', 'format', str(staged))
                run('git', 'add', '--', staged.name)
                before_index = run('git', 'diff', '--cached', '--binary').stdout
                before_files = (staged.read_bytes(), (root / 'unstaged.dart').read_bytes())
                result = run('bash', str(hook), check=False)
                self.assertEqual(result.returncode == 0, expected_success, result.stdout)
                if diagnostic:
                    self.assertIn(diagnostic, result.stdout)
                self.assertEqual(run('git', 'diff', '--cached', '--binary').stdout, before_index)
                self.assertEqual(
                    (staged.read_bytes(), (root / 'unstaged.dart').read_bytes()),
                    before_files,
                )

            # Informational diagnostics remain visible but do not block a commit.
            check_hook(
                'class Sample { int value = 1; int read() => this.value; }\n',
                True, 'unnecessary_this',
            )
            check_hook('void main() { var unused = 1; }\n', False, 'unused_local_variable')
            check_hook('void main() { undefinedFunction(); }\n', False, 'undefined_function')
            check_hook('void main(){print("format me");}\n', False, format_code=False)

            # A commit with no Dart paths does not require the SDK and must not
            # inspect the unrelated, invalid working-tree Dart file.
            run('git', 'rm', '--cached', '--', staged.name)
            (root / 'notes.txt').write_text('Documentation only.\n')
            run('git', 'add', '--', 'notes.txt')
            self.assertEqual(run('bash', str(hook), check=False).returncode, 0)


if __name__ == '__main__':
    unittest.main()
