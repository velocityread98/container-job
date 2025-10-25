#!/usr/bin/env python3
import argparse
import os
import sys
import time
from utils.betterstack import betterstack_log

def main():
    # Accept input path via CLI arg or environment variable
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--input-path", dest="input_path", default=None)
    args, _ = parser.parse_known_args()

    input_path = args.input_path or os.getenv("INPUT_PATH")
    if input_path:
        print(f"INPUT_PATH: {input_path}")
        # Optionally send to BetterStack for visibility
        try:
            betterstack_log("received input path", level="INFO", input_path=input_path)
        except Exception:
            pass
    else:
        print("No INPUT_PATH provided (set --input-path or env var INPUT_PATH)")

    # Minimal heartbeat so we can see the job is running
    try:
        for i in range(3):
            betterstack_log(f"heartbeat {i+1}/3 from container", level="INFO")
            time.sleep(5)
        print("Done ✅")
    except Exception as e:
        # Ensure non-zero exit for Azure failure classification
        try:
            betterstack_log(f"Error: {e}", level="ERROR")
        except Exception:
            pass
        sys.exit(1)
    sys.exit(0)

# Example:
# python ./Dolphin/demo_page.py --model_path ./Dolphin/hf_model --save_dir ./results --input_path ./demo/page_imgs/page_6.pdf

if __name__ == "__main__":
    main()
