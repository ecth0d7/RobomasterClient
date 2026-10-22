"""Native predicates and wording: a model ranks admissible tactical suggestions."""


def candidates(evidence, node):
    result = {}
    prefix = node+"/"
    fields = {key.rsplit(".", 1)[-1]: (key, value) for key, value in evidence.items()
              if value.get("kind") == "telemetry" and key.startswith(prefix) and type(value.get("value")) in (int, float)}
    units = {"current_health": "HP", "max_health": "HP", "current_heat": "heat", "max_heat": "heat", "remaining_ammo": "rounds"}
    fields = {k: v for k, v in fields.items() if k in units and v[1].get("unit") == units[k]}

    def add(name, text, rationale, ids, priority="info"):
        result[name] = {"action_id": name, "text": text, "rationale": rationale, "evidence": ids, "priority": priority}

    health, maximum = fields.get("current_health"), fields.get("max_health")
    if health and maximum and maximum[1]["value"] > 0 and 0 < health[1]["value"]/maximum[1]["value"] < .3:
        hp, maxhp = health[1]["value"], maximum[1]["value"]
        add("seek_cover", f"本机 HP {hp:g}/{maxhp:g}，建议优先寻找掩体，并确认补给条件。",
            "本机有效 HP 观测低于上限的三成；没有据此推断模块故障。", [health[0], maximum[0]], "caution")
    heat, limit = fields.get("current_heat"), fields.get("max_heat")
    if heat and limit and limit[1]["value"] > 0 and heat[1]["value"]/limit[1]["value"] > .85:
        add("reduce_fire", "热量接近已知上限，建议控制射击频率。", f"热量 {heat[1]['value']:g}/{limit[1]['value']:g}，超过85%。", [heat[0], limit[0]], "caution")
    ammo = fields.get("remaining_ammo")
    if ammo and ammo[1]["value"] == 0:
        add("check_resupply", "本机弹药为零，请确认补弹条件。", "弹药观测为0；没有假定远程兑换已经允许或成功。", [ammo[0]], "caution")
    conflict = next((key for key, value in evidence.items() if value.get("kind") == "fusion" and value.get("value") is True), None)
    if conflict:
        add("verify_conflict", "同一目标的位置来源存在冲突，请先核对各来源。", "融合器保留了存在分歧的观测，未将它们合成确定位置。", [conflict], "caution")
    spatial = next((key for key, value in evidence.items() if "position" in value), None)
    if spatial:
        add("verify_position", "已收到目标位置观测，建议结合来源、时效与现场画面核对后行动。", "位置是带时效的观测或融合估计，不能证明目标当前可见或可命中。", [spatial])
    if evidence:
        key = next(iter(evidence))
        add("observe", "当前建议保持观察，并核对信息来源与有效期。", "已收到有限有效信息；未据此假定未观测的目标、故障或执行结果。", [key])
    return result
