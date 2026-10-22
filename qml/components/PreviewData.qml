import QtQuick
import "OperatorDiagnostics.js" as Diagnostics
import "OperatorPreviewRules.js" as PreviewRules

TelemetryDefaults {
    id: root
    property int clientID: 3
    property string scenario: "nominal"
    property string baseVisual: "telemetry"
    property string outpostVisual: "telemetry"
    property string rosterVisual: "nominal"
    property string fillVisual: "telemetry"
    property var ownCombatDrawing: null
    property var ownEnergyDrawing:null
    property var ownAirDrawing:null
    property var ownSupportDrawing:null
    property var ownModuleDrawing:null
    property var ownVitalsDrawing:null
    property var scoreboardDrawing: null
    property int fixtureLevel: 2
    readonly property var ownRuleSample: PreviewRules.sample(clientID,fixtureLevel)
    readonly property var ownExperienceSample: PreviewRules.experience(fixtureLevel,350/550)
    property int outpostDrawingStep: 0
    readonly property string outpostDrawingState: outpostVisual === "sequence"
        ? ["normal","damage","stationary","destroyed","rebuildable","rebuilding","invulnerable","unknown"][outpostDrawingStep % 8]
        : outpostVisual
    property Timer outpostDrawingTimer: Timer {
        interval: 1500
        repeat: true
        running: root.outpostVisual === "sequence"
        onTriggered: root.outpostDrawingStep += 1
    }
    property int baseDrawingStep: 0
    readonly property string baseDrawingState: baseVisual === "sequence"
        ? ["normal", "damage", "shield", "low", "destroyed", "invulnerable", "stale", "normal"][baseDrawingStep % 8]
        : baseVisual
    // 仅离线绘制入口循环状态；不启动输入、音频、MQTT或真实比赛计时。
    property Timer baseDrawingTimer: Timer {
        interval: 1600
        repeat: true
        running: root.baseVisual === "sequence"
        onTriggered: root.baseDrawingStep += 1
    }
    property string dartVisual: "telemetry"
    property string roleVisual: "telemetry"
    property string byteVisual: "nominal"
    property string matchVisual: "battle"
    property string exchangeVisual: "remote"
    readonly property bool online: scenario !== "disconnected"
    readonly property bool critical: scenario === "low-health"
    readonly property bool sentryDefeatedSample: clientID % 100 === 7 && roleVisual === "failed" || ["pending", "free-ready", "pay-ready"].includes(exchangeVisual)
    gameStatus: scoreboardDrawing !== null ? scoreboardDrawing.values : online ? ({
                              current_round: 1,
                              total_rounds: 3,
                              red_score: 2,
                              blue_score: 1,
                              current_stage: ["unknown", "offline-preparation"].includes(matchVisual) ? undefined : matchVisual === "preparation" || matchVisual === "sequence" ? 1 : matchVisual === "countdown" ? 3 : 4,
                              stage_countdown_sec: scenario === "final-seconds" ? 7 : 187,
                              is_paused: scenario === "paused"
                          }) : ({})
    robotStatic: online ? Object.assign({
                               robot_id: clientID,
                               robot_type: clientID % 100,
                               max_health: ownRuleSample.maximum,
                               max_heat: 240,
                               max_power: 80,
                               max_buffer_energy: 60,
                               max_chassis_energy: 100,
                               level: ownRuleSample.level,
                               heat_cooldown_rate: 40,
                               performance_system_shooter: ownRuleSample.shooter,
                               performance_system_chassis: ownRuleSample.chassis,
                               connection_state: 1,
                               field_state: 0,
                               alive_state: sentryDefeatedSample ? 2 : 1
                           },root.ownEnergyDrawing?.staticValues ?? {},root.ownCombatDrawing?.staticValues ?? {},root.ownAirDrawing?.staticValues ?? {},root.ownSupportDrawing?.staticValues ?? {},root.ownModuleDrawing?.staticValues ?? {},root.ownVitalsDrawing?.staticValues ?? {}) : ({})
    robotDynamic: online ? Object.assign({
                                current_health: ownRuleSample.maximum === undefined ? undefined : sentryDefeatedSample || rosterVisual === "zero" ? 0 : critical ? 48 : Math.floor(ownRuleSample.maximum*(rosterVisual === "full" ? 1 : 0.8)),
                                remaining_ammo: rosterVisual === "zero" ? 0 : clientID % 100 === 6
                                    ? fillVisual !== "telemetry" ? ({empty:0,half:375,full:750})[fillVisual] : critical ? 40 : 540
                                    : 120,
                                current_heat: fillVisual !== "telemetry" ? ({empty:0,half:120,full:240})[fillVisual] : critical ? 220 : 56,
                                last_projectile_fire_rate: 25.8,
                                current_chassis_energy: 72,
                                current_buffer_energy: 44,
                                current_experience: ownRuleSample.level === undefined ? undefined : ownExperienceSample.current,
                                experience_for_upgrade: ownRuleSample.level === undefined ? undefined : ownExperienceSample.remaining,
                                total_projectiles_fired: 340,
                                is_out_of_combat: ownCombatDrawing !== null ? ownCombatDrawing.flag : false,
                                out_of_combat_countdown: ownCombatDrawing !== null ? ownCombatDrawing.countdown : 0,
                                can_remote_heal: true,
                                can_remote_ammo: true
                            },root.ownEnergyDrawing?.dynamicValues ?? {},root.ownCombatDrawing?.dynamicValues ?? {},root.ownAirDrawing?.dynamicValues ?? {},root.ownVitalsDrawing?.dynamicValues ?? {}) : ({})
    robotRespawn: online ? ({is_pending_respawn: ["pending", "free-ready", "pay-ready"].includes(exchangeVisual),
        total_respawn_progress: 100, current_respawn_progress: exchangeVisual === "free-ready" ? 100 : exchangeVisual === "pending" || exchangeVisual === "pay-ready" ? 54 : 0,
        can_free_respawn: exchangeVisual === "free-ready", can_pay_for_respawn: exchangeVisual === "pay-ready", gold_cost_for_respawn: 200}) : ({})
    globalUnit: online ? ({
                              base_health: baseDrawingState === "destroyed" ? 0 : baseDrawingState === "low" ? 800 : baseDrawingState === "damage" ? 3200 : 5000,
                              base_status: baseDrawingState === "unknown" ? 99 : baseDrawingState === "invulnerable" || baseDrawingState === "telemetry" ? 0 : 2,
                              base_shield: baseDrawingState === "shield" ? 2000 : 0,
                              enemy_base_health: 4200,
                              enemy_base_status: baseDrawingState === "telemetry" ? undefined : baseDrawingState === "unknown" ? 99 : 2,
                              enemy_base_shield: baseDrawingState === "shield" ? 150 : undefined,
                              outpost_health: ["destroyed","rebuildable","rebuilding"].includes(outpostDrawingState) ? 0
                                  : outpostDrawingState === "damage" ? 600 : outpostDrawingState === "telemetry" ? 1000 : 1500,
                              outpost_status: ({destroyed:3,rebuildable:4,rebuilding:5,invulnerable:0,stationary:2,unknown:99})[outpostDrawingState] ?? 1,
                              enemy_outpost_health: ["moving-target", "base-selection"].includes(dartVisual) ? 0 : 620,
                              enemy_outpost_status: ["moving-target", "base-selection"].includes(dartVisual) ? 3
                                  : outpostDrawingState === "unknown" ? undefined : 2,
                              robot_health: (() => {
                                  const order=clientID>100?[101,102,103,104,107,1,2,3,4,7]:[1,2,3,4,7,101,102,103,104,107];
                                  const values=order.map(id=>Math.floor((id===root.clientID?root.ownRuleSample:PreviewRules.sample(id)).maximum*(rosterVisual === "full" ? 1 : 0.8)));
                                  const ownIndex = [1, 2, 3, 4, 7].indexOf(clientID % 100);
                                  if (rosterVisual === "zero") return values.map(()=>0);
                                  if (sentryDefeatedSample && ownIndex >= 0) values[ownIndex] = 0;
                                  return values;
                              })(),
                              robot_bullets: [50, 0, 120, 100, 200],
                              total_damage_ally: 1400,
                              total_damage_enemy: 960
                          }) : ({})
    globalLogistics: online ? ({
                                   remaining_economy: 1280,
                                   total_economy_obtained: 3820,
                                   tech_level: 2,
                                   encryption_level: 1
                               }) : ({})
    globalSpecial: online ? ({
                                 mechanism_id: [1],
                                 mechanism_time_sec: [42]
                             }) : ({})
    robotModule: root.ownModuleDrawing !== null ? root.ownModuleDrawing.nativeValues : online ? ({
                               power_manager: roleVisual === "failed" ? 0 : 1,
                               main_controller: 1,
                               armor: 1,
                               video_transmission: roleVisual === "failed" ? 2 : 1,
                               small_shooter: 1,
                               big_shooter: 1,
                               rfid: 1,
                               uwb: 1,
                               capacitor: critical ? 0 : 1,
                               light_strip: 1,
                               laser_detection_module: roleVisual === "failed" ? 255 : 1
                           }) : ({})
    robotPerfSync: online ? ({
                                 shooter: ownRuleSample.shooter,
                                 chassis: ownRuleSample.chassis,
                                 sentry_control: clientID%100 === 7 ? (clientID>100?0:1) : undefined
                             }) : ({})
    runeStatus: online ? ({
                              activated_arms: roleVisual === "failed" ? 6 : roleVisual === "active" ? 2 : roleVisual === "complete" ? 5 : 0,
                              average_rings: roleVisual === "active" ? 8.6 : 0,
                              rune_status: roleVisual === "failed" ? 255 : roleVisual === "active" ? 2 : roleVisual === "complete" ? 3 : 1
                          }) : ({})
    techCore: online ? ({
                            basic_state: roleVisual === "active" ? 2 : ["confirm", "level4", "complete", "failed"].includes(roleVisual) ? 3 : 1,
                            maximum_difficulty_level: ["level4", "complete"].includes(roleVisual) ? 4 : 3,
                            move_state: ["level4", "complete"].includes(roleVisual) ? 1 : 0,
                            putin_state: ["confirm", "level4", "complete"].includes(roleVisual) ? 1 : 0,
                            rotate_state: roleVisual === "complete" ? 1 : 0,
                            remain_time_all: roleVisual === "level4" ? 28 : 0,
                            remain_time_step: roleVisual === "level4" ? 7 : 0,
                            enemy_core_status: 1
                        }) : ({})
    robotPosition: online ? ({
                                 x: 8,
                                 y: 5,
                                 yaw: 24
                             }) : ({})
    mapClick: online ? ({is_send_all: 0,
        robot_id: clientID > 100 ? "65660000000000" : "01020000000000",
        mode: 2, type: 1, map_x: 9, map_y: 11}) : ({})
    radar: online ? ({
                         radar_single_robot_info: [
                             {
                                 target_pos_x: 1900,
                                 target_pos_y: 900,
                                 is_high_light: 1
                             },
                             {
                                 target_pos_x: roleVisual === "active" ? 0 : 2100,
                                 target_pos_y: roleVisual === "active" ? 0 : 500,
                                 is_high_light: roleVisual === "active" ? 2 : 0
                             }
                         ]
                     }) : ({})
    robotInjury: online ? ({
                               total_damage: 80,
                               collision_damage: 10,
                               small_projectile_damage: 60,
                               large_projectile_damage: 10,
                               dart_splash_damage: 0,
                               module_offline_damage: 0,
                               offline_damage: 0,
                               penalty_damage: 0,
                               server_kill_damage: 0,
                               killer_id: 0
                           }) : ({})
    deployMode: online ? ({
                              status: roleVisual === "active" ? 1 : 0
                          }) : ({})
    sentryStatus: online ? ({
                                posture_id: roleVisual === "active" ? 2 : roleVisual === "complete" ? 3 : 1,
                                is_powered: roleVisual === "active",
                                is_weakened: roleVisual === "failed"
                            }) : ({})
    sentryCtrlResult: online ? ({command_id: 7, result_code: roleVisual === "failed" ? 1 : 0}) : ({})
    airSupport: online ? Object.assign({
                              airsupport_status: ["idle", "complete"].includes(roleVisual) ? 0 : 1,
                              left_time: roleVisual === "complete" ? 0 : 32,
                              cost_coins: roleVisual === "idle" ? 0 : 60,
                              is_being_targeted: ["idle", "complete"].includes(roleVisual) ? 0 : 1,
                              shooter_status: roleVisual === "idle" || roleVisual === "complete" ? 1 : roleVisual === "failed" ? 0 : 2
                          },root.ownAirDrawing?.airValues ?? {},root.ownSupportDrawing?.airValues ?? {}) : ({})
    dartTarget: online ? ({
                              open: dartVisual === "unrecognized" ? 255 : ["closed", "confirm", "base-selection", "cooldown", "exhausted"].includes(dartVisual) ? 0
                                    : dartVisual === "opening" ? 1 : 2,
                              target_id: dartVisual === "unrecognized" ? 255 : ["moving-target", "base-selection"].includes(dartVisual) ? 4 : 1
                          }) : ({})
    customByteBlock: online ? ({data: byteVisual === "empty" ? "" : byteVisual === "malformed" ? "0g"
        : byteVisual === "long" ? Array.from({length: 300}, (_, index) => (index % 256).toString(16).padStart(2, "0")).join("")
        : "01020304aabbccdd"}) : ({})
    freshness: {
        const result = {};
        for (const group of Object.keys(Diagnostics.groupTitles)) {
            const present = online && Object.keys(root[group] ?? {}).length > 0;
            result[group] = !present ? "missing" : scenario === "hud-stale" ? "stale" : "fresh";
        }
        const roleGroups = ["deployMode", "sentryStatus", "sentryCtrlResult", "airSupport",
                            "dartTarget", "runeStatus", "techCore"];
        if (scenario === "role-stale" || scenario === "role-missing") {
            for (const group of roleGroups) {
                result[group] = scenario === "role-stale" ? "stale" : "missing";
            }
        }
        return result;
    }
    // 仅角色组采用这些离线场景，其余 HUD 保持正常样例，方便看清局部差异。
    fieldFreshness: {
        const result = {};
        // 计分板严格消费逐字段时效；其普通mock也提供完整元数据。
        // 其他尚未迁移的组继续保持原场景语义，不能在此顺带改全局数据边界。
        if (root.scoreboardDrawing !== null) {
            if (root.scoreboardDrawing.fieldStates !== null) result.gameStatus=root.scoreboardDrawing.fieldStates;
        } else {
            result.gameStatus={};
            for (const key of Object.keys(root.gameStatus)) {
                if (root.gameStatus[key] !== undefined) result.gameStatus[key]=scenario === "hud-stale" ? "stale" : "fresh";
            }
        }
        result.robotDynamic={};
        for (const key of ["is_out_of_combat","out_of_combat_countdown"])
            if (root.robotDynamic[key] !== undefined) result.robotDynamic[key]=scenario === "hud-stale" ? "stale" : "fresh";
        if (root.ownCombatDrawing !== null) {
            result.robotDynamic.is_out_of_combat=root.ownCombatDrawing.flag_state;
            result.robotDynamic.out_of_combat_countdown=root.ownCombatDrawing.countdown_state;
        }
        // 本项只迁移能量与主体ID的mock元数据；不把其他HUD字段顺带改成整组保证。
        for (const group of ["robotStatic","robotDynamic"]) {
            const keys=group === "robotStatic" ? ["robot_id","max_chassis_energy","max_buffer_energy"]
                : ["current_chassis_energy","current_buffer_energy"];
            result[group]=Object.assign({},result[group]);
            for (const key of keys) if (root[group][key] !== undefined)
                result[group][key]=scenario === "hud-stale" ? "stale" : "fresh";
            if (root.ownEnergyDrawing !== null) {
                for (const key of keys) delete result[group][key];
                Object.assign(result[group],root.ownEnergyDrawing.fieldStates[group]);
            }
        }
        if (root.robotStatic.alive_state !== undefined)
            result.robotStatic.alive_state=scenario === "hud-stale" ? "stale" : "fresh";
        for (const group of ["robotStatic","robotDynamic"]) {
            const keys=group === "robotStatic" ? ["max_health","level"] : ["current_health","current_experience","experience_for_upgrade"];
            for (const key of keys) if (root[group][key] !== undefined)
                result[group][key]=scenario === "hud-stale" ? "stale" : "fresh";
        }
        // 专用脱战样例可省略主体元数据；不能让默认样例替它补fresh。
        if (root.ownCombatDrawing?.subjectStates !== undefined) {
            delete result.robotStatic.robot_id;
            delete result.robotStatic.alive_state;
            Object.assign(result.robotStatic,root.ownCombatDrawing.subjectStates);
        }
        const airKeys=["airsupport_status","left_time","cost_coins","is_being_targeted","shooter_status"];
        result.airSupport={};
        for (const key of airKeys) if (root.airSupport[key] !== undefined)
            result.airSupport[key]=scenario === "role-missing" ? "missing" : ["role-stale","hud-stale"].includes(scenario) ? "stale" : "fresh";
        if (root.robotDynamic.remaining_ammo !== undefined)
            result.robotDynamic.remaining_ammo=scenario === "hud-stale" ? "stale" : "fresh";
        if (root.ownAirDrawing !== null) {
            for (const group of ["robotStatic","robotDynamic","airSupport"]) {
                const keys=group === "robotStatic" ? ["robot_id"] : group === "robotDynamic" ? ["remaining_ammo"] : airKeys;
                for (const key of keys) delete result[group][key];
                Object.assign(result[group],root.ownAirDrawing.fieldStates[group]);
            }
        }
        if (root.ownSupportDrawing !== null) {
            delete result.robotStatic.robot_id;
            Object.assign(result.robotStatic,root.ownSupportDrawing.fieldStates.robotStatic);
            result.airSupport=Object.assign({},root.ownSupportDrawing.fieldStates.airSupport);
        }
        result.robotModule={};
        for (const key of Object.keys(root.robotModule)) if (root.robotModule[key] !== undefined)
            result.robotModule[key]=scenario === "hud-stale" ? "stale" : "fresh";
        if (root.ownModuleDrawing !== null) {
            delete result.robotStatic.robot_id;
            Object.assign(result.robotStatic,root.ownModuleDrawing.fieldStates.robotStatic);
            result.robotModule=Object.assign({},root.ownModuleDrawing.fieldStates.robotModule);
        }
        if (root.ownVitalsDrawing !== null) {
            for (const group of ["robotStatic","robotDynamic"]) {
                const keys=group === "robotStatic" ? ["robot_id","max_health","level"] : ["current_health","current_experience","experience_for_upgrade"];
                for (const key of keys) delete result[group][key];
                Object.assign(result[group],root.ownVitalsDrawing.fieldStates[group]);
            }
        }
        if (root.baseDrawingState === "stale") {
            result.globalUnit = {base_health:"stale",base_status:"stale",base_shield:"stale"};
        }
        if (scenario === "hud-partial") {
            result.mapClick = {map_x: "stale"};
            result.robotPosition = {x: "stale"};
            result.gameStatus = Object.assign({},result.gameStatus,{stage_countdown_sec:"stale"});
            result.globalUnit = {
                base_health: "stale",
                total_damage_enemy: "stale"
            };
            result.robotDynamic = Object.assign({},result.robotDynamic,{
                remaining_ammo: "stale",
                current_health: "stale",
                last_projectile_fire_rate: "stale",
                current_chassis_energy: "stale"
            });
            result.robotStatic = Object.assign({},result.robotStatic,{max_heat: "stale", heat_cooldown_rate: "missing", max_health: "stale", max_buffer_energy: "missing"});
            result.robotInjury = {small_projectile_damage: "stale", dart_splash_damage: "missing", killer_id: "stale"};
            result.robotModule = Object.assign({},result.robotModule,{video_transmission: "stale", armor: "missing"});
            return result;
        }
        if (scenario !== "role-partial") {
            return result;
        }
        result.airSupport = {
            shooter_status: "stale",
            left_time: "stale",
            cost_coins: "missing",
            is_being_targeted: "stale"
        };
        result.runeStatus = {activated_arms: "stale", average_rings: "missing"};
        result.dartTarget = {target_id: "stale"};
        result.robotRespawn = {current_respawn_progress: "stale", gold_cost_for_respawn: "stale"};
        result.robotDynamic = Object.assign({},result.robotDynamic,{can_remote_heal: "stale", can_remote_ammo: "missing"});
        result.techCore = {
            maximum_difficulty_level: "stale",
            putin_state: "stale",
            rotate_state: "missing",
            remain_time_step: "stale"
        };
        result.sentryStatus = {is_powered: "stale", is_weakened: "missing"};
        result.robotPerfSync = {sentry_control: "stale"};
        return result;
    }
    robotData: {
        if (!online)
            return {};
        const result = {}, allies = [1, 2, 3, 4, 7], health = globalUnit.robot_health;
        for (let i = 0; i < 10; ++i) {
            const id = allies[i % 5] + ((i < 5) === (clientID < 100) ? 0 : 100);
            result[String(id)] = {
                current_health: health[i], current_health_source: "globalUnit"
            };
            if (i < 5)
                result[String(id)].remaining_bullets = globalUnit.robot_bullets[i];
        }
        result[String(clientID)] = Object.assign({}, robotStatic, robotDynamic, {
                                                     remaining_bullets: robotDynamic.remaining_ammo,
                                                     current_health_source: "robotDynamic"
                                                 });
        return result;
    }
}
