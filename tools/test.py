"""Run isolated Lua 5.4 tests using lupa.lua54 (pip install lupa==2.8)."""
from pathlib import Path
import os
import runpy
from tempfile import TemporaryDirectory
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
os.chdir(root)
for path in sorted((root / "Scripts").glob("*.lua")):
    runtime = LuaRuntime()
    runtime.execute("assert(load(...))", path.read_text(encoding="utf-8"))
print("All shipped Lua modules parse under Lua 5.4", flush=True)
for spec in sorted((root / "tests").glob("*_spec.lua")):
    with TemporaryDirectory(prefix="srankalert-test-") as fixture:
        runtime = LuaRuntime()
        runtime.globals().TEST_TMP = Path(fixture).as_posix()
        runtime.execute('package.path = "Scripts/?.lua;tests/?.lua;" .. package.path')
        runtime.execute(spec.read_text(encoding="utf-8"))
runpy.run_path(str(root / "tests" / "config_lifecycle.py"), run_name="__main__")
print("All tests passed", flush=True)
