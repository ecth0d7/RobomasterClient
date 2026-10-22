"""Lazy ONNX inference; whole-body and armor models retain distinct scopes."""
import base64


def decode_frame(frame):
    import cv2
    import numpy as np
    image = cv2.imdecode(np.frombuffer(base64.b64decode(frame["jpeg"], validate=True), np.uint8), cv2.IMREAD_COLOR)
    if image is None or image.shape[0]*image.shape[1] > 2_000_000:
        raise ValueError("invalid frame")
    return image


def iou(a, b):
    x, y = max(a[0], b[0]), max(a[1], b[1])
    right, bottom = min(a[0]+a[2], b[0]+b[2]), min(a[1]+a[3], b[1]+b[3])
    area = max(0, right-x)*max(0, bottom-y)
    return area/max(1e-9, a[2]*a[3]+b[2]*b[3]-area)


class OnnxDetector:
    def __init__(self, config):
        self.config = config
        self.engine = None

    def infer(self, frame, image=None):
        import cv2
        import numpy as np
        import onnxruntime as ort
        dialect = self.config.get("format", "rp26-armor-v8")
        if self.engine is None:
            options = ort.SessionOptions()
            options.intra_op_num_threads = max(1, min(4, int(self.config.get("threads", 2))))
            options.inter_op_num_threads = 1
            self.engine = ort.InferenceSession(self.config["model_file"], sess_options=options, providers=["CPUExecutionProvider"])
        if image is None:
            image = decode_frame(frame)
        metadata = self.engine.get_inputs()[0]
        shape = metadata.shape
        height, width = int(shape[2]), int(shape[3])
        if not 32 <= height <= 1280 or not 32 <= width <= 1280:
            raise ValueError("model input dimensions")
        scale = min(width/image.shape[1], height/image.shape[0])
        sw, sh = round(image.shape[1]*scale), round(image.shape[0]*scale)
        px, py = (width-sw)//2, (height-sh)//2
        canvas = np.full((height, width, 3), 124 if dialect == "rp26-armor-v8" else 114, np.uint8)
        canvas[py:py+sh, px:px+sw] = cv2.resize(image, (sw, sh))
        tensor = canvas[:, :, ::-1].transpose(2, 0, 1)[None].copy()
        tensor = tensor.astype(np.float16 if metadata.type == "tensor(float16)" else np.float32)/255.0
        output = self.engine.run(None, {metadata.name: tensor})[0]
        candidates = np.asarray(output[0], dtype=np.float32)
        detections = []
        threshold = float(self.config.get("confidence", .55))
        if dialect == "rp26-armor-v8":
            if candidates.shape[0] != 21:
                raise ValueError("RP26 model output must be 1x21xN")
            candidates = candidates.T
            for row in candidates[candidates[:, 4:13].max(axis=1) >= threshold]:
                cls = int(row[4:13].argmax())
                color = int(row[:4].argmax())
                # Optional identity helper rejects close class/colour alternatives.
                # The standalone armor dialect retains its historical zero margin.
                margin = float(self.config.get("identity_margin", 0))
                if margin and (np.diff(np.sort(row[:4]))[-1] < margin or
                               np.diff(np.sort(row[4:13]))[-1] < margin):
                    continue
                points = row[13:21].reshape(4, 2)
                x1, y1 = points.min(axis=0)
                x2, y2 = points.max(axis=0)
                team = ("blue", "red", "unknown", "unknown")[color]
                # Armor is evidence of a robot, not its full silhouette. The UI labels this explicitly.
                label = ("哨兵", "英雄", "工程", "步兵3", "步兵4", "步兵5", "前哨站", "基地底部", "基地顶部")[cls]
                identity = str((7, 1, 2, 3, 4, 5, 11, 10, 10)[cls])
                target = team+":"+identity if team != "unknown" else "unknown"
                confidence = min(float(row[4+cls]), float(row[color]))
                if confidence >= threshold:
                    detections.append((x1, y1, x2, y2, confidence, team, target, label+"装甲板"))
        elif dialect in ("yolo-v5", "yolo-v8"):
            if candidates.ndim != 2:
                raise ValueError("YOLO output must be a two-dimensional candidate tensor")
            if dialect == "yolo-v8" and candidates.shape[0] < candidates.shape[1]:
                candidates = candidates.T
            labels = self.config.get("labels", [])
            offset = 5 if dialect == "yolo-v5" else 4
            if candidates.shape[1] != offset+len(labels) or not labels:
                raise ValueError("YOLO output/labels mismatch")
            for row in candidates:
                cls = int(row[offset:].argmax())
                score = float(row[offset+cls])
                if dialect == "yolo-v5":
                    score *= float(row[4])
                if score < threshold:
                    continue
                x, y, w, h = row[:4]
                # Custom label metadata is required; a generic COCO object is never called a robot.
                entry = labels[cls]
                if not entry.get("robot", False):
                    continue
                detections.append((x-w/2, y-h/2, x+w/2, y+h/2, score, entry.get("team", "unknown"), entry.get("target_id", "unknown"), entry.get("label", "机器人候选")))
        else:
            raise ValueError("unsupported detector format")
        boxes = []
        for x1, y1, x2, y2, confidence, team, target, label in detections:
            x1, x2 = max(0., min(1., (float(x1)-px)/sw)), max(0., min(1., (float(x2)-px)/sw))
            y1, y2 = max(0., min(1., (float(y1)-py)/sh)), max(0., min(1., (float(y2)-py)/sh))
            if x2-x1 > .001 and y2-y1 > .001:
                boxes.append({"bbox": [x1, y1, x2-x1, y2-y1], "confidence": confidence, "team": team, "target_id": target, "label": label, "detection_scope": "armor" if dialect == "rp26-armor-v8" else "whole_robot"})
        kept = []
        for box in sorted(boxes, key=lambda b: -b["confidence"])[:128]:
            if not any(iou(box["bbox"], old["bbox"]) > .4 for old in kept):
                kept.append(box)
        return kept[:32]

