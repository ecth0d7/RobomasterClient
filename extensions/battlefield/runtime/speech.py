"""Compatibility import for the independently packaged voice implementation."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/"speech"/"runtime"))
from voice_queue import VoiceQueue
