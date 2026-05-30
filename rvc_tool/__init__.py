"""
RVC tool - Renesas Verification Companion.

Unifies the four objects an MCU verifier juggles every day:

  * list files          (what runs in the simulator)
  * Verification Item Lists (checkpoints + priority)
  * patterns            (the source files)
  * master reports      (PASS / FAIL / N/A results)

into one HTML dashboard, one AI-review Excel, and a smarter list-file filter.
"""
from __future__ import annotations

__version__ = "0.1.0"
