#!/usr/bin/env python3
import hashlib
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent
expected = {
    "Dockerfile", "README.md", "pod-ssh-bootstrap.sh", "rental-entrypoint.sh",
    "rental-job-anchor.py", "verify_publication.py", ".github/workflows/publish.yml",
}
actual = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file() and ".git" not in path.parts}
if actual != expected:
    raise SystemExit(f"PUBLICATION_ALLOWLIST_DRIFT:{sorted(actual ^ expected)}")
text = "\n".join((root / name).read_text(errors="replace") for name in expected)
for pattern in (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", r"(?i)(?:runpod|github|hf)[_-]?(?:token|api[_-]?key)\s*=", r"(?i)authorization\s*:\s*bearer"):
    if re.search(pattern, text):
        raise SystemExit("FORBIDDEN_PUBLICATION_MATERIAL")
digest = hashlib.sha256((root / "pod-ssh-bootstrap.sh").read_bytes()).hexdigest()
if digest != "0d0156d915f7b9473518e2893983cbd1ff6c1dfa7824e984239ec9f58192308a":
    raise SystemExit(f"BOOTSTRAP_HASH_MISMATCH:{digest}")
if "@sha256:10764a9a7bfbe8d201967e493cfe238a9c599ef03efd183367163ff6092e4bd7" not in text:
    raise SystemExit("PINNED_BASE_DIGEST_MISSING")
print("PUBLICATION_PRIVACY_SCAN_PASS")
