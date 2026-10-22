"""Standalone optional projectile process entry."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/"battlefield"/"runtime"))
from image_feature_worker import run

def create(config):
    from projectile import Projectile
    return Projectile(config)

if __name__ == "__main__": run(create)
