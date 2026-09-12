"""Check generated files, compile Luau, and exercise the API with mocked services."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import json
import re
from build import outputs

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
    script_extensions = {".lua", ".luau", ".py", ".js", ".ts", ".ps1", ".sh", ".bat", ".cmd"}
    root_scripts = sorted(path.name for path in ROOT.iterdir() if path.is_file() and path.suffix.lower() in script_extensions)
    if root_scripts:
        parser.error("Scripts must live in project subdirectories: " + ", ".join(root_scripts))
    expected = {ROOT / path for path in outputs()}
    actual = set((ROOT / "dist").rglob("*.lua"))
    if actual != expected:
        parser.error("Distribution must contain only the current generated outputs (one player launcher)")
    for directory in ("src", "games", "dist", "examples", "config"):
        for path in (ROOT / directory).rglob("*.lua"):
            source = path.read_text(encoding="utf-8")
            if re.search(r"\b(?:readfile|loadfile|dofile)\s*\(", source):
                parser.error(f"Player code must use GitHub loadstrings: {path}")
            for url in re.findall(r'https://raw\.githubusercontent\.com/[^\s"\)]+', source):
                if not url.startswith("https://raw.githubusercontent.com/Fwrostt/FrostScripts/"):
                    parser.error(f"Unexpected GitHub script host in {path}: {url}")
    for directory in ("games", "examples"):
        for path in (ROOT / directory).rglob("*.lua"):
            if re.search(r'AddTab\("(?:Keybinds|Shortcuts)"', path.read_text(encoding="utf-8")):
                parser.error(f"Keybinds belong inside modules: {path}")
    files = list((ROOT / "dist").rglob("*.lua")) + list((ROOT / "games").rglob("*.lua")) + list((ROOT / "examples").rglob("*.lua"))
    # API fragments are compiled through their generated bundle.
    run(binary("luau-compile"), "--null", *files)
    temp = ROOT / ".local/tests"
    temp.mkdir(parents=True, exist_ok=True)
    api = (ROOT / "dist/api/FrostScriptsAPI.lua").read_text(encoding="utf-8")
    spec = (ROOT / "tests/api.spec.lua").read_text(encoding="utf-8")
    assert "]====]" not in api
    test_file = temp / "api.spec.luau"
    test_file.write_text("local API_SOURCE = [====[" + api + "]====]\n" + spec, encoding="utf-8")
    run(binary("luau"), test_file)
    ui = (ROOT / "dist/ui/UI.lua").read_text(encoding="utf-8")
    mock = (ROOT / "tests/roblox-ui-mock.lua").read_text(encoding="utf-8")
    ui_spec = (ROOT / "tests/ui.spec.lua").read_text(encoding="utf-8")
    assert "]====]" not in ui
    ui_file = temp / "ui.spec.luau"
    ui_file.write_text("local UI_SOURCE = [====[" + ui + "]====]\n" + mock + "\n" + ui_spec, encoding="utf-8")
    run(binary("luau"), ui_file)
    sources = {name: content for name, content in outputs().items()}
    fixture = "local SOURCES = {\n" + "\n".join(
        f"[{json.dumps(name)}] = [====[{content}]====]," for name, content in sources.items()
    ) + "\n}\n"
    launcher_file = temp / "launcher.spec.luau"
    launcher_file.write_text(fixture + mock + "\n" + (ROOT / "tests/launcher.spec.lua").read_text(encoding="utf-8"), encoding="utf-8")
    run(binary("luau"), launcher_file)
    print("All project checks passed.")


if __name__ == "__main__":
    main()
