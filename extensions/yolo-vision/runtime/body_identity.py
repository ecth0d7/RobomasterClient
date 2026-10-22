"""Optional armor-to-body identity evidence, never an armor ground anchor.

Only an unambiguous contained plate may name a whole-body candidate. A short
same-track run is required; missing/conflicting evidence immediately clears
the identity. No identity is propagated from another camera or pixel colour.
"""
import time
from contract import number, integer
from onnx_detector import OnnxDetector


def contained_fraction(plate, body):
    x, y = max(plate[0], body[0]), max(plate[1], body[1])
    right, bottom = min(plate[0]+plate[2], body[0]+body[2]), min(plate[1]+plate[3], body[1]+body[3])
    return max(0, right-x)*max(0, bottom-y)/max(1e-12, plate[2]*plate[3])


def associate(bodies, plates):
    """Return one agreeing identity per body; overlapping ownership is rejected."""
    votes = [[] for _ in bodies]
    ambiguous = set()
    for plate in plates:
        if plate.get('team') not in ('red', 'blue') or plate.get('target_id') not in {
                team+':'+str(i) for team in ('red', 'blue') for i in (1, 2, 3, 4, 5, 7)}:
            continue
        p = plate['bbox']
        owners = [i for i, b in enumerate(bodies) if b.get('detection_scope') == 'whole_robot'
                  and contained_fraction(p, b['bbox']) >= .85
                  and .0001 <= p[2]*p[3]/max(1e-12, b['bbox'][2]*b['bbox'][3]) <= .35]
        if len(owners) != 1:
            ambiguous.update(owners)
        else:
            votes[owners[0]].append(plate)
    result = []
    for index, evidence in enumerate(votes):
        identities = {p['target_id'] for p in evidence}
        if index in ambiguous or len(identities) != 1:
            result.append(None)
        else:
            first = evidence[0]
            result.append({'team': first['team'], 'target_id': first['target_id'],
                           'confidence': min(p['confidence'] for p in evidence),
                           'plate_count': len(evidence), 'method': 'contained-armor-candidate'})
    return result


class BodyIdentity:
    def __init__(self, config, threads):
        self.enabled = isinstance(config, dict) and config.get('enabled') is True
        self.detector = None
        self.minimum_hits = 3
        self.status = '装甲身份辅助未启用；整机身份保持实际输出'
        self.frames = self.failures = self.confirmed = 0
        self.retry_at = 0
        if not self.enabled:
            return
        if (not isinstance(config.get('model_file'), str) or not config['model_file'].startswith('/')
                or not number(config.get('confidence', .65), .5, 1)
                or not integer(config.get('minimum_hits', 3), 3, 10)):
            self.status = '装甲身份配置不可用；继续整机检测'
            return
        self.minimum_hits = config.get('minimum_hits', 3)
        self.detector = OnnxDetector(dict(format='rp26-armor-v8', model_file=config['model_file'],
                                         confidence=config.get('confidence', .65), identity_margin=.15, threads=threads))
        self.status = '等待装甲与整机的同帧关联'

    def enrich(self, bodies, frame, image=None):
        if not self.detector or time.monotonic() < self.retry_at:
            return
        # This helper complements whole-body inference; armor-only mode never projects.
        if not any(b.get('detection_scope') == 'whole_robot' for b in bodies):
            return
        try:
            plates = self.detector.infer(frame, image)
            for body, candidate in zip(bodies, associate(bodies, plates)):
                if body.get('target_id') == 'unknown' and candidate:
                    body['identity_candidate'] = candidate
            self.frames += 1
            self.status = '装甲身份辅助运行；仅采用连续一致的关联候选'
        except Exception as error:
            self.failures += 1
            self.retry_at = time.monotonic()+5
            self.status = '装甲身份辅助不可用：'+type(error).__name__+'；继续整机检测'

    def confirm(self, body, previous, stamp):
        candidate = body.get('identity_candidate')
        body['identity_streak'] = 0
        if not self.enabled or not candidate or body.get('detection_scope') != 'whole_robot':
            return
        old = (previous or {}).get('identity_candidate', {})
        continuous = (old.get('target_id') == candidate['target_id'] and previous
                      and 0 <= stamp-previous['stamp_ms'] <= 500)
        body['identity_streak'] = previous.get('identity_streak', 0)+1 if continuous else 1
        body['identity_confirmed'] = body['identity_streak'] >= self.minimum_hits
        if body['identity_confirmed']:
            body['team'] = candidate['team']
            body['target_id'] = candidate['target_id']
            body['confidence'] = min(body['confidence'], candidate['confidence'])
            body['label'] += ' · '+candidate['target_id']+'（装甲关联候选）'
            self.confirmed += 1

    def details(self):
        return {'enabled': self.enabled, 'status': self.status, 'frames': self.frames,
                'failures': self.failures, 'confirmed_frames': self.confirmed,
                'minimum_hits': self.minimum_hits, 'method': 'contained-armor-candidate'}
