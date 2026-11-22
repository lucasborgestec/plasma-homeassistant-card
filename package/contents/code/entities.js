.pragma library

// Parses a multi-line list where each line is: "entity_id ; Label ; extra".
// Empty lines and lines starting with '#' are ignored.
function parseLines(text) {
    const out = [];
    (text || "").split("\n").forEach(raw => {
        const line = raw.trim();
        if (!line || line.startsWith("#")) {
            return;
        }
        const parts = line.split(";").map(p => p.trim());
        if (!parts[0]) {
            return;
        }
        out.push({ id: parts[0], name: parts[1] || "", icon: parts[2] || "" });
    });
    return out;
}

// Turns "sensor.ap_master_temperature" into "Ap master temperature".
function prettyId(entityId) {
    const name = (entityId.split(".")[1] || entityId).replace(/_/g, " ");
    return name.charAt(0).toUpperCase() + name.slice(1);
}

function isTemperatureUnit(unit) {
    return unit === "°C" || unit === "°F" || unit === "K";
}

// Converts a data-rate value to Mbit/s when the unit is known; returns NaN otherwise.
function toMbit(value, unit) {
    const factors = {
        "bit/s": 1e-6, "kbit/s": 1e-3, "Mbit/s": 1, "Gbit/s": 1e3,
        "B/s": 8e-6, "kB/s": 8e-3, "KiB/s": 8 * 1.024e-3, "MB/s": 8, "MiB/s": 8 * 1.048576, "GB/s": 8e3
    };
    return unit in factors ? value * factors[unit] : NaN;
}
