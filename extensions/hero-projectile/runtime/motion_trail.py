"""Bounded temporal pixel persistence, derived only from received camera pixels.

Reference: Pacific_doorlock_sniper's preprocess_image motion-mask/temporal-max
approach. This independent implementation is a display aid, not bullet detection.
Camera-side processing before lossy encoding can preserve details this receiver
can no longer recover. No lines, ballistic arcs or predicted pixels are generated.
"""
import base64


class MotionTrail:
    def __init__(self):
        self.background = None
        self.previous = None
        self.history = []
        self.stamp = 0

    def process(self, image, stamp, roi_mask):
        import cv2
        import numpy as np
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        empty = dict(trail_image='', trail_stamp_ms=stamp, trail_pixels=0,
                     trail_status='等待明暗运动像素；拖影不是弹丸身份确认')
        if (self.background is None or self.background.shape != gray.shape
                or not 20 <= stamp-self.stamp <= 450):
            self.background = gray.astype(np.float32)
            self.previous = gray
            self.history = []
            self.stamp = stamp
            return empty
        self.stamp = stamp
        diff = cv2.absdiff(gray, cv2.convertScaleAbs(self.background))
        changed = cv2.absdiff(gray, self.previous) > 12
        self.previous = gray
        motion = (diff > 18) & (roi_mask > 0)
        ratio = float(motion.sum()) / max(1, int((roi_mask > 0).sum()))
        if ratio >= .30:
            # A pan/cut should not paint the background as a projectile trail.
            self.background = gray.astype(np.float32)
            self.history = []
            return dict(empty, trail_status='大范围运动；已清除拖影', motion_ratio=round(ratio, 3))
        # A 42 mm projectile need not be luminous: exposure, compression and a
        # bright background can make it a dark spot. Preserve local temporal
        # contrast of either sign, rather than discarding every pixel < 170.
        # This remains a motion display aid; it does not establish bullet identity.
        selected = motion & changed
        count, labels, stats, _ = cv2.connectedComponentsWithStats(selected.astype(np.uint8), 8)
        small = np.zeros(count, np.uint8)
        for i in range(1, count):
            if stats[i, cv2.CC_STAT_AREA] <= max(24, gray.size*.002):
                small[i] = 1
        selected = small[labels].astype(bool)
        # Contrast drives visibility so dark received pixels also leave a mark.
        # Positions are exclusively observed pixels; no connecting arc is drawn.
        pixels = np.where(selected, np.minimum(255, 90+diff.astype(np.uint16)*2), 0).astype(np.uint8)
        self.history = [(t, p) for t, p in self.history if 0 <= stamp-t <= 450][-7:]
        self.history.append((stamp, pixels))
        merged = np.zeros_like(gray)
        for t, p in self.history:
            # A time cap as well as a frame cap keeps persistence bounded at low FPS.
            faded = (p.astype(np.float32)*(1-(stamp-t)/600.)).astype(np.uint8)
            np.maximum(merged, faded, out=merged)
        cv2.accumulateWeighted(gray, self.background, .08)
        alpha = merged
        visible = (alpha > 60) & (roi_mask > 0)
        total = int(visible.sum())
        if not total:
            return empty
        rgba = np.zeros((gray.shape[0], gray.shape[1], 4), np.uint8)
        # Cyan tint identifies the aid; intensity comes from temporal contrast.
        rgba[:, :, 0] = alpha
        rgba[:, :, 1] = alpha
        rgba[:, :, 2] = (alpha.astype(np.uint16)*.45).astype(np.uint8)
        rgba[:, :, 3] = np.where(visible, np.minimum(alpha, 210), 0).astype(np.uint8)
        ok, png = cv2.imencode('.png', rgba, [cv2.IMWRITE_PNG_COMPRESSION, 3])
        if not ok or len(png) > 96*1024:
            return dict(empty, trail_status='拖影图层过大；已跳过')
        return dict(trail_image='data:image/png;base64,'+base64.b64encode(png).decode('ascii'),
                    trail_stamp_ms=stamp, trail_pixels=total,
                    trail_status='青色为明暗运动像素拖影；不代表弹丸确认',
                    motion_ratio=round(ratio, 3))
