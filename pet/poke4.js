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
        flatDmg: { p: 20, e: 0 },
        dmgScale: { p: 0.4, e: 0 },
        range: 24,
    },
    zap: {
        name: "Zap",
        category: "hitscan",
        cooldown: 4.2,
        resourceUse: { stamina: 0, energy: 5 },
        flatDmg: { p: 0, e: 16 },
        dmgScale: { p: 0, e: 0.3 },
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
        cooldown: 6.0,
        resourceUse: { stamina: 2, energy: 2 },
        flatDmg: { p: 4, e: 0 },
        dmgScale: { p: 0.15, e: 0 },
        range: 150,
        projectile: { speed: 280 },
        fx: { lineColor: "#d0c9b0" },
    },
    staticBurst: {
        name: "Static Burst",
        category: "aoe",
        cooldown: 5.2,
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
        cooldown: 6.2,
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
    revive_berry: { name: "Revive Berry", type: "revive", amount: 0.5 },
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
        this.manualCastRequest = null;
        this.manualCastStatus = { text: "", until: 0 };

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

        if (isActive && h.manualCastRequest) {
            const handled = this.executeManualCast(world, h);
            if (handled) return;
        }

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

    executeManualCast(world, h) {
        const req = h.manualCastRequest;
        if (!req) return false;
        if (req.awaitingResolution) {
            if ((h.cooldowns[req.abilityKey] ?? 0) > 0) {
                h.manualCastRequest = null;
            } else if (world.time - (req.issuedAt ?? 0) > 0.25) {
                req.awaitingResolution = false;
                req.issuedAt = world.time;
            }
            return true;
        }
        const ability = abilities[req.abilityKey];
        if (!ability) {
            h.manualCastRequest = null;
            world.setManualCastStatus(h, "Unknown ability");
            return false;
        }

        if (ability.category === "utility") {
            const gate = world.evaluateAbilityUse(h, req.abilityKey, h);
            if (!gate.ok) {
                world.setManualCastStatus(h, `Cast failed: ${gate.reason}`);
                h.manualCastRequest = null;
                return true;
            }
            h.intent.abilityKey = req.abilityKey;
            h.intent.targetId = h.id;
            h.intent.aimAt = { x: h.pos.x, z: h.pos.z };
            world.setManualCastStatus(h, `${ability.name} cast`);
            req.awaitingResolution = true;
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
            world.setManualCastStatus(h, "No target");
            h.manualCastRequest = null;
            return true;
        }

        const gate = world.evaluateAbilityUse(h, req.abilityKey, target);
        if (!gate.ok) {
            if (gate.reason === "out of range") {
                const dx = target.pos.x - h.pos.x;
                const dz = target.pos.z - h.pos.z;
                const n = norm2D(dx, dz);
                h.intent.move = { x: n.x, z: n.z };
                h.intent.aimAt = { x: target.pos.x, z: target.pos.z };
                world.setManualCastStatus(h, `${ability.name}: moving into range`);
                return true;
            }
            world.setManualCastStatus(h, `Cast failed: ${gate.reason}`);
            h.manualCastRequest = null;
            return true;
        }

        h.intent.abilityKey = req.abilityKey;
        h.intent.targetId = target.id;
        h.intent.aimAt = { x: target.pos.x, z: target.pos.z };
        world.setManualCastStatus(h, `${ability.name} cast`);
        req.awaitingResolution = true;
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
    getBiomeKeyAt(x, z) {
        const n = Math.sin(x * 0.004) + Math.cos(z * 0.005) + Math.sin((x + z) * 0.0025);
        if (n < -1.0) return "desert";
        if (n < -0.2) return "plains";
        if (n < 0.45) return "forest";
        if (n < 1.15) return "stormfield";
        return "volcanic";
    },
    getBiomeAt(x, z) {
        const key = this.getBiomeKeyAt(x, z);
        return { key, ...biomeDefs[key] };
    },
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

        this.petIds = [null, null, null];
        this.partyOwnedIds = [null, null, null];
        this.selectAll = false;
        this.activePetIndex = 0;
        this.commandTargetId = null;
        this.stance = "aggressive";
        this.selectedItemKey = null
        this.selectedItemIndex = 0
        this.itemBar =  ['berry_red', 'battery_seed', "lure_meat", "revive_berry"]
        this.inventory = { berry_red: 10, battery_seed: 5, lure_meat: 5, revive_berry: 3};
        this.reserveOwnedIds = [];
        this.selectedReserveIndex = 0;
        this.ownedCreatures = [];
        this.lastLog = "";
        this.autoFollowActive = true;
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
    update(dt, input, world) {
        let mx = 0;
        let mz = 0;
        if (input.isDown("KeyW")) mz -= 1;
        if (input.isDown("KeyD")) mx += 1;
        if (input.isDown("ArrowLeft")) mx -= 1;
        if (input.isDown("ArrowRight")) mx += 1;
        if (input.isDown("ArrowUp")) mz -= 1;
        if (input.isDown("ArrowDown")) mz += 1;
        const mv = norm2D(mx, mz);
        this.vel.x = mv.x * this.spd;
        this.vel.z = mv.z * this.spd;
        this.pos.x = clamp(this.pos.x + this.vel.x * dt, 0, world.width);
        this.pos.z = clamp(this.pos.z + this.vel.z * dt, 0, world.height);

        if (input.consumePress("Digit1")) this.activePetIndex = 0;
        if (input.consumePress("Digit2")) this.activePetIndex = 1;
        if (input.consumePress("Digit3")) this.activePetIndex = 2;
        if (input.consumePress("Digit4")) {
            this.selectAll = !this.selectAll;
            this.lastLog = this.selectAll ? "All Pets Selected" : `Pet ${this.activePetIndex + 1} selected`;
        }
        // if (input.consumePress("KeyQ")) {
        //     this.stance = this.stance === "aggressive" ? "follow" : this.stance === "follow" ? "hold" : "aggressive";
        //     this.lastLog = `Stance: ${this.stance}`;
        // }
        // if (input.consumePress("KeyR")) {
        //     world.commandAllPets({ type: "follow", issuedAt: world.time });
        //     this.lastLog = "Regroup all pets";
        // }
        // if (input.consumePress("KeyH")) {
        //     world.commandPets(this.targetPetIds, { type: "hold", issuedAt: world.time });
        //     this.lastLog = "Active pet: hold";
        // }
        // if (input.consumePress("KeyF")) {
        //     world.commandPets(this.targetPetIds, { type: "follow", issuedAt: world.time });
        //     this.lastLog = "Active pet: follow";
        // }
        // Item keys: Z/X/C on active pet; V attempts tame on selected wild target. 
        if (input.consumePress("KeyQ")) this.cycleItem(-1);
        if (input.consumePress("KeyE")) this.cycleItem(1);
        if (input.consumePress("KeyZ")) world.useSelectedItem();
        if (input.consumePress("KeyA")) world.queueManualCast(0);
        if (input.consumePress("KeyS")) world.queueManualCast(1);

        if (input.consumePress("KeyF")) world.tryInteractNearestNode();
        if (input.consumePress("BracketLeft")) this.selectedReserveIndex = Math.max(0, this.selectedReserveIndex - 1);
        if (input.consumePress("BracketRight")) this.selectedReserveIndex += 1;
        if (input.consumePress("KeyT")) world.swapActiveWithReserve(this.selectedReserveIndex);

        const worldPos = world.camera.screenToWorld(input.mouse.x, input.mouse.y);
        if (input.consumeMouseLeftPress()) {
            const target = world.findNearestEnemyToPoint(worldPos.x, worldPos.z, 32);
            if (target) {
                this.commandTargetId = target.id;
                world.commandPets(this.targetPetIds, { type: "attack", targetId: target.id, issuedAt: world.time });
                this.lastLog = `Attack ${target.speciesKey}`;
            }
        }
        if (input.consumeMouseRightPress()) {
            world.commandPets(this.targetPetIds, { type: "move", point: worldPos, issuedAt: world.time });
            this.commandTargetId = null;
            this.lastLog = "Move command";
        }

        if (this.autoFollowActive) {
            const activePet = world.getCreatureById(this.activePetId);
            if (activePet && activePet.lifecycle === "alive") {
                const dx = activePet.pos.x - this.pos.x;
                const dz = activePet.pos.z - this.pos.z;
                const d = Math.hypot(dx, dz);
                if (d > 60) {
                    const n = norm2D(dx, dz);
                    this.pos.x = clamp(this.pos.x + n.x * this.spd * 0.8 * dt, 0, world.width);
                    this.pos.z = clamp(this.pos.z + n.z * this.spd * 0.8 * dt, 0, world.height);
                }
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
        this.player = new PlayerEntity(this.width / 2, this.height / 2);
        this.creatures = [];
        this.factory = new CreatureFactory();
        this.spawnField = new SpawnField();

        this.nodes = [];
        this.nodeSpawnTimer = 0;

        this.floatingTexts = [];
        this.combatFx = [];
    }

    initialize(starterSpeciesKey = "dog") {
        this.camera.follow(this.player);

        const ownedStarter = this.createOwnedCreatureRecord(starterSpeciesKey);
        this.player.partyOwnedIds = [ownedStarter.ownedId, null, null];
        this.hydratePartyRuntime();
        this.spawnBiomeNodesAroundPlayer(8);
    }
    commandPets(petIds, command){
        for (const id of petIds){
            const pet = this.getCreatureById(id);
            if (!pet || pet.lifecycle !== "alive") continue;
            pet.command = {... command};
        }
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
        this.normalizeReserveSelection();
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
                c.ownedId == ownedId &&
                c.lifecycle !== "captured" &&
                c.lifecycle !== "despawned"
            );
            return runtime?.id ?? null
        });
    }

    commandActivePet(command) {
        const pet = this.getCreatureById(this.player.activePetId);
        if (!pet || pet.lifecycle !== "alive") return;
        pet.command = { ...command };
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

    evaluateAbilityUse(source, abilityKey, target) {
        const a = abilities[abilityKey];
        if (!a) return { ok: false, reason: "unknown ability" };
        if (!source || source.lifecycle !== "alive") return { ok: false, reason: "source invalid" };
        if ((source.cooldowns[abilityKey] ?? 0) > 0) return { ok: false, reason: `cooldown ${source.cooldowns[abilityKey].toFixed(1)}s` };
        if ((a.resourceUse?.stamina ?? 0) > source.currentStamina) return { ok: false, reason: "not enough stamina" };
        if ((a.resourceUse?.energy ?? 0) > source.currentEnergy) return { ok: false, reason: "not enough energy" };
        if (a.category === "utility") return { ok: true, reason: "ready" };
        if (!target || target.lifecycle !== "alive") return { ok: false, reason: "no valid target" };
        if (source.team === target.team) return { ok: false, reason: "invalid target" };
        const d = dist(source.pos.x, source.pos.z, target.pos.x, target.pos.z);
        if (d > (a.range ?? Infinity)) return { ok: false, reason: "out of range" };
        return { ok: true, reason: "ready" };
    }

    queueManualCast(slotIndex) {
        const pet = this.getCreatureById(this.player.activePetId);
        if (!pet || pet.lifecycle !== "alive") return false;
        const abilityKey = pet.moveset[slotIndex];
        if (!abilityKey) {
            this.setManualCastStatus(pet, `No move in slot ${slotIndex + 1}`);
            return false;
        }
        pet.manualCastRequest = { abilityKey, slotIndex, issuedAt: this.time };
        this.setManualCastStatus(pet, `Queued ${abilities[abilityKey]?.name ?? abilityKey}`);
        return true;
    }

    setManualCastStatus(creature, text, ttl = 1.2) {
        if (!creature) return;
        creature.manualCastStatus = { text, until: this.time + ttl };
        this.player.lastLog = text;
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
        const gate = this.evaluateAbilityUse(source, abilityKey, target);
        if (!gate.ok) return false;

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
        if (targetMode === "activePet") {
            const pet = this.getCreatureById(this.player.activePetId);
            if (!pet) return false;
            if (def.type === "revive") {
                if (pet.lifecycle !== "defeated") return false;
                pet.lifecycle = "alive"
                pet.currentHP = Math.max(1, Math.floor(pet.modifiedStats.maxHP*def.amount))
                pet.currentEnergy = Math.max(1, Math.floor(pet.modifiedStats.energy * 0.5))
                pet.currentStamina = Math.max(1, Math.floor(pet.modifiedStats.stamina * 0.5))
                this.pushFloatingText(pet.pos.x, pet.pos.z - 16, `Revived`, "#ffe38e");
                this.player.inventory[itemKey] -= 1;
                return true;
            }
            if (!pet || pet.lifecycle !== "alive") return false;
            if (def.type === "heal") {
                pet.currentHP = Math.min(pet.modifiedStats.maxHP, pet.currentHP + def.amount);
                this.pushFloatingText(pet.pos.x, pet.pos.z - 16, `+${def.amount} HP`, "#8dff9d");
            }
            if (def.type === "energy") {
                pet.currentEnergy = Math.min(pet.modifiedStats.energy, pet.currentEnergy + def.amount);
                pet.currentStamina = Math.min(pet.modifiedStats.stamina, pet.currentStamina + (def.stamina ?? 0));
                this.pushFloatingText(pet.pos.x, pet.pos.z - 16, "+energy", "#9de7ff");
            }
            if (def.type === "bait") {
                this.player.lastLog = "Bait ready - use V on weakened wild";
            }
        }

        if (targetMode === "wildTarget") {
            const t = this.getCreatureById(this.player.commandTargetId);
            if (!t || t.team !== 1 || t.lifecycle !== "alive") return false;
            const activePet = this.getCreatureById(this.player.activePetId);
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
        ctx.fillText("Reserve (Up/Down select, T swap)", reserveX + 10, reserveY + 18);

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
        ctx.fillText("Active Casts [A/S]", castPanelX + 10, castPanelY + 16);
        if (!activePet || activePet.lifecycle !== "alive") {
            ctx.fillStyle = "#bbb";
            ctx.fillText("No active pet", castPanelX + 10, castPanelY + 34);
        } else {
            for (let i = 0; i < 2; i++) {
                const abilityKey = activePet.moveset[i];
                const ability = abilities[abilityKey];
                const rowY = castPanelY + 34 + i * 24;
                if (!abilityKey || !ability) {
                    ctx.fillStyle = "#888";
                    ctx.fillText(`${i === 0 ? "A" : "S"}: (empty)`, castPanelX + 10, rowY);
                    continue;
                }
                const cd = activePet.cooldowns[abilityKey] ?? 0;
                const hasStamina = (ability.resourceUse?.stamina ?? 0) <= activePet.currentStamina;
                const hasEnergy = (ability.resourceUse?.energy ?? 0) <= activePet.currentEnergy;
                const ready = cd <= 0 && hasStamina && hasEnergy;
                let status = "READY";
                if (cd > 0) status = `CD ${cd.toFixed(1)}s`;
                else if (!hasStamina) status = "NO STAM";
                else if (!hasEnergy) status = "NO EN";
                ctx.fillStyle = ready ? "#8dff9d" : "#ffb3a1";
                ctx.fillText(`${i === 0 ? "A" : "S"}: ${ability.name} - ${status}`, castPanelX + 10, rowY);
            }
            if ((activePet.manualCastStatus?.until ?? 0) > this.time) {
                ctx.fillStyle = "#9ec7ff";
                ctx.fillText(activePet.manualCastStatus.text, castPanelX + 10, castPanelY + castPanelH - 8);
            }
        }

        const barH = 58;
        const barY = canvas.height - barH - 10;
        ctx.fillStyle = "rgba(0,0,0,0.62)";
        ctx.fillRect(10, barY, canvas.width - 20, barH);
        ctx.fillStyle = "#fff";
        ctx.fillText(`Controls: 1/2/3 pet  WASD/Arrows move  LMB target  RMB move  A/S cast  [/ ] reserve  T swap  | ${this.player.lastLog}`, 18, barY + 40);
        ctx.fillText(
            `Item: ${selectedItemDef?.name ?? "none"} x${selectedItemCount}   [ Q / E cycle ] [ Z use ]`,
            18,
            barY + 20
        )
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
