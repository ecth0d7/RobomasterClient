"""Compatibility import for the independently packaged advice implementation."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/"decision"/"runtime"))
from advice_model import Advisor
