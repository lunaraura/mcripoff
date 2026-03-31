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
function makeStats(fill = 0) {
    return {
        pAtk: fill,
        eAtk: fill,
        range: fill,
        maxHP: fill,
        spd: fill,
        castSpd: fill,
        size: fill,
        stamina: fill,
        energy: fill,
        recoverStamina: fill,
        recoverEnergy: fill,
    };
}


function deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
}
function addStats(a, b) {
    return {
        pAtk: (a.pAtk ?? 0) + (b.pAtk ?? 0),
        eAtk: (a.eAtk ?? 0) + (b.eAtk ?? 0),
        range: (a.range ?? 0) + (b.range ?? 0),
        maxHP: (a.maxHP ?? 0) + (b.maxHP ?? 0),
        spd: (a.spd ?? 0) + (b.spd ?? 0),
        castSpd: (a.castSpd ?? 0) + (b.castSpd ?? 0),
        size: (a.size ?? 0) + (b.size ?? 0),
        stamina: (a.stamina ?? 0) + (b.stamina ?? 0),
        energy: (a.energy ?? 0) + (b.energy ?? 0),
        recoverStamina: (a.recoverStamina ?? 0) + (b.recoverStamina ?? 0),
        recoverEnergy: (a.recoverEnergy ?? 0) + (b.recoverEnergy ?? 0),
    };
}
function multStats(a, b) {
    return {
        pAtk: (a.pAtk ?? 1) * (b.pAtk ?? 1),
        eAtk: (a.eAtk ?? 1) * (b.eAtk ?? 1),
        range: (a.range ?? 1) * (b.range ?? 1),
        maxHP: (a.maxHP ?? 1) * (b.maxHP ?? 1),
        spd: (a.spd ?? 1) * (b.spd ?? 1),
        castSpd: (a.castSpd ?? 1) * (b.castSpd ?? 1),
        size: (a.size ?? 1) * (b.size ?? 1),
        stamina: (a.stamina ?? 1) * (b.stamina ?? 1),
        energy: (a.energy ?? 1) * (b.energy ?? 1),
        recoverStamina: (a.recoverStamina ?? 1) * (b.recoverStamina ?? 1),
        recoverEnergy: (a.recoverEnergy ?? 1) * (b.recoverEnergy ?? 1),
    };
}

/* =========================
   consolidated concept bank
   compiled from: pokeCreature, poke2, poke3, pokefull, pokeprev, pok
========================= */
const conceptBank = {
    fromPokeCreature: {
        composites: {
            animal: { effectiveness: { physical: 1, energy: 1 }, specialEffects: [] },
            water: { effectiveness: { physical: 0.75, energy: 1.25 }, specialEffects: ["waterAdd"] },
            voltage: { effectiveness: { physical: 1.5, energy: 0.75 }, specialEffects: ["waterVolt"] },
            fire: { effectiveness: { physical: 0.5, energy: 1.75 }, specialEffects: ["fireUp", "burnoff"] },
            rock: { effectiveness: { physical: 1, energy: 0.5 }, specialEffects: ["hardSurface"] },
            metal: { effectiveness: { physical: 0.75, energy: 1.25 }, specialEffects: [] },
        },
        soakEffects: {
            water: { effect: "none", vulnerability: ["electric"] },
            electric: { effect: "damage", boost: "energy" },
            chemical: { effect: "damage", boost: "none" },
        },
        specialEffects: {
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
                const dmg = burst * 0.1;
                ctx.target.currentHP = Math.max(0, ctx.target.currentHP - dmg);
                ctx.targetState.soak.chemical = 0;
                ctx.targetState.soak.electric = 0;
            },
        },
    },
    fromPoke2AndPokePrev: {
        moveCategories: ["melee", "projectile", "projectileSeek", "AOEInstant", "AOELinger", "hitscan"],
        damageLanes: ["physical", "energy"],
        compositionAxes: ["tough", "hard", "elastic", "chemResist", "electroResist", "thermCond"],
    },
    fromPoke3AndPokeFull: {
        runtimePatterns: [
            "abilityRegistryWithCooldownTable",
            "worldEntityBaseClass",
            "abilityManagerQueue",
            "projectileAndAreaEffectSpecializations",
        ],
    },
    fromPok: {
        typeChart: {
            normal: { immune: ["ghost"], weak: ["rock", "steel"], strong: [] },
            fire: { immune: [], weak: ["fire", "water", "rock", "dragon"], strong: ["grass", "ice", "bug", "steel"] },
            water: { immune: [], weak: ["water", "grass", "dragon"], strong: ["fire", "ground", "rock"] },
            electric: { immune: ["ground"], weak: ["electric", "grass", "dragon"], strong: ["water", "flying"] },
            grass: { immune: [], weak: ["fire", "grass", "poison", "flying", "bug", "dragon", "steel"], strong: ["water", "ground", "rock"] },
            ghost: { immune: ["normal"], weak: ["dark"], strong: ["ghost", "psychic"] },
            steel: { immune: [], weak: ["fire", "water", "electric", "steel"], strong: ["ice", "rock", "fairy"] },
            none: { immune: [], weak: [], strong: [] },
        },
    },
};

const TypeCoverageTools = {
    getEffectiveness(moveType, targetType) {
        const moveData = conceptBank.fromPok.typeChart[moveType];
        if (!moveData || !targetType || targetType === "none") return 1;
        if (moveData.immune.includes(targetType)) return 0;
        if (moveData.strong.includes(targetType)) return 2;
        if (moveData.weak.includes(targetType)) return 0.5;
        return 1;
    },

    scoreMoveset(moveset, encounters) {
        let total = 0;
        for (const enc of encounters) {
            let best = 0;
            for (const move of moveset) {
                const eff = this.getEffectiveness(move, enc.priType) * this.getEffectiveness(move, enc.secType);
                if (eff > best) best = eff;
            }
            total += best * (enc.amt ?? 1);
        }
        return total;
    },
};

const EffectEngine = {
    createState() {
        return {
            soak: { water: 0, electric: 0, chemical: 0, heat: 0 },
            buff: { energyBonus: 0 },
        };
    },

    tickCreature(creature, dt) {
        const compositeKey = creature.compositeKey;
        const composite = conceptBank.fromPokeCreature.composites[compositeKey] ?? conceptBank.fromPokeCreature.composites.animal;
        const effects = composite.specialEffects ?? [];
        creature.effectState.buff.energyBonus = 0;

        const ctx = {
            dt,
            target: creature,
            targetState: creature.effectState,
        };

        for (const effectKey of effects) {
            const fn = conceptBank.fromPokeCreature.specialEffects[effectKey];
            if (typeof fn === "function") fn(ctx);
        }

        const s = creature.effectState.soak;
        s.water = Math.max(0, s.water - dt * 0.25);
        s.electric = Math.max(0, s.electric - dt * 0.4);
        s.chemical = Math.max(0, s.chemical - dt * 0.35);
        s.heat = Math.max(0, s.heat - dt * 0.2);
    },

    onHit(source, target, abilityDef) {
        if (abilityDef.category === "hitscan") target.effectState.soak.electric += 0.75;
        if (abilityDef.category === "melee") target.effectState.soak.heat += 0.2;

        const bonus = 1 + (source.effectState?.buff?.energyBonus ?? 0);
        return bonus;
    },
};

/* =========================
   tiny defs
========================= */
const abilities = {
    ram: {
        name: "Ram",
        category: "melee",
        cooldown: 1.0,
        resourceUse: { stamina: 5, energy: 0 },
        flatDmg: { p: 10, e: 0 },
        dmgScale: { p: 0.4, e: 0 },
        range: 24
    },
    zap: {
        name: "Zap",
        category: "hitscan",
        cooldown: 1.2,
        resourceUse: { stamina: 0, energy: 5 },
        flatDmg: { p: 0, e: 16 },
        dmgScale: { p: 0, e: 0.7 },
        range: 120
    }
};

const species = {
    dog: {
        name: "Dog",
        baseStats: {
            pAtk: 12,
            eAtk: 2,
            range: 24,
            maxHP: 110,
            spd: 70,
            castSpd: 1,
            size: 10,
            stamina: 25,
            energy: 10,
            recoverStamina: 6,
            recoverEnergy: 3,
        },
        moveset: ["ram"]
    },
    sparkit: {
        name: "Sparkit",
        baseStats: {
            pAtk: 4,
            eAtk: 12,
            range: 100,
            maxHP: 85,
            spd: 65,
            castSpd: 1,
            size: 9,
            stamina: 16,
            energy: 24,
            recoverStamina: 4,
            recoverEnergy: 6,
        },
        moveset: ["zap"]
    }
};

/* =========================
   input
========================= */
class InputManager {
    constructor() {
        this.keys = new Map();
        this.pressed = new Map();
        this.mouse = { x: 0, y: 0, down: false, pressed: false };
    }

    bind(canvas) {
        window.addEventListener("keydown", (e) => {
            if (!this.keys.get(e.code)) this.pressed.set(e.code, true);
            this.keys.set(e.code, true);
        });
        window.addEventListener("keyup", (e) => {
            this.keys.set(e.code, false);
        });

        canvas.addEventListener("mousemove", (e) => {
            const rect = canvas.getBoundingClientRect();
            this.mouse.x = e.clientX - rect.left;
            this.mouse.y = e.clientY - rect.top;
        });

        canvas.addEventListener("mousedown", () => {
            if (!this.mouse.down) this.mouse.pressed = true;
            this.mouse.down = true;
        });

        canvas.addEventListener("mouseup", () => {
            this.mouse.down = false;
        });
    }

    isDown(code) {
        return !!this.keys.get(code);
    }

    consumePress(code) {
        const had = !!this.pressed.get(code);
        this.pressed.set(code, false);
        return had;
    }

    consumeMousePress() {
        const had = this.mouse.pressed;
        this.mouse.pressed = false;
        return had;
    }

    endFrame() {
        this.mouse.pressed = false;
        this.pressed.clear();
    }
}

/* =========================
   camera
========================= */
class Camera {
    constructor() {
        this.x = 0;
        this.z = 0;
        this.zoom = 1.6;
        this.target = null;
    }

    follow(target) {
        this.target = target;
    }

    update(dt) {
        if (!this.target) return;
        const lerp = clamp(dt * 8, 0, 1);
        this.x += (this.target.pos.x - this.x) * lerp;
        this.z += (this.target.pos.z - this.z) * lerp;
    }

    worldToScreen(x, z) {
        return {
            sx: (x - this.x) * this.zoom + canvas.width / 2,
            sz: (z - this.z) * this.zoom + canvas.height / 2,
        };
    }

    screenToWorld(sx, sz) {
        return {
            x: (sx - canvas.width / 2) / this.zoom + this.x,
            z: (sz - canvas.height / 2) / this.zoom + this.z,
        };
    }
}

/* =========================
   player
========================= */
class PlayerEntity {
    constructor(x, z) {
        this.pos = { x, z };
        this.vel = { x: 0, z: 0 };
        this.spd = 140;

        this.petIds = [];
        this.activePetIndex = 0;
        this.commandTargetId = null;
        this.stance = "aggressive"; // aggressive | hold | follow
    }

    get activePetId() {
        return this.petIds[this.activePetIndex] ?? null;
    }

    update(dt, input, world) {
        let mx = 0;
        let mz = 0;

        if (input.isDown("KeyW")) mz -= 1;
        if (input.isDown("KeyS")) mz += 1;
        if (input.isDown("KeyA")) mx -= 1;
        if (input.isDown("KeyD")) mx += 1;

        const mv = norm2D(mx, mz);
        this.vel.x = mv.x * this.spd;
        this.vel.z = mv.z * this.spd;

        this.pos.x += this.vel.x * dt;
        this.pos.z += this.vel.z * dt;

        this.pos.x = clamp(this.pos.x, 0, world.width);
        this.pos.z = clamp(this.pos.z, 0, world.height);

        if (input.consumePress("Digit1")) this.activePetIndex = 0;
        if (input.consumePress("Digit2")) this.activePetIndex = 1;
        if (input.consumePress("Digit3")) this.activePetIndex = 2;

        if (input.consumePress("KeyQ")) {
            this.stance = this.stance === "aggressive"
                ? "follow"
                : this.stance === "follow"
                ? "hold"
                : "aggressive";
        }

        if (input.consumeMousePress()) {
            const worldPos = world.camera.screenToWorld(input.mouse.x, input.mouse.y);
            const target = world.findNearestEnemyToPoint(worldPos.x, worldPos.z, 30);
            this.commandTargetId = target ? target.id : null;
        }
    }
}

/* =========================
   creature
========================= */
let NEXT_ID = 1;

class Creature {
    constructor(speciesKey, team, x, z) {
        const def = species[speciesKey];
        this.id = NEXT_ID++;
        this.speciesKey = speciesKey;
        this.team = team; // 0 = player pets, 1 = wilds
        this.pos = { x, z };
        this.vel = { x: 0, z: 0 };
        this.angle = 0;

        this.baseStats = { ...def.baseStats };
        this.modifiedStats = { ...def.baseStats };
        this.compositeKey = this.speciesKey === "sparkit" ? "voltage" : "animal";
        this.effectState = EffectEngine.createState();

        this.currentHP = this.modifiedStats.maxHP;
        this.currentStamina = this.modifiedStats.stamina;
        this.currentEnergy = this.modifiedStats.energy;

        this.moveset = [...def.moveset];
        this.cooldowns = Object.fromEntries(this.moveset.map(k => [k, 0]));

        this.isDead = false;
        this.mode = team === 0 ? "pet" : "wild"; // pet | wild
        this.brain = null;
        this.intent = this.makeEmptyIntent();
    }

    makeEmptyIntent() {
        return {
            move: { x: 0, z: 0 },
            abilityKey: null,
            targetId: null,
            aimAt: null,
        };
    }

    tick(dt, world) {
        if (this.isDead) return;

        for (const key of Object.keys(this.cooldowns)) {
            this.cooldowns[key] = Math.max(0, this.cooldowns[key] - dt);
        }

        this.currentStamina = Math.min(
            this.modifiedStats.stamina,
            this.currentStamina + this.modifiedStats.recoverStamina * dt
        );
        this.currentEnergy = Math.min(
            this.modifiedStats.energy,
            this.currentEnergy + this.modifiedStats.recoverEnergy * dt
        );
        EffectEngine.tickCreature(this, dt);

        const mv = norm2D(this.intent.move.x, this.intent.move.z);
        this.vel.x = mv.x * this.modifiedStats.spd;
        this.vel.z = mv.z * this.modifiedStats.spd;

        this.pos.x += this.vel.x * dt;
        this.pos.z += this.vel.z * dt;

        this.pos.x = clamp(this.pos.x, 0, world.width);
        this.pos.z = clamp(this.pos.z, 0, world.height);

        if (mv.x !== 0 || mv.z !== 0) {
            this.angle = Math.atan2(mv.z, mv.x);
        }

        if (this.intent.abilityKey && this.intent.targetId) {
            world.tryUseAbility(this, this.intent.abilityKey, this.intent.targetId);
        }
    }
}

/* =========================
   brain
========================= */
class Brain {
    constructor() {
        this.host = null;
        this.role = "fighter"; // fighter | ranged
    }

    attach(creature) {
        this.host = creature;
        creature.brain = this;
    }

    think(world, dt) {
        const h = this.host;
        if (!h || h.isDead) return;

        h.intent = h.makeEmptyIntent();

        if (h.mode === "pet") {
            this.thinkPet(world, dt);
        } else {
            this.thinkWild(world, dt);
        }
    }

    thinkPet(world, dt) {
        const h = this.host;
        const player = world.player;
        const activePetId = player.activePetId;
        const isActive = h.id === activePetId;
        const followAnchor = world.getPetFollowAnchor(h.id);

        let target = null;

        if (isActive && player.commandTargetId != null) {
            target = world.getCreatureById(player.commandTargetId);
            if (target?.isDead) target = null;
        }

        if (!target) {
            target = world.findNearestEnemyOf(h, 180);
        }

        if (target) {
            this.fightTarget(world, h, target, isActive);
            return;
        }

        // no target: obey stance and follow player
        if (player.stance === "hold" && !isActive) {
            h.intent.move = { x: 0, z: 0 };
            return;
        }

        const dx = followAnchor.x - h.pos.x;
        const dz = followAnchor.z - h.pos.z;
        const d = Math.hypot(dx, dz);

        if (d > 12) {
            const n = norm2D(dx, dz);
            h.intent.move = { x: n.x, z: n.z };
        }
    }

    thinkWild(world, dt) {
        const h = this.host;
        const target = world.findNearestEnemyOf(h, 140);
        if (!target) return;
        this.fightTarget(world, h, target, false);
    }

    fightTarget(world, h, target, isActive) {
        const dx = target.pos.x - h.pos.x;
        const dz = target.pos.z - h.pos.z;
        const d = Math.hypot(dx, dz);
        const n = norm2D(dx, dz);

        const preferredRange = this.role === "ranged" ? 95 : 18;
        const leash = this.role === "ranged" ? 20 : 8;

        if (d > preferredRange + leash) {
            h.intent.move = { x: n.x, z: n.z };
        } else if (d < preferredRange - leash) {
            h.intent.move = { x: -n.x, z: -n.z };
        } else {
            h.intent.move = { x: 0, z: 0 };
        }

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
                (a.dmgScale?.e ?? 0) * creature.modifiedStats.eAtk;

            if (score > bestScore) {
                bestScore = score;
                best = key;
            }
        }

        return best;
    }
}

/* =========================
   spawnfield
========================= */
class SpawnField {
    constructor(radius = 240, innerNoSpawn = 80, maxWild = 6, interval = 2.0) {
        this.radius = radius;
        this.innerNoSpawn = innerNoSpawn;
        this.maxWild = maxWild;
        this.interval = interval;
        this.timer = 0;
        this.pool = ["dog", "sparkit"];
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
        const currentWild = world.creatures.filter(c => c.mode === "wild" && !c.isDead).length;
        if (currentWild >= this.maxWild) return;

        const player = world.player;
        for (let i = 0; i < 12; i++) {
            const angle = Math.random() * Math.PI * 2;
            const d = this.innerNoSpawn + Math.random() * (this.radius - this.innerNoSpawn);
            const x = player.pos.x + Math.cos(angle) * d;
            const z = player.pos.z + Math.sin(angle) * d;

            if (x < 0 || x > world.width || z < 0 || z > world.height) continue;

            const speciesKey = this.pool[(Math.random() * this.pool.length) | 0];
            const wild = new Creature(speciesKey, 1, x, z);
            const brain = new Brain();
            brain.role = speciesKey === "sparkit" ? "ranged" : "fighter";
            brain.attach(wild);

            world.creatures.push(wild);
            return;
        }
    }

    cleanup(world) {
        const p = world.player.pos;
        world.creatures = world.creatures.filter(c => {
            if (c.mode !== "wild") return true;
            if (c.isDead) return false;

            const engaged = world.isCreatureEngaged(c);
            if (engaged) return true;

            return dist(c.pos.x, c.pos.z, p.x, p.z) < this.radius * 1.6;
        });
    }
}

/* =========================
   world
========================= */
class World {
    constructor() {
        this.width = 1400;
        this.height = 1000;

        this.camera = new Camera();
        this.player = new PlayerEntity(this.width / 2, this.height / 2);
        this.creatures = [];
        this.spawnField = new SpawnField();
    }

    initialize() {
        this.camera.follow(this.player);

        const petA = new Creature("dog", 0, this.player.pos.x - 20, this.player.pos.z + 30);
        const petB = new Creature("sparkit", 0, this.player.pos.x + 20, this.player.pos.z + 30);
        const petC = new Creature("dog", 0, this.player.pos.x, this.player.pos.z + 55);

        const b1 = new Brain(); b1.role = "fighter"; b1.attach(petA);
        const b2 = new Brain(); b2.role = "ranged";  b2.attach(petB);
        const b3 = new Brain(); b3.role = "fighter"; b3.attach(petC);

        this.creatures.push(petA, petB, petC);
        this.player.petIds = [petA.id, petB.id, petC.id];
    }

    update(dt, input) {
        this.player.update(dt, input, this);
        this.spawnField.update(dt, this);

        for (const c of this.creatures) {
            if (c.brain) c.brain.think(this, dt);
        }

        for (const c of this.creatures) {
            c.tick(dt, this);
        }

        this.resolveSimpleSeparation();
        this.removeDeadCommandTarget();
        this.camera.update(dt);
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
            { x: p.x,      z: p.z + 52 },
        ];

        return anchors[idx] ?? { x: p.x, z: p.z + 30 };
    }

    findNearestEnemyOf(creature, maxRange = Infinity) {
        let best = null;
        let bestD = Infinity;

        for (const other of this.creatures) {
            if (other.id === creature.id || other.isDead) continue;
            if (other.team === creature.team) continue;

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
            if (c.team === 0 || c.isDead) continue;
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
            if (other.id === creature.id || other.isDead) continue;
            if (other.team === creature.team) continue;
            if (dist(creature.pos.x, creature.pos.z, other.pos.x, other.pos.z) < 160) {
                return true;
            }
        }
        return false;
    }

    tryUseAbility(source, abilityKey, targetId) {
        const a = abilities[abilityKey];
        const target = this.getCreatureById(targetId);

        if (!a || !target || target.isDead || source.isDead) return false;
        if (source.team === target.team) return false;
        if ((source.cooldowns[abilityKey] ?? 0) > 0) return false;

        const d = dist(source.pos.x, source.pos.z, target.pos.x, target.pos.z);
        if (d > (a.range ?? Infinity)) return false;

        if ((a.resourceUse?.stamina ?? 0) > source.currentStamina) return false;
        if ((a.resourceUse?.energy ?? 0) > source.currentEnergy) return false;

        source.currentStamina -= a.resourceUse?.stamina ?? 0;
        source.currentEnergy -= a.resourceUse?.energy ?? 0;
        source.cooldowns[abilityKey] = a.cooldown;

        const dmg =
            (a.flatDmg?.p ?? 0) +
            (a.flatDmg?.e ?? 0) +
            (a.dmgScale?.p ?? 0) * source.modifiedStats.pAtk +
            (a.dmgScale?.e ?? 0) * source.modifiedStats.eAtk;
        const effBonus = EffectEngine.onHit(source, target, a);

        target.currentHP = Math.max(0, target.currentHP - dmg * effBonus);
        if (target.currentHP <= 0) target.isDead = true;

        return true;
    }

    removeDeadCommandTarget() {
        const id = this.player.commandTargetId;
        if (id == null) return;
        const t = this.getCreatureById(id);
        if (!t || t.isDead) this.player.commandTargetId = null;
    }

    resolveSimpleSeparation() {
        const minDist = 16;

        for (let i = 0; i < this.creatures.length; i++) {
            const a = this.creatures[i];
            if (a.isDead) continue;

            for (let j = i + 1; j < this.creatures.length; j++) {
                const b = this.creatures[j];
                if (b.isDead) continue;

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

    draw(ctx) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // ground
        ctx.fillStyle = "#89a87c";
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // map border
        const tl = this.camera.worldToScreen(0, 0);
        ctx.strokeStyle = "#3d4b36";
        ctx.lineWidth = 2;
        ctx.strokeRect(
            tl.sx,
            tl.sz,
            this.width * this.camera.zoom,
            this.height * this.camera.zoom
        );

        // player
        const ps = this.camera.worldToScreen(this.player.pos.x, this.player.pos.z);
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(ps.sx, ps.sz, 7, 0, Math.PI * 2);
        ctx.fill();

        // creatures
        for (const c of this.creatures) {
            const s = this.camera.worldToScreen(c.pos.x, c.pos.z);
            const isActive = c.id === this.player.activePetId;
            const isCommandTarget = c.id === this.player.commandTargetId;

            if (c.isDead) {
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

            // hp bar
            const hpRatio = c.currentHP / c.modifiedStats.maxHP;
            ctx.fillStyle = "#222";
            ctx.fillRect(s.sx - 14, s.sz - 18, 28, 4);
            ctx.fillStyle = hpRatio > 0.5 ? "#5ad15a" : hpRatio > 0.25 ? "#e7c04a" : "#df5a5a";
            ctx.fillRect(s.sx - 14, s.sz - 18, 28 * hpRatio, 4);
        }

        // UI
        ctx.fillStyle = "rgba(0,0,0,0.5)";
        ctx.fillRect(8, 8, 270, 72);
        ctx.fillStyle = "#fff";
        ctx.font = "12px monospace";
        ctx.fillText(`Active Pet: ${this.player.activePetIndex + 1}`, 16, 28);
        ctx.fillText(`Stance: ${this.player.stance}`, 16, 46);
        ctx.fillText(`1/2/3 switch pet, Q stance, click enemy to focus`, 16, 64);
    }
}

/* =========================
   game
========================= */
class Game {
    constructor() {
        this.input = new InputManager();
        this.world = new World();
        this.last = 0;
    }

    start() {
        this.input.bind(canvas);
        this.world.initialize();

        requestAnimationFrame((ts) => this.loop(ts));
    }

    loop(ts) {
        const dt = this.last ? Math.min((ts - this.last) / 1000, 0.05) : 0.016;
        this.last = ts;

        this.world.update(dt, this.input);
        this.world.draw(ctx);
        this.input.endFrame();

        requestAnimationFrame((next) => this.loop(next));
    }
}

const game = new Game();
game.start();
