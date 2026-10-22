"""Optional YOLO feature adapter; missing feature files leave the core usable."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"yolo-vision"/"runtime"))
try:
    from yolo_detector import Vision
except ImportError:
    class Vision:
        def __init__(self,config):
            self.tracks=[]
            self.status="可选YOLO插件未安装"
        def close(self):pass
        def reset(self):self.tracks=[]
        def submit(self,frame):pass
        def poll(self):return []
        def details(self):return {"status":self.status,"frames":0,"dropped":0,"available":False}
