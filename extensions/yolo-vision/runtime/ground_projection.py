"""Optional mobile-camera ground-plane estimate, never a measured robot pose.

Frame XY/yaw come from the acquisition host (or an explicitly granted pose
sensor). Intrinsics and camera mounting require operator configuration. Pure
pinhole geometry is deliberately separate from ONNX and the transport.
"""
import math
from contract import identifier, integer, number, utc_ms


def rotate_ray(u, v, camera):
    fx, fy, cx, cy = camera['normalized_intrinsics']
    right, up = (u-cx)/fx, -(v-cy)/fy
    distortion = camera.get('distortion', [])
    if distortion:
        import cv2
        import numpy as np
        k = np.array([[fx, 0, cx], [0, fy, cy], [0, 0, 1]], dtype=np.float64)
        p = cv2.undistortPoints(np.array([[[u, v]]], dtype=np.float64), k, np.array(distortion, dtype=np.float64))[0, 0]
        right, up = float(p[0]), -float(p[1])
    roll = math.radians(camera.get('roll_clockwise_deg', 0))
    right, up = right*math.cos(roll)+up*math.sin(roll), -right*math.sin(roll)+up*math.cos(roll)
    pitch = math.radians(camera['pitch_down_deg'])
    return math.cos(pitch)+up*math.sin(pitch), right, -math.sin(pitch)+up*math.cos(pitch)


def ground_hit(u, v, camera, height_delta=0, pitch_delta=0):
    model = dict(camera, pitch_down_deg=camera['pitch_down_deg']+pitch_delta)
    forward, right, up = rotate_ray(u, v, model)
    height = camera['camera_height_m']+height_delta
    if up >= -.015 or height <= 0:
        raise ValueError('视线接近地平线或朝上，无法确定地面交点')
    scale = -height/up
    return forward*scale, right*scale


class GroundProjection:
    def __init__(self, configuration):
        self.config = dict(configuration or {})
        self.status = '移动相机定位未启用'
        self.ready = False
        self.positioned = self.rejected = 0
        if not self.config.get('enabled', False):
            return
        try:
            self.validate()
            self.ready = True
            self.status = '等待同期本车位姿与相机观测'
        except (ValueError, TypeError, KeyError) as error:
            self.status = '定位配置不可用：'+str(error)

    def validate(self):
        c = self.config
        for key in ('enabled', 'acknowledged', 'rigid_camera_confirmed', 'image_model_confirmed'):
            if type(c.get(key, False)) is not bool:
                raise ValueError(key+'须为布尔值')
        if c.get('acknowledged') is not True or c.get('image_model_confirmed') is not True:
            raise ValueError('须明确确认相机参数、平面假设及输入图像模型')
        if c.get('method', 'ground-plane') != 'ground-plane':
            raise ValueError('仅支持ground-plane方法')
        if not identifier(c.get('calibration_id')) or c['calibration_id'] == 'unconfigured':
            raise ValueError('请填写有效相机配置标识')
        if c.get('frame_id') not in ('field.2026', 'field.2027'):
            raise ValueError('请明确场地坐标系')
        k = c.get('normalized_intrinsics')
        if not isinstance(k, list) or len(k) != 4 or not all(number(x, -10, 10) for x in k) or min(k[:2]) <= .05 or not all(0 <= x <= 1 for x in k[2:]):
            raise ValueError('normalized_intrinsics须为归一化fx,fy,cx,cy')
        for key, default, low, high in [('camera_height_m', None, .05, 5), ('pitch_down_deg', None, -80, 80),
                ('camera_yaw_offset_deg', 0, -180, 180), ('roll_clockwise_deg', 0, -45, 45),
                ('forward_offset_m', 0, -3, 3), ('right_offset_m', 0, -3, 3),
                ('pose_uncertainty_m', .3, .01, 10), ('yaw_uncertainty_deg', 3, .1, 45),
                ('pitch_uncertainty_deg', 2, .1, 20), ('height_uncertainty_m', .1, .001, 1),
                ('pixel_uncertainty_normalized', .006, .001, .1), ('max_target_speed_mps', 5, 0, 30), ('max_observer_speed_mps', 5, 0, 30),
                ('max_observer_yaw_rate_degps', 180, 0, 720), ('max_camera_yaw_rate_degps', 360, 0, 1440),
                ('max_range_m', 25, .2, 60), ('max_uncertainty_m', 8, .1, 50)]:
            if not number(c.get(key, default), low, high):
                raise ValueError(key+'超出范围或未配置')
        if type(c.get('pose_heading_clockwise')) is not bool:
            raise ValueError('须明确RobotPosition的角度方向约定')
        if not integer(c.get('pose_max_age_ms', 1100), 50, 1500):
            raise ValueError('pose_max_age_ms须为50–1500ms')
        distortion = c.get('distortion', [])
        if not isinstance(distortion, list) or len(distortion) not in (0, 4, 5, 8) or not all(number(v, -5, 5) for v in distortion):
            raise ValueError('distortion须为0/4/5/8个有限系数')
        if c.get('pose_source_id') and (not identifier(c['pose_source_id']) or not identifier(c.get('pose_node_id')) or not identifier(c.get('pose_target_id'))):
            raise ValueError('外部位姿须指定可信来源与节点')
        if not c.get('rigid_camera_confirmed', False) and (not identifier(c.get('gimbal_source_id')) or not identifier(c.get('gimbal_node_id')) or not identifier(c.get('gimbal_target_id', 'camera.main'))):
            raise ValueError('活动云台必须指定实时角度来源，不能使用固定安装角代替')

    def project(self, box, observer, stamp, attitude=None):
        if not self.ready:
            return None, self.status
        try:
            value = self._project(box, observer, stamp, attitude)
            self.positioned += 1
            self.status = '移动相机地面估计；显示误差范围，非测量位置'
            return value, self.status
        except (ValueError, TypeError, KeyError, ArithmeticError) as error:
            self.rejected += 1
            self.status = '图像目标尚未定位：'+str(error)
            return None, self.status

    def _project(self, box, observer, stamp, attitude):
        c, now = self.config, utc_ms()
        if not isinstance(observer, dict) or observer.get('frame_id') != c['frame_id']:
            raise ValueError('缺少同坐标系本车位姿')
        if not integer(stamp, 1, now+250) or not integer(observer.get('stamp_ms'), 1, now+250) or not integer(observer.get('expires_ms'), now+1, now+5000):
            raise ValueError('本车位姿时间无效或已过期')
        skew = abs(stamp-observer['stamp_ms'])
        if skew > c.get('pose_max_age_ms', 1100) or now-stamp > 1500:
            raise ValueError('视频与本车位姿时间差过大')
        position = observer.get('position')
        if not isinstance(position, list) or len(position) != 2 or not all(number(v, -200, 200) for v in position):
            raise ValueError('本车位置无效')
        height = 16 if c['frame_id'] == 'field.2027' else 15
        if not 0 <= position[0] <= 28 or not 0 <= position[1] <= height:
            raise ValueError('本车位置超出场地')
        if number(observer.get('heading_rad'), -math.pi, math.pi):
            heading = observer['heading_rad']
        elif number(observer.get('yaw_deg'), -360, 360):
            yaw = observer['yaw_deg'] if c['pose_heading_clockwise'] else -observer['yaw_deg']
            heading = math.pi/2-math.radians(yaw)
        else:
            raise ValueError('缺少本车朝向')
        camera = dict(c)
        if not c.get('rigid_camera_confirmed', False):
            if not isinstance(attitude, dict) or abs(stamp-attitude.get('stamp_ms', 0)) > c.get('pose_max_age_ms', 1100) or attitude.get('expires_ms', 0) <= now:
                raise ValueError('缺少同期云台角度')
            yaw, pitch, roll = attitude.get('value', [None]*3)
            if not all(number(v, -180, 180) for v in (yaw, pitch, roll)) or abs(roll) > 45:
                raise ValueError('云台角度无效')
            camera['camera_yaw_offset_deg'] = camera.get('camera_yaw_offset_deg', 0)+yaw
            camera['pitch_down_deg'] += pitch
            camera['roll_clockwise_deg'] = camera.get('roll_clockwise_deg', 0)+roll
        if box.get('detection_scope') != 'whole_robot':
            raise ValueError('装甲板框不代表机器人地面接触点')
        b = box.get('bbox')
        if not isinstance(b, list) or len(b) != 4 or not all(number(v, 0, 1) for v in b) or min(b[2:]) <= 0 or b[0]+b[2] > 1.001 or b[1]+b[3] >= .985:
            raise ValueError('目标接地点被画面裁切或框无效')
        u, v = b[0]+b[2]/2, b[1]+b[3]
        forward, right = ground_hit(u, v, camera)
        distance = math.hypot(forward, right)
        if not .2 <= distance <= c.get('max_range_m', 25):
            raise ValueError('交点距离超出允许范围')
        # Position the camera mounting offset using chassis heading, then apply camera yaw.
        origin = [position[0]+math.cos(heading)*c.get('forward_offset_m', 0)+math.sin(heading)*c.get('right_offset_m', 0),
                  position[1]+math.sin(heading)*c.get('forward_offset_m', 0)-math.cos(heading)*c.get('right_offset_m', 0)]
        angle = heading-math.radians(camera.get('camera_yaw_offset_deg', 0))
        xy = [origin[0]+math.cos(angle)*forward+math.sin(angle)*right,
              origin[1]+math.sin(angle)*forward-math.cos(angle)*right]
        if not 0 <= xy[0] <= 28 or not 0 <= xy[1] <= height:
            raise ValueError('交点超出场地，不裁剪到边缘')
        error = 0
        pixel = c.get('pixel_uncertainty_normalized', .006)
        for du, dv, dh, dp in [(pixel, 0, 0, 0), (-pixel, 0, 0, 0), (0, pixel, 0, 0), (0, -pixel, 0, 0),
                (0, 0, c.get('height_uncertainty_m', .1), 0), (0, 0, -c.get('height_uncertainty_m', .1), 0),
                (0, 0, 0, c.get('pitch_uncertainty_deg', 2)), (0, 0, 0, -c.get('pitch_uncertainty_deg', 2))]:
            f, r = ground_hit(u+du, v+dv, camera, dh, dp)
            error = max(error, math.hypot(f-forward, r-right))
        # A one-hertz pose can lag a turning chassis. Include bounded rotation
        # during the pose/angle age; a fixed +/-3deg alone would understate it.
        angle_skew = abs(stamp-attitude['stamp_ms'])/1000 if not c.get('rigid_camera_confirmed', False) else 0
        angle_error = c.get('yaw_uncertainty_deg', 3)+skew/1000*c.get('max_observer_yaw_rate_degps', 180)+angle_skew*c.get('max_camera_yaw_rate_degps', 360)
        angular = 2*distance*math.sin(math.radians(min(180, angle_error))/2)
        uncertainty = (error+max(c.get('pose_uncertainty_m', .3), observer.get('uncertainty_m', 0))+angular
            +skew/1000*c.get('max_observer_speed_mps', 5)+max(0, now-stamp)/1000*c.get('max_target_speed_mps', 5))
        if uncertainty > c.get('max_uncertainty_m', 8):
            raise ValueError('误差范围过大，保留图像观测')
        remaining = min(1500, observer['expires_ms']-stamp)
        if not c.get('rigid_camera_confirmed', False):
            remaining = min(remaining, attitude['expires_ms']-stamp)
        if stamp+remaining-now < 50:
            raise ValueError('本车位姿有效期不足')
        return {'position': xy, 'frame_id': c['frame_id'], 'uncertainty_m': round(max(.05, uncertainty), 3),
                'calibration_id': c['calibration_id'], 'estimated': True, 'ttl_ms': int(remaining),
                'distance_m': round(distance, 2), 'method': 'mobile-ground-plane', 'observer_stamp_ms': observer['stamp_ms'],
                'observer_robot_id': observer.get('robot_id'), 'observer_position': position,
                'camera_attitude_stamp_ms': attitude.get('stamp_ms') if attitude else None, 'time_skew_ms': skew}

    def details(self):
        return {'enabled': self.config.get('enabled', False), 'ready': self.ready, 'status': self.status,
                'positioned': self.positioned, 'rejected': self.rejected, 'method': 'mobile-ground-plane',
                'calibration_id': self.config.get('calibration_id', ''), 'frame_id': self.config.get('frame_id', '')}
