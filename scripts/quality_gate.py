#!/usr/bin/env python3
"""委托给 vendor/my_env 里的同一脚本，避免副本漂移。"""
import os
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
TARGET = os.path.join(HERE, "..", "vendor", "my_env", "skills",
                      "rtl-developer", "scripts", "quality_gate.py")
if not os.path.exists(TARGET):
    sys.exit("vendor/my_env 未初始化：请运行 "
             "git submodule update --init --recursive，或 "
             "git clone https://github.com/ttoms/my_env.git vendor/my_env")
os.execv(sys.executable, [sys.executable, TARGET, *sys.argv[1:]])
