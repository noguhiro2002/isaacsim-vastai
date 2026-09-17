#!/usr/bin/env python3
import argparse
import os


def parse_args():
    parser = argparse.ArgumentParser(description="Create and save a minimal USD stage with headless Isaac Sim.")
    parser.add_argument(
        "--output",
        default=os.environ.get("USD_OUTPUT", "/workspace/output/isaac-headless-smoke.usda"),
    )
    return parser.parse_args()


args = parse_args()
os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)

from isaacsim import SimulationApp

simulation_app = SimulationApp({"headless": True})

import omni.usd
from pxr import UsdGeom

context = omni.usd.get_context()
context.new_stage()
stage = context.get_stage()
UsdGeom.Xform.Define(stage, "/World")
cube = UsdGeom.Cube.Define(stage, "/World/HeadlessSmokeCube")
cube.GetSizeAttr().Set(0.25)

if not context.save_as_stage(os.path.abspath(args.output)):
    simulation_app.close()
    raise RuntimeError(f"Failed to save USD stage: {args.output}")

simulation_app.update()
simulation_app.close()
print(f"USD_SAVED={os.path.abspath(args.output)}")

