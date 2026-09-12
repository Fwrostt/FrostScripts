"""Check generated files, compile Luau, and exercise the API with mocked services."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau-dir", type=Path, default=ROOT / ".tools/luau")
    args = parser.parse_args()
    suffix = ".exe" if sys.platform == "win32" else ""

    def binary(name):
        path = args.luau_dir / (name + suffix)
        found = str(path) if path.exists() else shutil.which(name)
        if not found:
            parser.error(f"Install Luau 0.738 and pass --luau-dir (missing {name})")
        return found

    run(sys.executable, "tools/build.py", "--check")
    files = list(ROOT.glob("*.lua")) + list((ROOT / "games").rglob("*.lua")) + list((ROOT / "examples").rglob("*.lua"))
    # API fragments are compiled through their generated bundle.
    run(binary("luau-compile"), "--null", *files)
    temp = ROOT / ".local/tests"
    temp.mkdir(parents=True, exist_ok=True)
    api = (ROOT / "FrostScriptsAPI.lua").read_text(encoding="utf-8")
    spec = (ROOT / "tests/api.spec.lua").read_text(encoding="utf-8")
    assert "]====]" not in api
    test_file = temp / "api.spec.luau"
    test_file.write_text("local API_SOURCE = [====[" + api + "]====]\n" + spec, encoding="utf-8")
    run(binary("luau"), test_file)
    ui = (ROOT / "UI.lua").read_text(encoding="utf-8")
    mock = (ROOT / "tests/roblox-ui-mock.lua").read_text(encoding="utf-8")
    ui_spec = (ROOT / "tests/ui.spec.lua").read_text(encoding="utf-8")
    assert "]====]" not in ui
    ui_file = temp / "ui.spec.luau"
    ui_file.write_text("local UI_SOURCE = [====[" + ui + "]====]\n" + mock + "\n" + ui_spec, encoding="utf-8")
    run(binary("luau"), ui_file)
    print("All project checks passed.")


if __name__ == "__main__":
    main()
