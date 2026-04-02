
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

/* =========================
   runtime registries (no legacy conceptBank paths)
========================= */
const composites = {
    animal: { effectiveness: { physical: 1, energy: 1 }, specialEffects: [] },
    water: { effectiveness: { physical: 0.75, energy: 1.25 }, specialEffects: ["waterAdd"] },
    voltage: { effectiveness: { physical: 1.5, energy: 0.75 }, specialEffects: ["waterVolt"] },
    fire: { effectiveness: { physical: 0.5, energy: 1.75 }, specialEffects: ["fireUp", "burnoff"] },
    rock: { effectiveness: { physical: 1, energy: 0.5 }, specialEffects: ["hardSurface"] },
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
        flatDmg: { p: 10, e: 0 },
        dmgScale: { p: 0.4, e: 0 },
        range: 24,
    },
    zap: {
        name: "Zap",
        category: "hitscan",
        cooldown: 3.2,
        resourceUse: { stamina: 0, energy: 5 },
        flatDmg: { p: 0, e: 16 },
        dmgScale: { p: 0, e: 0.7 },
        range: 120,
        soakAdd: { electric: 0.75 },
        effectsOnHit: [{ type: "shock", chance: 0.25, duration: 1.5, magnitude: 0.2 }],
        fx: { lineColor: "#8ac7ff" },
    },
    emberClaw: {
        name: "Ember Claw",
        category: "melee",
        cooldown: 2.4,
        resourceUse: { stamina: 6, energy: 2 },
        flatDmg: { p: 8, e: 5 },
        dmgScale: { p: 0.3, e: 0.35 },
        range: 26,
        soakAdd: { heat: 1.0 },
        effectsOnHit: [{ type: "burn", chance: 0.5, duration: 3.2, magnitude: 3.5 }],
    },
    pebbleShot: {
        name: "Pebble Shot",
        category: "projectile",
        cooldown: 2.0,
        resourceUse: { stamina: 2, energy: 2 },
        flatDmg: { p: 6, e: 0 },
        dmgScale: { p: 0.45, e: 0 },
        range: 150,
        projectile: { speed: 280 },
        fx: { lineColor: "#d0c9b0" },
    },
    staticBurst: {
        name: "Static Burst",
        category: "aoe",
        cooldown: 4.2,
        resourceUse: { stamina: 0, energy: 12 },
        flatDmg: { p: 0, e: 10 },
        dmgScale: { p: 0, e: 0.5 },
        range: 90,
        area: { radius: 40 },
        soakAdd: { electric: 0.4 },
        effectsOnHit: [{ type: "slow", duration: 1.5, magnitude: 0.35 }],
        fx: { pulseColor: "rgba(120,190,255,0.55)" },
    },
    rallyHowl: {
        name: "Rally Howl",
        category: "utility",
        cooldown: 5.2,
        resourceUse: { stamina: 0, energy: 8 },
        flatDmg: { p: 0, e: 0 },
        dmgScale: { p: 0, e: 0 },
        range: 0,
        selfStatus: [{ type: "regen", duration: 4.0, magnitude: 4.0 }],
    },
};

const species = {
    dog: {
        name: "Dog",
        compositeKey: "animal",
        role: "fighter",
        baseStats: { pAtk: 12, eAtk: 2, range: 24, maxHP: 110, spd: 70, castSpd: 1, size: 10, stamina: 25, energy: 10, recoverStamina: 6, recoverEnergy: 3 },
        moveset: ["ram", "rallyHowl"],
    },
    sparkit: {
        name: "Sparkit",
        compositeKey: "voltage",
        role: "ranged",
        baseStats: { pAtk: 4, eAtk: 12, range: 100, maxHP: 85, spd: 65, castSpd: 1, size: 9, stamina: 16, energy: 24, recoverStamina: 4, recoverEnergy: 6 },
        moveset: ["zap", "staticBurst"],
    },
    cinderpup: {
        name: "Cinderpup",
        compositeKey: "fire",
        role: "fighter",
        baseStats: { pAtk: 10, eAtk: 8, range: 30, maxHP: 95, spd: 74, castSpd: 1, size: 9, stamina: 24, energy: 18, recoverStamina: 6, recoverEnergy: 5 },
        moveset: ["emberClaw", "ram"],
    },
    pebblit: {
        name: "Pebblit",
        compositeKey: "rock",
        role: "ranged",
        baseStats: { pAtk: 9, eAtk: 3, range: 120, maxHP: 120, spd: 58, castSpd: 1, size: 11, stamina: 22, energy: 12, recoverStamina: 5, recoverEnergy: 3 },
        moveset: ["pebbleShot", "ram"],
    },
};

const biomeDefs = {
    plains: {
        color: "#89a87c",
        spawns: [{ key: "dog", weight: 5 }, { key: "pebblit", weight: 2 }],
        nodes: [{ key: "berry_bush", weight: 12 }, { key: "energy_crystal", weight: 2 }, {key: "revive_berry_bush", weight: 1}],
    },
    forest: {
        color: "#6e9a5f",
        spawns: [{ key: "dog", weight: 3 }, { key: "cinderpup", weight: 2 }],
        nodes: [{ key: "berry_bush", weight: 22 }, { key: "bait_shrub", weight: 3 }, {key: "revive_berry_bush", weight: 1}],
    },
    desert: {
        color: "#b8a56c",
        spawns: [{ key: "pebblit", weight: 5 }, { key: "cinderpup", weight: 3 }],
        nodes: [{ key: "energy_crystal", weight: 5 }, { key: "bait_shrub", weight: 2 }, {key: "revive_berry_bush", weight: 1}],
    },
    stormfield: {
        color: "#74879b",
        spawns: [{ key: "sparkit", weight: 6 }, { key: "dog", weight: 2 }],
        nodes: [{ key: "energy_crystal", weight: 6 }, { key: "berry_bush", weight: 2 }, {key: "revive_berry_bush", weight: 1}],
    },
    volcanic: {
        color: "#8b5c4f",
        spawns: [{ key: "cinderpup", weight: 6 }, { key: "pebblit", weight: 2 }],
        nodes: [{ key: "bait_shrub", weight: 4 }, { key: "energy_crystal", weight: 2 }, {key: "revive_berry_bush", weight: 1}],
    },
};

const itemDefs = {
    berry_red: { name: "Red Berry", type: "heal", amount: 40 },
    berry_blue: { name: "Blue Berry", type: "heal", amount: 25 },
    berry_yellow: { name: "Yellow Berry", type: "heal", amount: 30 },
    revive_berry: { name: "Revive Berry", type: "revive", amount: 50 },
    boost_berry: { name: "Boost Berry", type: "buff", amount: 0.15, duration: 20 },
    battery_seed: { name: "Battery Seed", type: "energy", amount: 16, stamina: 10 },
    lure_meat: { name: "Lure Meat", type: "bait", tameBonus: 0.25, requiredHPRatio: 0.45 },
};

const nodeDefs = {
    berry_bush: { color: "#bb2f58", reward: { key: "berry_red", amount: 2 }, cooldown: 12 },
    berry_bush_blue: { color: "#4a90e2", reward: { key: "berry_blue", amount: 2 }, cooldown: 12 },
    berry_bush_yellow: { color: "#f4c24a", reward: { key: "berry_yellow", amount: 2 }, cooldown: 12 },
    revive_berry_bush: { color: "#7b3e1d", reward: { key: "revive_berry", amount: 1 }, cooldown: 18 },
    boost_berry_bush: { color: "#ffcc00", reward: { key: "boost_berry", amount: 1 }, cooldown: 20 },
    energy_crystal: { color: "#5fc7ff", reward: { key: "battery_seed", amount: 1 }, cooldown: 14 },
    bait_shrub: { color: "#a6a052", reward: { key: "lure_meat", amount: 1 }, cooldown: 16 },
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
        for (let i = creature.statusEffects.length - 1; i >= 0; i--) {
            const st = creature.statusEffects[i];
            st.duration -= dt;
            if (st.type === "burn") creature.currentHP = Math.max(0, creature.currentHP - st.magnitude * dt);
            if (st.type === "shock") creature.currentEnergy = Math.max(0, creature.currentEnergy - st.magnitude * 5 * dt);
            if (st.type === "slow") slowMult *= 1 - st.magnitude;
            if (st.type === "regen") creature.currentHP = Math.min(creature.modifiedStats.maxHP, creature.currentHP + st.magnitude * dt);
            if (st.duration <= 0) creature.statusEffects.splice(i, 1);
        }
        creature.runtimeSpeedMult = clamp(slowMult, 0.35, 1);
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
        this.compositeKey = def.compositeKey;
        this.effectState = EffectEngine.createState();
        this.statusEffects = [];

        this.currentHP = this.permanentStats.maxHP;
        this.currentStamina = this.permanentStats.stamina;
        this.currentEnergy = this.permanentStats.energy;

        this.level = 1;
        this.xp = 0;
        this.nextXP = xpNeededForLevel(this.level);

        this.moveset = [...def.moveset];
        this.cooldowns = Object.fromEntries(this.moveset.map(k => [k, 0]));
        this.combatContributors = new Map();

        this.runtimeSpeedMult = 1;
        this.hitFlash = 0;
        this.lifecycle = "alive"; // alive | defeated | captured | despawned
        this.mode = team === 0 ? "pet" : "wild";
        this.ownedId = null;
        this.brain = null;
        this.intent = this.makeEmptyIntent();

        // Command system payload used by brains.
        this.command = { type: "follow", issuedAt: 0, targetId: null, point: null };
    }

    makeEmptyIntent() {
        return { move: { x: 0, z: 0 }, abilityKey: null, targetId: null, aimAt: null };
    }

    addXP(amount) {
        const events = [];
        this.xp += amount;
        while (this.xp >= this.nextXP) {
            this.xp -= this.nextXP;
            this.level += 1;
            this.nextXP = xpNeededForLevel(this.level);
            this.growthStats.maxHP += 8;
            this.growthStats.pAtk += 1.5;
            this.growthStats.eAtk += 1.5;
            this.growthStats.spd += 1.2;
            this.rebuildStats();
            this.currentHP = Math.min(this.currentHP + 14, this.modifiedStats.maxHP);
            events.push({ type: "leveledUp", newLevel: this.level });
        }
        return events;
    }

    rebuildStats() {
        this.permanentStats = {
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
        this.modifiedStats = { ...this.permanentStats };
    }

    tick(dt, world) {
        if (this.lifecycle !== "alive") return;
        for (const key of Object.keys(this.cooldowns)) this.cooldowns[key] = Math.max(0, this.cooldowns[key] - dt);

        this.currentStamina = Math.min(this.modifiedStats.stamina, this.currentStamina + this.modifiedStats.recoverStamina * dt);
        this.currentEnergy = Math.min(this.modifiedStats.energy, this.currentEnergy + this.modifiedStats.recoverEnergy * dt);
        EffectEngine.tickCreature(this, dt);

        const mv = norm2D(this.intent.move.x, this.intent.move.z);
        this.vel.x = mv.x * this.modifiedStats.spd * this.runtimeSpeedMult;
        this.vel.z = mv.z * this.modifiedStats.spd * this.runtimeSpeedMult;

        this.pos.x = clamp(this.pos.x + this.vel.x * dt, 0, world.width);
        this.pos.z = clamp(this.pos.z + this.vel.z * dt, 0, world.height);

        if (mv.x !== 0 || mv.z !== 0) this.angle = Math.atan2(mv.z, mv.x);
        if (this.intent.abilityKey && this.intent.targetId) world.tryUseAbility(this, this.intent.abilityKey, this.intent.targetId);

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
        if (opts.mode) c.mode = opts.mode;
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
        const followAnchor = world.getPetFollowAnchor(h.id);
        const stance = isActive ? "aggressive" : player.stance;

        // Explicit command priority for active pet.
        if (h.command?.type && (isActive || h.command.type === "hold" || h.command.type === "follow")) {
            const done = this.executeCommand(world, h, h.command, isActive, followAnchor);
            if (!done) return;
        }

        if (stance === "hold" && !isActive) {
            h.intent.move = { x: 0, z: 0 };
            return;
        }

        const acquisitionRange = stance === "follow" ? 120 : 190;
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
        const target = world.findNearestEnemyOf(h, 140);
        if (!target) return;
        this.fightTarget(world, h, target, null);
    }

    fightTarget(world, h, target, maxPursuitDistance = null) {
        const dx = target.pos.x - h.pos.x;
        const dz = target.pos.z - h.pos.z;
        const d = Math.hypot(dx, dz);
        const n = norm2D(dx, dz);

        const preferredRange = this.role === "ranged" ? 95 : 18;
        const leash = this.role === "ranged" ? 20 : 8;

        if (maxPursuitDistance != null) {
            const anchor = world.getPetFollowAnchor(h.id);
            if (dist(target.pos.x, target.pos.z, anchor.x, anchor.z) > maxPursuitDistance) {
                this.moveTowardAnchor(h, anchor, 10);
                return;
            }
        }

        if (d > preferredRange + leash) h.intent.move = { x: n.x, z: n.z };
        else if (d < preferredRange - leash) h.intent.move = { x: -n.x, z: -n.z };
        else h.intent.move = { x: 0, z: 0 };

        const bestAbility = this.pickAbility(h, d);
        if (bestAbility) {
            h.intent.abilityKey = bestAbility;
            h.intent.targetId = target.id;
            h.intent.aimAt = { x: target.pos.x, z: target.pos.z };
        }
    }

    pickAbility(creature, distToTarget) {
        let best = null;
        let bestScore = -Infinity;
        for (const key of creature.moveset) {
            const a = abilities[key];
            if (!a) continue;
            if ((creature.cooldowns[key] ?? 0) > 0) continue;
            if ((a.resourceUse?.stamina ?? 0) > creature.currentStamina) continue;
            if ((a.resourceUse?.energy ?? 0) > creature.currentEnergy) continue;
            if (distToTarget > (a.range ?? 999)) continue;

            const score =
                (a.flatDmg?.p ?? 0) +
                (a.flatDmg?.e ?? 0) +
                (a.dmgScale?.p ?? 0) * creature.modifiedStats.pAtk +
                (a.dmgScale?.e ?? 0) * creature.modifiedStats.eAtk +
                (a.effectsOnHit ? 2 : 0);
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
    // getBiomeKeyAt(x, z) {
    //     const n = Math.sin(x * 0.004) + Math.cos(z * 0.005) + Math.sin((x + z) * 0.0025);
    //     if (n < -1.0) return "desert";
    //     if (n < -0.2) return "plains";
    //     if (n < 0.45) return "forest";
    //     if (n < 1.15) return "stormfield";
    //     return "volcanic";
    // },
    getBiomeKeyAt(x, z) {
        const biomeKeys = Object.keys(biomeDefs);
        const biomeKeyAmt = biomeKeys.length;
        const n = Math.sin(x * 0.004) + Math.cos(z * 0.005) + Math.sin((x + z) * 0.0025);
        const sections = 2 / biomeKeyAmt;
        let index = Math.floor((n + 1) / sections);
        // Clamp index to valid range
        index = Math.max(0, Math.min(index, biomeKeyAmt - 1));
        return biomeKeys[index];
    },
    getBiomeAt(x, z) {
        const key = this.getBiomeKeyAt(x, z);
        if (!biomeDefs[key]) {
            console.warn('No biome data for key:', key);
            return null;
        }
        return { key, ...biomeDefs[key] };
    }
};
class SpawnField {
    constructor(radius = 260, innerNoSpawn = 90, maxWild = 4, interval = 1.6) {
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
    trySpawn(world) {
        const currentWild = world.creatures.filter(c => c.mode === "wild" && c.lifecycle === "alive").length;
        if (currentWild >= this.maxWild) return;

        const player = world.player;
        for (let i = 0; i < 14; i++) {
            const angle = Math.random() * Math.PI * 2;
            const d = this.innerNoSpawn + Math.random() * (this.radius - this.innerNoSpawn);
            const x = player.pos.x + Math.cos(angle) * d;
            const z = player.pos.z + Math.sin(angle) * d;
            if (x < 0 || x > world.width || z < 0 || z > world.height) continue;

            const biome = BiomeSystem.getBiomeAt(x, z);
            const speciesKey = pickWeighted(biome.spawns);
            const wild = world.factory.create(speciesKey, 1, x, z, { mode: "wild" });
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
            if (world.isCreatureEngaged(c)) return true;
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

/* =========================
   player + commands/items/taming
========================= */
class PlayerEntity {
    constructor(x, z) {
        this.pos = { x, z };
        this.vel = { x: 0, z: 0 };
        this.spd = 140;

        this.petIds         = [null, null, null];
        this.activePetIndex = 0;
        this.selectAll      = false;  // renamed from selectedAllPets — shorter, clearer

        this.commandTargetId = null;
        this.stance          = "aggressive";

        this.inventory       = { berry_red: 30, battery_seed: 20, lure_meat: 2 };
        this.reserveOwnedIds = [];
        this.ownedCreatures  = [];
        this.lastLog         = "";
        this.itemBar = ["berry_red", "battery_seed", "lure_meat", "revive_berry"];
        this.selectedItemIndex = 0;
    }
    get selectedItemKey() {
        return this.itemBar[this.selectedItemIndex] ?? null;
    }

    cycleItem(dir) {
        const len = this.itemBar.length;
        if (!len) return;
        this.selectedItemIndex = (this.selectedItemIndex + dir + len) % len;
    }
    get activePetId() {
        return this.petIds[this.activePetIndex] ?? null;
    }
    get targetPetIds() {
        return this.selectAll
            ? this.petIds.filter(Boolean)
            : [this.activePetId].filter(Boolean);
    }

    update(dt, input, world) {
        // ── Movement ──────────────────────────────────────────
        let mx = 0, mz = 0;
        if (input.isDown("KeyW")) mz -= 1;
        if (input.isDown("KeyS")) mz += 1;
        if (input.isDown("KeyA")) mx -= 1;
        if (input.isDown("KeyD")) mx += 1;
        const mv = norm2D(mx, mz);
        this.vel.x = mv.x * this.spd;
        this.vel.z = mv.z * this.spd;
        this.pos.x = clamp(this.pos.x + this.vel.x * dt, 0, world.width);
        this.pos.z = clamp(this.pos.z + this.vel.z * dt, 0, world.height);

        //eventually replace pet and item selection
        // with menus to scroll index and choose

        // ── Pet selection ─────────────────────────────────────
        if (input.consumePress("Digit1")) { this.activePetIndex = 0; this.selectAll = false; }
        if (input.consumePress("Digit2")) { this.activePetIndex = 1; this.selectAll = false; }
        if (input.consumePress("Digit3")) { this.activePetIndex = 2; this.selectAll = false; }

        // Tab toggles select-all; picking a digit cancels it
        if (input.consumePress("Digit4")) {
            this.selectAll = !this.selectAll;
            this.lastLog = this.selectAll ? "All pets selected" : `Pet ${this.activePetIndex + 1} selected`;
        }
        if (input.consumePress("BracketLeft")) this.cycleItem(-1);
        if (input.consumePress("BracketRight")) this.cycleItem(1);
        if (input.consumePress("KeyZ")) this.useSelectedItem(world);
        // ── Stance cycle ──────────────────────────────────────
        if (input.consumePress("KeyQ")) {
            const cycle = { aggressive: "follow", follow: "hold", hold: "aggressive" };
            this.stance = cycle[this.stance] ?? "aggressive";
            // Apply immediately to target set
            this.issueCommand(world, { type: "stance", stance: this.stance, issuedAt: world.time });
            this.lastLog = `Stance: ${this.stance}`;
        }

        // ── Direct commands ───────────────────────────────────
        if (input.consumePress("KeyR")) {
            // Regroup always hits all pets regardless of selectAll
            world.commandPets(this.petIds.filter(Boolean), { type: "follow", issuedAt: world.time });
            this.lastLog = "Regroup all pets";
        }
        if (input.consumePress("KeyH")) {
            this.issueCommand(world, { type: "hold", issuedAt: world.time });
            this.lastLog = `${this.selectAll ? "All" : "Active"} pet: hold`;
        }
        if (input.consumePress("KeyF")) {
            this.issueCommand(world, { type: "follow", issuedAt: world.time });
            this.lastLog = `${this.selectAll ? "All" : "Active"} pet: follow`;
        }

        // ── World interaction ─────────────────────────────────
        if (input.consumePress("KeyG")) world.tryInteractNearestNode();
        if (input.consumePress("KeyT")) world.swapActiveWithReserve(0);

        // ── Mouse commands ────────────────────────────────────
        const worldPos = world.camera.screenToWorld(input.mouse.x, input.mouse.y);

        if (input.consumeMouseLeftPress()) {
            const target = world.findNearestEnemyToPoint(worldPos.x, worldPos.z, 32);
            if (target) {
                this.commandTargetId = target.id;
                this.issueCommand(world, { type: "attack", targetId: target.id, issuedAt: world.time });
                this.lastLog = `${this.selectAll ? "All" : "Active"} → attack ${target.speciesKey}`;
            }
        }

        if (input.consumeMouseRightPress()) {
            this.issueCommand(world, { type: "move", point: worldPos, issuedAt: world.time });
            this.commandTargetId = null;
            this.lastLog = `${this.selectAll ? "All" : "Active"} → move`;
        }
    }

    issueCommand(world, command) {
        world.commandPets(this.targetPetIds, command);
    }

    useItemOnTargets(world, itemKey) {
        for (const id of this.targetPetIds) {
            if (!this.inventory[itemKey] || this.inventory[itemKey] <= 0) break;
            world.useItem(itemKey, id);
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
        this.player = new PlayerEntity(this.width / 2, this.height / 2);
        this.creatures = [];
        this.factory = new CreatureFactory();
        this.spawnField = new SpawnField();

        this.nodes = [];
        this.nodeSpawnTimer = 0;

        this.floatingTexts = [];
        this.combatFx = [];
    }
    initialize() {
        this.camera.follow(this.player);

        const p = this.player.pos;
        const ownedA = this.createOwnedCreatureRecord("dog");
        const ownedB = this.createOwnedCreatureRecord("sparkit");
        const ownedC = this.createOwnedCreatureRecord("cinderpup");
        this.player.partyOwnedIds = [ownedA.ownedId, ownedB.ownedId, ownedC.ownedId];
        this.hydratePartyRuntime();
        this.spawnBiomeNodesAroundPlayer(8);
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
        const owned = {
            ownedId: NEXT_OWNED_ID++,
            speciesKey,
            nickname: def?.name ?? speciesKey,
            level: runtime?.level ?? 1,
            xp: runtime?.xp ?? 0,
            nextXP: runtime?.nextXP ?? xpNeededForLevel(runtime?.level ?? 1),
            growthStats: { ...(runtime?.growthStats ?? { pAtk: 0, eAtk: 0, range: 0, maxHP: 0, spd: 0, castSpd: 0, size: 0, stamina: 0, energy: 0, recoverStamina: 0, recoverEnergy: 0 }) },
            moveset: [...(runtime?.moveset ?? def.moveset)],
            compositeKey: runtime?.compositeKey ?? def.compositeKey,
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
        owned.growthStats = { ...runtimeCreature.growthStats };
        owned.moveset = [...runtimeCreature.moveset];
        owned.compositeKey = runtimeCreature.compositeKey;
    }
    update(dt, input) {
        this.time += dt;
        this.player.update(dt, input, this);
        this.spawnField.update(dt, this);

        this.nodeSpawnTimer += dt;
        if (this.nodeSpawnTimer > 7.5 && this.nodes.length < 20) {
            this.nodeSpawnTimer = 0;
            this.spawnBiomeNodesAroundPlayer(2);
        }
        for (const node of this.nodes) node.update(dt);
        for (const c of this.creatures) if (c.brain) c.brain.think(this);
        for (const c of this.creatures) c.tick(dt, this);
        this.resolveSimpleSeparation();
        this.cleanupDefeatedCreatures();
        this.rebuildPartyPetIds();
        this.removeDeadCommandTarget();
        this.updateFx(dt);
        this.camera.update(dt);
    }
    rebuildPartyPetIds() {
        this.player.petIds = this.player.partyOwnedIds.map((ownedId) => {
            if (ownedId == null) return null;
            const runtime = this.creatures.find(c => c.mode === "pet" && c.ownedId === ownedId && c.lifecycle === "alive");
            return runtime?.id ?? null;
        });
    }
    commandActivePet(command) {
        const pet = this.getCreatureById(this.player.activePetId);
        if (!pet || pet.lifecycle !== "alive") return;
        pet.command = { ...command };
    }
    commandPets(petIds, command) {
        for (const id of petIds) {
            const creature = this.getCreatureById(id);
            if (creature?.lifecycle === "alive") creature.command = { ...command };
        }
    }
    commandAllPets(command) {
        for (const id of this.player.petIds) {
            const pet = this.getCreatureById(id);
            if (!pet || pet.lifecycle !== "alive") continue;
            pet.command = { ...command };
        }
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
    isCreatureEngaged(creature) {
        for (const other of this.creatures) {
            if (other.id === creature.id || other.lifecycle !== "alive" || other.team === creature.team) continue;
            if (dist(creature.pos.x, creature.pos.z, other.pos.x, other.pos.z) < 160) return true;
        }
        return false;
    }
    tryUseAbility(source, abilityKey, targetId) {
        const a = abilities[abilityKey];
        const target = this.getCreatureById(targetId);
        if (!a || !target || target.lifecycle !== "alive" || source.lifecycle !== "alive") return false;
        if (source.team === target.team) return false;
        if ((source.cooldowns[abilityKey] ?? 0) > 0) return false;
        const d = dist(source.pos.x, source.pos.z, target.pos.x, target.pos.z);
        if (d > (a.range ?? Infinity)) return false;
        if ((a.resourceUse?.stamina ?? 0) > source.currentStamina) return false;
        if ((a.resourceUse?.energy ?? 0) > source.currentEnergy) return false;
        source.currentStamina -= a.resourceUse?.stamina ?? 0;
        source.currentEnergy -= a.resourceUse?.energy ?? 0;
        source.cooldowns[abilityKey] = a.cooldown;
        if (a.category === "utility") {
            EffectEngine.applyAbilityEffects(source, source, a);
            this.pushFloatingText(source.pos.x, source.pos.z - 10, a.name, "#88ffb5");
            return true;
        }
        const dmg =
            (a.flatDmg?.p ?? 0) +
            (a.flatDmg?.e ?? 0) +
            (a.dmgScale?.p ?? 0) * source.modifiedStats.pAtk +
            (a.dmgScale?.e ?? 0) * source.modifiedStats.eAtk;

        if (a.category === "aoe") {
            const radius = a.area?.radius ?? 30;
            for (const other of this.creatures) {
                if (other.team === source.team || other.lifecycle !== "alive") continue;
                if (dist(target.pos.x, target.pos.z, other.pos.x, other.pos.z) > radius) continue;
                this.applyDamagePacket(source, other, dmg * 0.9, a);
            }
            this.combatFx.push({ type: "pulse", x: target.pos.x, z: target.pos.z, radius, ttl: 0.2, color: a.fx?.pulseColor ?? "rgba(255,255,255,0.4)" });
            return true;
        }
        this.applyDamagePacket(source, target, dmg, a);
        if (a.fx?.lineColor) this.combatFx.push({ type: "line", x1: source.pos.x, z1: source.pos.z, x2: target.pos.x, z2: target.pos.z, ttl: 0.12, color: a.fx.lineColor });
        return true;
    }
    applyDamagePacket(source, target, dmg, abilityDef) {
        const effBonus = EffectEngine.applyAbilityEffects(source, target, abilityDef);
        const composite = composites[target.compositeKey] ?? composites.animal;
        const physicalMod = composite.effectiveness.physical ?? 1;
        const energyMod = composite.effectiveness.energy ?? 1;
        const physicalPart = (abilityDef.flatDmg?.p ?? 0) + (abilityDef.dmgScale?.p ?? 0) * source.modifiedStats.pAtk;
        const energyPart = (abilityDef.flatDmg?.e ?? 0) + (abilityDef.dmgScale?.e ?? 0) * source.modifiedStats.eAtk;
        const scaled = (physicalPart * physicalMod + energyPart * energyMod) * effBonus;
        // Keep a minimum 1 damage floor so very low scaling attacks still provide gameplay feedback.
        const finalDmg = Math.max(1, scaled || dmg);
        target.currentHP = Math.max(0, target.currentHP - finalDmg);
        target.hitFlash = 1;
        target.combatContributors.set(source.id, this.time);
        this.pushFloatingText(target.pos.x, target.pos.z - 12, `${Math.round(finalDmg)}`, "#ffd7d7");
        if (target.currentHP <= 0) {
            target.lifecycle = "defeated";
        }
    }
    cleanupDefeatedCreatures() {
        for (const c of this.creatures) {
            if (c.lifecycle !== "defeated" || c._deathHandled) continue;
            c._deathHandled = true;
            this.pushFloatingText(c.pos.x, c.pos.z, "KO", "#ff8a8a");
            this.handleCreatureDefeat(c);
        }
    }
    handleCreatureDefeat(dead) {
        if (dead.team === 0) return;
        const contributors = [];
        for (const [id, t] of dead.combatContributors.entries()) {
            if (this.time - t > 14) continue;
            const c = this.getCreatureById(id);
            if (c && c.lifecycle === "alive" && c.team === 0) contributors.push(c);
        }
        // XP loop: nearby allies get a small share.
        for (const pid of this.player.petIds) {
            const pet = this.getCreatureById(pid);
            if (!pet || pet.lifecycle !== "alive") continue;
            if (!contributors.includes(pet) && dist(pet.pos.x, pet.pos.z, dead.pos.x, dead.pos.z) < 140) contributors.push(pet);
        }
        const baseXP = 24;
        for (const pet of contributors) {
            const events = pet.addXP(baseXP);
            this.syncOwnedCreatureFromRuntime(pet);
            for (const ev of events) {
                if (ev.type === "leveledUp") this.pushFloatingText(pet.pos.x, pet.pos.z - 14, `Lv Up! ${ev.newLevel}`, "#fff799");
            }
        }
    }
    useItem(itemKey, targetMode) {
        const def = itemDefs[itemKey];
        if (!def) return false;
        if ((this.player.inventory[itemKey] ?? 0) <= 0) return false;
        const targetCreature =
            typeof targetMode === "number"
                ? this.getCreatureById(targetMode)
                : targetMode === "activePet"
                    ? this.getCreatureById(this.player.activePetId)
                    : null;
        if (targetCreature && targetCreature.lifecycle === "alive") {
            if (def.type === "heal") {
                targetCreature.currentHP = Math.min(
                    targetCreature.modifiedStats.maxHP,
                    targetCreature.currentHP + def.amount
                );
                this.pushFloatingText(targetCreature.pos.x, targetCreature.pos.z - 16, `+${def.amount} HP`, "#8dff9d");
            }

            if (def.type === "energy") {
                targetCreature.currentEnergy = Math.min(targetCreature.modifiedStats.energy, targetCreature.currentEnergy + def.amount);
                targetCreature.currentStamina = Math.min(targetCreature.modifiedStats.stamina, targetCreature.currentStamina + (def.stamina ?? 0));
            }

            if (def.type === "revive") {
                targetCreature.currentHP = Math.min(targetCreature.modifiedStats.maxHP, def.amount);
                targetCreature.lifecycle = "alive";
            }
        }
        if (targetMode === "wildTarget") {
            const t = this.getCreatureById(this.player.commandTargetId);
            if (!t || t.team !== 1 || t.lifecycle !== "alive") return false;
            const activePet = this.getCreatureById(this.player.activePetId);
            if (!activePet || dist(activePet.pos.x, activePet.pos.z, t.pos.x, t.pos.z) > 90) return false;
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
        const owned = this.createOwnedCreatureRecord(wild.speciesKey, wild);
        const openSlot = this.getFirstOpenPartySlot();
        if (openSlot >= 0) {
            this.player.partyOwnedIds[openSlot] = owned.ownedId;
            this.hydratePartyRuntime();
            this.player.lastLog = `Tamed ${wild.speciesKey} into party`;
        } else {
            this.player.reserveOwnedIds.push(owned.ownedId);
            this.player.lastLog = `Tamed ${wild.speciesKey} -> reserve`;
        }
        this.pushFloatingText(wild.pos.x, wild.pos.z - 18, "Captured!", "#ffe38e");
        return true;
    }
    swapActiveWithReserve(reserveIndex) {
        const reserveOwnedId = this.player.reserveOwnedIds[reserveIndex];
        if (reserveOwnedId == null) return false;
        const slotIndex = this.player.activePetIndex;
        const activeOwnedId = this.player.partyOwnedIds[slotIndex];
        if (activeOwnedId == null) return false;
        this.player.reserveOwnedIds[reserveIndex] = activeOwnedId;
        this.player.partyOwnedIds[slotIndex] = reserveOwnedId;
        this.hydratePartyRuntime();
        const reserveData = this.getOwnedCreatureById(reserveOwnedId);
        this.player.lastLog = `Swapped in ${reserveData?.speciesKey ?? "pet"}`;
        return true;
    }
    spawnBiomeNodesAroundPlayer(count) {
        const p = this.player.pos;
        for (let i = 0; i < count; i++) {
            const x = clamp(p.x + (Math.random() - 0.5) * 450, 20, this.width - 20);
            const z = clamp(p.z + (Math.random() - 0.5) * 320, 20, this.height - 20);
            const biome = BiomeSystem.getBiomeAt(x, z);
            const type = pickWeighted(biome.nodes);
            this.nodes.push(new InteractableNode(type, x, z));
        }
    }
    tryInteractNearestNode() {
        let best = null;
        let bestD = Infinity;
        for (const n of this.nodes) {
            if (!n.active) continue;
            const d = dist(this.player.pos.x, this.player.pos.z, n.pos.x, n.pos.z);
            if (d < bestD && d <= 34) {
                bestD = d;
                best = n;
            }
        }
        if (!best) {
            this.player.lastLog = "No node nearby";
            return false;
        }
        const def = nodeDefs[best.type];
        this.player.inventory[def.reward.key] = (this.player.inventory[def.reward.key] ?? 0) + def.reward.amount;
        best.cooldown = def.cooldown;
        this.player.lastLog = `Gathered ${def.reward.key} x${def.reward.amount}`;
        this.pushFloatingText(best.pos.x, best.pos.z - 10, `+${def.reward.key}`, "#ffffff");
        return true;
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
    }
    pushFloatingText(x, z, text, color = "#fff") {
        this.floatingTexts.push({ x, z, text, color, ttl: 0.9 });
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
        // Biome flavor: coarse tiles tinted by biome.
        const tile = 90;
        const minX = Math.floor((this.camera.x - canvas.width / this.camera.zoom / 2) / tile) - 1;
        const maxX = Math.floor((this.camera.x + canvas.width / this.camera.zoom / 2) / tile) + 1;
        const minZ = Math.floor((this.camera.z - canvas.height / this.camera.zoom / 2) / tile) - 1;
        const maxZ = Math.floor((this.camera.z + canvas.height / this.camera.zoom / 2) / tile) + 1;
        for (let gx = minX; gx <= maxX; gx++) {
            for (let gz = minZ; gz <= maxZ; gz++) {
                const wx = gx * tile;
                const wz = gz * tile;
                const b = BiomeSystem.getBiomeAt(wx + tile * 0.5, wz + tile * 0.5);
                const s = this.camera.worldToScreen(wx, wz);
                ctx.fillStyle = b.color;
                ctx.fillRect(s.sx, s.sz, tile * this.camera.zoom + 1, tile * this.camera.zoom + 1);
            }
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
        const biome = BiomeSystem.getBiomeAt(this.player.pos.x, this.player.pos.z).key;
        this.HUDDraw(biome)
    }
    HUDDraw(biome){
        ctx.fillStyle = "rgba(0,0,0,0.56)";
        ctx.fillRect(8, 8, 420, 122);
        ctx.fillStyle = "#fff";
        ctx.font = "12px monospace";

        const activePet = this.getCreatureById(this.player.activePetId);
        const cmd = activePet?.command?.type ?? "none";
        ctx.fillText(`Biome: ${biome}`, 16, 26);
        ctx.fillText(`Active Pet: ${this.player.activePetIndex + 1} cmd:${cmd} stance:${this.player.stance}`, 16, 44);
const itemKey = this.player.selectedItemKey;
const itemDef = itemDefs[itemKey];
const itemCount = itemKey ? (this.player.inventory[itemKey] ?? 0) : 0;
ctx.fillText(`Selected Item: ${itemDef?.name ?? "None"} x${itemCount}`, 16, 62);        ctx.fillText(`1/2/3 switch | Q stance | LMB attack | RMB move | R regroup | H hold | F follow`, 16, 80);
        ctx.fillText(`Z heal | X energy | V tame target | G gather | T swap reserve | ${this.player.lastLog}`, 16, 98);
        ctx.fillText(`Reserve: ${this.player.reserveOwnedIds.length}`, 16, 116);
ctx.fillText(`PetIDs: ${this.player.petIds.join(",")}`, 16, 132);
    }
}

/* =========================
   game
========================= */
class Game {
    constructor() {
        this.input = new InputManager();
        this.sceneManager = new SceneManager(
            { mainScene: new Scene() },
            "mainScene"
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

class Scene {
    constructor() {
        this.world = new World();
    }

    onEnter(sm, payload) {
        this.world.initialize();
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
