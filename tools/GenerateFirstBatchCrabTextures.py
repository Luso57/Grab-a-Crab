"""Recreate the original texture atlases for the first imported crab batch."""

import importlib.util
from pathlib import Path

source = Path(__file__).resolve().parents[1] / "artifacts/crab-variants/build_crabs.py"
spec = importlib.util.spec_from_file_location("build_crabs", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.OUT.mkdir(parents=True, exist_ok=True)
for name in module.NAMES:
    _, atlas = module.texture(name)
    print(atlas, flush=True)
