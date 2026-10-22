"""Image-space tracer candidates. No weapon commands, range or physical ballistic claim."""
import base64
import concurrent.futures
import math
import time
from motion_trail import MotionTrail


class Detector:
    def __init__(self, config):
        self.config = config
        self.previous = None
        self.stamp = 0
        self.tracks = []
        self.next_id = 1
        self.bright_history = []
        self.id_stamps = {}
        self.motion_trail = MotionTrail()

    def process(self, image, stamp):
        import cv2
        import numpy as np
        cv2.setNumThreads(1)
        h, w = image.shape[:2]
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        roi = self.config.get('roi', [.04, .04, .92, .92])
        mask = np.zeros((h, w), np.uint8)
        x0, y0 = int(roi[0]*w), int(roi[1]*h)
        x1, y1 = min(w, int((roi[0]+roi[2])*w)), min(h, int((roi[1]+roi[3])*h))
        mask[y0:y1, x0:x1] = 255
        for x,y,rw,rh in self.config.get("exclude_regions",[]):
            mask[int(y*h):min(h,int((y+rh)*h)),int(x*w):min(w,int((x+rw)*w))]=0
        trail = self.motion_trail.process(image, stamp, mask)
        empty = dict(trail, tracks=[], candidates=[], camera_inliers=0., status='等待连续帧', stamp_ms=stamp)
        if self.previous is None or self.previous.shape != gray.shape or not 20 <= stamp-self.stamp <= 500:
            self.previous, self.stamp, self.tracks = gray, stamp, []
            self.bright_history = []
            return empty
        previous, previous_stamp = self.previous, self.stamp
        self.previous, self.stamp = gray, stamp
        points = cv2.goodFeaturesToTrack(previous, maxCorners=120, qualityLevel=.015, minDistance=5, mask=mask)
        affine, fraction = None, 0.
        if points is not None and len(points) >= 10:
            moved, valid, errors = cv2.calcOpticalFlowPyrLK(previous, gray, points, None, winSize=(15,15), maxLevel=2)
            if moved is not None:
                good = valid.ravel().astype(bool) & (errors.ravel() < 35)
                if int(good.sum()) >= 8:
                    affine, inliers = cv2.estimateAffinePartial2D(points[good], moved[good], method=cv2.RANSAC, ransacReprojThreshold=1.5)
                    if inliers is not None: fraction = float(inliers.mean())
        if affine is None or fraction < .55 or not np.isfinite(affine).all() or not .94 < math.hypot(affine[0,0], affine[1,0]) < 1.06 or np.linalg.norm(affine[:,2]) > .12*w:
            self.tracks = [];self.bright_history = []
            return dict(empty, status='相机运动补偿不足；不生成轨迹', camera_inliers=fraction)
        aligned = cv2.warpAffine(previous, affine, (w,h))
        residual = cv2.absdiff(gray, aligned)
        b,g,r = [c.astype(np.int16) for c in cv2.split(image)]
        color = self.config.get('color', 'bright')
        if color == 'green': contrast = g-np.maximum(r,b); bright = (g>105) & (contrast>22)
        elif color == 'red': contrast = r-np.maximum(g,b); bright = (r>120) & (contrast>30)
        else: contrast = gray.astype(np.int16); bright = gray>210
        # Local contrast rejects broad color panels; temporal residual rejects baked-in aim graphics.
        top = cv2.morphologyEx(np.clip(contrast,0,255).astype(np.uint8), cv2.MORPH_TOPHAT, np.ones((9,9),np.uint8))
        self.bright_history=[cv2.warpAffine(p,affine,(w,h)) for p in self.bright_history][-7:]
        recurring=np.zeros((h,w),np.uint8)
        if len(self.bright_history)>=3:
            recurring=(np.stack(self.bright_history).sum(axis=0)>=3).astype(np.uint8)
            recurring=cv2.dilate(recurring,np.ones((3,3),np.uint8))
        self.bright_history.append(bright.astype(np.uint8))
        candidates_mask = (bright & (top>15) & (residual>16) & (mask>0) & (recurring==0)).astype(np.uint8)
        count, labels, stats, centers = cv2.connectedComponentsWithStats(candidates_mask, 8)
        candidates=[]
        for i in range(1,count):
            x,y,bw,bh,area=map(int,stats[i]);cx,cy=map(float,centers[i])
            if not 1 <= area <= max(12,w*h*.0012) or bw>max(7,w*.035) or bh>max(12,h*.09):continue
            strength=float(contrast[y:y+bh,x:x+bw][labels[y:y+bh,x:x+bw]==i].mean())
            candidates.append({'x':cx,'y':cy,'bbox':[x/w,y/h,bw/w,bh/h], 'strength':strength})
        candidates=sorted(candidates,key=lambda c:-c['strength'])[:24]
        def warp(p):return [float(affine[0,0]*p[0]+affine[0,1]*p[1]+affine[0,2]),float(affine[1,0]*p[0]+affine[1,1]*p[1]+affine[1,2]),p[2]]
        self.tracks=[t for t in self.tracks if stamp-t['stamp_ms']<=450]
        for t in self.tracks:t['pixels']=[warp(p) for p in t['pixels']]
        used=set()
        for candidate in candidates:
            best=None
            for t in self.tracks:
                if t['id'] in used:continue
                p=t['pixels'][-1];dt=(stamp-p[2])/1000
                velocity=[0.,0.]
                if len(t['pixels'])>=2:
                    q=t['pixels'][-2];elapsed=max(.02,(p[2]-q[2])/1000)
                    velocity=[(p[j]-q[j])/elapsed for j in range(2)]
                distance=math.hypot(candidate['x']-p[0]-velocity[0]*dt,candidate['y']-p[1]-velocity[1]*dt)
                gate=max(5,w*.022)*(1+dt)
                if distance<=gate and (best is None or distance<best[0]):best=(distance,t)
            if best:t=best[1]
            else:
                track_id=None
                for _ in range(256):
                    candidate_id=self.next_id;self.next_id=self.next_id%256+1
                    if stamp-self.id_stamps.get(candidate_id,-100000)>2000:
                        track_id=candidate_id;break
                if track_id is None:continue
                t={'id':track_id,'pixels':[],'stamp_ms':stamp};self.tracks.append(t)
            self.id_stamps[t['id']]=stamp
            used.add(t['id']);t['pixels'].append([candidate['x'],candidate['y'],stamp]);t['pixels']=t['pixels'][-12:]
            t.update(stamp_ms=stamp,bbox=candidate['bbox'],strength=candidate['strength'])
        self.tracks=sorted(self.tracks,key=lambda t:-t['stamp_ms'])[:48]
        result=[]
        for t in self.tracks[:24]:
            ps=t['pixels'];n=len(ps)
            if n<2 or stamp-t['stamp_ms']>200:continue
            displacement=math.dist(ps[0][:2],ps[-1][:2]);length=sum(math.dist(a[:2],b[:2]) for a,b in zip(ps,ps[1:]))
            recent=ps[-4:]
            steps=[math.dist(a[:2],b[:2]) for a,b in zip(recent,recent[1:])]
            intervals=[b[2]-a[2] for a,b in zip(recent,recent[1:])]
            confirmed=n>=3 and all(.8<=v<=w*.09 for v in steps) and all(20<=v<=220 for v in intervals) and displacement>=max(4.,w*.014) and length<=max(4.,displacement*1.5)
            confidence=min(.85,.30+.07*n+.15*fraction)*math.exp(-(stamp-t['stamp_ms'])/450)
            prediction=[]
            if confirmed and n>=4:
                ts=np.array([(p[2]-ps[-1][2])/1000 for p in ps[-5:]])
                values=np.array([p[:2] for p in ps[-5:]])
                design=np.column_stack([ts,np.ones(len(ts))]);coeff=np.linalg.lstsq(design,values,rcond=None)[0]
                error=float(np.sqrt(((design@coeff-values)**2).mean()))
                p=coeff[1]+coeff[0]*.15
                if error<max(2.,w*.01) and np.linalg.norm(coeff[0])<w*2 and 0<=p[0]<w and 0<=p[1]<h:
                    prediction=[float(p[0]/w),float(p[1]/h),ps[-1][2]+150]
            result.append({'track_id':t['id'],'stamp_ms':t['stamp_ms'],'age_ms':stamp-t['stamp_ms'],
                           'bbox':t['bbox'],'confidence':round(confidence,3),'confirmed':confirmed,
                           'points':[[float(p[0]/w),float(p[1]/h),p[2]] for p in ps if 0<=p[0]<w and 0<=p[1]<h],
                           'prediction':prediction,'coordinate_frame':'camera.hero.normalized','estimated':True})
        return dict(trail, tracks=result, candidates=[c['bbox'] for c in candidates], camera_inliers=round(fraction,3),
                    status='明暗运动像素拖影已启用；连线仍仅为亮点候选', stamp_ms=stamp)


class Projectile:
    def __init__(self, config):
        self.config=config;self.pool=concurrent.futures.ThreadPoolExecutor(max_workers=1,thread_name_prefix='projectile')
        self.future=None;self.epoch=0;self.detector=Detector(config);self.view={'tracks':[],'status':'等待吊射视频帧' if config.get('enabled',False) else '弹丸跟踪未启用'}
        self.frames=self.dropped=self.sequence=0;self.last_stamp=0;self.inference_ms=0.
    def reset(self):
        self.epoch+=1;self.detector=Detector(self.config);self.view={'tracks':[],'status':'等待新吊射画面'};self.last_stamp=0
    def close(self):self.reset();self.pool.shutdown(wait=False,cancel_futures=True)
    def submit(self, frame):
        if not self.config.get('enabled',False):return
        if self.future is not None or int(time.time()*1000)-frame.get('stamp_ms',0)>600:self.dropped+=1;return
        self.future=self.pool.submit(self._process,dict(frame),self.detector,self.epoch)
    @staticmethod
    def _process(frame,detector,epoch):
        import cv2,numpy as np
        start=time.monotonic();raw=base64.b64decode(frame['jpeg'],validate=True)
        image=cv2.imdecode(np.frombuffer(raw,np.uint8),cv2.IMREAD_COLOR)
        if image is None or image.shape[0]*image.shape[1]>960*640:raise ValueError('invalid projectile frame')
        h,w=image.shape[:2]
        if w>640:image=cv2.resize(image,(640,round(h*640/w)))
        return detector.process(image,frame['stamp_ms']),epoch,(time.monotonic()-start)*1000
    def poll(self):
        now=int(time.time()*1000)
        self.view['tracks']=[t for t in self.view.get('tracks',[]) if now-t['stamp_ms']<=450]
        if not 0 <= now-self.view.get('trail_stamp_ms', 0) <= 450:
            self.view['trail_image']='';self.view['trail_pixels']=0
        if self.future is None or not self.future.done():return []
        f,self.future=self.future,None
        try:
            result,epoch,self.inference_ms=f.result()
            if epoch!=self.epoch or now-result.get('stamp_ms',now)>600:return []
            self.frames+=1;self.view=result;samples=[]
            for t in result['tracks']:
                if not t['confirmed'] or t['stamp_ms']<=self.last_stamp:continue
                self.sequence+=1
                samples.append({'source_id':'video.hero.projectile','target_id':'projectile:'+str(t['track_id']),
                    'sequence':self.sequence,'stamp_ms':t['stamp_ms'],'ttl_ms':450,'kind':'vision','team':'unknown',
                    'frame_id':'camera.hero.normalized','bbox':t['bbox'],'confidence':t['confidence'],'estimated':True,
                    'label':'弹丸轨迹候选（图像估计，接收帧时间）','image_trail':t['points'][-12:]})
            self.last_stamp=max([self.last_stamp]+[t['stamp_ms'] for t in result['tracks']]);return samples
        except Exception as error:self.view={'tracks':[],'status':'弹丸视觉不可用：'+type(error).__name__};return []
    def details(self):
        return dict(self.view,frames=self.frames,dropped=self.dropped,inference_ms=round(self.inference_ms,2),
                    boundary='image-space bright moving tracer candidates; not range, impact or verified ballistic trajectory')
