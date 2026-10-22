.pragma library

// 只决定2026身份约定下的显示外形，不推断新协议字段或实际机构状态。
var definitions = {
    infantry: {prefix:"robot", min:[-35,.5,-53.45], max:[35,46.25,35.9]},
    hero: {prefix:"hero", min:[-37.92,.5,-61.95], max:[37.92,49.25,38.21]},
    engineer: {prefix:"engineer", min:[-36.168,.5,-54.577], max:[36.168,60.708,36.824]},
    aerial: {prefix:"aerial", min:[-38.97,.9,-38.97], max:[38.97,27.55,38.97]},
    sentry: {prefix:"sentry", min:[-35,.5,-53.45], max:[35,66.5,35.9]}
};
function roleForId(id) {
    if (!Number.isInteger(id)) return "infantry";
    return ({1:"hero",2:"engineer",6:"aerial",7:"sentry"})[id % 100] ?? "infantry";
}
function visual(id) { return definitions[roleForId(id)]; }
function asset(id, team) {
    return "../assets/robot/" + visual(id).prefix + "-"
        + (team === "red" ? "red" : team === "blue" ? "blue" : "neutral") + ".glb";
}
