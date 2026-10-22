.pragma library

// Relative camp is presentation only; an inferred identity remains a candidate.
function relation(team, clientId) {
    const own = Number.isInteger(clientId) && ((clientId >= 1 && clientId <= 7)
        || (clientId >= 101 && clientId <= 107));
    if (!own || !['red', 'blue'].includes(team)) return '阵营未知';
    const ownTeam = clientId > 100 ? 'blue' : 'red';
    return team === ownTeam ? '己方候选' : '敌方候选';
}
