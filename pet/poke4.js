const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");
/* =========================
   helpers
========================= */
function clamp(v, min, max) {
    return Math.max(min, Math.min(max, v));
}
function dist(ax, az, bx, bz) {
    return Math.hypot(bx - ax, bz - az);
}
function norm2D(x, z) {
    const len = Math.hypot(x, z) || 1;
    return { x: x / len, z: z / len };
}
function pickWeighted(entries) {
    let total = 0;
    for (const entry of entries) total += entry.weight;
    let r = Math.random() * total;
    for (const entry of entries) {
        r -= entry.weight;
        if (r <= 0) return entry.key;
    }
    return entries[0]?.key ?? null;
}
function drawGauge(ctx, x, y, w, h, ratio, fill, back = "#222") {
    ctx.fillStyle = back;
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = fill;
    ctx.fillRect(x, y, w * clamp(ratio, 0, 1), h);
}
const DEFAULT_RESISTANCES = {
  physical: { pierce: 1.0, slash: 1.0, impact: 1.0, drill: 1.0 },
  energy: { heat: 1.0, cold: 1.0, poison: 1.0, water: 1.0, electric: 1.0 },
};
function makeResistances(overrides = {}) {
  return {
    physical: {
      ...DEFAULT_RESISTANCES.physical,
      ...(overrides.physical ?? {}),
    },
    energy: {
      ...DEFAULT_RESISTANCES.energy,
      ...(overrides.energy ?? {}),
    },
  };
}
const composites = {
  animal: {
    resistances: makeResistances({
      physical: { pierce: 1.0, slash: 1.0, impact: 1.0, drill: 1.1 },
      energy: { heat: 1.0, cold: 1.0, poison: 1.0, water: 0.8, electric: 1.4 },
    }),
    specialEffects: [],
    traits: {
      toughness: 0,
      conductivity: 0.25,
      heatRetention: 0.35,
      mobilityBias: 0.08,
      energyBias: 0.05,
      regenBias: 0.10,
    },
  },

  water: {
    resistances: makeResistances({
      physical: { pierce: 1.0, slash: 0.95, impact: 1.15, drill: 1.05 },
      energy: { heat: 1.35, cold: 0.85, poison: 0.9, water: 0.6, electric: 1.6 },
    }),
    specialEffects: ["waterAdd"],
    traits: {
      toughness: -0.05,
      conductivity: 0.90,
      heatRetention: -0.35,
      mobilityBias: 0.10,
      energyBias: 0.10,
      regenBias: 0.18,
    },
  },

  voltage: {
    resistances: makeResistances({
      physical: { pierce: 1.05, slash: 1.0, impact: 1.1, drill: 1.0 },
      energy: { heat: 1.1, cold: 1.0, poison: 1.0, water: 1.4, electric: 0.55 },
    }),
    specialEffects: ["waterVolt"],
    traits: {
      toughness: -0.10,
      conductivity: 1.00,
      heatRetention: 0.05,
      mobilityBias: 0.18,
      energyBias: 0.28,
      regenBias: 0.00,
    },
  },

  fire: {
    resistances: makeResistances({
      physical: { pierce: 1.0, slash: 0.95, impact: 1.1, drill: 1.0 },
      energy: { heat: 0.55, cold: 1.45, poison: 0.9, water: 1.5, electric: 1.0 },
    }),
    specialEffects: ["fireUp", "burnoff"],
    traits: {
      toughness: -0.08,
      conductivity: 0.10,
      heatRetention: 0.95,
      mobilityBias: 0.05,
      energyBias: 0.20,
      regenBias: -0.05,
    },
  },

  rock: {
    resistances: makeResistances({
      physical: { pierce: 0.85, slash: 0.75, impact: 1.1, drill: 1.35 },
      energy: { heat: 0.9, cold: 0.9, poison: 0.6, water: 0.95, electric: 0.8 },
    }),
    specialEffects: ["hardSurface"],
    traits: {
      toughness: 0.35,
      conductivity: 0.15,
      heatRetention: 0.65,
      mobilityBias: -0.12,
      energyBias: -0.05,
      regenBias: 0.00,
    },
  },

  arcane: {
    resistances: makeResistances({
      physical: { pierce: 1.0, slash: 1.0, impact: 1.05, drill: 1.0 },
      energy: { heat: 0.95, cold: 0.95, poison: 1.2, water: 1.0, electric: 0.85 },
    }),
    specialEffects: [],
    traits: {
      toughness: -0.04,
      conductivity: 0.60,
      heatRetention: 0.20,
      mobilityBias: 0.05,
      energyBias: 0.30,
      regenBias: 0.05,
    },
  },

  frost: {
    resistances: makeResistances({
      physical: { pierce: 1.0, slash: 0.95, impact: 1.05, drill: 1.0 },
      energy: { heat: 1.5, cold: 0.55, poison: 1.0, water: 0.85, electric: 1.1 },
    }),
    specialEffects: [],
    traits: {
      toughness: 0.08,
      conductivity: 0.35,
      heatRetention: -0.25,
      mobilityBias: -0.04,
      energyBias: 0.05,
      regenBias: 0.10,
    },
  },
};
const familyDefs = {
    canine: {
        aiTendency: { aggression: 0.65, formation: "pack", engageRangeBias: 1.0 },
        statMult: { maxHP: 1.04, spd: 1.05, stamina: 1.10, energy: 0.95 },
    },
    feline: {
        aiTendency: { aggression: 0.55, formation: "flank", engageRangeBias: 1.08 },
        statMult: { maxHP: 0.95, spd: 1.15, stamina: 1.00, energy: 1.08 },
    },
    ursine: {
        aiTendency: { aggression: 0.72, formation: "bruiser", engageRangeBias: 0.92 },
        statMult: { maxHP: 1.22, spd: 0.88, stamina: 1.14, energy: 0.90 },
    },
    crust_rock: {
        aiTendency: { aggression: 0.50, formation: "anchor", engageRangeBias: 1.15 },
        statMult: { maxHP: 1.12, spd: 0.90, stamina: 1.00, energy: 0.92 },
    },
    avian: {
        aiTendency: { aggression: 0.48, formation: "kite", engageRangeBias: 1.25 },
        statMult: { maxHP: 0.90, spd: 1.20, stamina: 0.95, energy: 1.15 },
    },
    slime: {
        aiTendency: { aggression: 0.40, formation: "swarm", engageRangeBias: 0.95 },
        statMult: { maxHP: 1.08, spd: 0.92, stamina: 0.92, energy: 1.10 },
    },
};
const compositeEffects = {
    waterVolt(ctx) {
        if ((ctx.targetState.soak.water ?? 0) <= 0) return;
        ctx.targetState.buff.energyBonus += 0.1;
    },
    waterAdd(ctx) {
        const water = ctx.targetState.soak.water ?? 0;
        if (water <= 0) return;
        const heal = Math.min(water * 0.25, ctx.target.modifiedStats.maxHP * 0.01);
        ctx.target.currentHP = Math.min(ctx.target.modifiedStats.maxHP, ctx.target.currentHP + heal);
        ctx.targetState.soak.water = Math.max(0, water - heal);
    },
    fireUp(ctx) {
        if ((ctx.targetState.soak.heat ?? 0) <= 0) return;
        ctx.targetState.buff.energyBonus += 0.15;
    },
    burnoff(ctx) {
        for (const key of Object.keys(ctx.targetState.soak)) {
            ctx.targetState.soak[key] = Math.max(0, ctx.targetState.soak[key] - ctx.dt * 2);
        }
    },
    hardSurface(ctx) {
        const burst = (ctx.targetState.soak.chemical ?? 0) + (ctx.targetState.soak.electric ?? 0);
        if (burst <= 0) return;
        const dmg = burst * 0.08;
        ctx.target.currentHP = Math.max(0, ctx.target.currentHP - dmg);
        ctx.targetState.soak.chemical = 0;
        ctx.targetState.soak.electric = 0;
    },
};
const abilities = {
    ram: {
        name: "Ram",
        category: "melee",
        cooldown: 2.0,
        resourceUse: { stamina: 5, energy: 0 },
        flatDmg: { p: 3, e: 0 },
        dmgScale: { p: 0.8, e: 0 },
        damageProfile: { physical: ["impact"] },
        range: 24,
    },
    zap: {
        name: "Zap",
        category: "hitscan",
        cooldown: 4.2,
        resourceUse: { stamina: 0, energy: 10 },
        flatDmg: { p: 0, e: 2 },
        dmgScale: { p: 0, e: 0.3 },
        damageProfile: { energy: ["electric"] },
        range: 80,
        soakAdd: { electric: 0.5 },
        effectsOnHit: [{ type: "shock", chance: 0.25, duration: 1.5, magnitude: 0.2 }],
        fx: { lineColor: "#8ac7ff" },
    },
    emberClaw: {
        name: "Ember Claw",
        category: "melee",
        cooldown: 1.4,
        resourceUse: { stamina: 6, energy: 2 },
        flatDmg: { p: 5, e: 3 },
        dmgScale: { p: 0.4, e: 0.2 },
        damageProfile: { physical: ["slash"], energy: ["heat"] },
        range: 26,
        soakAdd: { heat: 1.0 },
        effectsOnHit: [{ type: "burn", chance: 0.5, duration: 3.2, magnitude: 3.5 }],
    },
    pebbleShot: {
        name: "Pebble Shot",
        category: "projectile",
        cooldown: 6.0,
        resourceUse: { stamina: 5, energy: 0 },
        flatDmg: { p: 4, e: 0 },
        dmgScale: { p: 0.2, e: 0 },
        damageProfile: { physical: ["pierce"] },
        range: 150,
        projectile: { speed: 10 },
        fx: { lineColor: "#d0c9b0" },
    },
    staticBurst: {
        name: "Static Burst",
        category: "aoe",
        cooldown: 5.2,
        resourceUse: { stamina: 0, energy: 15 },
        flatDmg: { p: 0, e: 10 },
        dmgScale: { p: 0, e: 0.3 },
        damageProfile: { energy: ["electric"] },
        range: 90,
        area: { radius: 40 },
        soakAdd: { electric: 0.2 },
        effectsOnHit: [{ type: "slow", duration: 1.5, magnitude: 0.35 }],
        fx: { pulseColor: "rgba(120,190,255,0.55)" },
    },
    stomp: {
        name: "Stomp",
        category: "aoe",
        cooldown: 5.2,
        resourceUse: { stamina: 15, energy: 0 },
        flatDmg: { p: 10, e: 0 },
        dmgScale: { p: 0.9, e: 0 },
        damageProfile: { physical: ["impact"] },
        range: 90,
        area: { radius: 60 },
        effectsOnHit: [{ type: "slow", duration: 1.5, magnitude: 0.35 }],
        fx: { pulseColor: "rgba(255, 226, 80, 0.55)" },
    },
    dashBite: {
        name: "Dash Bite",
        category: "dash",
        cooldown: 3.0,
        resourceUse: { stamina: 10, energy: 0 },
        flatDmg: { p: 15, e: 0 },
        dmgScale: { p: 0.65, e: 0 },
        damageProfile: { physical: ["slash"] },
        range: 26,
        dash: { distance: 90, stopShort: 18 },
        effectsOnHit: [{ type: "slow", chance: 0.35, duration: 1.1, magnitude: 0.25 }],
        fx: { lineColor: "#ffe8a3" },
    },
    staticBarrier: {
        name: "Static Barrier",
        category: "barrier",
        cooldown: 10.5,
        resourceUse: { stamina: 0, energy: 20 },
        flatDmg: { p: 0, e: 0 },
        dmgScale: { p: 0, e: 0 },
        range: 120,
        barrier: { radius: 52, duration: 5.0, slow: 0.25, damageReduction: 0.22, blockMovement: true },
        fx: { pulseColor: "rgba(120,190,255,0.20)" },
    },
    rallyHowl: {
        name: "Rally Howl",
        category: "utility",
        cooldown: 6.2,
        resourceUse: { stamina: 0, energy: 10 },
        flatDmg: { p: 0, e: 0 },
        dmgScale: { p: 0, e: 0 },
        range: 0,
        selfStatus: [{ type: "regen", duration: 4.0, magnitude: 4.0 }],
    },
    disengage: {
        name: "Disengage",
        category: "retreat",
        cooldown: 3.0,
        resourceUse: { stamina: 10, energy: 0 },
        flatDmg: { p: 10, e: 0 },
        dmgScale: { p: 0, e: 0 },
        damageProfile: { physical: ["impact"] },
        dash: { distance: 80, stopShort: 10 },
        range: 0,
    },
};
const species = {
    dog: {
        name: "Dog",
        familyKey: "canine",
        outerCompositeKey: "animal",
        innerCompositeKey: "animal",
        compositeKey: "animal",
        role: "fighter",
        baseStats: { pAtk: 12, eAtk: 2, range: 24, maxHP: 110, spd: 70, castSpd: 1, size: 10, stamina: 25, energy: 10, recoverStamina: 2, recoverEnergy: 1 },
        moveset: ["ram", "dashBite", "rallyHowl", "stomp"], learnset: [], //later, add at what level it learns what
        morphOptions: [
            { option: "warden_hound", pointsNeeded: 3, path: "guardian", biomeAffinity: ["plains", "forest"], materialFocus: "stone" },
            { option: "storm_hound", pointsNeeded: 3, path: "skirmisher", biomeAffinity: ["stormfield", "polar"], materialFocus: "crystal_shard" },
        ],

    },
    sparkit: {
        name: "Sparkit",
        familyKey: "feline",
        outerCompositeKey: "animal",
        innerCompositeKey: "voltage",
        compositeKey: "voltage",
        role: "ranged",
        baseStats: { pAtk: 4, eAtk: 12, range: 100, maxHP: 85, spd: 65, castSpd: 1, size: 9, stamina: 16, energy: 24, recoverStamina: 1, recoverEnergy: 2 },
        moveset: ["zap", "staticBurst", "staticBarrier"],
        signatureMoveConcept: "Arc Lash (chain spark that weakens energy defense)",
    },
    cinderpup: {
        name: "Cinderpup",
        familyKey: "ursine",
        outerCompositeKey: "fire",
        innerCompositeKey: "animal",
        compositeKey: "fire",
        role: "fighter",
        baseStats: { pAtk: 10, eAtk: 8, range: 30, maxHP: 95, spd: 74, castSpd: 1, size: 9, stamina: 24, energy: 18, recoverStamina: 2, recoverEnergy: 2 },
        moveset: ["emberClaw", "ram"],
        signatureMoveConcept: "Cinder Guard (short self-shield then slam)",
        morphOptions: [{ option: "magma_ursa", pointsNeeded: 3, path: "juggernaut", biomeAffinity: ["volcanic"] }],
    },
    pebblit: {
        name: "Pebblit",
        familyKey: "crust_rock",
        outerCompositeKey: "rock",
        innerCompositeKey: "animal",
        compositeKey: "rock",
        role: "ranged",
        baseStats: { pAtk: 9, eAtk: 3, range: 120, maxHP: 120, spd: 58, castSpd: 1, size: 11, stamina: 22, energy: 12, recoverStamina: 1, recoverEnergy: 1 },
        moveset: ["pebbleShot", "ram"],
        signatureMoveConcept: "Shard Burst (cone of fragments)",
    },
    warden_hound: {
        name: "Warden Hound",
        familyKey: "canine",
        outerCompositeKey: "rock",
        innerCompositeKey: "animal",
        compositeKey: "rock",
        role: "tank",
        baseStats: { pAtk: 12, eAtk: 4, range: 26, maxHP: 135, spd: 62, castSpd: 0.95, size: 11, stamina: 28, energy: 12, recoverStamina: 2.1, recoverEnergy: 1.0 },
        moveset: ["ram", "stomp", "rallyHowl"],
        signatureMoveConcept: "Bulwark Bark (team toughness pulse)",
        morphOptions: [],
    },
    storm_hound: {
        name: "Storm Hound",
        familyKey: "canine",
        outerCompositeKey: "animal",
        innerCompositeKey: "voltage",
        compositeKey: "voltage",
        role: "skirmisher",
        baseStats: { pAtk: 9, eAtk: 10, range: 90, maxHP: 96, spd: 78, castSpd: 1.1, size: 10, stamina: 24, energy: 20, recoverStamina: 2.0, recoverEnergy: 2.1 },
        moveset: ["dashBite", "zap", "staticBurst"],
        signatureMoveConcept: "Tempest Pounce (dash that primes shock)",
        morphOptions: [],
    },
    magma_ursa: {
        name: "Magma Ursa",
        familyKey: "ursine",
        outerCompositeKey: "rock",
        innerCompositeKey: "fire",
        compositeKey: "rock",
        role: "tank",
        baseStats: { pAtk: 14, eAtk: 7, range: 30, maxHP: 150, spd: 56, castSpd: 0.9, size: 13, stamina: 30, energy: 16, recoverStamina: 2.2, recoverEnergy: 1.2 },
        moveset: ["emberClaw", "stomp", "ram"],
        signatureMoveConcept: "Lava Shell (burn aura while bracing)",
        morphOptions: [],
    },
    glintswift: {
        name: "Glintswift",
        familyKey: "avian",
        outerCompositeKey: "frost",
        innerCompositeKey: "arcane",
        compositeKey: "frost",
        role: "ranged",
        baseStats: { pAtk: 5, eAtk: 11, range: 110, maxHP: 80, spd: 82, castSpd: 1.2, size: 8, stamina: 18, energy: 25, recoverStamina: 1.3, recoverEnergy: 2.4 },
        moveset: ["zap", "staticBurst", "disengage"],
        signatureMoveConcept: "Prism Draft (slow field + reposition)",
        morphOptions: [],
    },
    miregel: {
        name: "Miregel",
        familyKey: "slime",
        outerCompositeKey: "water",
        innerCompositeKey: "arcane",
        compositeKey: "water",
        role: "utility",
        baseStats: { pAtk: 6, eAtk: 9, range: 70, maxHP: 112, spd: 52, castSpd: 1.0, size: 11, stamina: 18, energy: 22, recoverStamina: 1.0, recoverEnergy: 2.1 },
        moveset: ["ram", "rallyHowl", "staticBarrier"],
        signatureMoveConcept: "Gel Flux (team sustain pulse)",
        morphOptions: [],
    },
    sheeplet: {
        name: "Sheeplet",
        familyKey: "feline",
        outerCompositeKey: "animal",
        innerCompositeKey: "animal",
        compositeKey: "animal",
        role: "passive",
        baseStats: { pAtk: 3, eAtk: 0, range: 20, maxHP: 76, spd: 56, castSpd: 1.0, size: 9, stamina: 14, energy: 8, recoverStamina: 1.8, recoverEnergy: 1.0 },
        moveset: [],
        harvestDrop: [{ key: "fiber", amount: 2 }],
        harvestCooldown: 20,
        drop: [{ key: "meat", amount: 1 }],
        morphOptions: [],
    },
};
const biomeDefs = {
    plains: {
        color: "#89a87c",
        rules: {
            temperature: 0.55,
            rainfall: 0.45,
            lithosphere: 0.45,
            barrenness: 0.35,
            arcane: 0.45,
            softness: 0.28,
            bias: 1.0,
        },
        spawns: [{ key: "dog", weight: 4 }, { key: "sheeplet", weight: 3 }, { key: "pebblit", weight: 2 }, { key: "warden_hound", weight: 1 }],
        nodes: [{ key: "berry_bush_red", weight: 12 }, { key: "energy_crystal", weight: 2 }, {key: "revive_berry_bush", weight: 1}, {key: "replenish_berry_bush", weight: 1}],
    },
    ocean: {
        color: "#4b7396",
        rules: {
            temperature: 0.46,
            rainfall: 0.86,
            lithosphere: 0.22,
            barrenness: 0.20,
            arcane: 0.50,
            softness: 0.22,
            bias: 0.82,
        },
        spawns: [{ key: "sparkit", weight: 2 }, { key: "dog", weight: 1 }, { key: "miregel", weight: 2 }],
        nodes: [{ key: "energy_crystal", weight: 6 }, { key: "replenish_berry_bush", weight: 4 }, { key: "bait_shrub", weight: 1 }],
    },
    forest: {
        color: "#6e9a5f",
        rules: {
            temperature: 0.50,
            rainfall: 0.75,
            lithosphere: 0.42,
            barrenness: 0.15,
            arcane: 0.42,
            softness: 0.26,
            bias: 1.05,
        },
        spawns: [{ key: "dog", weight: 3 }, { key: "cinderpup", weight: 2 }, { key: "miregel", weight: 1 }],
        nodes: [{ key: "berry_bush_red", weight: 22 }, { key: "bait_shrub", weight: 3 }, {key: "revive_berry_bush", weight: 1}, {key: "replenish_berry_bush", weight: 1}],
    },
    desert: {
        color: "#b8a56c",
        rules: {
            temperature: 0.82,
            rainfall: 0.12,
            lithosphere: 0.40,
            barrenness: 0.90,
            arcane: 0.30,
            softness: 0.22,
            bias: 0.95,
        },
        spawns: [{ key: "pebblit", weight: 5 }, { key: "cinderpup", weight: 3 }],
        nodes: [{ key: "energy_crystal", weight: 5 }, { key: "bait_shrub", weight: 2 }, {key: "revive_berry_bush", weight: 1}, {key: "replenish_berry_bush", weight: 1}],
    },
    stormfield: {
        color: "#74879b",
        rules: {
            temperature: 0.45,
            rainfall: 0.65,
            lithosphere: 0.55,
            barrenness: 0.55,
            arcane: 0.76,
            softness: 0.24,
            bias: 0.85,
        },
        spawns: [{ key: "sparkit", weight: 5 }, { key: "dog", weight: 1 }, { key: "storm_hound", weight: 2 }],
        nodes: [{ key: "energy_crystal", weight: 6 }, { key: "berry_bush_red", weight: 2 }, {key: "revive_berry_bush", weight: 1}, {key: "replenish_berry_bush", weight: 1}],
    },
    volcanic: {
        color: "#8b5c4f",
        rules: {
            temperature: 0.88,
            rainfall: 0.18,
            lithosphere: 0.82,
            barrenness: 0.78,
            arcane: 0.55,
            softness: 0.20,
            bias: 0.70,
        },
        spawns: [{ key: "cinderpup", weight: 5 }, { key: "pebblit", weight: 2 }, { key: "magma_ursa", weight: 1 }],
        nodes: [{ key: "bait_shrub", weight: 4 }, { key: "energy_crystal", weight: 2 }, {key: "revive_berry_bush", weight: 1}, {key: "replenish_berry_bush", weight: 1}],
    },
    tundra: {
        color: "#94a6ae",
        rules: {
            temperature: 0.20,
            rainfall: 0.44,
            lithosphere: 0.52,
            barrenness: 0.55,
            arcane: 0.38,
            softness: 0.21,
            bias: 0.72,
        },
        spawns: [{ key: "dog", weight: 2 }, { key: "pebblit", weight: 3 }, { key: "glintswift", weight: 1 }],
        nodes: [{ key: "replenish_berry_bush", weight: 5 }, { key: "revive_berry_bush", weight: 3 }, { key: "energy_crystal", weight: 2 }],
    },
    polar: {
        color: "#d7e7f0",
        rules: {
            temperature: 0.07,
            rainfall: 0.26,
            lithosphere: 0.58,
            barrenness: 0.76,
            arcane: 0.62,
            softness: 0.18,
            bias: 0.55,
        },
        spawns: [{ key: "sparkit", weight: 2 }, { key: "pebblit", weight: 2 }, { key: "glintswift", weight: 2 }],
        nodes: [{ key: "energy_crystal", weight: 6 }, { key: "replenish_berry_bush", weight: 2 }, { key: "revive_berry_bush", weight: 2 }],
    },
};
const biomeRules = Object.fromEntries(Object.entries(biomeDefs).map(([key, def]) => [key, { ...(def.rules ?? {}) }]));
const itemDefs = {
    berry_red: { name: "Red Berry", type: "heal", amount: 40 },
    berry_blue: { name: "Blue Berry", type: "heal", amount: 25 },
    berry_yellow: { name: "Yellow Berry", type: "heal", amount: 30 },
    revive_berry: { name: "Revive Berry", type: "revive", amount: 0.5 },
    boost_berry: { name: "Boost Berry", type: "buff", amount: 0.15, duration: 20 },
    battery_seed: { name: "Battery Seed", type: "energy", amount: 16, stamina: 10 },
    replenish_berry: { name: "Replenish Berry", type: "energy", amount: 0, stamina: 20 },
    lure_meat: { name: "Lure Meat", type: "bait", tameBonus: 0.25, requiredHPRatio: 0.45 },
};
const nodeDefs = {
    berry_bush_red: { color: "#bb2f58", reward: { key: "berry_red", amount: 2 }, cooldown: 12 },
    berry_bush_blue: { color: "#4a90e2", reward: { key: "berry_blue", amount: 2 }, cooldown: 12 },
    berry_bush_yellow: { color: "#f4c24a", reward: { key: "berry_yellow", amount: 2 }, cooldown: 12 },
    revive_berry_bush: { color: "#7b3e1d", reward: { key: "revive_berry", amount: 1 }, cooldown: 18 },
    boost_berry_bush: { color: "#ffcc00", reward: { key: "boost_berry", amount: 1 }, cooldown: 20 },
    energy_crystal: { color: "#5fc7ff", reward: { key: "battery_seed", amount: 1 }, cooldown: 14 },
    replenish_berry_bush: { color: "#e1f2d8", reward: { key: "replenish_berry", amount: 1 }, cooldown: 20 },
    bait_shrub: { color: "#a6a052", reward: { key: "lure_meat", amount: 1 }, cooldown: 16 },
};
const placeableDefs = {
  berry_bush_red: {
    kind: "farm",
    name: "Berry Bush",
    color: "#bb2f58",
    maxHP: 60,
    radius: 10,
    buildTime: 3.0,
    destroyTime: 2.0,
    harvestTime: 2.0,
    buildCost: [{ key: "wood", amount: 1 }],
    growTime: 12,
    rewards: [{ key: "berry_red", amount: 1 }],
    placementRadius: 11,
    blocksMovement: false,
    destroyRefund: [{ key: "wood", amount: 1, chance: 0.6 }],
  },
  berry_bush_blue: {
    kind: "farm",
    name: "Blue Berry Bush",
    color: "#4a90e2",
    maxHP: 60,
    radius: 10,
    buildTime: 3.0,
    destroyTime: 2.0,
    harvestTime: 2.0,
    buildCost: [{ key: "wood", amount: 1 }],
    growTime: 12,
    rewards: [{ key: "berry_blue", amount: 1 }],
    placementRadius: 11,
    blocksMovement: false,
    destroyRefund: [{ key: "wood", amount: 1, chance: 0.6 }],
  },
  berry_bush_yellow: {
    kind: "farm",
    name: "Yellow Berry Bush",
    color: "#f4c24a",
    maxHP: 60,
    radius: 10,
    buildTime: 3.0,
    destroyTime: 2.0,
    harvestTime: 2.0,
    buildCost: [{ key: "wood", amount: 1 }],
    growTime: 12,
    rewards: [{ key: "berry_yellow", amount: 1 }],
    placementRadius: 11,
    blocksMovement: false,
    destroyRefund: [{ key: "wood", amount: 1, chance: 0.6 }],
  },
  shelter: {
    kind: "structure",
    name: "Shelter",
    color: "#8b5c4f",
    maxHP: 300,
    radius: 16,
    buildTime: 6.0,
    destroyTime: 4.0,
    buildCost: [{ key: "wood", amount: 5 }, { key: "stone", amount: 2 }],
    provides: { restHeal: 0.02 },
    placementRadius: 16,
    blocksMovement: true,
    destroyRefund: [{ key: "wood", amount: 2, chance: 1.0 }, { key: "stone", amount: 1, chance: 0.7 }],
  },

};
const toolDefs = {
  hammer: {
    name: "Hammer",
    modes: ["build", "destroy"],
    buildTypes: ["shelter", "berry_bush_red", "berry_bush_blue", "berry_bush_yellow"],
    canDestroy: true,
    range: 40,
  },
  gather_tool: {
    name: "Gather Tool",
    modes: ["gather"],
    canGather: true,
    range: 42,
    gatherTime: 1.6,
  },
};
const obstacleHarvestDefs = {
    tree: {
        gatherTime: 1.5,
        rewards: [{ key: "wood", amount: 3 }],
    },
    rock: {
        gatherTime: 1.8,
        rewards: [{ key: "stone", amount: 2 }, { key: "metal_scrap", amount: 1, chance: 0.25 }],
    },
    crystal: {
        gatherTime: 2.0,
        rewards: [{ key: "crystal_shard", amount: 2 }],
    },
};
/* =========================
   systems: effects/status/progression
========================= */
const EffectEngine = {
    createState() {
        return { soak: { water: 0, electric: 0, chemical: 0, heat: 0 }, buff: { energyBonus: 0 } };
    },
    createStatus(type, duration, magnitude = 0, sourceId = null) {
        return { type, duration, magnitude, sourceId };
    },
    addStatus(creature, status) {
        const existing = creature.statusEffects.find(s => s.type === status.type && s.sourceId === status.sourceId);
        if (existing) {
            existing.duration = Math.max(existing.duration, status.duration);
            existing.magnitude = Math.max(existing.magnitude, status.magnitude);
            return;
        }
        creature.statusEffects.push(status);
    },
    tickCreature(creature, dt) {
        const composite = composites[creature.compositeKey] ?? composites.animal;
        const effects = composite.specialEffects ?? [];
        creature.effectState.buff.energyBonus = 0;
        const ctx = { dt, target: creature, targetState: creature.effectState };
        for (const effectKey of effects) {
            const fn = compositeEffects[effectKey];
            if (typeof fn === "function") fn(ctx);
        }
        const s = creature.effectState.soak;
        s.water = Math.max(0, s.water - dt * 0.25);
        s.electric = Math.max(0, s.electric - dt * 0.4);
        s.chemical = Math.max(0, s.chemical - dt * 0.35);
        s.heat = Math.max(0, s.heat - dt * 0.2);
        let slowMult = 1;
        let speedBonus = 0;
        let atkBonus = 0;
        let dmgReduction = 0;
        for (let i = creature.statusEffects.length - 1; i >= 0; i--) {
            const st = creature.statusEffects[i];
            st.duration -= dt;
            if (st.type === "burn") creature.currentHP = Math.max(0, creature.currentHP - st.magnitude * dt);
            if (st.type === "shock") creature.currentEnergy = Math.max(0, creature.currentEnergy - st.magnitude * 5 * dt);
            if (st.type === "slow") slowMult *= 1 - st.magnitude;
            if (st.type === "regen") creature.currentHP = Math.min(creature.modifiedStats.maxHP, creature.currentHP + st.magnitude * dt);
            if (st.type === "boost") creature.effectState.buff.energyBonus += st.magnitude;
            if (st.type === "atkBoost") atkBonus += st.magnitude;
            if (st.type === "spdBoost") speedBonus += st.magnitude;
            if (st.type === "defBoost") dmgReduction = Math.max(dmgReduction, st.magnitude);
            if (st.duration <= 0) creature.statusEffects.splice(i, 1);
        }
        creature.runtimeSpeedMult = clamp(slowMult * (1 + speedBonus), 0.35, 1.9);
        creature.runtimeAtkMult = clamp(1 + atkBonus, 0.5, 2.5);
        creature.runtimeDmgReduction = clamp(dmgReduction, 0, 0.75);
    },
    applyAbilityEffects(source, target, abilityDef) {
        if (abilityDef.soakAdd) {
            for (const key of Object.keys(abilityDef.soakAdd)) {
                target.effectState.soak[key] = (target.effectState.soak[key] ?? 0) + abilityDef.soakAdd[key];
            }
        }
        if (abilityDef.effectsOnHit) {
            for (const fx of abilityDef.effectsOnHit) {
                if (fx.chance && Math.random() > fx.chance) continue;
                this.addStatus(target, this.createStatus(fx.type, fx.duration ?? 1, fx.magnitude ?? 0, source.id));
            }
        }
        if (abilityDef.selfStatus) {
            for (const fx of abilityDef.selfStatus) {
                this.addStatus(source, this.createStatus(fx.type, fx.duration ?? 1, fx.magnitude ?? 0, source.id));
            }
        }
        return 1 + (source.effectState?.buff?.energyBonus ?? 0);
    },
};
function xpNeededForLevel(level) {
    return 35 + (level - 1) * 22;
}
/* =========================
   input
========================= */
class InputManager {
    constructor() {
        this.keys = new Map();
        this.pressed = new Map();
        this.mouse = { x: 0, y: 0, downLeft: false, downRight: false, pressedLeft: false, pressedRight: false };
    }
    bind(canvas) {
        window.addEventListener("keydown", (e) => {
            if (!this.keys.get(e.code)) this.pressed.set(e.code, true);
            this.keys.set(e.code, true);
        });
        window.addEventListener("keyup", (e) => this.keys.set(e.code, false));
        canvas.addEventListener("contextmenu", (e) => e.preventDefault());
        canvas.addEventListener("mousemove", (e) => {
            const rect = canvas.getBoundingClientRect();
            this.mouse.x = e.clientX - rect.left;
            this.mouse.y = e.clientY - rect.top;
        });
        canvas.addEventListener("mousedown", (e) => {
            if (e.button === 0) {
                if (!this.mouse.downLeft) this.mouse.pressedLeft = true;
                this.mouse.downLeft = true;
            }
            if (e.button === 2) {
                if (!this.mouse.downRight) this.mouse.pressedRight = true;
                this.mouse.downRight = true;
            }
        });
        canvas.addEventListener("mouseup", (e) => {
            if (e.button === 0) this.mouse.downLeft = false;
            if (e.button === 2) this.mouse.downRight = false;
        });
    }
    isDown(code) { return !!this.keys.get(code); }
    consumePress(code) {
        const had = !!this.pressed.get(code);
        this.pressed.set(code, false);
        return had;
    }
    consumeMouseLeftPress() {
        const had = this.mouse.pressedLeft;
        this.mouse.pressedLeft = false;
        return had;
    }
    consumeMouseRightPress() {
        const had = this.mouse.pressedRight;
        this.mouse.pressedRight = false;
        return had;
    }
    endFrame() {
        this.mouse.pressedLeft = false;
        this.mouse.pressedRight = false;
        this.pressed.clear();
    }
}
/* =========================
   camera
========================= */
class Camera {
    constructor() {
        this.x = 0; this.z = 0; this.zoom = 1.6; this.target = null;
    }
    follow(target) { this.target = target; }
    update(dt) {
        if (!this.target) return;
        const lerp = clamp(dt * 8, 0, 1);
        this.x += (this.target.pos.x - this.x) * lerp;
        this.z += (this.target.pos.z - this.z) * lerp;
    }
    worldToScreen(x, z) {
        return { sx: (x - this.x) * this.zoom + canvas.width / 2, sz: (z - this.z) * this.zoom + canvas.height / 2 };
    }
    screenToWorld(sx, sz) {
        return { x: (sx - canvas.width / 2) / this.zoom + this.x, z: (sz - canvas.height / 2) / this.zoom + this.z };
    }
}
/* =========================
   creature + factory (single creation path)
========================= */
let NEXT_ID = 1;
let NEXT_OWNED_ID = 1;
class Creature {
    constructor(id, speciesKey, team, x, z, def) {
        this.id = id;
        this.speciesKey = speciesKey;
        this.team = team;
        this.pos = { x, z };
        this.vel = { x: 0, z: 0 };
        this.angle = 0;
        this.speciesBaseStats = { ...def.baseStats };
        this.growthStats = { pAtk: 0, eAtk: 0, range: 0, maxHP: 0, spd: 0, castSpd: 0, size: 0, stamina: 0, energy: 0, recoverStamina: 0, recoverEnergy: 0 };
        this.permanentStats = { ...def.baseStats };
        this.modifiedStats = { ...def.baseStats };
        this.familyKey = def.familyKey ?? "canine";
        this.outerCompositeKey = def.outerCompositeKey ?? def.compositeKey ?? "animal";
        this.innerCompositeKey = def.innerCompositeKey ?? def.compositeKey ?? "animal";
        this.compositeKey = this.outerCompositeKey;
        this.aiTendency = { ...(familyDefs[this.familyKey]?.aiTendency ?? { aggression: 0.5, formation: "pack", engageRangeBias: 1.0 }) };
        this.effectState = EffectEngine.createState();
        this.statusEffects = [];
        this.currentHP = this.permanentStats.maxHP;
        this.currentStamina = this.permanentStats.stamina;
        this.currentEnergy = this.permanentStats.energy;
        this.level = 1;
        this.wildTier = "normal";
        this.wildProfile = {
            aggroMult: 1,
            pursuitRange: null,
            targetNearPlayerBias: 0,
            statMult: null,
            sizeMult: 1,
        };
        this.aggroRange = 140;
        this.xp = 0;
        this.nextXP = xpNeededForLevel(this.level);
        this.moveset = [...def.moveset];
        this.drop = Array.isArray(def.drop) ? def.drop.map(d => ({ ...d })) : [];
        this.harvestDrop = Array.isArray(def.harvestDrop) ? def.harvestDrop.map(d => ({ ...d })) : [];
        this.harvestCooldown = def.harvestCooldown ?? 0;
        this.nextHarvestAt = 0;
        this.cooldowns = Object.fromEntries(this.moveset.map(k => [k, 0]));
        this.combatContributors = new Map();
        this.runtimeSpeedMult = 1;
        this.runtimeAtkMult = 1;
        this.runtimeDmgReduction = 0;
        this.hitFlash = 0;
        this.lifecycle = "alive"; // alive | defeated | captured | despawned
        this.mode = team === 0 ? "pet" : "wild";
        this.ownedId = null;
        this.brain = null;
        this.intent = this.makeEmptyIntent();
        this.manualCastRequest = null;
        this.manualCastStatus = { text: "", until: 0 };
        this.castState = null;
        this.recoveryRemaining = 0;
        this.globalCooldown = 0;
        // Command system payload used by brains.
        this.command = { type: "follow", issuedAt: 0, targetId: null, point: null };
        this.spawnAnchor = { x, z };
        this.updateAggroRange();
    }
    makeEmptyIntent() {
        return { move: { x: 0, z: 0 }, abilityKey: null, targetId: null, aimAt: null };
    }
    isCasting() {
        return !!this.castState;
    }
    isRecovering() {
        return this.recoveryRemaining > 0;
    }
    addXP(amount) {
        const events = [];
        this.xp += amount;
        //add by level-up composite stats.
        while (this.xp >= this.nextXP) {
            this.xp -= this.nextXP;
            this.level += 1;
            this.nextXP = xpNeededForLevel(this.level);
            this.growthStats.maxHP += 40;
            this.growthStats.pAtk += 5.5;
            this.growthStats.eAtk += 5.5;
            this.growthStats.spd += 1.0;
            this.rebuildStats();
            this.currentHP = Math.min(this.currentHP + 14, this.modifiedStats.maxHP);
            events.push({ type: "leveledUp", newLevel: this.level });
        }
        return events;
    }
    setWildProfile(tier = "normal", profile = null) {
        this.wildTier = tier;
        this.wildProfile = {
            aggroMult: profile?.aggroMult ?? 1,
            pursuitRange: profile?.pursuitRange ?? null,
            targetNearPlayerBias: profile?.targetNearPlayerBias ?? 0,
            statMult: profile?.statMult ?? null,
            sizeMult: profile?.sizeMult ?? 1,
        };
        this.rebuildStats();
    }
    updateAggroRange() {
        const baseRange = this.modifiedStats.range * (this.level * 0.08 + 1) * this.aiTendency.engageRangeBias;
        const tierMult = this.wildProfile?.aggroMult ?? 1;
        this.aggroRange = baseRange * tierMult;
    }
    rebuildStats() {
        const base = {
            pAtk: this.speciesBaseStats.pAtk + this.growthStats.pAtk,
            eAtk: this.speciesBaseStats.eAtk + this.growthStats.eAtk,
            range: this.speciesBaseStats.range + this.growthStats.range,
            maxHP: this.speciesBaseStats.maxHP + this.growthStats.maxHP,
            spd: this.speciesBaseStats.spd + this.growthStats.spd,
            castSpd: this.speciesBaseStats.castSpd + this.growthStats.castSpd,
            size: this.speciesBaseStats.size + this.growthStats.size,
            stamina: this.speciesBaseStats.stamina + this.growthStats.stamina,
            energy: this.speciesBaseStats.energy + this.growthStats.energy,
            recoverStamina: this.speciesBaseStats.recoverStamina + this.growthStats.recoverStamina,
            recoverEnergy: this.speciesBaseStats.recoverEnergy + this.growthStats.recoverEnergy,
        };
        const family = familyDefs[this.familyKey] ?? null;
        const outerTraits = composites[this.outerCompositeKey]?.traits ?? composites.animal.traits;
        const innerTraits = composites[this.innerCompositeKey]?.traits ?? composites.animal.traits;
        this.permanentStats = { ...base };
        if (family?.statMult) {
            this.permanentStats.maxHP *= family.statMult.maxHP ?? 1;
            this.permanentStats.spd *= family.statMult.spd ?? 1;
            this.permanentStats.stamina *= family.statMult.stamina ?? 1;
            this.permanentStats.energy *= family.statMult.energy ?? 1;
        }
        this.permanentStats.maxHP *= 1 + ((outerTraits.toughness ?? 0) * 0.35);
        this.permanentStats.spd *= 1 + ((outerTraits.mobilityBias ?? 0) * 0.25);
        this.permanentStats.energy *= 1 + ((innerTraits.energyBias ?? 0) * 0.45);
        this.permanentStats.recoverEnergy *= 1 + ((innerTraits.regenBias ?? 0) * 0.35);
        this.permanentStats.recoverStamina *= 1 + ((outerTraits.regenBias ?? 0) * 0.25);
        this.permanentStats.castSpd *= 1 + ((innerTraits.energyBias ?? 0) * 0.12);
        this.modifiedStats = { ...this.permanentStats };
        const wildMult = this.wildProfile?.statMult ?? null;
        if (wildMult) {
            for (const [k, v] of Object.entries(wildMult)) {
                if (this.modifiedStats[k] != null) this.modifiedStats[k] *= v;
            }
        }
        if (this.wildProfile?.sizeMult != null) this.modifiedStats.size *= this.wildProfile.sizeMult;
        this.updateAggroRange();
    }
    tick(dt, world) {
        if (this.lifecycle !== "alive") return;
        for (const key of Object.keys(this.cooldowns)) this.cooldowns[key] = Math.max(0, this.cooldowns[key] - dt);
        this.globalCooldown = Math.max(0, this.globalCooldown - dt);
        this.recoveryRemaining = Math.max(0, this.recoveryRemaining - dt);
        this.currentStamina = Math.min(this.modifiedStats.stamina, this.currentStamina + this.modifiedStats.recoverStamina * dt);
        this.currentEnergy = Math.min(this.modifiedStats.energy, this.currentEnergy + this.modifiedStats.recoverEnergy * dt);
        EffectEngine.tickCreature(this, dt);
        const mv = norm2D(this.intent.move.x, this.intent.move.z);
        this.vel.x = mv.x * this.modifiedStats.spd * this.runtimeSpeedMult;
        this.vel.z = mv.z * this.modifiedStats.spd * this.runtimeSpeedMult;
        this.pos.x += this.vel.x* dt
        this.pos.z += this.vel.z* dt
        if (mv.x !== 0 || mv.z !== 0) this.angle = Math.atan2(mv.z, mv.x);
        world.CM.tickAbilityCast(this, dt);
        if (this.intent.abilityKey && this.intent.targetId) world.CM.tryUseAbility(this, this.intent.abilityKey, this.intent.targetId, this.intent.aimAt);
        this.hitFlash = Math.max(0, this.hitFlash - dt * 5);
    }
}
class CreatureFactory {
    create(speciesKey, team, x, z, opts = {}) {
        const def = species[speciesKey];
        if (!def) throw new Error(`Unknown species ${speciesKey}`);
        const c = new Creature(NEXT_ID++, speciesKey, team, x, z, def);
        if (opts.level && opts.level > 1) {
            for (let i = 1; i < opts.level; i++) c.addXP(c.nextXP);
        }
        if (opts.xp) c.xp = opts.xp;
        if (opts.nextXP) c.nextXP = opts.nextXP;
        if (opts.growthStats) {
            c.growthStats = { ...c.growthStats, ...opts.growthStats };
            c.rebuildStats();
        }
        if (opts.moveset) {
            c.moveset = [...opts.moveset];
            c.cooldowns = Object.fromEntries(c.moveset.map(k => [k, 0]));
        }
        if (opts.ownedId != null) c.ownedId = opts.ownedId;
        if (opts.spawnAnchor) c.spawnAnchor = { ...opts.spawnAnchor };
        if (opts.mode) c.mode = opts.mode;
        if (opts.mode === "wild" || opts.wildTier || opts.wildProfile) {
            c.setWildProfile(opts.wildTier ?? "normal", opts.wildProfile ?? null);
        } else {
            c.updateAggroRange();
        }
        return c;
    }
}
/* =========================
   brain (explicit commands + stance handling)
========================= */
class Brain {
    constructor() {
        this.host = null;
        this.role = "fighter";
    }
    attach(creature) {
        this.host = creature;
        creature.brain = this;
        this.role = species[creature.speciesKey]?.role ?? "fighter";
    }
    think(world) {
        const h = this.host;
        if (!h || h.lifecycle !== "alive") return;
        h.intent = h.makeEmptyIntent();
        if (h.mode === "pet") this.thinkPet(world);
        else this.thinkWild(world);
    }
    thinkPet(world) {
        const h = this.host;
        const player = world.player;
        const isActive = h.id === player.activePetId;
        const activeControlMode = player.activeControlMode ?? "AUTO";
        const followAnchor = world.getPetFollowAnchor(h.id);
        const stance = isActive ? "aggressive" : player.stance;
        if (isActive && h.manualCastRequest) {
            const handled = this.executeManualCast(world, h);
            if (handled) return;
        }
        // Explicit command priority for active pet.
        if (h.command?.type && (isActive || h.command.type === "hold" || h.command.type === "follow")) {
            const done = this.executeCommand(world, h, h.command, isActive, followAnchor);
            if (!done) return;
        }
        if (isActive && activeControlMode === "MANUAL") {
            // MANUAL mode: no autonomous target acquisition / auto-casting.
            this.moveTowardAnchor(h, followAnchor, 20);
            return;
        }
        if (stance === "hold" && !isActive) {
            h.intent.move = { x: 0, z: 0 };
            return;
        }
        const engageBias = h.aiTendency?.engageRangeBias ?? 1;
        const acquisitionRange = (stance === "follow" ? 120 : 190) * engageBias;
        const target = world.findNearestEnemyOf(h, acquisitionRange);
        if (target) {
            this.fightTarget(world, h, target, stance === "follow" ? 100 : null);
            return;
        }
        this.moveTowardAnchor(h, followAnchor, stance === "follow" ? 8 : 14);
    }
    executeCommand(world, h, cmd, isActive, followAnchor) {
        if (cmd.type === "hold") {
            h.intent.move = { x: 0, z: 0 };
            return false;
        }
        if (cmd.type === "follow") {
            this.moveTowardAnchor(h, followAnchor, 10);
            return false;
        }
        if (cmd.type === "move") {
            if (!cmd.point) return true;
            const dx = cmd.point.x - h.pos.x;
            const dz = cmd.point.z - h.pos.z;
            const d = Math.hypot(dx, dz);
            if (d < 8) return true;
            const n = norm2D(dx, dz);
            h.intent.move = { x: n.x, z: n.z };
            return false;
        }
        if (cmd.type === "attack") {
            const target = world.getCreatureById(cmd.targetId);
            if (!target || target.lifecycle !== "alive" || target.team === h.team) return true;
            this.fightTarget(world, h, target, null);
            return false;
        }
        return true;
    }
    executeManualCast(world, h) {
        const req = h.manualCastRequest;
        if (!req) return false;
        const ability = abilities[req.abilityKey];
        if (!ability) {
            h.manualCastRequest = null;
            world.CM.setManualCastStatus(h, "Unknown ability");
            return false;
        }
        if (ability.category === "utility" || ability.category === "barrier") {
            const gate = world.CM.evaluateAbilityUse(h, req.abilityKey, h);
            if (!gate.ok) {
                world.CM.setManualCastStatus(h, `Cast failed: ${gate.reason}`);
                h.manualCastRequest = null;
                return true;
            }
            h.intent.abilityKey = req.abilityKey;
            h.intent.targetId = h.id;
            h.intent.aimAt = { x: h.pos.x, z: h.pos.z };
            world.CM.setManualCastStatus(h, `Casting ${ability.name}`);
            h.manualCastRequest = null;
            return true;
        }
        const commandTarget = world.getCreatureById(world.player.commandTargetId);
        let target = null;
        if (commandTarget && commandTarget.lifecycle === "alive" && commandTarget.team !== h.team) {
            target = commandTarget;
        } else {
            target = world.findNearestEnemyOf(h, ability.range ?? Infinity) ?? world.findNearestEnemyOf(h, Infinity);
        }
        if (!target) {
            world.CM.setManualCastStatus(h, "No target");
            h.manualCastRequest = null;
            return true;
        }
        const gate = world.CM.evaluateAbilityUse(h, req.abilityKey, target);
        if (!gate.ok) {
            if (gate.reason === "out of range") {
                const dx = target.pos.x - h.pos.x;
                const dz = target.pos.z - h.pos.z;
                const n = norm2D(dx, dz);
                h.intent.move = { x: n.x, z: n.z };
                h.intent.aimAt = { x: target.pos.x, z: target.pos.z };
                world.CM.setManualCastStatus(h, `${ability.name}: moving into range`);
                return true;
            }
            world.CM.setManualCastStatus(h, `Cast failed: ${gate.reason}`);
            h.manualCastRequest = null;
            return true;
        }
        h.intent.abilityKey = req.abilityKey;
        h.intent.targetId = target.id;
        h.intent.aimAt = { x: target.pos.x, z: target.pos.z };
        world.CM.setManualCastStatus(h, `Casting ${ability.name}`);
        h.manualCastRequest = null;
        return true;
    }
    moveTowardAnchor(h, anchor, tolerance) {
        const dx = anchor.x - h.pos.x;
        const dz = anchor.z - h.pos.z;
        const d = Math.hypot(dx, dz);
        if (d > tolerance) {
            const n = norm2D(dx, dz);
            h.intent.move = { x: n.x, z: n.z };
        }
    }
    thinkWild(world) {
        const h = this.host;
        if (this.role === "passive") return;
        const aggroRange = h.aggroRange ?? 140;
        const target = this.pickWildTarget(world, h, aggroRange);
        if (!target) return;
        this.fightTarget(world, h, target, h.wildProfile?.pursuitRange ?? null);
    }
    pickWildTarget(world, h, aggroRange) {
        const nearPlayerBias = h.wildProfile?.targetNearPlayerBias ?? 0;
        if (nearPlayerBias <= 0) return world.findNearestEnemyOf(h, aggroRange);
        let best = null;
        let bestScore = Infinity;
        for (const other of world.creatures) {
            if (other.id === h.id || other.lifecycle !== "alive" || other.team === h.team) continue;
            const d = dist(h.pos.x, h.pos.z, other.pos.x, other.pos.z);
            if (d > aggroRange) continue;
            const dToPlayer = dist(world.player.pos.x, world.player.pos.z, other.pos.x, other.pos.z);
            const nonPetPenalty = other.team === 0 ? 0 : 85;
            const score = d + dToPlayer * nearPlayerBias + nonPetPenalty;
            if (score < bestScore) {
                best = other;
                bestScore = score;
            }
        }
        return best;
    }
    fightTarget(world, h, target, maxPursuitDistance = null) {
        const dx = target.pos.x - h.pos.x;
        const dz = target.pos.z - h.pos.z;
        const d = Math.hypot(dx, dz);
        const n = norm2D(dx, dz);
        const ctx = this.getLocalCombatContext(world, h, target);
        const familyRangeBias = h.aiTendency?.engageRangeBias ?? 1;
        const preferredRange = (this.role === "ranged" ? 95 : 18) * familyRangeBias;
        const leash = this.role === "ranged" ? 20 : 8;
        if (maxPursuitDistance != null) {
            const anchor = h.mode === "wild"
                ? (h.spawnAnchor ?? h.pos)
                : world.getPetFollowAnchor(h.id);
            if (dist(target.pos.x, target.pos.z, anchor.x, anchor.z) > maxPursuitDistance) {
                this.moveTowardAnchor(h, anchor, 10);
                return;
            }
        }
        if (this.role === "ranged" && (ctx.outnumbered || ctx.hpRatio < 0.45) && d < preferredRange + 10) {
            h.intent.move = { x: -n.x, z: -n.z };
        } else if (d > preferredRange + leash) h.intent.move = { x: n.x, z: n.z };
        else if (d < preferredRange - leash) h.intent.move = { x: -n.x, z: -n.z };
        else h.intent.move = { x: 0, z: 0 };
        if (h.isCasting() || h.isRecovering() || h.globalCooldown > 0) return;
        const bestAbility = this.pickAbility(world, h, target, d, ctx);
        if (bestAbility) {
            const ability = abilities[bestAbility]
            h.intent.abilityKey = bestAbility;
            h.intent.targetId = (ability.category === "barrier" || ability.category === "utility")
                ? h.id : target.id;
            h.intent.aimAt = { x: target.pos.x, z: target.pos.z };
        }
    }
    getLocalCombatContext(world, creature, target) {
        let nearbyAllies = 0;
        let nearbyEnemies = 0;
        let lowHpAllies = 0;
        for (const other of world.creatures) {
            if (other.lifecycle !== "alive" || other.id === creature.id) continue;
            if (dist(creature.pos.x, creature.pos.z, other.pos.x, other.pos.z) > 150) continue;
            if (other.team === creature.team) {
                nearbyAllies++;
                if (other.currentHP / Math.max(1, other.modifiedStats.maxHP) < 0.45) lowHpAllies++;
            } else nearbyEnemies++;
        }
        const hpRatio = creature.currentHP / Math.max(1, creature.modifiedStats.maxHP);
        const staminaRatio = creature.currentStamina / Math.max(1, creature.modifiedStats.stamina);
        const energyRatio = creature.currentEnergy / Math.max(1, creature.modifiedStats.energy);
        const targetRatio = target ? (target.currentHP / Math.max(1, target.modifiedStats.maxHP)) : 1;
        return {
            hpRatio,
            staminaRatio,
            energyRatio,
            targetRatio,
            nearbyAllies,
            lowHpAllies,
            nearbyEnemies,
            outnumbered: nearbyEnemies > nearbyAllies + 1,
        };
    }
    shouldDashEngage(creature, target, ability, distToTarget, ctx) {
        if (!ability?.dash) return false;
        const dashReach = (ability.dash.distance ?? 70) + (ability.range ?? 20);
        const preferredRange = this.role === "ranged" ? 95 : 18;
        if (distToTarget <= preferredRange + 6) return false;
        if (distToTarget > dashReach) return false;
        if (ctx.hpRatio < 0.35 && ctx.outnumbered) return false;
        return ctx.targetRatio < 0.65 || this.role !== "ranged";
    }
    shouldDashEscape(creature, target, ability, distToTarget, ctx) {
        if (ability.category !== "retreat" && ability.category !== "dash") return false;
        const lowResources = ctx.staminaRatio < 0.3 && ctx.energyRatio < 0.3;
        const tooCloseForRanged = this.role === "ranged" && distToTarget < 50;
        return ctx.hpRatio < 0.38 || lowResources || ctx.outnumbered || tooCloseForRanged;
    }
    shouldUseBarrier(creature, ctx) {
        if (ctx.hpRatio < 0.45) return true;
        if (ctx.outnumbered) return true;
        if (ctx.lowHpAllies > 0) return true;
        if (this.role === "ranged" && ctx.nearbyEnemies > 0 && ctx.energyRatio > 0.4) return true;
        return false;
    }
    scoreAbilityUse(creature, target, ability, distToTarget, ctx) {
        let score =
            (ability.flatDmg?.p ?? 0) +
            (ability.flatDmg?.e ?? 0) +
            (ability.dmgScale?.p ?? 0) * creature.modifiedStats.pAtk +
            (ability.dmgScale?.e ?? 0) * creature.modifiedStats.eAtk +
            (ability.effectsOnHit ? 2 : 0);
        if (ability.category === "barrier") {
            return this.shouldUseBarrier(creature, ctx) ? 35 : -10;
        }
        if (ability.category === "dash" || ability.category === "gap_close") {
            if (this.shouldDashEscape(creature, target, ability, distToTarget, ctx) && this.role === "ranged") score += 10;
            if (this.shouldDashEngage(creature, target, ability, distToTarget, ctx)) score += 16;
            else score -= 12;
        }
        if (ability.category === "retreat") {
            score += this.shouldDashEscape(creature, target, ability, distToTarget, ctx) ? 20 : -8;
        }
        if (ctx.targetRatio < 0.3) score += 5;
        return score;
    }
    pickAbility(world, creature, target, distToTarget, ctx) {
        let best = null;
        let bestScore = -Infinity;
        for (const key of creature.moveset) {
            const a = abilities[key];
            if (!a) continue;
            if ((creature.cooldowns[key] ?? 0) > 0) continue;
            if ((a.resourceUse?.stamina ?? 0) > creature.currentStamina) continue;
            if ((a.resourceUse?.energy ?? 0) > creature.currentEnergy) continue;
            const isDash = a.category === "dash" || a.category === "gap_close" || a.category === "retreat";
            const inNormalRange = distToTarget <= (a.range ?? 999);
            const inDashReach = isDash && distToTarget <= ((a.dash?.distance ?? 70) + (a.range ?? 20));
            const isBarrier = a.category === "barrier";
            if (!isBarrier && !inNormalRange && !inDashReach) continue;
            const score = this.scoreAbilityUse(creature, target, a, distToTarget, ctx);
            if (score > bestScore) {
                bestScore = score;
                best = key;
            }
        }
        return best;
    }
}
/* =========================
   world helpers: biome, spawn, interactables
========================= */
const BiomeSystem = {
    RULE_EXCLUDE_KEYS: new Set(["softness", "bias"]),
    sampleWorldFields(x, z) {
        const temperature =
            0.5 +
            Math.sin(x * 0.00045) * 0.28 +
            Math.cos(z * 0.00023) * 0.22 +
            Math.sin((x + z) * 0.00011) * 0.12;

        const rainfall =
            0.5 +
            Math.cos(x * 0.00031) * 0.25 +
            Math.sin(z * 0.00041) * 0.27 +
            Math.cos((x - z) * 0.00013) * 0.10;

        const lithosphere =
            0.5 +
            Math.sin(x * 0.00018) * 0.35 +
            Math.cos(z * 0.00016) * 0.25 +
            Math.sin((x + z) * 0.00006) * 0.20;

        const barrenness =
            0.5 +
            Math.cos(x * 0.00052) * 0.22 +
            Math.sin(z * 0.00037) * 0.18 +
            Math.cos((x + z) * 0.00019) * 0.14;
        const arcane =
            0.5 +
            Math.sin(x * 0.00073 + 1.73) * 0.24 +
            Math.cos(z * 0.00068 + 0.51) * 0.19 +
            Math.sin((x - z) * 0.00021 + 3.12) * 0.13;

        return {
            temperature: clamp(temperature, 0, 1),
            rainfall: clamp(rainfall, 0, 1),
            lithosphere: clamp(lithosphere, 0, 1),
            barrenness: clamp(barrenness, 0, 1),
            arcane: clamp(arcane, 0, 1),
        };
    },

    scoreField(value, target, softness) {
        const d = Math.abs(value - target) / Math.max(0.001, softness);
        return Math.exp(-(d * d));
    },

    getBiomeMix(x, z) {
        const f = this.sampleWorldFields(x, z);
        const weights = {};
        let total = 0;

        for (const key of Object.keys(biomeDefs)) {
            const rule = biomeDefs[key]?.rules ?? biomeRules[key];
            if (!rule) continue;

            let score = 1;
            const softness = rule.softness ?? 0.24;
            for (const field of Object.keys(rule)) {
                if (this.RULE_EXCLUDE_KEYS.has(field)) continue;
                if (typeof rule[field] !== "number") continue;
                if (typeof f[field] !== "number") continue;
                score *= this.scoreField(f[field], rule[field], softness);
            }
            score *= rule.bias ?? 1;

            score = Math.max(0.0001, score);
            weights[key] = score;
            total += score;
        }

        if (total <= 0) {
            const fallback = Object.keys(biomeDefs)[0];
            return { [fallback]: 1 };
        }

        for (const key of Object.keys(weights)) {
            weights[key] /= total;
        }
        return weights;
    },

    getDominantBiomeKey(mix) {
        let best = "plains";
        let bestWeight = -Infinity;
        for (const key of Object.keys(mix)) {
            if (mix[key] > bestWeight) {
                bestWeight = mix[key];
                best = key;
            }
        }
        return best;
    },

    getBiomeKeyAt(x, z) {
        return this.getDominantBiomeKey(this.getBiomeMix(x, z));
    },

    getBiomeAt(x, z) {
        const key = this.getBiomeKeyAt(x, z);
        return { key, ...biomeDefs[key] };
    },
};
const ChunkSystem = {
  CHUNK_SIZE: 128,
  CELL_SIZE: 16,
  LOAD_RADIUS: 2,
  WATER_LEVEL: -24,
  SHORE_HEIGHT_DELTA: 8,
  SLOPE_ROUGH: 0.9,
  SLOPE_CLIFF: 2.1,

  key(cx, cz) {
    return `${cx}|${cz}`;
  },

  worldToChunk(x, z) {
    return {
      cx: Math.floor(x / this.CHUNK_SIZE),
      cz: Math.floor(z / this.CHUNK_SIZE),
    };
  },

  dominantBiomeKey(biomeMix) {
    return BiomeSystem.getDominantBiomeKey(biomeMix);
  },

  getChunkAtWorld(world, x, z) {
    const { cx, cz } = this.worldToChunk(x, z);
    return world.chunks.get(this.key(cx, cz)) ?? null;
  },

  getCellAtWorld(world, x, z) {
    const chunk = this.getChunkAtWorld(world, x, z);
    if (!chunk) return null;
    const localX = Math.floor((x - chunk.x0) / this.CELL_SIZE);
    const localZ = Math.floor((z - chunk.z0) / this.CELL_SIZE);
    if (localX < 0 || localZ < 0 || localX >= chunk.cellsPerSide || localZ >= chunk.cellsPerSide) return null;
    return chunk.cells[localZ * chunk.cellsPerSide + localX] ?? null;
  },

  forEachLoadedChunk(world, fn) {
    for (const chunk of world.chunks.values()) fn(chunk);
  },

  collectLoadedNodes(world) {
    const out = [];
    this.forEachLoadedChunk(world, (chunk) => {
      for (const node of chunk.nodes) out.push(node);
    });
    return out;
  },

  collectLoadedSpawnPoints(world) {
    const out = [];
    this.forEachLoadedChunk(world, (chunk) => {
      for (const point of chunk.spawnPoints) out.push(point);
    });
    return out;
  },

  ensureChunk(world, cx, cz) {
    const key = this.key(cx, cz);
    if (world.chunks.has(key)) return world.chunks.get(key);

    const chunk = this.generateChunk(world, cx, cz);
    world.chunks.set(key, chunk);
    return chunk;
  },

  randFromInt(seed) {
    const x = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return x - Math.floor(x);
  },

  deterministicChoice(cx, cz, idx, salt = 1) {
    const seed = cx * 928371 + cz * 364583 + idx * 193 + salt * 101;
    return this.randFromInt(seed);
  },

  generateChunk(world, cx, cz) {
    const chunkSize = this.CHUNK_SIZE;
    const cellSize = this.CELL_SIZE;
    const cellsPerSide = Math.floor(chunkSize / cellSize);
    const x0 = cx * chunkSize;
    const z0 = cz * chunkSize;
    const x1 = x0 + chunkSize;
    const z1 = z0 + chunkSize;
    const chunkKey = this.key(cx, cz);

    const cells = [];
    const biomeWeightSums = {};
    for (const key of Object.keys(biomeDefs)) biomeWeightSums[key] = 0;

    for (let gz = 0; gz < cellsPerSide; gz++) {
      for (let gx = 0; gx < cellsPerSide; gx++) {
        const x = x0 + gx * cellSize + cellSize * 0.5;
        const z = z0 + gz * cellSize + cellSize * 0.5;
        const y = this.sampleHeight(x, z);
        const biomeMix = BiomeSystem.getBiomeMix(x, z);
        const dominantBiome = this.dominantBiomeKey(biomeMix);
        for (const key of Object.keys(biomeMix)) biomeWeightSums[key] += biomeMix[key];
        const yPx = this.sampleHeight(x + cellSize, z);
        const yNx = this.sampleHeight(x - cellSize, z);
        const yPz = this.sampleHeight(x, z + cellSize);
        const yNz = this.sampleHeight(x, z - cellSize);
        const slope = (Math.abs(yPx - yNx) + Math.abs(yPz - yNz)) / (cellSize * 2);
        const water = y <= this.WATER_LEVEL;
        const nearWater = !water && (
            this.sampleHeight(x + cellSize * 0.5, z) <= this.WATER_LEVEL ||
            this.sampleHeight(x - cellSize * 0.5, z) <= this.WATER_LEVEL ||
            this.sampleHeight(x, z + cellSize * 0.5) <= this.WATER_LEVEL ||
            this.sampleHeight(x, z - cellSize * 0.5) <= this.WATER_LEVEL ||
            Math.abs(y - this.WATER_LEVEL) < this.SHORE_HEIGHT_DELTA
        );
        let terrainClass = "land";
        if (water) terrainClass = "water";
        else if (slope >= this.SLOPE_CLIFF) terrainClass = "cliff";
        else if (nearWater) terrainClass = "shore";
        else if (slope >= this.SLOPE_ROUGH) terrainClass = "rough";

        const blocked = terrainClass === "water" || terrainClass === "cliff";
        let moveCost = 1;
        if (terrainClass === "rough") moveCost = 1.25;
        if (terrainClass === "shore") moveCost = 1.12;
        if (blocked) moveCost = 999;

        cells.push({
          gx,
          gz,
          x,
          z,
          y,
          biomeMix,
          dominantBiome,
          slope,
          terrainClass,
          blocked,
          water,
          moveCost,
        });
      }
    }

    const biomeMixSummary = {};
    const cellCount = cells.length;
    for (const key of Object.keys(biomeWeightSums)) biomeMixSummary[key] = biomeWeightSums[key] / Math.max(1, cellCount);
    const dominantBiome = this.dominantBiomeKey(biomeMixSummary);

    const obstacles = [];
    const nodes = [];
    const spawnPoints = [];

    const canPlaceAround = (x, z, radius, list, extra = []) => {
      for (const o of list) {
        if (dist(x, z, o.x, o.z) < radius + (o.radius ?? 8)) return false;
      }
      for (const o of extra) {
        if (dist(x, z, o.x, o.z) < radius + (o.radius ?? 8)) return false;
      }
      return true;
    };

    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      const r = this.deterministicChoice(cx, cz, i, 7);
      const r2 = this.deterministicChoice(cx, cz, i, 17);
      const r3 = this.deterministicChoice(cx, cz, i, 27);
      if (!cell.blocked && !cell.water) {
        let obstacleChance = 0.0;
        let obstacleType = null;
        if (cell.dominantBiome === "forest") {
          obstacleChance = 0.16;
          obstacleType = "tree";
        } else if (cell.dominantBiome === "ocean") {
          obstacleChance = 0.03;
          obstacleType = "rock";
        } else if (cell.dominantBiome === "tundra") {
          obstacleChance = 0.09;
          obstacleType = "rock";
        } else if (cell.dominantBiome === "polar") {
          obstacleChance = 0.10;
          obstacleType = "crystal";
        } else if (cell.dominantBiome === "volcanic" || cell.dominantBiome === "desert" || cell.terrainClass === "rough") {
          obstacleChance = 0.11;
          obstacleType = "rock";
        } else if (cell.dominantBiome === "stormfield") {
          obstacleChance = 0.07;
          obstacleType = "crystal";
        }
        if (obstacleType && r < obstacleChance) {
          const obstacleId = `obs-${chunkKey}-${i}`;
          if (world.harvestedObstacleIds?.has(obstacleId)) continue;
          const ox = cell.x + (r2 - 0.5) * (cellSize * 0.6);
          const oz = cell.z + (r3 - 0.5) * (cellSize * 0.6);
          const radius = obstacleType === "tree" ? 5 + r3 * 4 : 4 + r2 * 4;
          obstacles.push({
            id: obstacleId,
            type: obstacleType,
            x: ox,
            z: oz,
            radius,
            blocksMovement: true,
            chunkKey,
          });
        }
      }
    }

    const nodeTable = biomeDefs[dominantBiome]?.nodes ?? biomeDefs.plains.nodes;
    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      if (cell.blocked || cell.water) continue;
      if (cell.terrainClass === "cliff") continue;
      const placeRoll = this.deterministicChoice(cx, cz, i, 53);
      if (placeRoll > 0.032) continue;
      if (!canPlaceAround(cell.x, cell.z, 14, obstacles, nodes)) continue;
      const type = pickWeighted(nodeTable);
      nodes.push(new InteractableNode(type, cell.x, cell.z));
      nodes[nodes.length - 1].chunkKey = chunkKey;
      nodes[nodes.length - 1].id = `node-${chunkKey}-${i}`;
    }

    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      if (cell.blocked || cell.water) continue;
      if (cell.terrainClass === "cliff") continue;
      const placeRoll = this.deterministicChoice(cx, cz, i, 71);
      if (placeRoll > 0.045) continue;
      if (!canPlaceAround(cell.x, cell.z, 22, obstacles, spawnPoints)) continue;
      const spBiome = cell.dominantBiome;
      spawnPoints.push({
        id: `spawn-${chunkKey}-${i}`,
        x: cell.x,
        z: cell.z,
        biomeKey: spBiome,
        levelBias: Math.round((cell.y - this.WATER_LEVEL) / 18),
        spawnWeights: biomeDefs[spBiome]?.spawns ?? biomeDefs.plains.spawns,
        blocked: false,
        chunkKey,
      });
    }

    return {
      cx,
      cz,
      x0,
      z0,
      x1,
      z1,
      cellsPerSide,
      cells,
      nodes,
      obstacles,
      spawnPoints,
      dominantBiome,
      biomeMixSummary,
      generated: true,
    };
  },
  sampleHeight(x, z) {
    const f = BiomeSystem.sampleWorldFields(x, z);
    const mix = BiomeSystem.getBiomeMix(x, z);

    const broad =
        Math.sin(x * 0.00018) * 36 +
        Math.cos(z * 0.00016) * 28 +
        Math.sin((x + z) * 0.00006) * 18;

    const medium =
        Math.sin(x * 0.0018) * 8 +
        Math.cos(z * 0.0015) * 7 +
        Math.sin((x - z) * 0.0012) * 5;

    const fine =
        Math.sin(x * 0.006) * 2.5 +
        Math.cos(z * 0.005) * 2 +
        Math.sin((x + z) * 0.004) * 1.5;

    const lithoBase = (f.lithosphere - 0.5) * 110;
    const moistureFlatten = (f.rainfall - 0.5) * -12;
    const barrenHarshness = (f.barrenness - 0.5) * 8;

    // Biome-specific terrain shaping.
    const plainsBias   = (mix.plains ?? 0) * -10;
    const oceanBias    = (mix.ocean ?? 0) * -38;
    const forestBias   = (mix.forest ?? 0) * 4;
    const desertBias   = (mix.desert ?? 0) * -6;
    const stormBias    = (mix.stormfield ?? 0) * 10;
    const volcanicBias = (mix.volcanic ?? 0) * 24;
    const tundraBias   = (mix.tundra ?? 0) * -8;
    const polarBias    = (mix.polar ?? 0) * -16;

    const volcanicRough =
        (mix.volcanic ?? 0) *
        (Math.sin(x * 0.0035) * 10 + Math.cos(z * 0.0032) * 8);

    const stormRough =
        (mix.stormfield ?? 0) *
        (Math.sin((x + z) * 0.0024) * 6 + Math.cos((x - z) * 0.0021) * 5);
    const polarRough =
        (mix.polar ?? 0) *
        (Math.sin((x - z) * 0.0028) * 4 + Math.cos((x + z) * 0.0022) * 3);

    const plainFlatten =
        (mix.plains ?? 0) *
        (Math.sin(x * 0.0012) * -4 + Math.cos(z * 0.0011) * -3);
    const oceanFlatten =
        (mix.ocean ?? 0) *
        (Math.sin(x * 0.0013) * -7 + Math.cos(z * 0.0014) * -6);
    const tundraFlatten =
        (mix.tundra ?? 0) *
        (Math.sin(x * 0.0014) * -2 + Math.cos(z * 0.0013) * -2);

    return (
        broad +
        medium +
        fine +
        lithoBase +
        moistureFlatten +
        barrenHarshness +
        plainsBias +
        oceanBias +
        forestBias +
        desertBias +
        stormBias +
        volcanicBias +
        tundraBias +
        polarBias +
        volcanicRough +
        stormRough +
        polarRough +
        plainFlatten +
        oceanFlatten +
        tundraFlatten
    );
  },
  updateLoadedChunks(world) {
    const { cx, cz } = this.worldToChunk(world.player.pos.x, world.player.pos.z);

    for (let dz = -this.LOAD_RADIUS; dz <= this.LOAD_RADIUS; dz++) {
      for (let dx = -this.LOAD_RADIUS; dx <= this.LOAD_RADIUS; dx++) {
        this.ensureChunk(world, cx + dx, cz + dz);
      }
    }

    for (const [key, chunk] of world.chunks) {
      if (Math.abs(chunk.cx - cx) > this.LOAD_RADIUS + 1 || Math.abs(chunk.cz - cz) > this.LOAD_RADIUS + 1) {
        world.chunks.delete(key);
      }
    }

    world.nodes = this.collectLoadedNodes(world);
  }
};
class SpawnField {
    constructor(radius = 260, innerNoSpawn = 90, maxWild = 8, interval = 1.6) {
        this.radius = radius;
        this.innerNoSpawn = innerNoSpawn;
        this.maxWild = maxWild;
        this.interval = interval;
        this.timer = 0;
    }
    update(dt, world) {
        this.timer += dt;
        if (this.timer >= this.interval) {
            this.timer = 0;
            this.trySpawn(world);
        }
        this.cleanup(world);
    }
    getAveragePartyLevel(world) {
        const livingParty = world.player.petIds
            .map(id => world.getCreatureById(id))
            .filter(c => c && c.lifecycle === "alive");
        if (livingParty.length <= 0) return 1;
        const total = livingParty.reduce((sum, c) => sum + c.level, 0);
        return total / livingParty.length;
    }
    rollWildTier() {
        const r = Math.random();
        if (r < 0.24) return "small";
        if (r < 0.92) return "normal";
        return "big";
    }
    getTierConfig(tier) {
        if (tier === "small") {
            return {
                team: 1,
                levelDeltaMin: -3,
                levelDeltaMax: 1,
                aggroMult: 0.72,
                pursuitRange: 120,
                targetNearPlayerBias: 0.55,
                statMult: { maxHP: 0.86, pAtk: 0.9, eAtk: 0.9, spd: 1.05 },
                sizeMult: 0.85,
                nearbyRadius: 34,
            };
        }
        if (tier === "big") {
            return {
                team: 2,
                levelDeltaMin: 2,
                levelDeltaMax: 6,
                aggroMult: 1.45,
                pursuitRange: 240,
                targetNearPlayerBias: 0,
                statMult: { maxHP: 1.35, pAtk: 1.22, eAtk: 1.22, spd: 0.94 },
                sizeMult: 1.26,
                nearbyRadius: 90,
            };
        }
        return {
            team: 1,
            levelDeltaMin: -2,
            levelDeltaMax: 2,
            aggroMult: 1,
            pursuitRange: 170,
            targetNearPlayerBias: 0,
            statMult: null,
            sizeMult: 1,
            nearbyRadius: 40,
        };
    }
    rollWildLevel(avgPartyLevel, levelBias, cfg) {
        const deltaRoll = cfg.levelDeltaMin + Math.random() * (cfg.levelDeltaMax - cfg.levelDeltaMin);
        const delta = deltaRoll + (levelBias ?? 0) * 0.2;
        return Math.max(1, Math.round(avgPartyLevel + delta));
    }
    trySpawn(world) {
        const currentWild = world.creatures.filter(c => c.mode === "wild" && c.lifecycle === "alive").length;
        if (currentWild >= this.maxWild) return;
        const player = world.player;
        const avgPartyLevel = this.getAveragePartyLevel(world);
        const candidates = ChunkSystem.collectLoadedSpawnPoints(world)
            .filter((sp) => !sp.blocked)
            .filter((sp) => true)
            .filter((sp) => {
                const d = dist(player.pos.x, player.pos.z, sp.x, sp.z);
                return d >= this.innerNoSpawn && d <= this.radius;
            });
        if (candidates.length <= 0) return;

        for (let i = 0; i < 6; i++) {
            const sp = candidates[Math.floor(Math.random() * candidates.length)];
            const cell = ChunkSystem.getCellAtWorld(world, sp.x, sp.z);
            if (!cell || cell.blocked || cell.water) continue;
            const tier = this.rollWildTier();
            const cfg = this.getTierConfig(tier);
            const nearbyWild = world.creatures.some((c) => c.mode === "wild" && c.lifecycle === "alive" && dist(c.pos.x, c.pos.z, sp.x, sp.z) < cfg.nearbyRadius);
            if (nearbyWild) continue;
            if (tier === "big") {
                const nearbyBig = world.creatures.some((c) =>
                    c.mode === "wild" &&
                    c.lifecycle === "alive" &&
                    c.wildTier === "big" &&
                    dist(c.pos.x, c.pos.z, sp.x, sp.z) < 170
                );
                if (nearbyBig) continue;
            }

            const speciesKey = pickWeighted(sp.spawnWeights ?? biomeDefs[sp.biomeKey]?.spawns ?? biomeDefs.plains.spawns);
            const wildLevel = this.rollWildLevel(avgPartyLevel, sp.levelBias, cfg);
            const wild = world.factory.create(speciesKey, cfg.team, sp.x, sp.z, {
                mode: "wild",
                level: wildLevel,
                wildTier: tier,
                wildProfile: {
                    aggroMult: cfg.aggroMult,
                    pursuitRange: cfg.pursuitRange,
                    targetNearPlayerBias: cfg.targetNearPlayerBias,
                    statMult: cfg.statMult,
                    sizeMult: cfg.sizeMult,
                },
                spawnAnchor: { x: sp.x, z: sp.z },
            });
            const brain = new Brain();
            brain.attach(wild);
            world.creatures.push(wild);
            return;
        }
    }
    cleanup(world) {
        const p = world.player.pos;
        world.creatures = world.creatures.filter(c => {
            if (c.mode !== "wild") return true;
            if (c.lifecycle !== "alive") return false;
            if (world.CM.isCreatureEngaged(c)) return true;
            return dist(c.pos.x, c.pos.z, p.x, p.z) < this.radius * 1.75;
        });
    }
}
class InteractableNode {
    constructor(type, x, z) {
        this.type = type;
        this.pos = { x, z };
        this.cooldown = 0;
    }
    update(dt) {
        this.cooldown = Math.max(0, this.cooldown - dt);
    }
    get active() {
        return this.cooldown <= 0;
    }
}
class BarrierZone {
    constructor(x, z, team, radius, duration, opts = {}) {
        this.pos = { x, z };
        this.team = team;
        this.radius = radius;
        this.ttl = duration;
        this.slow = opts.slow ?? 0.2;
        this.damageReduction = opts.damageReduction ?? 0.18;
        this.blockMovement = opts.blockMovement ?? true;
        this.color = opts.color ?? "rgba(120,190,255,0.18)";
    }
}
/* =========================
   player + commands/items/taming
========================= */
class PlayerEntity {
    constructor(x, z) {
        this.MANUAL_FOLLOW_DISTANCE = 42;
        this.MANUAL_FOLLOW_DEADZONE = 10;
        this.MANUAL_LEASH_RADIUS = 96;
        this.MANUAL_FOLLOW_SPEED = 170;
        this.MANUAL_LEASH_PULL_SPEED = 240;
        this.pos = { x, z };
        this.vel = { x: 0, z: 0 };
        this.spd = 140;
        this.petIds = [null, null, null];
        this.partyOwnedIds = [null, null, null];
        this.selectAll = false;
        this.activePetIndex = 0;
        this.commandTargetId = null;
        this.stance = "aggressive";
        this.selectedItemIndex = 0
        this.inventory = { berry_red: 10, berry_blue: 4, berry_yellow: 4, battery_seed: 5, lure_meat: 5, revive_berry: 3 };
        this.materialsInventory = { wood: 6, stone: 4, crystal_shard: 0, metal_scrap: 0 };
        this.itemBar =  ['berry_red', 'battery_seed', "lure_meat", "revive_berry"]
        this.selectedItemKey = this.itemBar[this.selectedItemIndex] ?? null;
        this.toolbelt = ["hammer", "gather_tool"];
        this.selectedToolIndex = -1;
        this.selectedToolKey = null;
        this.toolMode = "build";
        this.selectedBuildKey = "shelter";
        this.selectedMorphOptionIndex = 0;
        this.reserveOwnedIds = [];
        this.selectedReserveIndex = 0;
        this.ownedCreatures = [];
        this.lastLog = "";
        this.activeControlMode = "AUTO"; // AUTO | MANUAL
    }
    get activePetId() {
        return this.petIds[this.activePetIndex] ?? null;
    }
    get targetPetIds(){
        return this.selectAll
            ? this.petIds.filter(Boolean)
            : [this.activePetId].filter(Boolean);
    }
    cycleItem(dir){
        const len = this.itemBar.length;
        if (!len) return;
        this.selectedItemIndex = (this.selectedItemIndex + dir + len) % len;
        this.selectedItemKey = this.itemBar[this.selectedItemIndex];
    }
    cycleTool(dir) {
        const len = this.toolbelt.length;
        if (!len) return;
        this.selectedToolIndex = (this.selectedToolIndex + dir + len) % len;
        this.selectedToolKey = this.toolbelt[this.selectedToolIndex];
    }
    updateAutoMovement(input, dt, world) {
        let mx = 0;
        let mz = 0;
        if (input.isDown("ArrowLeft")) mx -= 1;
        if (input.isDown("ArrowRight")) mx += 1;
        if (input.isDown("ArrowUp")) mz -= 1;
        if (input.isDown("ArrowDown")) mz += 1;
        const mv = norm2D(mx, mz);
        this.vel.x = mv.x * this.spd;
        this.vel.z = mv.z * this.spd;
        this.pos.x += this.vel.x * dt
        this.pos.z += this.vel.z * dt
    }
    updateManualFollow(world, dt) {
        const activePet = world.getCreatureById(this.activePetId);
        if (!activePet || activePet.lifecycle !== "alive") {
            this.vel.x *= 0.85;
            this.vel.z *= 0.85;
            return;
        }
        const speed = Math.hypot(activePet.vel.x, activePet.vel.z);
        let heading = { x: Math.cos(activePet.angle), z: Math.sin(activePet.angle) };
        if (speed > 0.5) heading = norm2D(activePet.vel.x, activePet.vel.z);
        const anchor = {
            x: activePet.pos.x - heading.x * this.MANUAL_FOLLOW_DISTANCE,
            z: activePet.pos.z - heading.z * this.MANUAL_FOLLOW_DISTANCE,
        };
        const dx = anchor.x - this.pos.x;
        const dz = anchor.z - this.pos.z;
        const d = Math.hypot(dx, dz);
        if (d > this.MANUAL_FOLLOW_DEADZONE) {
            const n = norm2D(dx, dz);
            const desiredVx = n.x * this.MANUAL_FOLLOW_SPEED;
            const desiredVz = n.z * this.MANUAL_FOLLOW_SPEED;
            const blend = clamp(dt * 6, 0, 1);
            this.vel.x += (desiredVx - this.vel.x) * blend;
            this.vel.z += (desiredVz - this.vel.z) * blend;
        } else {
            this.vel.x *= 0.8;
            this.vel.z *= 0.8;
        }

        this.pos.x += this.vel.x* dt
        this.pos.z += this.vel.z* dt
        this.enforceActivePetLeash(world, dt);
    }
    enforceActivePetLeash(world, dt) {
        const activePet = world.getCreatureById(this.activePetId);
        if (!activePet || activePet.lifecycle !== "alive") return;
        const dx = this.pos.x - activePet.pos.x;
        const dz = this.pos.z - activePet.pos.z;
        const d = Math.hypot(dx, dz);
        if (d <= this.MANUAL_LEASH_RADIUS) return;
        const n = norm2D(dx, dz);
        const overshoot = d - this.MANUAL_LEASH_RADIUS;
        const pull = Math.min(overshoot, this.MANUAL_LEASH_PULL_SPEED * dt);
        this.pos.x -= n.x * pull;
        this.pos.z -= n.z * pull;
        // Safety clamp to avoid ever drifting outside due to low frame rates.
        const safeD = Math.hypot(this.pos.x - activePet.pos.x, this.pos.z - activePet.pos.z);
        if (safeD > this.MANUAL_LEASH_RADIUS) {
            this.pos.x = activePet.pos.x + n.x * this.MANUAL_LEASH_RADIUS;
            this.pos.z = activePet.pos.z + n.z * this.MANUAL_LEASH_RADIUS;
        }
    }
    update(dt, input, world) {
        if (this.activeControlMode === "MANUAL") this.updateManualFollow(world, dt);
        else this.updateAutoMovement(input, dt, world);
        if (input.consumePress("Digit1")) this.activePetIndex = 0;
        if (input.consumePress("Digit2")) this.activePetIndex = 1;
        if (input.consumePress("Digit3")) this.activePetIndex = 2;
        if (input.consumePress("Digit4")) {
            this.selectAll = !this.selectAll;
            this.lastLog = this.selectAll ? "All Pets Selected" : `Pet ${this.activePetIndex + 1} selected`;
        }
        if (input.consumePress("KeyM")) {
            this.activeControlMode = this.activeControlMode === "AUTO" ? "MANUAL" : "AUTO";
            this.lastLog = `Control: ${this.activeControlMode}`;
        }
        if (input.consumePress("KeyQ")) this.cycleItem(-1);
        if (input.consumePress("KeyE")) this.cycleItem(1);
        if (input.consumePress("KeyZ")) world.PIS.useSelectedItem();
        if (input.consumePress("KeyA")) world.CM.queueManualCast(0);
        if (input.consumePress("KeyS")) world.CM.queueManualCast(1);
        if (input.consumePress("KeyD")) world.CM.queueManualCast(2);
        if (input.consumePress("KeyF")) world.CM.queueManualCast(3);
        const contextWorldPos = world.camera.screenToWorld(input.mouse.x, input.mouse.y);
        if (input.consumePress("KeyG")) world.PIS.tryContextAction(contextWorldPos, { allowBuildAtCursor: true });
        if (input.consumePress("KeyY")) world.BS.cycleSelectedTool(1);
        if (input.consumePress("KeyR")) world.BS.cycleToolMode(1);
        if (input.consumePress("KeyB")) world.BS.cycleBuildType(1);
        if (input.consumePress("KeyJ")) world.cycleActiveMorphOption(-1);
        if (input.consumePress("KeyK")) world.cycleActiveMorphOption(1);
        if (input.consumePress("KeyP")) world.tryMorphActivePetSelectedOption();
        if (input.consumePress("BracketLeft")) this.selectedReserveIndex = Math.max(0, this.selectedReserveIndex - 1);
        if (input.consumePress("BracketRight")) this.selectedReserveIndex += 1;
        if (input.consumePress("KeyT")) world.PIS.swapActiveWithReserve(this.selectedReserveIndex);
        const worldPos = contextWorldPos;
        if (input.consumeMouseLeftPress()) {
            const target = world.findNearestEnemyToPoint(worldPos.x, worldPos.z, 32);
            if (target) {
                this.commandTargetId = target.id;
                world.PIS.commandPets(this.targetPetIds, { type: "attack", targetId: target.id, issuedAt: world.time });
                this.lastLog = `Attack ${target.speciesKey}`;
            }
        }
        if (input.consumeMouseRightPress()) {
            if (this.selectedToolKey === "hammer" || this.selectedToolKey === "gather_tool") {
                world.PIS.tryContextAction(worldPos, { allowBuildAtCursor: true });
            } else {
                world.PIS.commandPets(this.targetPetIds, { type: "move", point: worldPos, issuedAt: world.time });
                this.commandTargetId = null;
                this.lastLog = "Move command";
            }
        }
    }
}
/* =========================
   world
========================= */
class World {
    constructor() {
        this.width = 1600;
        this.height = 1100;
        this.time = 0;
        this.camera = new Camera();
        this.chunks = new Map();
        this.player = new PlayerEntity(this.width / 2, this.height / 2);
        this.PIS = new PlayerInteractionSystem(this)
        this.CM = new CombatManager(this)
        this.BS = new BuildSystem(this);
        this.creatures = [];
        this.factory = new CreatureFactory();
        this.spawnField = new SpawnField();
        this.nodes = [];
        this.harvestedObstacleIds = new Set();
        this.buildablesById = new Map();
        this.buildableIdsByChunk = new Map();
        this.nextBuildId = 1;
        this.nodeSpawnTimer = 0;
        this.floatingTexts = [];
        this.combatFx = [];
    }
    createEmptyGrowthStats() {
        return { pAtk: 0, eAtk: 0, range: 0, maxHP: 0, spd: 0, castSpd: 0, size: 0, stamina: 0, energy: 0, recoverStamina: 0, recoverEnergy: 0 };
    }
    cloneGrowthStats(source) {
        return { ...this.createEmptyGrowthStats(), ...(source ?? {}) };
    }
    initialize(starterSpeciesKey = "dog") {
        this.camera.follow(this.player);
        const ownedStarter = this.createOwnedCreatureRecord(starterSpeciesKey);
        this.player.partyOwnedIds = [ownedStarter.ownedId, null, null];
        this.hydratePartyRuntime();
    }
    spawnPetFromOwned(ownedId, x, z) {
        const owned = this.getOwnedCreatureById(ownedId);
        if (!owned) return null;
        const pet = this.factory.create(owned.speciesKey, 0, x, z, {
            mode: "pet",
            level: owned.level,
            xp: owned.xp,
            nextXP: owned.nextXP,
            growthStats: owned.growthStats,
            moveset: owned.moveset,
            ownedId: owned.ownedId,
        });
        pet.level = owned.level;
        pet.xp = owned.xp;
        pet.nextXP = owned.nextXP;
        this.applyOwnedIdentityToRuntime(pet, owned, true);
        const brain = new Brain();
        brain.attach(pet);
        pet.command = { type: "follow", issuedAt: this.time };
        this.creatures.push(pet);
        this.syncOwnedCreatureFromRuntime(pet);
        return pet;
    }
    hydratePartyRuntime() {
        this.creatures = this.creatures.filter(c => c.mode !== "pet");
        this.player.petIds = [null, null, null];
        const p = this.player.pos;
        const offsets = [{ x: -20, z: 30 }, { x: 20, z: 30 }, { x: 0, z: 55 }];
        for (let i = 0; i < 3; i++) {
            const ownedId = this.player.partyOwnedIds[i];
            if (ownedId == null) continue;
            const off = offsets[i] ?? { x: 0, z: 40 + i * 14 };
            const pet = this.spawnPetFromOwned(ownedId, p.x + off.x, p.z + off.z);
            if (pet) this.player.petIds[i] = pet.id;
        }
    }
    getFirstOpenPartySlot() {
        for (let i = 0; i < this.player.partyOwnedIds.length; i++) {
            if (this.player.partyOwnedIds[i] == null) return i;
        }
        return -1;
    }
    createOwnedCreatureRecord(speciesKey, runtime = null) {
        const def = species[speciesKey];
        const source = runtime ?? {};
        const owned = {
            ownedId: NEXT_OWNED_ID++,
            speciesKey,
            nickname: def?.name ?? speciesKey,
            level: source.level ?? 1,
            xp: source.xp ?? 0,
            nextXP: source.nextXP ?? xpNeededForLevel(source.level ?? 1),
            growthStats: this.cloneGrowthStats(source.growthStats),
            moveset: [...(source.moveset ?? def.moveset)],
            familyKey: source.familyKey ?? def.familyKey ?? "canine",
            outerCompositeKey: source.outerCompositeKey ?? def.outerCompositeKey ?? def.compositeKey,
            innerCompositeKey: source.innerCompositeKey ?? def.innerCompositeKey ?? def.compositeKey,
            compositeKey: source.compositeKey ?? def.compositeKey,
            morphPoints: source.morphPoints ?? 0,
            morphHistory: [...(source.morphHistory ?? [])],
        };
        this.player.ownedCreatures.push(owned);
        return owned;
    }
    getOwnedCreatureById(ownedId) {
        return this.player.ownedCreatures.find(o => o.ownedId === ownedId) ?? null;
    }
    syncOwnedCreatureFromRuntime(runtimeCreature) {
        if (runtimeCreature.ownedId == null) return;
        const owned = this.getOwnedCreatureById(runtimeCreature.ownedId);
        if (!owned) return;
        owned.level = runtimeCreature.level;
        owned.xp = runtimeCreature.xp;
        owned.nextXP = runtimeCreature.nextXP;
        owned.growthStats = this.cloneGrowthStats(runtimeCreature.growthStats);
        owned.moveset = [...runtimeCreature.moveset];
        owned.familyKey = runtimeCreature.familyKey;
        owned.outerCompositeKey = runtimeCreature.outerCompositeKey;
        owned.innerCompositeKey = runtimeCreature.innerCompositeKey;
        owned.compositeKey = runtimeCreature.compositeKey;
        owned.morphPoints = runtimeCreature.morphPoints ?? owned.morphPoints ?? 0;
    }
    getMorphPointsForOwned(owned) {
        return Math.max(0, owned?.morphPoints ?? 0);
    }
    awardMorphPointsToOwned(ownedId, amount, reason = "progress") {
        if (amount <= 0) return;
        const owned = this.getOwnedCreatureById(ownedId);
        if (!owned) return;
        owned.morphPoints = Math.max(0, (owned.morphPoints ?? 0) + amount);
        const runtime = this.creatures.find(c => c.ownedId === ownedId && c.lifecycle === "alive");
        if (runtime) runtime.morphPoints = owned.morphPoints;
        this.player.lastLog = `+${amount} morph point${amount > 1 ? "s" : ""} (${reason})`;
    }
    getAvailableMorphsForOwned(ownedId) {
        const owned = this.getOwnedCreatureById(ownedId);
        if (!owned) return [];
        const baseDef = species[owned.speciesKey];
        const options = baseDef?.morphOptions ?? [];
        const out = [];
        for (const option of options) {
            const check = this.canMorphOwnedCreature(ownedId, option.option, option);
            out.push({ ...option, check });
        }
        return out;
    }
    canMorphOwnedCreature(ownedId, targetSpeciesKey, optionOverride = null) {
        const owned = this.getOwnedCreatureById(ownedId);
        if (!owned) return { ok: false, reason: "Owned creature not found" };
        const fromDef = species[owned.speciesKey];
        const toDef = species[targetSpeciesKey];
        if (!fromDef || !toDef) return { ok: false, reason: "Unknown species" };
        const option = optionOverride ?? (fromDef.morphOptions ?? []).find(m => m.option === targetSpeciesKey);
        if (!option) return { ok: false, reason: "Morph path unavailable" };
        const pointsNeeded = option.pointsNeeded ?? 0;
        const points = this.getMorphPointsForOwned(owned);
        if (points < pointsNeeded) return { ok: false, reason: `Need ${pointsNeeded} morph points` };
        if (option.biomeAffinity?.length) {
            const biome = ChunkSystem.getCellAtWorld(this, this.player.pos.x, this.player.pos.z)?.dominantBiome
                ?? BiomeSystem.getBiomeAt(this.player.pos.x, this.player.pos.z).key;
            if (!option.biomeAffinity.includes(biome)) return { ok: false, reason: `Need biome: ${option.biomeAffinity.join("/")}` };
        }
        if (option.materialFocus) {
            const amount = Math.max(1, pointsNeeded);
            const have = this.player.materialsInventory[option.materialFocus] ?? 0;
            if (have < amount) return { ok: false, reason: `Need ${option.materialFocus} x${amount}` };
        }
        return { ok: true, reason: "ok", option, points, pointsNeeded };
    }
    cycleActiveMorphOption(dir = 1) {
        const ownedId = this.player.partyOwnedIds[this.player.activePetIndex];
        if (ownedId == null) return;
        const options = this.getAvailableMorphsForOwned(ownedId);
        if (!options.length) {
            this.player.selectedMorphOptionIndex = 0;
            return;
        }
        const len = options.length;
        this.player.selectedMorphOptionIndex = (this.player.selectedMorphOptionIndex + dir + len) % len;
    }
    getSelectedMorphOptionForActive() {
        const ownedId = this.player.partyOwnedIds[this.player.activePetIndex];
        if (ownedId == null) return null;
        const options = this.getAvailableMorphsForOwned(ownedId);
        if (!options.length) return null;
        const idx = clamp(this.player.selectedMorphOptionIndex, 0, options.length - 1);
        this.player.selectedMorphOptionIndex = idx;
        return options[idx];
    }
    buildMorphMoveset(previousMoveset, targetMoveset, maxMoves = 4) {
        const out = [];
        const targetSet = new Set(targetMoveset);
        const targetCategories = new Set(targetMoveset.map(m => abilities[m]?.category).filter(Boolean));
        const carry = previousMoveset.find((m) => targetSet.has(m))
            ?? previousMoveset.find((m) => targetCategories.has(abilities[m]?.category));
        if (carry) out.push(carry);
        for (const move of targetMoveset) {
            if (out.includes(move)) continue;
            out.push(move);
            if (out.length >= maxMoves) break;
        }
        return out.slice(0, maxMoves);
    }
    applyOwnedIdentityToRuntime(runtimeCreature, owned, resetLevels = false) {
        if (!runtimeCreature || !owned) return;
        runtimeCreature.speciesKey = owned.speciesKey;
        runtimeCreature.familyKey = owned.familyKey ?? species[owned.speciesKey]?.familyKey ?? "canine";
        runtimeCreature.outerCompositeKey = owned.outerCompositeKey ?? species[owned.speciesKey]?.outerCompositeKey ?? owned.compositeKey;
        runtimeCreature.innerCompositeKey = owned.innerCompositeKey ?? species[owned.speciesKey]?.innerCompositeKey ?? owned.compositeKey;
        runtimeCreature.compositeKey = owned.compositeKey ?? runtimeCreature.outerCompositeKey;
        runtimeCreature.speciesBaseStats = { ...(species[owned.speciesKey]?.baseStats ?? runtimeCreature.speciesBaseStats) };
        runtimeCreature.moveset = [...owned.moveset];
        runtimeCreature.cooldowns = Object.fromEntries(runtimeCreature.moveset.map(k => [k, runtimeCreature.cooldowns?.[k] ?? 0]));
        if (resetLevels) {
            runtimeCreature.level = owned.level;
            runtimeCreature.xp = owned.xp;
            runtimeCreature.nextXP = owned.nextXP;
        }
        runtimeCreature.growthStats = { ...owned.growthStats };
        runtimeCreature.morphPoints = owned.morphPoints ?? runtimeCreature.morphPoints ?? 0;
        runtimeCreature.aiTendency = { ...(familyDefs[runtimeCreature.familyKey]?.aiTendency ?? runtimeCreature.aiTendency) };
        runtimeCreature.rebuildStats();
    }
    applyMorphToRuntimeCreature(runtimeCreature, owned) {
        if (!runtimeCreature || !owned) return false;
        const hpRatio = runtimeCreature.currentHP / Math.max(1, runtimeCreature.modifiedStats.maxHP);
        const staminaRatio = runtimeCreature.currentStamina / Math.max(1, runtimeCreature.modifiedStats.stamina);
        const energyRatio = runtimeCreature.currentEnergy / Math.max(1, runtimeCreature.modifiedStats.energy);
        this.applyOwnedIdentityToRuntime(runtimeCreature, owned, true);
        runtimeCreature.currentHP = clamp(runtimeCreature.modifiedStats.maxHP * hpRatio, 1, runtimeCreature.modifiedStats.maxHP);
        runtimeCreature.currentStamina = clamp(runtimeCreature.modifiedStats.stamina * staminaRatio, 0, runtimeCreature.modifiedStats.stamina);
        runtimeCreature.currentEnergy = clamp(runtimeCreature.modifiedStats.energy * energyRatio, 0, runtimeCreature.modifiedStats.energy);
        return true;
    }
    applyMorphToOwnedCreature(ownedId, targetSpeciesKey) {
        const check = this.canMorphOwnedCreature(ownedId, targetSpeciesKey);
        if (!check.ok) return check;
        const owned = this.getOwnedCreatureById(ownedId);
        const targetDef = species[targetSpeciesKey];
        const option = check.option ?? {};
        if (option.materialFocus) {
            const amt = Math.max(1, option.pointsNeeded ?? 1);
            this.player.materialsInventory[option.materialFocus] = Math.max(0, (this.player.materialsInventory[option.materialFocus] ?? 0) - amt);
        }
        const previousSpeciesKey = owned.speciesKey;
        const previousMoveset = [...owned.moveset];
        owned.speciesKey = targetSpeciesKey;
        owned.familyKey = targetDef.familyKey ?? owned.familyKey;
        owned.outerCompositeKey = targetDef.outerCompositeKey ?? targetDef.compositeKey ?? owned.outerCompositeKey;
        owned.innerCompositeKey = targetDef.innerCompositeKey ?? targetDef.compositeKey ?? owned.innerCompositeKey;
        owned.compositeKey = targetDef.compositeKey ?? owned.outerCompositeKey;
        owned.moveset = this.buildMorphMoveset(previousMoveset, [...targetDef.moveset], 4);
        owned.morphHistory = [...(owned.morphHistory ?? []), { from: previousSpeciesKey, to: targetSpeciesKey, at: this.time }];
        const runtime = this.creatures.find(c => c.ownedId === ownedId && c.lifecycle === "alive");
        if (runtime) this.applyMorphToRuntimeCreature(runtime, owned);
        this.player.lastLog = `${owned.nickname} morphed into ${targetDef.name}`;
        this.pushFloatingText(this.player.pos.x, this.player.pos.z - 20, `Morphed: ${targetDef.name}`, "#fff799");
        return { ok: true, reason: "Morphed", owned };
    }
    tryMorphActivePetSelectedOption() {
        const ownedId = this.player.partyOwnedIds[this.player.activePetIndex];
        if (ownedId == null) {
            this.player.lastLog = "No active owned creature";
            return false;
        }
        const selected = this.getSelectedMorphOptionForActive();
        if (!selected) {
            this.player.lastLog = "No morph options";
            return false;
        }
        const result = this.applyMorphToOwnedCreature(ownedId, selected.option);
        if (!result.ok) this.player.lastLog = `Morph failed: ${result.reason}`;
        return result.ok;
    }
    update(dt, input) {
        this.time += dt;
        this.player.update(dt, input, this);
        this.normalizeReserveSelection();
        ChunkSystem.updateLoadedChunks(this);
        this.spawnField.update(dt, this);
        for (const node of this.nodes) node.update(dt);
        for (const c of this.creatures) if (c.brain) c.brain.think(this);
        for (const c of this.creatures) c.tick(dt, this);
        this.resolveSimpleSeparation();
        this.BS.update(dt, input);
        this.CM.cleanupDefeatedCreatures();
        this.rebuildPartyPetIds();
        this.removeDeadCommandTarget();
        this.CM.updateBarriers(dt);
        this.updateFx(dt);
        this.camera.update(dt);
    }
    normalizeReserveSelection() {
        if (this.player.reserveOwnedIds.length <= 0) {
            this.player.selectedReserveIndex = 0;
            return;
        }
        this.player.selectedReserveIndex = clamp(this.player.selectedReserveIndex, 0, this.player.reserveOwnedIds.length - 1);
    }
    rebuildPartyPetIds() {
        this.player.petIds = this.player.partyOwnedIds.map((ownedId) => {
            if (ownedId == null) return null;
            
            const runtime = this.creatures.find(c =>
                c.mode === "pet" &&
                c.ownedId === ownedId &&
                c.lifecycle !== "captured" &&
                c.lifecycle !== "despawned"
            );
            return runtime?.id ?? null
        });
    }
    getCreatureById(id) {
        return this.creatures.find(c => c.id === id) ?? null;
    }
    getPetFollowAnchor(petId) {
        const ids = this.player.petIds;
        const idx = ids.indexOf(petId);
        const p = this.player.pos;
        const anchors = [
            { x: p.x - 28, z: p.z + 26 },
            { x: p.x + 28, z: p.z + 26 },
            { x: p.x, z: p.z + 52 },
        ];
        return anchors[idx] ?? { x: p.x, z: p.z + 30 };
    }
    findNearestEnemyOf(creature, maxRange = Infinity) {
        let best = null;
        let bestD = Infinity;
        for (const other of this.creatures) {
            if (other.id === creature.id || other.lifecycle !== "alive" || other.team === creature.team) continue;
            const d = dist(creature.pos.x, creature.pos.z, other.pos.x, other.pos.z);
            if (d < bestD && d <= maxRange) {
                bestD = d;
                best = other;
            }
        }
        return best;
    }
    findNearestEnemyToPoint(x, z, maxRange = 30) {
        let best = null;
        let bestD = Infinity;
        for (const c of this.creatures) {
            if (c.team === 0 || c.lifecycle !== "alive") continue;
            const d = dist(x, z, c.pos.x, c.pos.z);
            if (d < bestD && d <= maxRange) {
                bestD = d;
                best = c;
            }
        }
        return best;
    }

    spawnBiomeNodesAroundPlayer(count) {
        // Legacy path intentionally disabled; chunk generation now owns node placement.
        return count;
    }
    removeDeadCommandTarget() {
        const id = this.player.commandTargetId;
        if (id == null) return;
        const t = this.getCreatureById(id);
        if (!t || t.lifecycle !== "alive") this.player.commandTargetId = null;
    }
    resolveSimpleSeparation() {
        const minDist = 16;
        for (let i = 0; i < this.creatures.length; i++) {
            const a = this.creatures[i];
            if (a.lifecycle !== "alive") continue;
            for (let j = i + 1; j < this.creatures.length; j++) {
                const b = this.creatures[j];
                if (b.lifecycle !== "alive") continue;
                const dx = b.pos.x - a.pos.x;
                const dz = b.pos.z - a.pos.z;
                const d = Math.hypot(dx, dz) || 0.001;
                if (d >= minDist) continue;
                const push = (minDist - d) * 0.5;
                const n = { x: dx / d, z: dz / d };
                a.pos.x -= n.x * push;
                a.pos.z -= n.z * push;
                b.pos.x += n.x * push;
                b.pos.z += n.z * push;
            }
        }
        this.applyChunkCollisionToEntity(this.player, 10);
        for (const c of this.creatures) {
            if (c.lifecycle !== "alive") continue;
            this.applyChunkCollisionToEntity(c, c.modifiedStats?.size ?? 10);
        }
    }
    applyChunkCollisionToEntity(entity, radius = 8) {
        const cell = ChunkSystem.getCellAtWorld(this, entity.pos.x, entity.pos.z);
        if (cell?.blocked) {
            const dx = entity.pos.x - cell.x;
            const dz = entity.pos.z - cell.z;
            const n = norm2D(dx, dz);
            const pushDist = ChunkSystem.CELL_SIZE * 0.55 + radius;
            entity.pos.x =cell.x + n.x * pushDist;
            entity.pos.z =cell.z + n.z * pushDist;
        }
        const chunk = ChunkSystem.getChunkAtWorld(this, entity.pos.x, entity.pos.z);
        if (!chunk) return;
        for (const obstacle of chunk.obstacles) {
            if (!obstacle.blocksMovement) continue;
            const dx = entity.pos.x - obstacle.x;
            const dz = entity.pos.z - obstacle.z;
            const d = Math.hypot(dx, dz) || 0.001;
            const minD = radius + obstacle.radius;
            if (d >= minD) continue;
            const n = { x: dx / d, z: dz / d };
            entity.pos.x = obstacle.x + n.x * minD;
            entity.pos.z = obstacle.z + n.z * minD;
        }
        this.BS.applyBuildCollisionToEntity(entity, radius);
    }
    pushFloatingText(x, z, text, color = "#fff") {
        this.floatingTexts.push({ x, z, text, color, ttl: 0.9 });
    }
    grantInventoryRewards(rewards = [], opts = {}) {
        const out = [];
        const x = opts.x ?? null;
        const z = opts.z ?? null;
        const color = opts.color ?? "#ffffff";
        for (const r of rewards) {
            const chance = r.chance ?? 1;
            if (Math.random() > chance) continue;
            if (!r?.key || !r?.amount) continue;
            this.player.inventory[r.key] = (this.player.inventory[r.key] ?? 0) + r.amount;
            out.push({ key: r.key, amount: r.amount });
            if (x != null && z != null) this.pushFloatingText(x, z - 10, `+${r.amount} ${r.key}`, color);
        }
        return out;
    }
    updateFx(dt) {
        for (const fx of this.floatingTexts) {
            fx.ttl -= dt;
            fx.z -= 20 * dt;
        }
        this.floatingTexts = this.floatingTexts.filter(fx => fx.ttl > 0);
        for (const fx of this.combatFx) fx.ttl -= dt;
        this.combatFx = this.combatFx.filter(fx => fx.ttl > 0);
    }

    draw(ctx) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        // Chunk surface cells are the source of truth for terrain rendering.
        for (const chunk of this.chunks.values()) {
            for (const cell of chunk.cells) {
                const biome = biomeDefs[cell.dominantBiome] ?? biomeDefs.plains;
                const s = this.camera.worldToScreen(cell.x - ChunkSystem.CELL_SIZE * 0.5, cell.z - ChunkSystem.CELL_SIZE * 0.5);
                let color = biome.color;
                if (cell.terrainClass === "water") color = "#4e7fa8";
                else if (cell.terrainClass === "shore") color = "#8fae84";
                else if (cell.terrainClass === "rough") color = "#7a7a6e";
                else if (cell.terrainClass === "cliff") color = "#54545a";
                ctx.fillStyle = color;
                ctx.fillRect(
                    s.sx,
                    s.sz,
                    ChunkSystem.CELL_SIZE * this.camera.zoom + 1,
                    ChunkSystem.CELL_SIZE * this.camera.zoom + 1
                );
            }
            // Obstacles
            for (const obstacle of chunk.obstacles) {
                const s = this.camera.worldToScreen(obstacle.x, obstacle.z);
                ctx.fillStyle = obstacle.type === "tree" ? "#2f5f2f" : (obstacle.type === "crystal" ? "#7db7d8" : "#7c6758");
                ctx.beginPath();
                ctx.arc(s.sx, s.sz, obstacle.radius * this.camera.zoom, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = "rgba(0,0,0,0.45)";
                ctx.stroke();
            }
            // Debug: chunk border
            const cs = this.camera.worldToScreen(chunk.x0, chunk.z0);
            ctx.strokeStyle = "rgba(255,255,255,0.15)";
            ctx.lineWidth = 1;
            ctx.strokeRect(cs.sx, cs.sz, ChunkSystem.CHUNK_SIZE * this.camera.zoom, ChunkSystem.CHUNK_SIZE * this.camera.zoom);
        }
        const tl = this.camera.worldToScreen(0, 0);
        ctx.strokeStyle = "#3d4b36";
        ctx.lineWidth = 2;
        ctx.strokeRect(tl.sx, tl.sz, this.width * this.camera.zoom, this.height * this.camera.zoom);
        // Interactables.
        for (const node of this.nodes) {
            const def = nodeDefs[node.type];
            const s = this.camera.worldToScreen(node.pos.x, node.pos.z);
            ctx.globalAlpha = node.active ? 1 : 0.35;
            ctx.fillStyle = def.color;
            ctx.beginPath();
            ctx.arc(s.sx, s.sz, 6, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = 1;
        }
        for (const b of this.CM.barriers) {
            const s = this.camera.worldToScreen(b.pos.x, b.pos.z);
            ctx.fillStyle = b.color;
            ctx.beginPath();
            ctx.arc(s.sx, s.sz, b.radius * this.camera.zoom, 0, Math.PI * 2);
            ctx.fill();
            ctx.strokeStyle = "rgba(140,220,255,0.75)";
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(s.sx, s.sz, b.radius * this.camera.zoom, 0, Math.PI * 2);
            ctx.stroke();
        }
        this.BS.drawPlacedBuildables(ctx);
        this.BS.drawBuildPreview(ctx);
        const ps = this.camera.worldToScreen(this.player.pos.x, this.player.pos.z);
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(ps.sx, ps.sz, 7, 0, Math.PI * 2);
        ctx.fill();
        // Combat feedback lines/pulses.
        for (const fx of this.combatFx) {
            if (fx.type === "line") {
                const a = this.camera.worldToScreen(fx.x1, fx.z1);
                const b = this.camera.worldToScreen(fx.x2, fx.z2);
                ctx.strokeStyle = fx.color;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(a.sx, a.sz);
                ctx.lineTo(b.sx, b.sz);
                ctx.stroke();
            } else if (fx.type === "pulse") {
                const p = this.camera.worldToScreen(fx.x, fx.z);
                ctx.fillStyle = fx.color;
                ctx.beginPath();
                ctx.arc(p.sx, p.sz, fx.radius * this.camera.zoom, 0, Math.PI * 2);
                ctx.fill();
            }
        }
        for (const c of this.creatures) {
            const s = this.camera.worldToScreen(c.pos.x, c.pos.z);
            const isActive = c.id === this.player.activePetId;
            const isCommandTarget = c.id === this.player.commandTargetId;
            if (c.lifecycle === "captured" || c.lifecycle === "despawned") continue;
            if (c.lifecycle === "defeated") {
                ctx.strokeStyle = "#222";
                ctx.beginPath();
                ctx.moveTo(s.sx - 6, s.sz - 6);
                ctx.lineTo(s.sx + 6, s.sz + 6);
                ctx.moveTo(s.sx + 6, s.sz - 6);
                ctx.lineTo(s.sx - 6, s.sz + 6);
                ctx.stroke();
                continue;
            }
            ctx.fillStyle = c.team === 0 ? "#4a90d9" : "#d95c5c";
            ctx.beginPath();
            ctx.arc(s.sx, s.sz, 9, 0, Math.PI * 2);
            ctx.fill();
            if (c.hitFlash > 0) {
                ctx.strokeStyle = `rgba(255,255,255,${c.hitFlash})`;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(s.sx, s.sz, 12, 0, Math.PI * 2);
                ctx.stroke();
            }
            if (isActive) {
                ctx.strokeStyle = "#fff799";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(s.sx, s.sz, 13, 0, Math.PI * 2);
                ctx.stroke();
            }
            if (isCommandTarget) {
                ctx.strokeStyle = "#ffefef";
                ctx.lineWidth = 2;
                ctx.strokeRect(s.sx - 12, s.sz - 12, 24, 24);
            }
            if (c.command?.type === "attack" && c.command?.targetId) {
                const t = this.getCreatureById(c.command.targetId);
                if (t && t.lifecycle === "alive") {
                    const ts = this.camera.worldToScreen(t.pos.x, t.pos.z);
                    ctx.strokeStyle = "rgba(255,230,120,0.8)";
                    ctx.setLineDash([4, 3]);
                    ctx.beginPath();
                    ctx.moveTo(s.sx, s.sz);
                    ctx.lineTo(ts.sx, ts.sz);
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
            }
            if (c.isCasting()) {
                const cast = c.castState;
                const ability = abilities[cast.abilityKey];
                const total = Math.max(0.01, this.CM.getAbilityTiming(ability, c).castTime);
                const progress = 1 - clamp((cast.windupRemaining ?? 0) / total, 0, 1);
                ctx.fillStyle = "rgba(20,20,20,0.7)";
                ctx.fillRect(s.sx - 16, s.sz - 32, 32, 4);
                ctx.fillStyle = "#76d7ff";
                ctx.fillRect(s.sx - 16, s.sz - 32, 32 * progress, 4);
                ctx.fillStyle = "#c7ecff";
                ctx.font = "10px monospace";
                ctx.fillText(`CAST ${ability?.name ?? cast.abilityKey}`, s.sx - 24, s.sz - 36);
            } else if (c.isRecovering()) {
                const ratio = clamp(c.recoveryRemaining / 0.5, 0, 1);
                ctx.fillStyle = `rgba(255,180,110,${0.25 + ratio * 0.5})`;
                ctx.beginPath();
                ctx.arc(s.sx, s.sz, 14, 0, Math.PI * 2);
                ctx.stroke();
            }
            const hpRatio = c.currentHP / c.modifiedStats.maxHP;
            ctx.fillStyle = "#222";
            ctx.fillRect(s.sx - 16, s.sz - 20, 32, 4);
            ctx.fillStyle = hpRatio > 0.5 ? "#5ad15a" : hpRatio > 0.25 ? "#e7c04a" : "#df5a5a";
            ctx.fillRect(s.sx - 16, s.sz - 20, 32 * hpRatio, 4);
            if (c.team === 0) {
                ctx.fillStyle = "#fff";
                ctx.font = "10px monospace";
                ctx.fillText(`Lv${c.level}`, s.sx - 12, s.sz - 25);
            }
        }
        for (const fx of this.floatingTexts) {
            const s = this.camera.worldToScreen(fx.x, fx.z);
            ctx.fillStyle = fx.color;
            ctx.font = "12px monospace";
            ctx.fillText(fx.text, s.sx - 10, s.sz);
        }
        const biome = ChunkSystem.getCellAtWorld(this, this.player.pos.x, this.player.pos.z)?.dominantBiome
            ?? BiomeSystem.getBiomeAt(this.player.pos.x, this.player.pos.z).key;
        ctx.font = "12px monospace";
        // Left party panel.
        const partyX = 10;
        const partyY = 10;
        const partyW = 250;
        const slotH = 88;
        ctx.fillStyle = "rgba(0,0,0,0.58)";
        ctx.fillRect(partyX, partyY, partyW, slotH * 3 + 14);
        ctx.fillStyle = "#fff";
        ctx.fillText(`Party (${biome})`, partyX + 10, partyY + 18);
        for (let i = 0; i < 3; i++) {
            const slotY = partyY + 24 + i * slotH;
            const runtimeId = this.player.petIds[i];
            const c = this.getCreatureById(runtimeId);
            const isActiveSlot = i === this.player.activePetIndex;
            ctx.fillStyle = isActiveSlot ? "rgba(255,247,153,0.18)" : "rgba(255,255,255,0.06)";
            ctx.fillRect(partyX + 8, slotY, partyW - 16, slotH - 6);
            ctx.strokeStyle = isActiveSlot ? "#fff799" : "rgba(255,255,255,0.16)";
            ctx.strokeRect(partyX + 8, slotY, partyW - 16, slotH - 6);
            if (!c) {
                ctx.fillStyle = "#bbb";
                ctx.fillText(`${i + 1}. (empty)`, partyX + 16, slotY + 18);
                continue;
            }
            const isDefeated = c.lifecycle === "defeated"
            const hpRatio = c.currentHP / c.modifiedStats.maxHP;
            const stamRatio = c.currentStamina / c.modifiedStats.stamina;
            const enRatio = c.currentEnergy / c.modifiedStats.energy;
            const slotCmd = i === this.player.activePetIndex ? (c.command?.type ?? "none") : this.player.stance;
            ctx.fillStyle = isDefeated ? "#ff9a9a" : "#fff"
            ctx.fillText(`HP ${Math.round(c.currentHP)}/${Math.round(c.modifiedStats.maxHP)}`, partyX + 166, slotY + 18);
            if (c.lifecycle == "alive"){
                ctx.fillStyle = "#cbd8ff";
                ctx.fillText(`${i + 1}. ${species[c.speciesKey]?.name ?? c.speciesKey}  Lv${c.level}`, partyX + 16, slotY + 18);
                ctx.fillText(`Cmd/Stance: ${slotCmd}`, partyX + 16, slotY + 34);
            }else {
                ctx.fillText(`${i + 1}. ${species[c.speciesKey]?.name ?? c.speciesKey}  Lv${c.level}`, partyX + 16, slotY + 18);
                ctx.fillStyle = '#ffb3b3';
                ctx.fillText('DEFEATED', partyX + 16, slotY + 34);
            }
            drawGauge(ctx, partyX + 16, slotY + 42, partyW - 34, 8, hpRatio, "#62d55f");
            drawGauge(ctx, partyX + 16, slotY + 56, partyW - 34, 8, enRatio, "#55b9ff");
            drawGauge(ctx, partyX + 16, slotY + 70, partyW - 34, 8, stamRatio, "#ffe045");
        }
        // Right reserve panel.
        const reserveW = 250;
        const reserveX = canvas.width - reserveW - 10;
        const reserveY = 10;
        const reserveH = 286;
        ctx.fillStyle = "rgba(0,0,0,0.58)";
        ctx.fillRect(reserveX, reserveY, reserveW, reserveH);
        ctx.fillStyle = "#fff";
        ctx.fillText("Reserve ([ / ] select, T swap)", reserveX + 10, reserveY + 18);
        const selected = this.player.selectedReserveIndex;
        const maxRows = 8;
        const start = Math.max(0, Math.min(selected - Math.floor(maxRows / 2), Math.max(0, this.player.reserveOwnedIds.length - maxRows)));
        for (let row = 0; row < maxRows; row++) {
            const idx = start + row;
            if (idx >= this.player.reserveOwnedIds.length) break;
            const ownedId = this.player.reserveOwnedIds[idx];
            const owned = this.getOwnedCreatureById(ownedId);
            const y = reserveY + 28 + row * 31;
            const isSelected = idx === selected;
            ctx.fillStyle = isSelected ? "rgba(255,247,153,0.2)" : "rgba(255,255,255,0.06)";
            ctx.fillRect(reserveX + 8, y - 14, reserveW - 16, 24);
            ctx.fillStyle = isSelected ? "#fff799" : "#ddd";
            const reserveName = owned ? (species[owned.speciesKey]?.name ?? owned.speciesKey) : "unknown";
            ctx.fillText(`${idx + 1}. ${reserveName} Lv${owned?.level ?? "?"}`, reserveX + 14, y);
            ctx.fillStyle = "#9ec7ff";
            ctx.fillText(`${owned?.compositeKey ?? "none"}`, reserveX + reserveW - 90, y);
        }
        const selectedItemKey = this.player.selectedItemKey;
        const selectedItemDef = itemDefs[selectedItemKey];
        const selectedItemCount = this.player.inventory[selectedItemKey] ?? 0;
        const activePet = this.getCreatureById(this.player.activePetId);
        const castPanelW = 360;
        const castPanelH = 90;
        const castPanelX = canvas.width - castPanelW - 10;
        const castPanelY = canvas.height - castPanelH - 78;
        ctx.fillStyle = "rgba(0,0,0,0.62)";
        ctx.fillRect(castPanelX, castPanelY, castPanelW, castPanelH);
        ctx.fillStyle = "#fff";
        const castKeys = ["A", "S", "D", "F"];
        if (!activePet || activePet.lifecycle !== "alive") {
            ctx.fillStyle = "#bbb";
            ctx.fillText("No active pet", castPanelX + 10, castPanelY + 34);
        } else {
            for (let i = 0; i < 4; i++) {
                const abilityKey = activePet.moveset[i];
                const ability = abilities[abilityKey];
                const rowY = castPanelY + 34 + i * 24;
                if (!abilityKey || !ability) {
                    ctx.fillStyle = "#888";
                    ctx.fillText(`${castKeys[i]}: (empty)`, castPanelX + 10, rowY);
                    continue;
                }
                const cd = activePet.cooldowns[abilityKey] ?? 0;
                const hasStamina = (ability.resourceUse?.stamina ?? 0) <= activePet.currentStamina;
                const hasEnergy = (ability.resourceUse?.energy ?? 0) <= activePet.currentEnergy;
                const ready = cd <= 0 && hasStamina && hasEnergy && !activePet.isCasting() && !activePet.isRecovering() && activePet.globalCooldown <= 0;
                let status = "READY";
                if (cd > 0) status = `CD ${cd.toFixed(1)}s`;
                else if (activePet.isCasting()) status = "CASTING";
                else if (activePet.isRecovering()) status = `REC ${activePet.recoveryRemaining.toFixed(1)}s`;
                else if (activePet.globalCooldown > 0) status = `GCD ${activePet.globalCooldown.toFixed(1)}s`;
                else if (!hasStamina) status = "NO STAM";
                else if (!hasEnergy) status = "NO EN";
                ctx.fillStyle = ready ? "#8dff9d" : "#ffb3a1";
                ctx.fillText(`${castKeys[i]}: ${ability.name} - ${status}`, castPanelX + 10, rowY);            }
            if (activePet.isCasting()) {
                const cast = activePet.castState;
                const a = abilities[cast?.abilityKey];
                ctx.fillStyle = "#8fd5ff";
                ctx.fillText(`Now casting: ${a?.name ?? cast?.abilityKey} (${Math.max(0, cast?.windupRemaining ?? 0).toFixed(2)}s)`, castPanelX + 10, castPanelY + castPanelH - 24);
            } else if (activePet.isRecovering()) {
                ctx.fillStyle = "#ffd89d";
                ctx.fillText(`Recovering: ${activePet.recoveryRemaining.toFixed(2)}s  GCD: ${activePet.globalCooldown.toFixed(2)}s`, castPanelX + 10, castPanelY + castPanelH - 24);
            }
            if ((activePet.manualCastStatus?.until ?? 0) > this.time) {
                ctx.fillStyle = "#9ec7ff";
                ctx.fillText(activePet.manualCastStatus.text, castPanelX + 10, castPanelY + castPanelH - 8);
            }
            const buffNames = activePet.statusEffects
                .filter(st => st.type === "atkBoost" || st.type === "spdBoost" || st.type === "defBoost" || st.type === "boost")
                .map(st => `${st.type.replace("Boost", "").toUpperCase()} ${st.duration.toFixed(1)}s`);
            if (buffNames.length) {
                ctx.fillStyle = "#fff79a";
                ctx.fillText(`Buffs: ${buffNames.join(" | ")}`, castPanelX + 10, castPanelY - 8);
            }
        }
        const barH = 74;
        const barY = canvas.height - barH - 10;
        ctx.fillStyle = "rgba(0,0,0,0.62)";
        ctx.fillRect(10, barY, canvas.width - 20, barH);
        ctx.fillStyle = "#fff";
        ctx.fillText(`Controls: 1/2/3 pet  W/D + Arrows move(AUTO)  M mode  LMB target  RMB tool/move  A/S cast  [ / ] reserve  T swap  | ${this.player.lastLog}`, 18, barY + 46);
        ctx.fillText(
            `Mode: ${this.player.activeControlMode}  Item: ${selectedItemDef?.name ?? "none"} x${selectedItemCount}  Tool: ${this.player.selectedToolKey ?? "none"}  Build: ${this.player.toolMode}/${this.player.selectedBuildKey}`,
            18,
            barY + 20
        )
        const mats = this.player.materialsInventory;
        const selectedMorph = this.getSelectedMorphOptionForActive();
        const morphLabel = selectedMorph
            ? `${selectedMorph.option} (${selectedMorph.check.ok ? "ready" : selectedMorph.check.reason})`
            : "none";
        const activeOwned = this.getOwnedCreatureById(this.player.partyOwnedIds[this.player.activePetIndex]);
        const morphPts = this.getMorphPointsForOwned(activeOwned);
        ctx.fillText(`Materials: wood ${mats.wood ?? 0} | stone ${mats.stone ?? 0} | crystal ${mats.crystal_shard ?? 0} | metal ${mats.metal_scrap ?? 0}  MorphPts: ${morphPts}  Morph: ${morphLabel} [J/K select, P morph]`, 18, barY + 66);
    }
}
class PlayerInteractionSystem {
    constructor(world) {
        this.world = world;
        this.player = world.player
    }
    useSelectedItem(){
        const itemKey = this.player.selectedItemKey;
        if (!itemKey) return false;
        const def = itemDefs[itemKey];
        if (!def) return false;
        if (def.type === "bait") {
            return this.useItem(itemKey, "wildTarget")
        }
        return this.useItem(itemKey, "activePet")
    }
    useItem(itemKey, targetMode) {
        const def = itemDefs[itemKey];
        if (!def) return false;
        if ((this.player.inventory[itemKey] ?? 0) <= 0) return false;
        if (targetMode === "activePet") {
            const pet = this.world.getCreatureById(this.player.activePetId);
            if (!pet) return false;
            if (def.type === "revive") {
                if (pet.lifecycle !== "defeated") return false;
                pet.lifecycle = "alive"
                // Revive berries intentionally restore by ratio (50% from amount: 0.5).
                pet.currentHP = Math.max(1, Math.floor(pet.modifiedStats.maxHP*def.amount))
                pet.currentEnergy = Math.max(1, Math.floor(pet.modifiedStats.energy * 0.5))
                pet.currentStamina = Math.max(1, Math.floor(pet.modifiedStats.stamina * 0.5))
                EffectEngine.addStatus(pet, EffectEngine.createStatus("defBoost", 4.0, 0.75, pet.id));
                this.world.pushFloatingText(pet.pos.x, pet.pos.z - 16, `Revived`, "#ffe38e");
                this.player.inventory[itemKey] -= 1;
                return true;
            }
            if (pet.lifecycle !== "alive") return false;
            if (def.type === "heal") {
                pet.currentHP = Math.min(pet.modifiedStats.maxHP, pet.currentHP + def.amount);
                this.world.pushFloatingText(pet.pos.x, pet.pos.z - 16, `+${def.amount} HP`, "#8dff9d");
            }
            
            if (def.type === "energy") {
                pet.currentEnergy = Math.min(pet.modifiedStats.energy, pet.currentEnergy + def.amount);
                pet.currentStamina = Math.min(pet.modifiedStats.stamina, pet.currentStamina + (def.stamina ?? 0));
                this.world.pushFloatingText(pet.pos.x, pet.pos.z - 16, "+energy", "#9de7ff");
            }
            if (def.type === "buff") {
                const amt = def.amount ?? 0.1;
                const dur = def.duration ?? 8;
                EffectEngine.addStatus(pet, EffectEngine.createStatus("atkBoost", dur, amt, pet.id));
                EffectEngine.addStatus(pet, EffectEngine.createStatus("spdBoost", dur, amt * 0.8, pet.id));
                EffectEngine.addStatus(pet, EffectEngine.createStatus("defBoost", dur, amt * 0.7, pet.id));
                EffectEngine.addStatus(pet, EffectEngine.createStatus("boost", dur, amt * 0.5, pet.id));
                this.world.pushFloatingText(pet.pos.x, pet.pos.z - 16, "Boosted!", "#fff79a");
            }
            if (def.type === "bait") {
                this.player.lastLog = "Bait ready - use V on weakened wild";
            }
        }
        if (targetMode === "wildTarget") {
            const t = this.world.getCreatureById(this.player.commandTargetId);
            if (!t || t.team !== 1 || t.lifecycle !== "alive") return false;
            const activePet = this.world.getCreatureById(this.player.activePetId);
            // if (!activePet || dist(activePet.pos.x, activePet.pos.z, t.pos.x, t.pos.z) > 90) return false;
            if (!this.tryTameWild(t, def)) {
                t.command = { type: "attack", targetId: activePet.id, issuedAt: this.time };
                this.player.lastLog = "Capture failed! Wild enraged.";
            }
        }
        this.player.inventory[itemKey] -= 1;
        return true;
    }
    tryTameWild(wild, itemDef) {
        if (itemDef.type !== "bait") return false;
        const hpRatio = wild.currentHP / wild.modifiedStats.maxHP;
        if (hpRatio > (itemDef.requiredHPRatio ?? 0.5)) {
            this.player.lastLog = "Wild too healthy to tame";
            return false;
        }
        const chance = clamp((1 - hpRatio) * 0.45 + (itemDef.tameBonus ?? 0), 0.1, 0.85);
        if (Math.random() > chance) return false;
        wild.lifecycle = "captured";
        const owned = this.world.createOwnedCreatureRecord(wild.speciesKey, wild);
        const openSlot = this.world.getFirstOpenPartySlot();
        if (openSlot >= 0) {
            this.player.partyOwnedIds[openSlot] = owned.ownedId;
            this.world.hydratePartyRuntime();
            this.player.lastLog = `Tamed ${wild.speciesKey} into party`;
        } else {
            this.player.reserveOwnedIds.push(owned.ownedId);
            this.player.lastLog = `Tamed ${wild.speciesKey} -> reserve`;
        }
        this.world.pushFloatingText(wild.pos.x, wild.pos.z - 18, "Captured!", "#ffe38e");
        this.world.awardMorphPointsToOwned(owned.ownedId, 2, "capture");
        return true;
    }
    tryContextAction(worldPos = null, opts = {}) {
        const allowBuildAtCursor = opts.allowBuildAtCursor ?? false;
        const cursor = worldPos ?? this.player.pos;
        if (this.tryHarvestNearestCreature()) return true;
        if (this.tryInteractNearestNode(false, true)) return true;
        if (this.world.BS.tryStartGatherNearestObstacle(true)) return true;
        if (this.world.BS.tryHarvestNearestFarm(true)) return true;
        if (this.player.selectedToolKey === "hammer") {
            if (this.player.toolMode === "destroy") {
                if (this.world.BS.tryStartDestroyNearest(true)) return true;
            } else if (this.player.toolMode === "build" && allowBuildAtCursor) {
                if (this.world.BS.tryPlaceSelectedAt(cursor.x, cursor.z, true)) return true;
            }
        }
        this.player.lastLog = "No context action available";
        return false;
    }
    swapActiveWithReserve(reserveIndex) {
        const reserveOwnedId = this.player.reserveOwnedIds[reserveIndex];
        if (reserveOwnedId == null) return false;
        const slotIndex = this.player.activePetIndex;
        const activeOwnedId = this.player.partyOwnedIds[slotIndex];
        if (activeOwnedId == null) return false;
        this.player.reserveOwnedIds[reserveIndex] = activeOwnedId;
        this.player.partyOwnedIds[slotIndex] = reserveOwnedId;
        this.world.hydratePartyRuntime();
        const reserveData = this.world.getOwnedCreatureById(reserveOwnedId);
        this.player.lastLog = `Swapped in ${reserveData?.speciesKey ?? "pet"}`;
        return true;
    }
    tryInteractNearestNode(includeCreatureHarvest = true, silent = false) {
        if (includeCreatureHarvest && this.tryHarvestNearestCreature()) return true;
        let best = null;
        let bestD = Infinity;
        for (const n of this.world.nodes) {
            if (!n.active) continue;
            const d = dist(this.player.pos.x, this.player.pos.z, n.pos.x, n.pos.z);
            if (d < bestD && d <= 34) {
                bestD = d;
                best = n;
            }
        }
        if (!best) {
            if (!silent) this.player.lastLog = "No node nearby";
            return false;
        }
        const def = nodeDefs[best.type];
        if (!this.player.inventory[def.reward.key]) {
            this.player.itemBar.push(def.reward.key);
            this.player.inventory[def.reward.key] = 0;
        }
        this.player.inventory[def.reward.key] = (this.player.inventory[def.reward.key] ?? 0) + def.reward.amount;
        best.cooldown = def.cooldown;
        this.player.lastLog = `Gathered ${def.reward.key} x${def.reward.amount}`;
        this.world.pushFloatingText(best.pos.x, best.pos.z - 10, `+${def.reward.key}`, "#ffffff");
        return true;
    }
    tryHarvestNearestCreature() {
        let best = null;
        let bestD = Infinity;
        for (const c of this.world.creatures) {
            if (c.lifecycle !== "alive" || c.mode !== "wild") continue;
            if (!Array.isArray(c.harvestDrop) || c.harvestDrop.length <= 0) continue;
            const d = dist(this.player.pos.x, this.player.pos.z, c.pos.x, c.pos.z);
            if (d < bestD && d <= 34) {
                bestD = d;
                best = c;
            }
        }
        if (!best) return false;
        if (this.world.time < (best.nextHarvestAt ?? 0)) {
            const wait = Math.max(0, (best.nextHarvestAt ?? 0) - this.world.time);
            this.player.lastLog = `${best.speciesKey} can be harvested in ${wait.toFixed(1)}s`;
            return true;
        }
        const rewards = species[best.speciesKey]?.harvestDrop ?? best.harvestDrop ?? [];
        const granted = this.world.grantInventoryRewards(rewards, {
            x: best.pos.x,
            z: best.pos.z,
            color: "#d7fcb7",
        });
        if (granted.length <= 0) {
            this.player.lastLog = `${best.speciesKey} had nothing to harvest`;
            return true;
        }
        best.nextHarvestAt = this.world.time + Math.max(0, best.harvestCooldown ?? 0);
        const rewardText = granted.map(r => `${r.key} x${r.amount}`).join(", ");
        this.player.lastLog = `Harvested ${best.speciesKey}: ${rewardText}`;
        return true;
    }
    commandPets(petIds, command){
        for (const id of petIds){
            const pet = this.world.getCreatureById(id);
            if (!pet || pet.lifecycle !== "alive") continue;
            pet.command = {... command};
        }
    }
    commandActivePet(command) {
        const pet = this.world.getCreatureById(this.player.activePetId);
        if (!pet || pet.lifecycle !== "alive") return;
        pet.command = { ...command };
    }
    commandAllPets(command) {
        for (const id of this.player.petIds) {
            const pet = this.world.getCreatureById(id);
            if (!pet || pet.lifecycle !== "alive") continue;
            pet.command = { ...command };
        }
    }
}
class CombatManager {
    constructor(world) {
        this.world = world;
        this.player = world.player;
        this.barriers = []
    }
    resolveResistance(resistanceMap, damageTypes, fallbackKey) {
        const map = resistanceMap ?? {};
        const keys = (damageTypes && damageTypes.length > 0)
            ? damageTypes
            : [fallbackKey];
        let total = 0;
        for (const key of keys) total += map[key] ?? 1;
        return total / Math.max(1, keys.length);
    }
    isCreatureEngaged(creature) {
        for (const other of this.world.creatures) {
            if (other.id === creature.id || other.lifecycle !== "alive" || other.team === creature.team) continue;
            if (dist(creature.pos.x, creature.pos.z, other.pos.x, other.pos.z) < 160) return true;
        }
        return false;
    }
    evaluateAbilityUse(source, abilityKey, target) {
        const a = abilities[abilityKey];
        if (!a) return { ok: false, reason: "unknown ability" };
        if (!source || source.lifecycle !== "alive") return { ok: false, reason: "source invalid" };
        if (source.isCasting()) return { ok: false, reason: "already casting" };
        if (source.isRecovering()) return { ok: false, reason: "recovering" };
        if (source.globalCooldown > 0) return { ok: false, reason: `global cooldown ${source.globalCooldown.toFixed(1)}s` };
        if ((source.cooldowns[abilityKey] ?? 0) > 0) return { ok: false, reason: `cooldown ${source.cooldowns[abilityKey].toFixed(1)}s` };
        if ((a.resourceUse?.stamina ?? 0) > source.currentStamina) return { ok: false, reason: "not enough stamina" };
        if ((a.resourceUse?.energy ?? 0) > source.currentEnergy) return { ok: false, reason: "not enough energy" };
        if (a.category === "utility" || a.category === "barrier") return { ok: true, reason: "ready" };
        if (!target || target.lifecycle !== "alive") return { ok: false, reason: "no valid target" };
        if (source.team === target.team) return { ok: false, reason: "invalid target" };
        const d = dist(source.pos.x, source.pos.z, target.pos.x, target.pos.z);
        if (a.category === "dash" || a.category === "gap_close" || a.category === "retreat"){
            const dashReach = (a.dash?.distance ?? 70) + (a.range ?? 20);
            if (d > dashReach) return { ok: false, reason: "out of dash range" };
            return { ok: true, reason: "ready" };
        }
        if (d > (a.range ?? Infinity)) return { ok: false, reason: "out of range" };
        return { ok: true, reason: "ready" };
    }
    getAbilityTiming(abilityDef, source = null) {
        const defaultsByCategory = {
            melee: { castTime: 0.3, recovery: 0.2, gcd: 0.7 },
            hitscan: { castTime: 0.45, recovery: 0.25, gcd: 0.8 },
            projectile: { castTime: 0.5, recovery: 0.25, gcd: 0.85 },
            aoe: { castTime: 0.6, recovery: 0.35, gcd: 0.95 },
            barrier: { castTime: 0.65, recovery: 0.4, gcd: 1.0 },
            utility: { castTime: 0.5, recovery: 0.35, gcd: 0.9 },
            dash: { castTime: 0.25, recovery: 0.35, gcd: 0.8 },
            gap_close: { castTime: 0.25, recovery: 0.35, gcd: 0.8 },
            retreat: { castTime: 0.25, recovery: 0.4, gcd: 0.8 },
        };
        const category = abilityDef?.category ?? "melee";
        const defaults = defaultsByCategory[category] ?? defaultsByCategory.melee;
        const castSpd = Math.max(0.25, source?.modifiedStats?.castSpd ?? 1);
        return {
            castTime: (abilityDef?.castTime ?? defaults.castTime) / castSpd,
            recovery: (abilityDef?.recovery ?? defaults.recovery) / castSpd,
            gcd: (abilityDef?.gcd ?? defaults.gcd) / castSpd,
        };
    }
    queueManualCast(slotIndex) {
        const pet = this.world.getCreatureById(this.player.activePetId);
        if (!pet || pet.lifecycle !== "alive") return false;
        if (pet.isCasting()) {
            this.setManualCastStatus(pet, "Already casting");
            return false;
        }
        if (pet.isRecovering() || pet.globalCooldown > 0) {
            this.setManualCastStatus(pet, "Still recovering");
            return false;
        }
        const abilityKey = pet.moveset[slotIndex];
        if (!abilityKey) {
            this.setManualCastStatus(pet, `No move in slot ${slotIndex + 1}`);
            return false;
        }
        pet.manualCastRequest = { abilityKey, slotIndex, issuedAt: this.world.time };
        this.setManualCastStatus(pet, `Queued ${abilities[abilityKey]?.name ?? abilityKey}`);
        return true;
    }
    setManualCastStatus(creature, text, ttl = 1.2) {
        if (!creature) return;
        creature.manualCastStatus = { text, until: this.world.time + ttl };
        if (creature.team === 0 && creature.id === this.player.activePetId) this.player.lastLog = text;
    }
    beginAbilityCast(source, abilityKey, targetId, aimAt = null) {
        const a = abilities[abilityKey];
        const target = this.world.getCreatureById(targetId);
        const gate = this.evaluateAbilityUse(source, abilityKey, target);
        if (!gate.ok) return false;
        source.currentStamina -= a.resourceUse?.stamina ?? 0;
        source.currentEnergy -= a.resourceUse?.energy ?? 0;
        source.cooldowns[abilityKey] = a.cooldown;
        const timing = this.getAbilityTiming(a, source);
        source.globalCooldown = Math.max(source.globalCooldown, timing.gcd);
        source.castState = {
            abilityKey,
            targetId,
            windupRemaining: timing.castTime,
            recoveryRemaining: timing.recovery,
            executed: false,
            aimAt: aimAt ? { x: aimAt.x, z: aimAt.z } : null,
        };
        return true;
    }
    cancelAbilityCast(source, reason = "cancelled") {
        if (!source?.castState) return;
        source.castState = null;
        this.setManualCastStatus(source, reason, 0.7);
    }
    executeAbilityCast(source) {
        const cast = source.castState;
        if (!cast || cast.executed || source.lifecycle !== "alive") return false;
        const a = abilities[cast.abilityKey];
        if (!a) {
            this.cancelAbilityCast(source, "Cast failed: unknown");
            return false;
        }
        cast.executed = true;
        if (a.category === "utility") {
            EffectEngine.applyAbilityEffects(source, source, a);
            this.world.pushFloatingText(source.pos.x, source.pos.z - 10, a.name, "#88ffb5");
            return true;
        }
        if (a.category === "barrier") {
            const atX = source.pos.x;
            const atZ = source.pos.z;
            this.spawnBarrier(source, atX, atZ, a.barrier ?? {});
            this.world.pushFloatingText(atX, atZ - 12, a.name, "#9ed8ff");
            this.world.combatFx.push({ type: "pulse", x: atX, z: atZ, radius: a.barrier?.radius ?? 48, ttl: 0.22, color: a.fx?.pulseColor ?? "rgba(120,190,255,0.25)" });
            return true;
        }
        const target = this.world.getCreatureById(cast.targetId);
        if (!target || target.lifecycle !== "alive" || target.team === source.team) {
            this.setManualCastStatus(source, `${a.name} fizzled`, 0.9);
            return false;
        }
        const d = dist(source.pos.x, source.pos.z, target.pos.x, target.pos.z);
        if (a.category === "dash" || a.category === "gap_close" || a.category === "retreat") {
            const dashReach = (a.dash?.distance ?? 70) + (a.range ?? 20);
            if (d > dashReach) {
                this.setManualCastStatus(source, `${a.name} out of dash range`, 0.9);
                return false;
            }
            const dir = norm2D(target.pos.x - source.pos.x, target.pos.z - source.pos.z);
            const dashDist = a.dash?.distance ?? 70;
            const stopShort = a.dash?.stopShort ?? 16;
            const toward = a.category === "retreat" ? -1 : 1;
            const step = toward > 0 ? Math.max(0, Math.min(dashDist, d - stopShort)) : dashDist;
            source.pos.x = source.pos.x + dir.x * step * toward
            source.pos.z = source.pos.z + dir.z * step * toward
            this.world.combatFx.push({ type: "line", x1: source.pos.x - dir.x * step * toward, z1: source.pos.z - dir.z * step * toward, x2: source.pos.x, z2: source.pos.z, ttl: 0.1, color: a.fx?.lineColor ?? "#ffffff" });
        } else if (d > (a.range ?? Infinity)) {
            this.setManualCastStatus(source, `${a.name} out of range`, 0.9);
            return false;
        }
        const dmg =
            (a.flatDmg?.p ?? 0) +
            (a.flatDmg?.e ?? 0) +
            (a.dmgScale?.p ?? 0) * source.modifiedStats.pAtk +
            (a.dmgScale?.e ?? 0) * source.modifiedStats.eAtk;
        if (a.category === "aoe") {
            const radius = a.area?.radius ?? 30;
            for (const other of this.world.creatures) {
                if (other.team === source.team || other.lifecycle !== "alive") continue;
                if (dist(target.pos.x, target.pos.z, other.pos.x, other.pos.z) > radius) continue;
                this.applyDamagePacket(source, other, dmg * 0.9, a);
            }
            this.world.combatFx.push({ type: "pulse", x: target.pos.x, z: target.pos.z, radius, ttl: 0.2, color: a.fx?.pulseColor ?? "rgba(255,255,255,0.4)" });
            return true;
        }
        this.applyDamagePacket(source, target, dmg, a);
        if (a.fx?.lineColor) this.world.combatFx.push({ type: "line", x1: source.pos.x, z1: source.pos.z, x2: target.pos.x, z2: target.pos.z, ttl: 0.12, color: a.fx.lineColor });
        return true;
    }
    tickAbilityCast(source, dt) {
        if (!source?.castState) return;
        if (source.lifecycle !== "alive") {
            this.cancelAbilityCast(source, "Cast interrupted");
            return;
        }
        const cast = source.castState;
        cast.windupRemaining = Math.max(0, cast.windupRemaining - dt);
        if (!cast.executed && cast.windupRemaining <= 0) {
            this.executeAbilityCast(source);
        }
        if (cast.executed) {
            cast.recoveryRemaining = Math.max(0, cast.recoveryRemaining - dt);
            source.recoveryRemaining = Math.max(source.recoveryRemaining, cast.recoveryRemaining);
            if (cast.recoveryRemaining <= 0) source.castState = null;
        }
    }
    tryUseAbility(source, abilityKey, targetId, aimAt = null) {
        return this.beginAbilityCast(source, abilityKey, targetId, aimAt);
    }
    applyDamagePacket(source, target, dmg, abilityDef) {
        const effBonus = EffectEngine.applyAbilityEffects(source, target, abilityDef);
        const composite = composites[target.compositeKey] ?? composites.animal;
        const resistances = composite.resistances ?? DEFAULT_RESISTANCES;
        const profile = abilityDef?.damageProfile ?? {};
        const physicalPart = (abilityDef.flatDmg?.p ?? 0) + (abilityDef.dmgScale?.p ?? 0) * source.modifiedStats.pAtk;
        const energyPart = (abilityDef.flatDmg?.e ?? 0) + (abilityDef.dmgScale?.e ?? 0) * source.modifiedStats.eAtk;
        const physicalMod = this.resolveResistance(resistances.physical, profile.physical, "impact");
        const energyMod = this.resolveResistance(resistances.energy, profile.energy, "electric");
        const scaled = (physicalPart * physicalMod + energyPart * energyMod) * effBonus;
        // Keep a minimum 1 damage floor so very low scaling attacks still provide gameplay feedback.
        const atkScaled = (scaled || dmg) * (source.runtimeAtkMult ?? 1);
        const reduced = atkScaled * (1 - (target.runtimeDmgReduction ?? 0));
        const finalDmg = Math.max(1, reduced);
        target.currentHP = Math.max(0, target.currentHP - finalDmg);
        target.hitFlash = 1;
        target.combatContributors.set(source.id, this.world.time);
        this.world.pushFloatingText(target.pos.x, target.pos.z - 12, `${Math.round(finalDmg)}`, "#ffd7d7");
        if (target.currentHP <= 0) {
            target.lifecycle = "defeated";
        }
    }
    cleanupDefeatedCreatures() {
        for (const c of this.world.creatures) {
            if (c.lifecycle !== "defeated" || c._deathHandled) continue;
            c._deathHandled = true;
            this.world.pushFloatingText(c.pos.x, c.pos.z, "KO", "#ff8a8a");
            this.handleCreatureDefeat(c);
        }
    }
    handleCreatureDefeat(dead) {
        if (dead.team === 0) return;
        const defeatDrop = species[dead.speciesKey]?.drop ?? dead.drop ?? [];
        const grantedDrop = this.world.grantInventoryRewards(defeatDrop, {
            x: dead.pos.x,
            z: dead.pos.z,
            color: "#ffe8b3",
        });
        if (grantedDrop.length > 0) {
            const dropText = grantedDrop.map(d => `${d.key} x${d.amount}`).join(", ");
            this.player.lastLog = `Looted ${dropText}`;
        }
        const contributors = [];
        for (const [id, t] of dead.combatContributors.entries()) {
            if (this.world.time - t > 14) continue;
            const c = this.world.getCreatureById(id);
            if (c && c.lifecycle === "alive" && c.team === 0) contributors.push(c);
        }
        let averageLevel = 0
        // XP loop: nearby allies get a small share.
        for (const pid of this.player.petIds) {
            const pet = this.world.getCreatureById(pid);
            if (pet) averageLevel += pet.level;
            if (!pet || pet.lifecycle !== "alive") continue;
            if (!contributors.includes(pet) && dist(pet.pos.x, pet.pos.z, dead.pos.x, dead.pos.z) < 140) contributors.push(pet);
        }
        if (contributors.length > 0) {
            averageLevel /= contributors.length;
        }
        const scale = clamp(1 + (dead.level - averageLevel) * 0.12, 0.75, 1.25);
        const adjustedXP = Math.round((dead.level * 12 + 50) * scale);
        for (const pet of contributors) {
            const events = pet.addXP(adjustedXP);
            this.world.syncOwnedCreatureFromRuntime(pet);
            if (pet.ownedId != null) {
                const gainedMorphPoints = Math.max(1, Math.floor(adjustedXP / 80));
                this.world.awardMorphPointsToOwned(pet.ownedId, gainedMorphPoints, "defeat");
            }
            for (const ev of events) {
                if (ev.type === "leveledUp") this.world.pushFloatingText(pet.pos.x, pet.pos.z - 14, `Lv Up! ${ev.newLevel}`, "#fff799");
            }
        }
    }
    spawnBarrier(source, x, z, barrierDef) {
        const zone = new BarrierZone(
            x,
            z,
            source.team,
            barrierDef.radius ?? 48,
            barrierDef.duration ?? 4.5,
            {
                slow: barrierDef.slow ?? 0.2,
                damageReduction: barrierDef.damageReduction ?? 0.18,
                blockMovement: barrierDef.blockMovement ?? true,
                color: "rgba(120,190,255,0.20)",
            }
        );
        this.barriers.push(zone);
    }
    updateBarriers(dt) {
        for (const b of this.barriers) {
            b.ttl -= dt;
            for (const c of this.world.creatures) {
                if (c.lifecycle !== "alive") continue;
                const d = dist(c.pos.x, c.pos.z, b.pos.x, b.pos.z);
                if (d > b.radius) continue;
                if (c.team === b.team) {
                    EffectEngine.addStatus(c, EffectEngine.createStatus("defBoost", 0.25, b.damageReduction, null));
                } else {
                    EffectEngine.addStatus(c, EffectEngine.createStatus("slow", 0.25, b.slow, null));
                    if (b.blockMovement) {
                        const n = norm2D(c.pos.x - b.pos.x, c.pos.z - b.pos.z);
                        const edge = b.radius + 2;
                        c.pos.x = b.pos.x + n.x * edge;
                        c.pos.z = b.pos.z + n.z * edge;
                    }
                }
            }
        }
        this.barriers = this.barriers.filter(b => b.ttl > 0);
    }
}
class BuildSystem {
    constructor(world) {
        this.world = world;
        this.destroyAction = null;
        this.harvestAction = null;
        this.gatherAction = null;
        this.preview = { x: world.player.pos.x, z: world.player.pos.z };
    }
    cycleSelectedTool(dir = 1) {
        const player = this.world.player;
        player.cycleTool(dir);
        const tool = toolDefs[player.selectedToolKey];
        if (tool?.modes?.length && !tool.modes.includes(player.toolMode)) {
            player.toolMode = tool.modes[0];
        }
        player.lastLog = `Tool: ${player.selectedToolKey}`;
    }
    cycleToolMode(dir = 1) {
        const player = this.world.player;
        const tool = toolDefs[player.selectedToolKey];
        if (!tool?.modes?.length) return;
        const idx = Math.max(0, tool.modes.indexOf(player.toolMode));
        player.toolMode = tool.modes[(idx + dir + tool.modes.length) % tool.modes.length];
        player.lastLog = `Tool mode: ${player.toolMode}`;
    }
    cycleBuildType(dir = 1) {
        const player = this.world.player;
        const tool = toolDefs[player.selectedToolKey];
        const builds = tool?.buildTypes ?? [];
        if (!builds.length) return;
        const idx = Math.max(0, builds.indexOf(player.selectedBuildKey));
        player.selectedBuildKey = builds[(idx + dir + builds.length) % builds.length];
        player.lastLog = `Build type: ${player.selectedBuildKey}`;
    }
    getToolRange() {
        const tool = toolDefs[this.world.player.selectedToolKey];
        return tool?.range ?? 0;
    }
    isHammerActionAllowed(mode) {
        const player = this.world.player;
        const tool = toolDefs[player.selectedToolKey];
        return player.selectedToolKey === "hammer" && tool?.modes?.includes(mode);
    }
    getBuildDef(buildKey) {
        return placeableDefs[buildKey] ?? null;
    }
    canAffordMaterialCost(cost = []) {
        const inv = this.world.player.materialsInventory;
        for (const c of cost) {
            if ((inv[c.key] ?? 0) < c.amount) return false;
        }
        return true;
    }
    consumeBuildCost(cost = []) {
        if (!this.canAffordMaterialCost(cost)) return false;
        const inv = this.world.player.materialsInventory;
        for (const c of cost) inv[c.key] = (inv[c.key] ?? 0) - c.amount;
        return true;
    }
    grantMaterials(rewards = []) {
        const inv = this.world.player.materialsInventory;
        for (const r of rewards) {
            const chance = r.chance ?? 1;
            if (Math.random() > chance) continue;
            inv[r.key] = (inv[r.key] ?? 0) + r.amount;
        }
    }
    grantItems(rewards = []) {
        const player = this.world.player;
        for (const r of rewards) {
            if (!player.itemBar.includes(r.key)) player.itemBar.push(r.key);
            player.inventory[r.key] = (player.inventory[r.key] ?? 0) + r.amount;
        }
    }
    getPlacementRadius(def) {
        return def?.placementRadius ?? def?.radius ?? 10;
    }
    createBuildRecord(type, x, z) {
        const def = this.getBuildDef(type);
        const radius = this.getPlacementRadius(def);
        return {
            id: this.world.nextBuildId++,
            type,
            kind: def.kind,
            x,
            z,
            radius,
            hp: def.maxHP,
            maxHP: def.maxHP,
            blocksMovement: !!def.blocksMovement,
            placedAt: this.world.time,
            provides: def.provides ? { ...def.provides } : null,
            farmState: def.kind === "farm" ? "planted" : null,
            plantedTimer: def.kind === "farm" ? 1.0 : 0,
            growTimer: def.kind === "farm" ? (def.growTime ?? 0) : 0,
            destroyProgress: 0,
        };
    }
    addBuildable(buildable) {
        this.world.buildablesById.set(buildable.id, buildable);
        this.indexBuildableToChunk(buildable);
    }
    removeBuildable(buildId) {
        const b = this.world.buildablesById.get(buildId);
        if (!b) return null;
        this.unindexBuildableFromChunk(b);
        this.world.buildablesById.delete(buildId);
        return b;
    }
    indexBuildableToChunk(buildable) {
        const { cx, cz } = ChunkSystem.worldToChunk(buildable.x, buildable.z);
        const chunkKey = ChunkSystem.key(cx, cz);
        if (!this.world.buildableIdsByChunk.has(chunkKey)) this.world.buildableIdsByChunk.set(chunkKey, new Set());
        this.world.buildableIdsByChunk.get(chunkKey).add(buildable.id);
        buildable.chunkKey = chunkKey;
    }
    unindexBuildableFromChunk(buildable) {
        if (!buildable.chunkKey) return;
        const set = this.world.buildableIdsByChunk.get(buildable.chunkKey);
        if (!set) return;
        set.delete(buildable.id);
        if (set.size <= 0) this.world.buildableIdsByChunk.delete(buildable.chunkKey);
    }
    getBuildablesInChunk(cx, cz) {
        const key = ChunkSystem.key(cx, cz);
        const ids = this.world.buildableIdsByChunk.get(key);
        if (!ids) return [];
        const out = [];
        for (const id of ids) {
            const b = this.world.buildablesById.get(id);
            if (b) out.push(b);
        }
        return out;
    }
    getBuildablesNear(x, z, range = 0) {
        const chunkRadius = Math.max(0, Math.ceil((range + 20) / ChunkSystem.CHUNK_SIZE));
        const { cx, cz } = ChunkSystem.worldToChunk(x, z);
        const out = [];
        for (let dz = -chunkRadius; dz <= chunkRadius; dz++) {
            for (let dx = -chunkRadius; dx <= chunkRadius; dx++) {
                const list = this.getBuildablesInChunk(cx + dx, cz + dz);
                for (const b of list) out.push(b);
            }
        }
        return out;
    }
    canPlaceAt(type, x, z) {
        const def = this.getBuildDef(type);
        if (!def) return { ok: false, reason: "Unknown build type" };
        const radius = this.getPlacementRadius(def);
        const cell = ChunkSystem.getCellAtWorld(this.world, x, z);
        if (!cell) return { ok: false, reason: "Chunk not loaded" };
        if (cell.blocked || cell.water || cell.terrainClass === "cliff") return { ok: false, reason: "Blocked terrain" };
        const toolRange = this.getToolRange();
        const player = this.world.player;
        if (dist(player.pos.x, player.pos.z, x, z) > toolRange) return { ok: false, reason: "Out of tool range" };
        if (!this.canAffordMaterialCost(def.buildCost ?? [])) return { ok: false, reason: "Missing materials" };
        const chunk = ChunkSystem.getChunkAtWorld(this.world, x, z);
        for (const o of chunk?.obstacles ?? []) {
            if (dist(x, z, o.x, o.z) < radius + (o.radius ?? 8)) return { ok: false, reason: "Overlaps obstacle" };
        }
        for (const node of this.world.nodes) {
            if (dist(x, z, node.pos.x, node.pos.z) < radius + 10) return { ok: false, reason: "Overlaps node" };
        }
        for (const c of this.world.creatures) {
            if (c.lifecycle !== "alive") continue;
            const creatureRadius = c.modifiedStats?.size ?? 10;
            if (dist(x, z, c.pos.x, c.pos.z) < radius + creatureRadius) return { ok: false, reason: "Overlaps creature" };
        }
        for (const b of this.getBuildablesNear(x, z, radius + 22)) {
            if (dist(x, z, b.x, b.z) < radius + b.radius) return { ok: false, reason: "Overlaps buildable" };
        }
        return { ok: true, reason: "ok" };
    }
    tryPlaceSelectedAt(x, z, silent = false) {
        if (!this.isHammerActionAllowed("build")) return false;
        const buildKey = this.world.player.selectedBuildKey;
        const check = this.canPlaceAt(buildKey, x, z);
        if (!check.ok) {
            if (!silent) this.world.player.lastLog = `Cannot place: ${check.reason}`;
            return false;
        }
        const def = this.getBuildDef(buildKey);
        if (!this.consumeBuildCost(def.buildCost ?? [])) {
            if (!silent) this.world.player.lastLog = "Cannot place: Missing materials";
            return false;
        }
        const record = this.createBuildRecord(buildKey, x, z);
        this.addBuildable(record);
        this.world.player.lastLog = `Placed ${buildKey}`;
        return true;
    }
    findNearestBuildableInRange(x, z, maxRange, filterFn = null) {
        let best = null;
        let bestD = Infinity;
        for (const b of this.getBuildablesNear(x, z, maxRange)) {
            const d = dist(x, z, b.x, b.z);
            if (d > maxRange || d >= bestD) continue;
            if (filterFn && !filterFn(b)) continue;
            best = b;
            bestD = d;
        }
        return best;
    }
    tryStartDestroyNearest(silent = false) {
        if (!this.isHammerActionAllowed("destroy")) return false;
        const player = this.world.player;
        const nearest = this.findNearestBuildableInRange(player.pos.x, player.pos.z, this.getToolRange());
        if (!nearest) {
            if (!silent) player.lastLog = "No buildable in range";
            return false;
        }
        this.destroyAction = { targetId: nearest.id, progress: 0 };
        player.lastLog = `Destroying ${nearest.type}`;
        return true;
    }
    updateDestroyAction(dt) {
        if (!this.destroyAction) return;
        if (!this.isHammerActionAllowed("destroy")) {
            this.destroyAction = null;
            return;
        }
        const player = this.world.player;
        const target = this.world.buildablesById.get(this.destroyAction.targetId);
        if (!target) {
            this.destroyAction = null;
            return;
        }
        if (dist(player.pos.x, player.pos.z, target.x, target.z) > this.getToolRange() + 2) {
            this.destroyAction = null;
            player.lastLog = "Destroy cancelled: Out of range";
            return;
        }
        const def = this.getBuildDef(target.type);
        const destroyTime = Math.max(0.1, def?.destroyTime ?? 2);
        this.destroyAction.progress += dt;
        target.destroyProgress = this.destroyAction.progress / destroyTime;
        if (this.destroyAction.progress < destroyTime) return;
        const removed = this.removeBuildable(target.id);
        if (removed) {
            this.tryGrantDestroyRefund(def);
            this.world.pushFloatingText(removed.x, removed.z - 12, "Destroyed", "#ffb3a1");
            player.lastLog = `Destroyed ${removed.type}`;
        }
        this.destroyAction = null;
    }
    tryGrantDestroyRefund(def) {
        const refunds = def?.destroyRefund ?? [];
        this.grantMaterials(refunds);
    }
    findNearestObstacleInRange(x, z, maxRange) {
        const chunk = ChunkSystem.getChunkAtWorld(this.world, x, z);
        if (!chunk) return null;
        let best = null;
        let bestD = Infinity;
        for (const o of chunk.obstacles ?? []) {
            if (!obstacleHarvestDefs[o.type]) continue;
            const d = dist(x, z, o.x, o.z);
            if (d > maxRange || d >= bestD) continue;
            best = o;
            bestD = d;
        }
        return best;
    }
    tryStartGatherNearestObstacle(silent = false) {
        const player = this.world.player;
        const tool = toolDefs[player.selectedToolKey];
        if (!tool?.canGather) return false;
        const target = this.findNearestObstacleInRange(player.pos.x, player.pos.z, this.getToolRange());
        if (!target) {
            if (!silent) player.lastLog = "No obstacle to gather";
            return false;
        }
        this.gatherAction = { chunkKey: target.chunkKey, obstacleId: target.id, progress: 0 };
        player.lastLog = `Gathering ${target.type}`;
        return true;
    }
    getObstacleByAction(action) {
        const chunk = this.world.chunks.get(action.chunkKey);
        if (!chunk) return null;
        const obstacle = chunk.obstacles.find(o => o.id === action.obstacleId);
        if (!obstacle) return null;
        return { chunk, obstacle };
    }
    updateGatherAction(dt) {
        if (!this.gatherAction) return;
        const player = this.world.player;
        const tool = toolDefs[player.selectedToolKey];
        if (!tool?.canGather) {
            this.gatherAction = null;
            return;
        }
        const hit = this.getObstacleByAction(this.gatherAction);
        if (!hit) {
            this.gatherAction = null;
            return;
        }
        const { chunk, obstacle } = hit;
        if (dist(player.pos.x, player.pos.z, obstacle.x, obstacle.z) > this.getToolRange() + 2) {
            player.lastLog = "Gather cancelled: Out of range";
            this.gatherAction = null;
            return;
        }
        const gatherDef = obstacleHarvestDefs[obstacle.type];
        const gatherTime = Math.max(0.1, gatherDef?.gatherTime ?? tool.gatherTime ?? 1.5);
        this.gatherAction.progress += dt;
        if (this.gatherAction.progress < gatherTime) return;
        this.grantMaterials(gatherDef?.rewards ?? []);
        const idx = chunk.obstacles.findIndex(o => o.id === obstacle.id);
        if (idx >= 0) chunk.obstacles.splice(idx, 1);
        this.world.harvestedObstacleIds.add(obstacle.id);
        this.world.pushFloatingText(obstacle.x, obstacle.z - 10, "+materials", "#d4ffc1");
        player.lastLog = `Gathered ${obstacle.type}`;
        this.gatherAction = null;
    }
    tryHarvestNearestFarm(silent = false) {
        const player = this.world.player;
        const nearest = this.findNearestBuildableInRange(
            player.pos.x,
            player.pos.z,
            this.getToolRange(),
            (b) => b.kind === "farm" && b.farmState === "mature"
        );
        if (!nearest) {
            if (!silent) player.lastLog = "No mature farm in range";
            return false;
        }
        this.harvestAction = { targetId: nearest.id, progress: 0 };
        player.lastLog = `Harvesting ${nearest.type}`;
        return true;
    }
    updateHarvestAction(dt) {
        if (!this.harvestAction) return;
        const farm = this.world.buildablesById.get(this.harvestAction.targetId);
        if (!farm || farm.kind !== "farm") {
            this.harvestAction = null;
            return;
        }
        const player = this.world.player;
        if (dist(player.pos.x, player.pos.z, farm.x, farm.z) > this.getToolRange() + 2) {
            this.harvestAction = null;
            player.lastLog = "Harvest cancelled: Out of range";
            return;
        }
        if (farm.farmState !== "mature") {
            this.harvestAction = null;
            return;
        }
        const def = this.getBuildDef(farm.type);
        const harvestTime = Math.max(0.1, def?.harvestTime ?? 1);
        this.harvestAction.progress += dt;
        if (this.harvestAction.progress < harvestTime) return;
        this.harvestFarm(farm, def);
        this.harvestAction = null;
    }
    harvestFarm(farm, def) {
        this.grantItems(def?.rewards ?? []);
        farm.farmState = "planted";
        farm.plantedTimer = 1.0;
        farm.growTimer = def?.growTime ?? 0;
        this.world.pushFloatingText(farm.x, farm.z - 10, "Harvested", "#9dffb0");
        this.world.player.lastLog = `Harvested ${farm.type}`;
    }
    updateFarmGrowth(dt) {
        for (const b of this.world.buildablesById.values()) {
            if (b.kind !== "farm") continue;
            if (b.farmState === "planted") {
                b.plantedTimer = Math.max(0, b.plantedTimer - dt);
                if (b.plantedTimer <= 0) b.farmState = "growing";
                continue;
            }
            if (b.farmState !== "growing") continue;
            b.growTimer = Math.max(0, b.growTimer - dt);
            if (b.growTimer <= 0) b.farmState = "mature";
        }
    }
    applyBuildCollisionToEntity(entity, radius = 8) {
        for (const b of this.getBuildablesNear(entity.pos.x, entity.pos.z, radius + 40)) {
            if (!b.blocksMovement) continue;
            const dx = entity.pos.x - b.x;
            const dz = entity.pos.z - b.z;
            const d = Math.hypot(dx, dz) || 0.001;
            const minD = radius + b.radius;
            if (d >= minD) continue;
            const n = { x: dx / d, z: dz / d };
            entity.pos.x = b.x + n.x * minD;
            entity.pos.z = b.z + n.z * minD;
        }
    }
    drawPlacedBuildables(ctx) {
        for (const b of this.world.buildablesById.values()) {
            const def = this.getBuildDef(b.type);
            const s = this.world.camera.worldToScreen(b.x, b.z);
            let fill = def?.color ?? "#888";
            if (b.kind === "farm" && b.farmState === "planted") fill = "rgba(120,120,95,0.95)";
            if (b.kind === "farm" && b.farmState === "growing") fill = "rgba(120,160,120,0.95)";
            if (b.kind === "farm" && b.farmState === "mature") fill = def?.color ?? "#88c070";
            ctx.fillStyle = fill;
            ctx.beginPath();
            ctx.arc(s.sx, s.sz, b.radius * this.world.camera.zoom, 0, Math.PI * 2);
            ctx.fill();
            ctx.strokeStyle = "rgba(0,0,0,0.45)";
            ctx.stroke();
            if (b.kind === "farm") {
                ctx.fillStyle = "#fff";
                ctx.font = "10px monospace";
                const label = b.farmState === "mature"
                    ? "READY"
                    : (b.farmState === "planted" ? "PLANTED" : `${Math.ceil(b.growTimer)}s`);
                ctx.fillText(label, s.sx - 16, s.sz - b.radius * this.world.camera.zoom - 6);
            }
            if (b.destroyProgress > 0) {
                const ratio = clamp(b.destroyProgress, 0, 1);
                ctx.fillStyle = "rgba(30,30,30,0.75)";
                ctx.fillRect(s.sx - 16, s.sz + b.radius * this.world.camera.zoom + 4, 32, 4);
                ctx.fillStyle = "#ff926b";
                ctx.fillRect(s.sx - 16, s.sz + b.radius * this.world.camera.zoom + 4, 32 * ratio, 4);
            }
        }
    }
    drawBuildPreview(ctx) {
        const player = this.world.player;
        if (!this.isHammerActionAllowed("build")) return;
        const def = this.getBuildDef(player.selectedBuildKey);
        if (!def) return;
        const check = this.canPlaceAt(player.selectedBuildKey, this.preview.x, this.preview.z);
        const s = this.world.camera.worldToScreen(this.preview.x, this.preview.z);
        const radius = this.getPlacementRadius(def) * this.world.camera.zoom;
        ctx.globalAlpha = 0.45;
        ctx.fillStyle = check.ok ? "#66ff88" : "#ff6767";
        ctx.beginPath();
        ctx.arc(s.sx, s.sz, radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;
        ctx.strokeStyle = check.ok ? "#9effb4" : "#ff9c9c";
        ctx.stroke();
        ctx.fillStyle = "#fff";
        ctx.font = "11px monospace";
        ctx.fillText(player.selectedBuildKey, s.sx - 30, s.sz - radius - 8);
    }
    update(dt, input) {
        const mouseWorld = this.world.camera.screenToWorld(input.mouse.x, input.mouse.y);
        this.preview.x = mouseWorld.x;
        this.preview.z = mouseWorld.z;
        this.updateFarmGrowth(dt);
        this.updateDestroyAction(dt);
        this.updateHarvestAction(dt);
        this.updateGatherAction(dt);
    }
}
/* =========================
   game
========================= */
class Game {
    constructor() {
        this.input = new InputManager();
        this.sceneManager = new SceneManager(
            {
                introScene: new IntroScene(),
                mainScene: new MainScene(),
            },
            "introScene"
        );
        this.last = 0;
    }
    start() {
        this.input.bind(canvas);
        requestAnimationFrame((ts) => this.loop(ts));
    }
    loop(ts) {
        const dt = this.last ? Math.min((ts - this.last) / 1000, 0.05) : 0.016;
        this.last = ts;
        this.sceneManager.update(dt, this.input);
        this.sceneManager.draw(ctx);
        this.input.endFrame();
        requestAnimationFrame((next) => this.loop(next));
    }
}
class SceneManager {
    constructor(defs, startId) {
        this.defs = defs;
        this.id = null;
        this.scene = null;
        this.t = 0;
        this.state = {};
        this._events = [];
        this.set(startId);
    }
    set(id, payload = {}) {
        if (this.scene?.onExit) this.scene.onExit(this, payload);
        this.id = id;
        this.scene = this.defs[id];
        this.t = 0;
        this.state = {};
        this._events = [];
        if (!this.scene) throw new Error(`Unknown scene: ${id}`);
        if (this.scene.onEnter) this.scene.onEnter(this, payload);
    }
    update(dt, input) {
        this.t += dt;
        for (const ev of this._events) {
            if (!ev.fired && this.t >= ev.t) {
                ev.fired = true;
                ev.fn(this);
            }
        }
        if (this.scene?.update) this.scene.update(this, dt, input);
    }
    draw(ctx) {
        if (this.scene?.draw) this.scene.draw(this, ctx);
    }
}
class IntroScene {
    constructor() {
        this.starterKeys = ["dog", "sparkit", "cinderpup"];
        this.selectedIndex = 0;
    }
    onEnter(sm) {
        this.selectedIndex = 0;
    }
    update(sm, dt, input) {
        if (input.consumePress("ArrowLeft") || input.consumePress("KeyA")) this.selectedIndex = (this.selectedIndex + this.starterKeys.length - 1) % this.starterKeys.length;
        if (input.consumePress("ArrowRight") || input.consumePress("KeyD")) this.selectedIndex = (this.selectedIndex + 1) % this.starterKeys.length;
        if (input.consumePress("ArrowUp")) this.selectedIndex = (this.selectedIndex + this.starterKeys.length - 1) % this.starterKeys.length;
        if (input.consumePress("ArrowDown")) this.selectedIndex = (this.selectedIndex + 1) % this.starterKeys.length;
        if (input.consumePress("Digit1")) this.selectedIndex = 0;
        if (input.consumePress("Digit2")) this.selectedIndex = 1;
        if (input.consumePress("Digit3")) this.selectedIndex = 2;
        if (input.consumePress("Enter") || input.consumePress("Space")) {
            sm.set("mainScene", { starterKey: this.starterKeys[this.selectedIndex] });
        }
    }
    draw(sm, ctx) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = "#111";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = "#fff";
        ctx.font = "24px monospace";
        ctx.fillText("Choose Your Starter", 40, 54);
        ctx.font = "14px monospace";
        ctx.fillText("Arrow keys / A-D to move, Enter or Space to confirm", 40, 82);
        const cardW = 250;
        const cardH = 210;
        const gap = 20;
        const totalW = cardW * this.starterKeys.length + gap * (this.starterKeys.length - 1);
        const startX = Math.floor((canvas.width - totalW) / 2);
        const y = 130;
        for (let i = 0; i < this.starterKeys.length; i++) {
            const key = this.starterKeys[i];
            const def = species[key];
            const s = def?.baseStats ?? {};
            const x = startX + i * (cardW + gap);
            const selected = i === this.selectedIndex;
            ctx.fillStyle = selected ? "rgba(255,247,153,0.18)" : "rgba(255,255,255,0.06)";
            ctx.fillRect(x, y, cardW, cardH);
            ctx.strokeStyle = selected ? "#fff799" : "rgba(255,255,255,0.26)";
            ctx.lineWidth = selected ? 2 : 1;
            ctx.strokeRect(x, y, cardW, cardH);
            ctx.fillStyle = "#fff";
            ctx.font = "18px monospace";
            ctx.fillText(`${i + 1}. ${def?.name ?? key}`, x + 14, y + 28);
            ctx.font = "13px monospace";
            ctx.fillStyle = "#9ec7ff";
            ctx.fillText(`Role: ${def?.role ?? "unknown"}`, x + 14, y + 50);
            ctx.fillStyle = "#ddd";
            ctx.fillText(`HP ${Math.round(s.maxHP ?? 0)}  SPD ${Math.round(s.spd ?? 0)}`, x + 14, y + 78);
            ctx.fillText(`PAtk ${Math.round(s.pAtk ?? 0)}  EAtk ${Math.round(s.eAtk ?? 0)}`, x + 14, y + 98);
            ctx.fillText(`Sta ${Math.round(s.stamina ?? 0)}  Eng ${Math.round(s.energy ?? 0)}`, x + 14, y + 118);
            ctx.fillText(`Range ${Math.round(s.range ?? 0)}  Cast ${Math.round(s.castSpd ?? 0)}`, x + 14, y + 138);
            ctx.fillStyle = "#cfcfcf";
            ctx.fillText(`Moves: ${(def?.moveset ?? []).map(k => abilities[k]?.name ?? k).join(", ")}`, x + 14, y + 164);
        }
    }
}
class MainScene {
    constructor() {
        this.world = new World();
    }
    onEnter(sm, payload) {
        this.world = new World();
        this.world.initialize(payload?.starterKey ?? "dog");
    }
    update(sm, dt, input) {
        this.world.update(dt, input);
    }
    draw(sm, ctx) {
        this.world.draw(ctx);
    }
}
const game = new Game();
game.start();
// Notes2: Later in const species definition, re-add learnset: [{move: 
// movekey, level: at what level it can learn it}]. Also add morphOptions that
//  has the key to what it can morph into and how many morphpoints are needed
//  for it. Changes: scaled defeated creatures level into addXP arguments.
//  Added skeleton for BuildingManager: may be hosted inside World or 
// ChunkManager or whichever hosts BiomeManager (chunkmanager doesn't
//  actually exist in this iteration but does in the roblox version. Maybe 
// biomesystem is an overlay to chunkManager or they mix in together. roblox
//  version isn't voxel based, but js game prototype can be, maybe should 
// be.). Added Tree as interactable node. Right now it can be "picked" by 
// player with nothing special. Later, may want to use creature ability to 
// "damage" the tree. In this case, interactable node and creature have to be
//  selected by player maybe, so maybe have a super class that they extend 
// from or something. Added Chunk system as an object. It is technically tp 
// down for now so there isn't a need for height maps, digging, etc.. World
//  class is cluttered with things that you could put in a manager. Probably
//  refactor with world.combat.methods(args) that are already there, use 
// world.playerInteraction.methods and other stuff. The pet creatures also 
// wander off too far away from the camera center. Might want to give pets 
// an explicit leash to the player even in combat. Also added "disengage". 
// Should work like quinn E: target an enemy, gap close and damage, and then
//  jump back a larger distance. Added replenish berry that replenishes 
// stamina more, adjusted stamina and energy recovery rates so that it 
// matters more, and fixed up itemBar and inventory to automatically add
//  items not already there so you can select them in inventory
