"""Standalone optional YOLO process entry; imports native inference only here."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/"battlefield"/"runtime"))
from image_feature_worker import run

def create(config):
    from yolo_detector import Vision
    return Vision(config)

if __name__ == "__main__": run(create, vision=True)
