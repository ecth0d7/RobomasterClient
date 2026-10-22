.pragma library

// Scene-local high-water pools. A free slot holds no expired source record.
// ListModel role changes preserve the Repeater3D delegate and its resources.
function keyed(model, records, maximum) {
    const desired = new Map();
    for (const record of records.slice(0, maximum)) desired.set(record.key, record);
    const retained = new Map(), free = [];
    for (let i = 0; i < model.count; i++) {
        const slot = model.get(i);
        const key = slot.occupied ? slot.payload.key : null;
        if (key !== null && desired.has(key)) retained.set(key, i);
        else {
            if (slot.occupied) model.set(i, {occupied: false, payload: {}});
            free.push(i);
        }
    }
    for (const [key, record] of desired) {
        let index = retained.get(key);
        if (index === undefined && free.length) index = free.pop();
        if (index === undefined) model.append({occupied: true, payload: record});
        else model.set(index, {occupied: true, payload: record});
    }
    return {active: desired.size, slots: model.count, omitted: Math.max(0, records.length-maximum)};
}

function indexed(model, records, maximum) {
    const count = Math.min(records.length, maximum);
    for (let i = 0; i < count; i++) {
        if (i < model.count) model.set(i, {occupied: true, payload: records[i]});
        else model.append({occupied: true, payload: records[i]});
    }
    for (let i = count; i < model.count; i++)
        if (model.get(i).occupied) model.set(i, {occupied: false, payload: {}});
    return {active: count, slots: model.count, omitted: Math.max(0, records.length-maximum)};
}
