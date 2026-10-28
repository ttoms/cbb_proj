#!/usr/bin/env python3
"""委托给 vendor/my_env 里的同一脚本，避免副本漂移。"""
import os
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
TARGET = os.path.join(HERE, "..", "vendor", "my_env", "skills",
                      "rtl-developer", "scripts", "quality_gate.py")
os.execv(sys.executable, [sys.executable, TARGET, *sys.argv[1:]])
