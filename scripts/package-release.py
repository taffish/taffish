#!/usr/bin/env python3
"""Compatibility entry point for the TAFFISH shell release packager."""

import os
from pathlib import Path
import sys


if __name__ == "__main__":
    script = Path(__file__).resolve().parents[1] / "target/make-sha-asc.sh"
    os.execv("/bin/sh", ["sh", str(script), "--package-only", *sys.argv[1:]])
