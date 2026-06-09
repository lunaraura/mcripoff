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
    herd: {
        aiTendency: { aggression: 0.18, formation: "anchor", engageRangeBias: 0.9 },
        statMult: { maxHP: 1.0, spd: 1.0, stamina: 1.06, energy: 0.92 },
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
        familyKey: "herd",
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

class Game {
    constructor(){
        this.input = new InputManager();
        this.sceneManager = new SceneManager()
        this.last = 0;
    }
    init(){
        this.loadSceneDefs()
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
class Scene{
    constructor(){
    }
    onEnter(sm) {
        this.selectedIndex = 0;
    }
    update(sm, dt, input){

    }
}
function near(origin, range, list){
    let best = null; return best;
}


class World{
    constructor(){
        this.time = 0;
        this.lastDt = 1/60;
        this.camera = new Camera();
        //runtime
        this.chunks = new Map();
        this.player = new PlayerEntity(0,0)
        this.creatures = []
        this.entities = []
        this.worldNodes = []
        //mediations
        this.PIS = new PlayerIntSys(this)
        this.CIS = new CreatureIntSys(this)
        this.CS = new CombatSys(this)
        this.BS = new BuildSys(this)
        this.NS = new NodeSys(this)
        this.EM = new EffectManager(this)
        this.spawnField = new SpawnField(this);
    }
    initWorld(){
        //chunk spawn function(chunk radius settings)
        //chunk heightmap etc
        //init Nodes for each biome
    }
    run(){
        //event bus
        //run each runtime tick
    }
}
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
                timidness: 1.35,
                commitment: 0.75,
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
                timidness: 0.82,
                commitment: 1.28,
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
            timidness: 1,
            commitment: 1,
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
                    timidness: cfg.timidness,
                    commitment: cfg.commitment,
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
class Player{}
class Creature{} //creatures
class CreatureAI{} //creatures' brain
class WorldEntity{} //projectile, barrier, wall, etc
class WorldNode{} //harvestables, etc
class WorldBuild{} //built by player

class PlayerIntSys{
    constructor(world){
        this.w = world;
        this.p = world.player
    }
    useSelectedItem(){}
    useItem(){}
    isItemUseValid(type, target){}
}
class CreatureIntSys{}
class NodeSys{}
class CombatManager{
    constructor(world){
        this.w = world;
        this.p = world.player
        this.c = world.creatures;
        this.e = world.entities;
        this.EM = world.EM;
    }
    tryAbility(def){}
    executeAbility(def){}
    createEntity(def, from, {}){}
    entityCreatureCollide(){}
    resolveDamage(){}
    sendEffect(){}
    receiveEffect(){}
}
class EffectManager{}
class BuildSys{}
