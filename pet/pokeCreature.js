const canvas = document.getElementById("canvas");
const ctx    = canvas.getContext("2d");

const consList = []

//helpers
function clamp(v,min,max){
    return Math.max(min,Math.min(max,v))
}
function deepClone(obj){
    return JSON.parse(JSON.stringify(obj))
}
function makeStats(fill = 0){
    return{
        pAtk: fill, eAtk: fill, range: fill, //melee
        maxHP:fill, spd: fill, castSpd: fill,
        size: fill, stamina: fill, energy: fill,
        recoverStamina: fill, recoverEnergy: fill,
    }
}
function addStats(a,b){
    return{
        pAtk: (a.pAtk??0) + (b.pAtk??0),
        eAtk: (a.eAtk??0) + (b.eAtk??0),
        range: (a.range??0) + (b.range??0),
        maxHP: (a.maxHP??0) + (b.maxHP??0),
        spd: (a.spd??0) + (b.spd??0),
        castSpd: (a.castSpd??0) + (b.castSpd??0),
        size: (a.size??0) + (b.size??0),
        stamina: (a.stamina??0) + (b.stamina??0),
        energy: (a.energy??0) + (b.energy??0),
        recoverStamina: (a.recoverStamina??0) + (b.recoverStamina??0), //recovers x per second
        recoverEnergy: (a.recoverEnergy??0) + (b.recoverEnergy??0),
    }
}
function multStats(a,b){
    return{
        pAtk: (a.pAtk??1) * (b.pAtk??1),
        eAtk: (a.eAtk??1) * (b.eAtk??1),
        range: (a.range??1) * (b.range??1),
        maxHP: (a.maxHP??1) * (b.maxHP??1),
        spd: (a.spd??1) * (b.spd??1),
        castSpd: (a.castSpd??1) * (b.castSpd??1),
        size: (a.size??1) * (b.size??1),
        stamina: (a.stamina??1) * (b.stamina??1),
        energy: (a.energy??1) * (b.energy??1),
        recoverStamina: (a.recoverStamina??1) * (b.recoverStamina??1),
        recoverEnergy: (a.recoverEnergy??1) * (b.recoverEnergy??1),
    }
}



//effectiveness: overall ability effectiveness against the creature, based on solid,liquid,gas 
//properties: old way of calculating extra base stats, might be defunct compared to effectiveness and hurtscale
//hurtScale: energy atk effectiveness, may include physical atks in replacement of properties
//statBoost: stat boost per 5 size units when initializing or morphing a creature
//maybe add recovery stat for stamina and energy: some soaks slow it down/speed it up/restore it for certain comps, etc
const composites = {
    animal: {
        name: "animal", effectiveness:{physical: 1, energy: 1}, 
        eHurtScale: {tempChange: 1, chem: 1, water: 0.75, electric: 1},
        pHurtScale: {pierce: 1, slash: 1, impact: 1, drill: 1},
        baselines: {temp: 0.5, water: 0, electric: 0.0, chemical: 0}, //The ratio of capacity soaks that it will bleed to.
        capacityScale: {water: 1, electric: 1, chemical: 1},
        tempCapHot: 1,   // how much positive temp deviation it can absorb per size unit
        tempCapCold: 1,  // how much negative temp deviation it can absorb per size unit
        tempThresholds: {hot: 0.7, cold: 0.3},
        statBoost: {pAtk: 1, eAtk: 0, maxHP:1, spd: 0},
        specialEffects: []
    },
    plant: {
        name: "plant", effectiveness:{physical: 1, energy: 1}, 
        eHurtScale: {tempChange: 1.5, chem: 1, water: 0.75, electric: 1},
        pHurtScale: {pierce: 1, slash: 1, impact: 1, drill: 1},
        baselines: {temp: 0.5, water: 0.1, electric: 0.1, chemical: 0},
        capacityScale: {water: 1, cold: 1, hot: 1, electric: 1, chemical: 1}, //per 1 size unit
        tempThresholds: {hot: 0.6, cold:0.4},
        statBoost: {maxHP:1, pAtk: 1, eAtk: 0, spd: 0},
        specialEffects: ["waterHeal"]
    },
    water: {
        name: "water", effectiveness:{physical: 0.75, energy: 1.25}, 
        eHurtScale: {tempChange: 1.25, chem: 1, water: 0.75, electric: 1.5},
        pHurtScale: {pierce: 0.75, slash: 0.75, impact: 1.25, drill: 1},
        baselines: {temp: 0.5, water: 1, electric: 0, chemical: 0},
        capacityScale: {water: 2, cold: 1, hot: 1, electric: 2, chemical: 1},
        tempThresholds: {hot: 0.7, cold:0.3},
        statBoost: {maxHP:2, pAtk: 0, eAtk: 2, spd: 1},
        specialEffects: ["waterAdd"]
    },
    voltage: {
        name: "voltage", effectiveness:{physical: 1.5, energy: 0.75}, 
        eHurtScale: {tempChange: 0.5, chem: 0.5, water: 0.5, electric: 0.5},
        pHurtScale: {pierce: 1, slash: 1, impact: 1, drill: 1},
        baselines: {temp: 0.5, water: 0, electric: 1, chemical: 0},
        capacityScale: {water: 1, cold: 0.5, hot: 0.5, electric: 2, chemical: 1},
        tempThresholds: {hot: 1, cold:0.0},
        statBoost: {maxHP:0, pAtk: 0, eAtk: 3, spd: 3},
        specialEffects: ["waterVolt"]
    },
    fire: {
        name: "fire", effectiveness:{physical: 0.5, energy: 1.75}, 
        eHurtScale: {tempChange: 1.5, chem: 0.5, water: 1.5, electric: 0.5},
        pHurtScale: {pierce: 1, slash: 1, impact: 1, drill: 1},
        baselines: {temp: 0.9, water: 0, electric: 1, chemical: 0},
        capacityScale: {water: 1, cold: 3, hot: 1, electric: 1, chemical: 1},
        tempThresholds: {hot: 1, cold:0.8},
        statBoost: {maxHP:0, pAtk: 0, eAtk: 3, spd: 3},
        specialEffects: ["fireUp", "burnoff"]
    },
    frost: {
        name: "frost", effectiveness:{physical: 0.5, energy: 0.75},
        eHurtScale: {tempChange: 1.5, chem: 0.25, water: 0.75, electric: 0.75},
        pHurtScale: {pierce: 1, slash: 1, impact: 1, drill: 1},
        baselines: {temp: 0.1, water: 0, electric: 0, chemical: 0},
        capacityScale: {water: 1, electric: 0.5, chemical: 0.5},
        tempCapHot: 2,   // large — tolerates a lot of heat before threshold
        tempCapCold: 2,
        tempThresholds: {hot: 0.3, cold: 0},
        statBoost: {maxHP:3, pAtk: 2, eAtk: 2, spd: 0},
        specialEffects: []
    },
    lava: {
        name: "lava", effectiveness:{physical: 0.75, energy: 0.75},
        eHurtScale: {tempChange: 0.5, chem: 0.25, water: 1.5, electric: 0.5},
        pHurtScale: {pierce: 0.75, slash: 0.75, impact: 1.25, drill: 1},
        baselines: {temp: 0.9, water: 0, electric: 0, chemical: 0},
        capacityScale: {water: 1, cold: 2, hot: 2, electric: 0.5, chemical: 0.5},
        tempThresholds: {hot: 1, cold:0.8},
        statBoost: {maxHP:3, pAtk: 2, eAtk: 2, spd: 0},
        specialEffects: ["waterHarden", "fireUp", "burnoff"]
    },
    ice: {
        name: "ice", effectiveness:{physical: 0.75, energy: 0.75},
        eHurtScale: {tempChange: 1.5, chem: 0.25, water: 1, electric: 0.5},
        pHurtScale: {pierce: 1.5, slash: 0.75, impact: 1.75, drill: 1},
        baselines: {temp: 0.2, water: 0, electric: 0, chemical: 0},
        capacityScale: {water: 1, cold: 2, hot: 2, electric: 0.5, chemical: 0.5},
        tempThresholds: {hot: 0.3, cold:0},
        statBoost: {maxHP:3, pAtk: 2, eAtk: 2, spd: 0},
        specialEffects: ["waterHarden", "solidIce"]
    },
    rock: {
        name: "rock", effectiveness:{physical: 1, energy: 0.5},
        eHurtScale: {tempChange: 0.5, chem: 0.25, water: 1.5, electric: 0.25},
        pHurtScale: {pierce: 0.5, slash: 0.5, impact: 1.25, drill: 1.5},
        baselines: {temp: 0.9, water: 0, electric: 0, chemical: 0},
        capacityScale: {water: 1, cold: 1, hot: 1, electric: 1, chemical: 1},
        tempThresholds: {hot: 0.7, cold:0.3},
        statBoost: {maxHP:3, pAtk: 5, eAtk: 0, spd: 0},
        specialEffects: ["hardSurface"]
    },
    metal: {
        name: "metal", effectiveness:{physical: 0.75, energy: 1.25},
        eHurtScale: {tempChange: 0.5, chem: 0.5, water: 1, electric: 0.25},
        pHurtScale: {pierce: 0.5, slash: 0.5, impact: 1.25, drill: 1},
        baselines: {temp: 0.5, water: 0, electric: 0, chemical: 0},
        capacityScale: {water: 1, electric: 1.5, chemical: 0.5},
        tempCapHot: 1.5, tempCapCold: 0.5,
        tempThresholds: {hot: 0.8, cold: 0.2},
        statBoost: {pAtk: 3, eAtk: 0, maxHP: 2, spd: 0},
        specialEffects: []
    },
}

const tempStates = {
    sweltering: { effect: "melt", vulnerability: ["slash", "pierce", "drill"] },
    freezing:   { effect: "brittle", vulnerability: ["impact"] },
    normal:     { effect: "none", vulnerability: [] }
}
//might rework to make effects return functions for additional tick
const soakEffects = {
    water:    {name: "water",    effect: "none",   vulnerability: ["electric"], boost: "none",   per: 1},
    electric: {name: "electric", effect: "damage", vulnerability: [],           boost: "energy", per: 1},
    chemical: {name: "chemical", effect: "damage", vulnerability: [],           boost: "none",   per: 1},
}
const specialEffects = {
    waterVolt: {
        name: "Retain Voltage With Water",
        desc: "When soaked with water, retain electricity. Reduces physical attack effectiveness against creature by 0.25.",
        effect: null //put in function later for additional creature tick
    },
    waterHarden: {
        name: "Water Hardening",
        desc: "When soaked with water, solidify magma. The igneous rock boosts HP but reduces speed and energy attacks.",
        effect: null,
    },
    waterCrystal: {
        name: "Water Crystalized",
        desc: "When soaked with water, consume at a rate based on size to crystalize it as max HP.",
        effect: null,
    },
    solidIce: {
        name: "Solid Ice",
        desc: "When current temperature is scaled under 0.1, nullify all soak damage over time and vulnerability"
    },
    waterAdd: {
        name: "Water On Water",
        desc: "When soaked with water, add flat HP per water units."
    },
    waterHeal: {
        name: "Water Healing",
        desc: "Instead of normal water soak depletion, the creature consumes it to heal 1 health per 1 water unit"
    },
    fireUp: {
        name: "Fired up",
        desc: "When gaining heat, boost energy attacks from this creature."
    },
    burnoff: {
        name: "Burnoff",
        desc: "All soaks burn off twice as fast on this creature."
    },
    hardSurface:{
        name:"Hard Surface",
        desc: "All non-temperature soaks are consumed instantly as half damage on this creature"
    }
}
const abilities = {
    ram: {
        name: "Ram", category: "melee", flatDmg: {p: 10, e: 0}, dmgScale: {p: 0.5, e: 0}, cooldown: 100, resourceUse: {stamina: 10, energy: 0},
        effects: [], soakAdd: [], args: {maxCastRange:25, dash: {spd: 10, decay: "none"}, radius:10}//life? maybe until it actually hits
    },
    frostAOEInst: {
        name: "Frost Churn", category: "AOEInstant", flatDmg: {p: 0, e: 5}, dmgScale: {p: 0, e: 0.75}, cooldown: 200, resourceUse: {stamina: 0, energy: 15},
        effects: [], soakAdd: [{}], args: {delayStart:10, maxCastRange:50, radius:50, pos: "fixed"} //args arbitrary until theres a function/class to process it
    },
    frostAOELinger: {
        name: "Frost Wind", category: "AOELinger", flatDmg: {p: 0, e: 1}, dmgScale: {p: 0, e: 0.2}, cooldown: 200, resourceUse: {stamina: 0, energy: 15},
        effects: [], soakAdd: [], args: {delayStart:0, maxCastRange:50, radius:50, pos: "anchorToEntity", dps: 20, life: 100} //just for planning, etc
    },
    zap: {
        name: "Zap", category: "Hitscan", flatDmg: {p: 0, e: 20}, dmgScale: {p: 0, e: 0.8}, cooldown: 100, resourceUse: {stamina: 0, energy: 5},
        effects: [], soakAdd: [{electric:3}], args: {}
    },
    stonethrow: {
        name: "StoneThrow", category: "Projectile", flatDmg: {p: 2, e: 0}, dmgScale: {p: 0.2, e: 0}, cooldown: 300, resourceUse: {stamina: 2, energy: 0},
        effects: [], soakAdd: [], args: {}
    },
    magnetThrow:{
        name: "StoneThrow", category: "ProjectileSeek", flatDmg: {p: 2, e: 0}, dmgScale: {p: 0.2, e: 0}, cooldown: 300, resourceUse: {stamina: 2, energy: 0},
        effects: [], soakAdd: [], args: {}
    }
}
const temporary = { //lazy
    baseStats: {pAtk: 10, eAtk: 0, maxHP:100, spd: 40, castSpd: 100, range: 10, size: 10, stamina: 20, energy: 0},
    morphStats: {pAtk: 10, eAtk: 0, maxHP:100, spd: 40, castSpd: 100, range: 10, size: 10, stamina: 20, energy: 0},
    maxVariation: {pAtk: 5, eAtk: 5, maxHP:20, spd: 40, castSpd: 50, range: 0, size: 5, stamina: 10, energy: 10},
    levelUp: {pAtk: 2, eAtk: 2, maxHP:10, spd: 5, castSpd: 10, range: 1, size: 1, stamina: 5, energy: 5},
    baseMoveset: ["ram", "stonethrow"]
}
const species = {
    dog: {
        name: "Dog", baseStats: temporary.baseStats, maxVariation: temporary.maxVariation,
        levelUpBoost: temporary.levelUp, baseMoveset: temporary.baseMoveset,
        commonComp: {inner: ["animal"], outer: ["animal"]},
        morphs: { 
            stage1: { //add stuff for more base stats
                armoredDog: {name:"Steel Dog", composite: {inner: "animal", outer:"metal"}, morphPointsNeeded: [{metal: 50}], morphNeeded: "none",
                    baseStats: temporary.morphStats, allowedMoves: []
                },
                cyberDog: {name:"Cyber Dog", composite: {inner: "metal", outer:"animal"}, morphPointsNeeded: [{metal: 20}, {electric:20}],morphNeeded: "none",
                    baseStats: temporary.morphStats, allowedMoves: []
                },
            },
            stage2: {} //probably more base stats, allowed moves
        }
    },
    shrubling: {
        name: "Shrubling", baseStats: temporary.baseStats, maxVariation: temporary.maxVariation,
        levelUpBoost: temporary.levelUp,  baseMoveset: temporary.baseMoveset,
        commonComp: {inner: ["plant"], outer: ["plant"]}
    },
}

// global stuff
class TimeManager {
    constructor() {this.systems = [];}
    add(system) {this.systems.push(system);}
    remove(system) {this.systems = this.systems.filter(s => s !== system);}
    update(dt) {
        for (const s of this.systems) {
            if (s && typeof s.update === "function") s.update(dt);            
        }
    }
}
class Space {
    constructor(width, height) {
        this.width  = width;
        this.height = height;
    }
    clamp(x, z) {return {x: Math.max(0, Math.min(this.width,  x)),z: Math.max(0, Math.min(this.height, z))};}
    randomPoint() {return {x: Math.random() * this.width,z: Math.random() * this.height};
    }
}
class Camera {
    constructor() {
        this.x      = 0;
        this.z      = 0;
        this.zoom   = 3;
        this.target = null;
    }
    follow(entity) {this.target = entity;}
    worldToScreen(x, z) {return {sx: (x - this.x) * this.zoom + canvas.width  / 2,sz: (z - this.z) * this.zoom + canvas.height / 2};}
    screenToWorld(sx, sz) {return {x: (sx - canvas.width  / 2) / this.zoom + this.x,z: (sz - canvas.height / 2) / this.zoom + this.z};}
    update(dt) {
        if (!this.target) return;
        const lerp = 10 * dt;
        this.x += (this.target.pos.x - this.x) * lerp;
        this.z += (this.target.pos.z - this.z) * lerp;
    }
}
function toScreen(wx, wz, camera) {
    return {
        sx: (wx - camera.x) * camera.zoom + canvas.width  / 2,
        sz: (wz - camera.z) * camera.zoom + canvas.height / 2,
    };
}
class SpawnField {
    constructor(world, player, options = {}) {
        this.world  = world;
        this.player = player;
        this.radius          = options.radius || 120;
        this.innerNoSpawn    = options.innerNoSpawn || 40; 
        this.maxWild         = options.maxWild || 6;
        this.spawnInterval   = options.spawnInterval || 2.5;
        this.timer = 0;
        this.speciesPool = options.speciesPool || ["dog", "shrubling"];
    }
    update(dt) {
        this.timer += dt;
        if (this.timer >= this.spawnInterval) {this.timer = 0;this.trySpawn();}
        this.cleanup();
    }
    trySpawn() {
        const currentWild = this.world.entities.filter(e => e instanceof WildEntity).length;
        if (currentWild >= this.maxWild) return;
        const speciesKey = this.speciesPool[Math.floor(Math.random() * this.speciesPool.length)];
        const pos = this.randomSpawnPoint();
        if (!pos) return;
        const factory = new CreatureFactory(speciesKey, "wild", 0, 1);
        const creature = factory.createEntity();
        this.world.addEntity(new WildEntity(this.world, creature, pos.x, pos.z));
    }
    randomSpawnPoint() {
        const px = this.player.x;
        const pz = this.player.z;
        for (let i = 0; i < 10; i++) {
            const angle = Math.random() * Math.PI * 2;
            const dist  = this.innerNoSpawn + Math.random() * (this.radius - this.innerNoSpawn);
            const x = px + Math.cos(angle) * dist; const z = pz + Math.sin(angle) * dist;
            if (x < 0 || x > this.world.space.width) continue;
            if (z < 0 || z > this.world.space.height) continue;
            return { x, z };
        }
        return null;
    }
    cleanup() {
        const px = this.player.x;
        const pz = this.player.z;
        this.world.entities = this.world.entities.filter(e => {
            if (!(e instanceof WildEntity)) return true;
            const dx = e.x - px;
            const dz = e.z - pz;
            const dist = Math.hypot(dx, dz);

            if (dist > this.radius * 1.8) { 
                return false; 
            }
            return true;
        });
    }
}
const MorphService = {
    canMorph(creature, morphKey) {
        const spec = species[creature.species];
        const morph = spec.morphs.stage1[morphKey]; // check stage
        if (!morph) return false;
        return morph.morphPointsNeeded.every(req => {
            const [mat, amt] = Object.entries(req)[0];
            return (creature.morphPoints?.[mat] ?? 0) >= amt;
        });
    },
    applyMorph(creature, morphKey) {
        if (!MorphService.canMorph(creature, morphKey)) return false;
        const spec = species[creature.species];
        const morph = spec.morphs.stage1[morphKey];
        creature.composites = deepClone(morph.composite);
        creature.morphPath = morphKey;
        creature.morphStage = 1;

        const allComps = [morph.composite.inner, morph.composite.outer]; // strings, not arrays
        const factory = new CreatureFactory(creature.species, null, creature.team, 1);
        creature.soakCap      = factory.initSoakCaps(creature.baseStats.size, allComps);
        const tempCaps        = factory.initTempCaps(creature.baseStats.size, allComps);
        creature.tempCapHot   = tempCaps.hot;
        creature.tempCapCold  = tempCaps.cold;
        creature.soakBaseline = factory.initSoakBaselines(allComps);
        creature.tempRatio    = factory.calcTempRatio(creature);
        
        recomputeModifiedStats(creature);
        return true;
    }
};
const LevelService = {
    ensure(creature) {
        if (!creature.level)   creature.level = 1;
        if (!creature.xp)      creature.xp = 0;
        if (!creature.nextXP)  creature.nextXP = 10;
        if (!creature.baseStats) {
            creature.baseStats = { ...creature.stats };
        }
    },
    xpNeeded(level) {
        return 10 * level; // same simple curve
    },
    recomputeStats(creature) {
        recomputeModifiedStats(creature);
    },
    addXP(creature, amount) {
        if (amount <= 0) return;
        LevelService.ensure(creature);
        creature.xp += amount;
        while (creature.xp >= creature.nextXP) {
            creature.xp -= creature.nextXP;
            creature.level += 1;
            creature.nextXP = LevelService.xpNeeded(creature.level);
            LevelService.recomputeStats(creature);
        }
    }
};
function recomputeModifiedStats(creature) {
    const base = creature.baseStats;
    const L = creature.level ?? 1;
    const spec = species[creature.species];

    // level bonus scales species.levelUpBoost per level gained
    const lvlBonus = makeStats(0);
    for (const key in lvlBonus) {
        lvlBonus[key] = (spec.levelUpBoost?.[key] ?? 0) * (L - 1);
    }

    // morph bonus from composite statBoosts if morphed
    let morphBonus = makeStats(0);
    if (creature.morphPath) {
        const stageKey = `stage${creature.morphStage}`;
        const morph = spec.morphs?.[stageKey]?.[creature.morphPath];
        if (morph) {
            const allComps = [morph.composite.inner, morph.composite.outer];
            const size = base.size + lvlBonus.size; // use grown size for scaling
            allComps.forEach(compKey => {
                const comp = composites[compKey];
                if (!comp?.statBoost) return;
                const multiplier = size / 5;
                const boost = Object.fromEntries(
                    Object.entries(comp.statBoost).map(([k, v]) => [k, v * multiplier])
                );
                morphBonus = addStats(morphBonus, boost);
            });
        }
    }

    creature.modifiedStats = addStats(addStats(base, lvlBonus), morphBonus);
    creature.currentHP = Math.min(creature.currentHP, creature.modifiedStats.maxHP);
}

//Creature
let newID = 0
class Creature{
    constructor(pos, species, team){
        this.pos = pos; this.vel = {x:0,z:0};
        this.angle = 0; this.angVel = 0; //in rads rn
        this.species = species;
        this.team = team; this.id = newID++; this.isDead = false;

        this.baseStats = makeStats();
        this.modifiedStats = makeStats();
        this.composites = null; this.morphStage = 0;
        this.soaks =        { water: 0, electric: 0, temp: 0, chemical: 0 }
        this.soakCap =      { water: 0, electric: 0, chemical: 0 }
        this.soakBaseline = { water: 0, electric: 0, temp: 0, chemical: 0 }
        this.tempCapHot  = 0;   // max positive temp deviation
        this.tempCapCold = 0;   // max negative temp deviation (stored as positive)
        this.tempRatio   = null; // derived each tick
    }
    tick(world, dt) {
        if (this.isDead) return;
        if (!this.abilityManager) return;

        this.abilityManager.tick(dt);

        this.currentStamina = Math.min(
            this.modifiedStats?.stamina ?? 0,
            (this.currentStamina ?? 0) + (this.recovery?.stamina ?? 0) * dt
        );
        this.currentEnergy = Math.min(
            this.modifiedStats?.energy ?? 0,
            (this.currentEnergy ?? 0) + (this.recovery?.energy ?? 0) * dt
        );
        const intent = this.intent;
        if (!intent) return;
        const spd = this.modifiedStats?.spd ?? 0;
        this.vel.x = intent.move.x * spd;
        this.vel.z = intent.move.z * spd;
        this.pos.x += this.vel.x * dt;
        this.pos.z += this.vel.z * dt;

        this.pos.x = clamp(this.pos.x, 0, 1000);
        this.pos.z = clamp(this.pos.z, 0,1000);

        if (intent.move.x !== 0 || intent.move.z !== 0) {
            this.angle = Math.atan2(intent.move.z, intent.move.x);
        }
        // Fire ability if brain chose one
        if (intent.ability && intent.aimAt) {
            this.abilityManager.use(intent.ability, world, intent.aimAt);
        }
    }
}
class AbilityManager {
    constructor(creature) {
        this.host      = creature;
        this.cooldowns = {};  // key → remaining cooldown (same units as abilities.cooldown)
        this.slots     = [null, null, null, null]; // up to 4 keyed ability slots
    }
    // Called by CreatureFactory after moveset is rolled
    initFromMoveset(movesetKeys) {
        this.cooldowns = {};
        this.slots = [null, null, null, null];
        movesetKeys.forEach((key, i) => {
            if (i < 4) this.slots[i] = key;
            this.cooldowns[key] = 0;
        });
        // Keep creature.cooldowns in sync for Brain compatibility
        this.host.cooldowns = this.cooldowns;
        this.host.moveset   = movesetKeys;
    }
    tick(dt) {
        for (const key in this.cooldowns) {
            if (this.cooldowns[key] > 0) {
                this.cooldowns[key] = Math.max(0, this.cooldowns[key] - dt * 100);
            }
        }
    }
    canUse(key) {
        const ability = abilities[key];
        if (!ability) return false;
        if ((this.cooldowns[key] ?? 0) > 0) return false;

        const h    = this.host;
        const cost = ability.resourceUse ?? {};
        if ((cost.stamina ?? 0) > 0 && (h.currentStamina ?? 0) < cost.stamina) return false;
        if ((cost.energy  ?? 0) > 0 && (h.currentEnergy  ?? 0) < cost.energy)  return false;

        return true;
    }

    use(key, world, aimAt, targetId) {
        if (!this.canUse(key)) return false;

        const ability = abilities[key];
        const h       = this.host;
        const cost    = ability.resourceUse ?? {};

        h.currentStamina = Math.max(0, (h.currentStamina ?? 0) - (cost.stamina ?? 0));
        h.currentEnergy  = Math.max(0, (h.currentEnergy  ?? 0) - (cost.energy  ?? 0));
        this.cooldowns[key] = ability.cooldown;
        this._execute(key, ability, world, aimAt, targetId);
        return true;
    }
    _execute(key, ability, world, aimAt) {
        const h = this.host;
        if (ability.category === "melee") {
            // Instant hit on target in range
            const rangeArg  = ability.args?.maxCastRange ?? 999;
            const castRange = ability.args?.radius ?? 20;
            const targets = this._entitiesInRadius(world, h.pos, castRange);
            for (const target of targets) {
                if (target === h || target.team === h.team) continue;
                const dmg = (ability.flatDmg?.p ?? 0)
                          + (ability.dmgScale?.p ?? 0) * (h.modifiedStats?.pAtk ?? 0);
                applyDamage(target, dmg, "physical", ability);
                break; // melee hits one target
            }

        } else if (ability.category === "Hitscan") {
            // Find target by ID for instant hit — aimAt is just the aim direction hint
            const target = world.entities.find(e => {
                const c = e.creature ?? e;
                return c.id === (h.intent?.targetId ?? -1) && !c.isDead;
            });
            if (!target) return;
            const c = target.creature ?? target;
            if (c.team === h.team) return;

            const dmg = (ability.flatDmg?.p ?? 0)
                    + (ability.dmgScale?.p ?? 0) * (h.modifiedStats?.pAtk ?? 0)
                    + (ability.flatDmg?.e ?? 0)
                    + (ability.dmgScale?.e ?? 0) * (h.modifiedStats?.eAtk ?? 0);
            applyDamage(c, dmg, ability.flatDmg?.p > 0 ? "physical" : "energy", ability);

            for (const soakMap of (ability.soakAdd ?? [])) {
                for (const [soakType, amount] of Object.entries(soakMap)) {
                    applySoak(c, soakType, amount);
                }
            }
        } else if (ability.category === "AOEInstant") {
            const radiusArg = ability.args?.find(a => a.radius !== undefined);
            const radius    = radiusArg?.radius ?? 40;
            const targets   = this._entitiesInRadius(world, aimAt ?? h.pos, radius);

            for (const target of targets) {
                if (target === h || target.team === h.team) continue;
                const dmg = (ability.flatDmg?.e ?? 0)
                          + (ability.dmgScale?.e ?? 0) * (h.modifiedStats?.eAtk ?? 0);
                applyDamage(target, dmg, "energy", ability);
            }
        }
    }

    _entitiesInRadius(world, center, radius) {
        const cx = center?.x ?? 0;
        const cz = center?.z ?? 0;
        const results = [];
        for (const e of world.entities ?? []) {
            const ex = e.creature?.pos?.x ?? e.pos?.x ?? e.x ?? 0;
            const ez = e.creature?.pos?.z ?? e.pos?.z ?? e.z ?? 0;
            if (Math.hypot(ex - cx, ez - cz) <= radius) results.push(e.creature ?? e);
        }
        return results;
    }
}
function applyDamage(target, amount, type, ability) {
    if (amount <= 0 || target.isDead) return;

    let scale = 0;
    const comps = getCompositeList(target);
    for (const key of comps) {
        scale += (type === "physical")
            ? (composites[key].effectiveness?.physical ?? 1)
            : (composites[key].effectiveness?.energy   ?? 1);
    }
    scale /= comps.length;
    const finalDmg = amount * scale;
    target.currentHP = Math.max(0, (target.currentHP ?? 0) - finalDmg);
    if (target.currentHP <= 0) target.isDead = true;
}
function applySoak(target, soakType, amount) {
    if (!(soakType in (target.soaks ?? {}))) return;
    const cap = target.soakCap?.[soakType] ?? 0;
    target.soaks[soakType] = Math.min(cap, (target.soaks[soakType] ?? 0) + amount);
}
function getCompositeList(creature) {
    const c = creature.composites;
    if (!c) return [];
    const inner = Array.isArray(c.inner) ? c.inner : [c.inner];
    const outer = Array.isArray(c.outer) ? c.outer : [c.outer];
    return [...inner, ...outer];
}
function getTempState(creature) {
    const ratio = creature.tempRatio; // baseline + offset
    const thresholds = getCompositeThresholds(creature); // averaged across composites
    if (ratio >= thresholds.hot) return "sweltering";
    if (ratio <= thresholds.cold) return "freezing";
    return "normal";
}
function getCompositeThresholds(creature) {
    const inner = Array.isArray(creature.composites.inner) 
        ? creature.composites.inner : [creature.composites.inner];
    const outer = Array.isArray(creature.composites.outer) 
        ? creature.composites.outer : [creature.composites.outer];
    const comps = [...inner, ...outer];
    let hot = 0, cold = 0;
    comps.forEach(key => {
        hot  += composites[key].tempThresholds.hot;
        cold += composites[key].tempThresholds.cold;
    });
    return { hot: hot / comps.length, cold: cold / comps.length };
}
//ufncion or class?
class CreatureFactory{
    constructor(speciesKey, origin, teamNumber, amtOfTeams){
        this.type = speciesKey;
        this.origin = origin;
        this.teamNumber = teamNumber;
        this.amtOfTeam = amtOfTeams;
    }
    spawnpoint(){
        for(let i = 0; i < 100; i++){
            let pos = {x: Math.random()*1000, z: Math.random()*1000} //placeholder, make sure to spawn within bounds and not on top of other creatures
            if(this.isValidSpawn(pos)) return pos;
        }
    }
    createEntity() {
        const spec = species[this.type];
        const comp = spec.commonComp; // {inner: [...], outer: [...]}
        const allComps = [...comp.inner, ...comp.outer];

        // 1. Roll stats
        const stats = this.rollEntityStats(this.type, allComps);

        // 2. Roll moveset
        const moveset = this.rollStarterEntityMoves(this.type);

        // 3. Build creature
        const pos = this.spawnpoint();
        const creature = new Creature(pos, this.type, this.teamNumber);

        creature.level = 1;
        creature.baseStats = stats;
        creature.modifiedStats = { ...stats };
        creature.composites = deepClone(comp);
        creature.morphStage = 0;
        creature.morphPath = null; // e.g. "armoredDog" once morphed

        // 4. Current resource pools
        creature.currentHP = stats.maxHP;
        creature.currentStamina = stats.stamina;
        creature.currentEnergy = stats.energy;

        // 5. Recovery rates (can be tweaked per composite later)
        creature.recovery = { stamina: 2, energy: 1 };

        // 6. Init soaks
        creature.soakCap      = this.initSoakCaps(stats.size, allComps);
        creature.soakBaseline = this.initSoakBaselines(allComps);
        const tempCaps        = this.initTempCaps(stats.size, allComps);
        creature.tempCapHot   = tempCaps.hot;
        creature.tempCapCold  = tempCaps.cold;
        creature.soaks        = { ...creature.soakBaseline, temp: 0 }; // temp offset starts at 0
        creature.tempRatio    = this.calcTempRatio(creature);

        // 7. Per-creature cooldown state
        creature.moveset = moveset;
        creature.cooldowns = {};
        moveset.forEach(key => creature.cooldowns[key] = 0);
        creature.abilityManager = new AbilityManager(creature);
        creature.abilityManager.initFromMoveset(moveset);

        // 8. Active status effects
        creature.statusEffects = [];
        creature.tameProgress = 0;
        creature.isDead = false; // fixed the global bug

        return creature;
    }
    initSoakCaps(size, compKeys) {
        const cap = { water: 0, electric: 0, chemical: 0 };
        compKeys.forEach(key => {
            const scale = composites[key].capacityScale;
            for (const s in cap) cap[s] += (scale[s] ?? 1) * size;
        });
        return cap;
    }
    initTempCaps(size, compKeys) {
        let hot = 0, cold = 0;
        compKeys.forEach(key => {
            const comp = composites[key];
            hot  += (comp.tempCapHot  ?? 1) * size;
            cold += (comp.tempCapCold ?? 1) * size;
        });
        return { hot, cold };
    }
    initSoakBaselines(compKeys) {
        const base = { water: 0, electric: 0, temp: 0, chemical: 0 };
        compKeys.forEach(key => {
            const bl = composites[key].baselines;
            for (const s in base) base[s] += (bl[s] ?? 0) / compKeys.length;
        });
        return base;
    }
    calcTempRatio(creature) {
        const baseline = creature.soakBaseline.temp; // e.g. 0.9 for fire
        const offset   = creature.soaks.temp;        // signed deviation
        if (offset >= 0) {
            return baseline + (offset / (creature.tempCapHot  || 1)) * (1 - baseline);
        } else {
            return baseline + (offset / (creature.tempCapCold || 1)) * baseline;
        }
    }
    rollEntityStats(speciesKey, compositesKeys) {
        const spec = species[speciesKey];
        let finalStats = addStats(spec.baseStats, this.generateVariation(spec.maxVariation));
        compositesKeys.forEach(key => {
            const comp = composites[key];
            if (comp.statBoost) {
                // If size is 10, and boost is per 5 units, mult by 2
                const multiplier = finalStats.size / 5; 
                const boost = this.scaleStats(comp.statBoost, multiplier);
                finalStats = addStats(finalStats, boost);
            }
        });
        return finalStats;
    }
    generateVariation(maxVariation) {
        const v = makeStats(0);
        for (const key in maxVariation) {
            v[key] = Math.round((Math.random() ) * (maxVariation[key] ?? 0));
        }
        return v;
    }
    scaleStats(statBoost, multiplier) {
        const out = makeStats(0);
        for (const key in statBoost) {
            out[key] = (statBoost[key] ?? 0) * multiplier;
        }
        return out;
    }
    rollStarterEntityMoves(speciesKey) {
        return [...species[speciesKey].baseMoveset];
    }
    isValidSpawn(){
        return true;
    }
}

// test
const factory = new CreatureFactory("dog", "wild", 0, 1);
const c = factory.createEntity();
console.log("base stats:", c.baseStats);
console.log("temp ratio:", c.tempRatio);

LevelService.addXP(c, 50);
console.log("after level up:", c.level, c.modifiedStats);

// force morph — bypass point check
c.morphPoints = { metal: 20, electric: 20 };
MorphService.applyMorph(c, "cyberDog");
console.log("after morph:", c.composites, c.soakCap, c.tempCapHot);

LevelService.addXP(c, 100);
console.log("after level up:", c.level, c.modifiedStats);

class TemporaryArena {
    constructor(teams, entOnEach, options = {}) {
        this.teamNumber = teams;
        this.entityOnEach = entOnEach;

        this.teamList = [];
        this.allCreatures = [];

        this.width = options.width ?? 1000;
        this.height = options.height ?? 1000;

        this.started = false;
        this.ended = false;
        this.winnerTeam = null;

        this.time = 0;
        this.round = 0;
        this.camera = { x: this.width / 2, z: this.height / 2, zoom: 0.8 };
    }
    initTeams() {
        this.teamList = [];
        this.allCreatures = [];

        for (let teamID = 0; teamID < this.teamNumber; teamID++) {
            const team = [];
            for (let j = 0; j < this.entityOnEach; j++) {
                const factory  = new CreatureFactory("dog", "arena", teamID, this.teamNumber);
                const creature = factory.createEntity();
                creature.team      = teamID;
                creature.arenaSlot = j;

                const brain = new Brain();
                brain.nature = 'aggressive'; // arena creatures always fight
                brain.attachTo(creature);

                team.push(creature);
                this.allCreatures.push(creature);
            }
            this.teamList.push(team);
        }
    }
    placeTeams() {
        const centerX = this.width / 2;
        const centerZ = this.height / 2;
        const teamRadius = Math.min(this.width, this.height) * 0.35;

        for (let teamID = 0; teamID < this.teamList.length; teamID++) {
            const team = this.teamList[teamID];
            const teamAngle = (teamID / this.teamList.length) * Math.PI * 2;

            const teamCenterX = centerX + Math.cos(teamAngle) * teamRadius;
            const teamCenterZ = centerZ + Math.sin(teamAngle) * teamRadius;
            for (let i = 0; i < team.length; i++) {
                const creature = team[i];
                const offset = (i - (team.length - 1) / 2) * 30;
                creature.pos.x = teamCenterX + Math.cos(teamAngle + Math.PI / 2) * offset;
                creature.pos.z = teamCenterZ + Math.sin(teamAngle + Math.PI / 2) * offset;
            }
        }
    }
    start() {
        this.initTeams();
        this.placeTeams();
        this.started = true;
        this.ended = false;
        this.winnerTeam = null;
        this.time = 0;
        this.round = 1;
    }
    getLivingCreatures() {
        return this.allCreatures.filter(c => !c.isDead);
    }
    getLivingTeams() {
        return this.teamList
            .map((team, index) => ({
                teamID: index,
                members: team.filter(c => !c.isDead)
            }))
            .filter(t => t.members.length > 0);
    }
    getEnemiesOf(creature) {
        return this.getLivingCreatures().filter(c => c.team !== creature.team);
    }
    findNearestEnemy(creature) {
        const enemies = this.getEnemiesOf(creature);
        if (enemies.length === 0) return null;
        let best = enemies[0];
        let bestDist = Infinity;
        for (const enemy of enemies) {
            const dx = enemy.pos.x - creature.pos.x;
            const dz = enemy.pos.z - creature.pos.z;
            const dist = Math.hypot(dx, dz);
            if (dist < bestDist) {
                bestDist = dist;
                best = enemy;
            }
        }
        return best;
    }
    checkWinner() {
        const livingTeams = this.getLivingTeams();
        if (livingTeams.length <= 1) {
            this.ended = true;
            this.winnerTeam = livingTeams.length === 1 ? livingTeams[0].teamID : null;
            return true;
        }

        return false;
    }
    step(dt) {
        if (!this.started || this.ended) return;
        this.time += dt;

        for (const creature of this.getLivingCreatures()) {
            if (creature.brain) {
                creature.brain.think(this, dt); // ← pass arena as "world", fix missing dt
            }
            creature.tick(this, dt);
        }

        this.checkWinner();
    }
    get entities() { return this.allCreatures; }
    get projectiles() { return []; }
    run(maxSteps = 1000, dt = 0.1) {
        let steps = 0;

        while (!this.ended && steps < maxSteps) {
            this.step(dt);
            this.draw()
            steps++;
        }

        return {
            ended: this.ended,
            winnerTeam: this.winnerTeam,
            steps
        };
    }
    draw(camera = this.camera) {
        const W = canvas.width, H = canvas.height;
        const zoom = camera.zoom;

        const toSX = (wx) => (wx - camera.x) * zoom + W / 2;
        const toSZ = (wz) => (wz - camera.z) * zoom + H / 2;

        // Background
        ctx.fillStyle = "#899c89";
        ctx.fillRect(0, 0, W, H);

        // Arena boundary
        const bx = toSX(0), bz = toSZ(0);
        const bw = this.width * zoom, bh = this.height * zoom;
        ctx.strokeStyle = "#555";
        ctx.lineWidth = 2;
        ctx.strokeRect(bx, bz, bw, bh);

        // Team colors — extend if you add more teams
        const teamColors = ["#4a90d9", "#e05c5c", "#5cb85c", "#f0ad4e"];

        for (const creature of this.allCreatures) {
            const sx = toSX(creature.pos.x);
            const sz = toSZ(creature.pos.z);
            const radius = Math.max(4, (creature.modifiedStats?.size ?? 10) * 0.4 * zoom);

            // Dead creatures — draw faded X
            if (creature.isDead) {
                ctx.globalAlpha = 0.3;
                ctx.strokeStyle = teamColors[creature.team] ?? "#aaa";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(sx - radius, sz - radius); ctx.lineTo(sx + radius, sz + radius);
                ctx.moveTo(sx + radius, sz - radius); ctx.lineTo(sx - radius, sz + radius);
                ctx.stroke();
                ctx.globalAlpha = 1;
                continue;
            }

            // Direction indicator (facing angle)
            const faceLen = radius + 4;
            ctx.strokeStyle = "#fff";
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(sx, sz);
            ctx.lineTo(sx + Math.cos(creature.angle) * faceLen, sz + Math.sin(creature.angle) * faceLen);
            ctx.stroke();

            // Body circle
            ctx.fillStyle = teamColors[creature.team] ?? "#888";
            ctx.beginPath();
            ctx.arc(sx, sz, radius, 0, Math.PI * 2);
            ctx.fill();

            // Target line (thin, semi-transparent)
            if (creature.brain?.targetFocus && !creature.brain.targetFocus.isDead) {
                const tx = toSX(creature.brain.targetFocus.pos.x);
                const tz = toSZ(creature.brain.targetFocus.pos.z);
                ctx.strokeStyle = "rgba(255,255,100,0.2)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(sx, sz);
                ctx.lineTo(tx, tz);
                ctx.stroke();
            }

            // HP bar
            const maxHP = creature.modifiedStats?.maxHP ?? 1;
            const hpRatio = clamp((creature.currentHP ?? 0) / maxHP, 0, 1);
            const barW = radius * 2.5, barH = 4;
            const barX = sx - barW / 2, barY = sz - radius - 10;

            ctx.fillStyle = "#333";
            ctx.fillRect(barX, barY, barW, barH);
            ctx.fillStyle = hpRatio > 0.5 ? "#5cb85c" : hpRatio > 0.25 ? "#f0ad4e" : "#e05c5c";
            ctx.fillRect(barX, barY, barW * hpRatio, barH);

            // Stamina bar (below HP, dimmer)
            const maxSt = creature.modifiedStats?.stamina ?? 1;
            const stRatio = clamp((creature.currentStamina ?? 0) / maxSt, 0, 1);
            ctx.fillStyle = "#222";
            ctx.fillRect(barX, barY + barH + 1, barW, 3);
            ctx.fillStyle = "#7ec8e3";
            ctx.fillRect(barX, barY + barH + 1, barW * stRatio, 3);

            // ID label
            ctx.fillStyle = "#fff";
            ctx.font = `${Math.max(9, 11 * zoom)}px monospace`;
            ctx.textAlign = "center";
            ctx.fillText(`#${creature.id}`, sx, sz + radius + 12);
        }

        // HUD — step/time counter
        ctx.fillStyle = "rgba(0,0,0,0.45)";
        ctx.fillRect(8, 8, 180, 48);
        ctx.fillStyle = "#eee";
        ctx.font = "12px monospace";
        ctx.textAlign = "left";
        ctx.fillText(`time:  ${this.time.toFixed(1)}s`, 16, 26);
        ctx.fillText(`alive: ${this.getLivingCreatures().length} / ${this.allCreatures.length}`, 16, 44);

        // Winner banner
        if (this.ended) {
            ctx.fillStyle = "rgba(0,0,0,0.55)";
            ctx.fillRect(0, H / 2 - 36, W, 72);
            ctx.fillStyle = "#fff";
            ctx.font = "bold 28px monospace";
            ctx.textAlign = "center";
            const msg = this.winnerTeam !== null
                ? `Team ${this.winnerTeam} wins!`
                : "Draw!";
            ctx.fillText(msg, W / 2, H / 2 + 10);
        }
    }
}
class Brain {
    constructor() {
        this.host = null;
        this.observedCreatures   = [];
        this.enemyCreatures      = [];
        this.observedProjectiles = [];
        this.enemyProjectiles    = [];

        this.type           = 'wild';
        this.mode           = 'auto';
        this.nature         = 'passive';
        this.followDistance = 0;
        this.leashDistance  = 0;
        this.aggroRange     = 60;

        this.targetFocus = null;
        this.viable      = { move: 1, fight: 1 };
        this.commit      = { target: 1, movePlan: 1, actionPlan: 1 };
        this.redecide    = false;
        this.intentRequest = this._makeEmptyIntent();
    }

    _makeEmptyIntent() {
        return { move: { x: 0, z: 0 }, ability: null, targetId: null, aimAt: null, dodge: false };
    }

    think(world, dt) {
        if (!this.host || this.host.isDead) return;
        this.intentRequest = this._makeEmptyIntent();

        this.scanEntities(world);
        this.decideTarget();
        this.decideAction();
        this.decideMovement();
        this.decideAbility(dt);
        this.writeIntoHost();
    }
    scanEntities(world) {
        this.observedCreatures   = [];
        this.enemyCreatures      = [];
        this.observedProjectiles = [];
        this.enemyProjectiles    = [];

        const h  = this.host;
        const px = h.pos?.x ?? h.x;
        const pz = h.pos?.z ?? h.z;
        const sightRange = (h.modifiedStats?.range ?? 40) * 100; // perception range

        for (const e of world.entities) {
            if (e === h || e.isDead) continue;
            const ex   = e.pos?.x ?? e.x;
            const ez   = e.pos?.z ?? e.z;
            const dist = Math.hypot(ex - px, ez - pz);
            if (dist > sightRange) continue;

            this.observedCreatures.push({ entity: e, dist });
            if (e.team !== h.team) this.enemyCreatures.push({ entity: e, dist });
        }

        for (const p of world.projectiles ?? []) {
            if (p.team === h.team) continue;
            const dist = Math.hypot((p.x - px), (p.z - pz));
            if (dist < sightRange) this.enemyProjectiles.push({ proj: p, dist });
        }
    }

    _scoreTarget(enemyEntry) {
        const { entity: e, dist } = enemyEntry;
        // Prefer hurt enemies, then close ones
        const hpRatio  = (e.currentHP ?? e.modifiedStats.maxHP) / (e.modifiedStats.maxHP || 1);
        const distNorm = dist / 200; // normalise to ~0-1 over 200 units
        return hpRatio * 0.5 + distNorm * 0.5;
    }

    decideTarget() {
        if (this.enemyCreatures.length === 0) {
            this.targetFocus = null;
            return;
        }
        if (this.targetFocus && !this.targetFocus.isDead) {
            const stillSeen = this.enemyCreatures.find(e => e.entity === this.targetFocus);
            if (stillSeen) return;
        }

        let best = null, bestScore = Infinity;
        for (const entry of this.enemyCreatures) {
            const score = this._scoreTarget(entry);
            if (score < bestScore) { bestScore = score; best = entry.entity; }
        }
        this.targetFocus = best;
    }

    decideAction() {
        const h = this.host;
        // if (!this.targetFocus || this.nature === 'passive') {
        //     this.viable.fight = 0;
        //     this.viable.move  = 1;
        //     return;
        // }
        const hpRatio = (h.currentHP ?? 1) / (h.modifiedStats?.maxHP || 1);

        if (hpRatio < 0.25) {
            this.viable.fight = -1; 
            this.viable.move  = 1;
            return;
        }

        const incomingThreat = this.enemyProjectiles.some(p => p.dist < 30);
        if (incomingThreat) this.intentRequest.dodge = true;

        this.viable.fight = 1;
        this.viable.move  = 1;
    }
    decideMovement() {
        const h  = this.host;
        const px = h.pos?.x ?? h.x;
        const pz = h.pos?.z ?? h.z;

        if (!this.targetFocus) {
            if (this.wanderEnable){
                this.intentRequest.move = { x: Math.random(), z: Math.random() };
            } else{
                this.intentRequest.move = { x: 0, z: 0 };
            }
            return;
        }

        const tx   = this.targetFocus.pos?.x ?? this.targetFocus.x;
        const tz   = this.targetFocus.pos?.z ?? this.targetFocus.z;
        const dist = Math.hypot(tx - px, tz - pz);
        const dx   = (tx - px) / (dist || 1);
        const dz   = (tz - pz) / (dist || 1);

        const attackRange = h.modifiedStats?.range ?? 20;

        if (this.viable.fight === -1) {
            // Flee: move directly away
            this.intentRequest.move = { x: -dx, z: -dz };
        } else if (dist > attackRange) {
            // Chase
            this.intentRequest.move = { x: dx, z: dz };
        } else {
            // In range — hold position
            this.intentRequest.move = { x: 0, z: 0 };
        }
    }

    decideAbility(dt) {
        if (this.viable.fight !== 1 || !this.targetFocus) return;

        const h   = this.host;
        const px  = h.pos?.x ?? h.x;
        const pz  = h.pos?.z ?? h.z;
        const tx  = this.targetFocus.pos?.x ?? this.targetFocus.x;
        const tz  = this.targetFocus.pos?.z ?? this.targetFocus.z;
        const dist = Math.hypot(tx - px, tz - pz);

        let bestKey = null, bestScore = -Infinity;

        for (const key of (h.moveset ?? [])) {
            const ability = abilities[key];
            if (!ability) continue;
            if ((h.cooldowns[key] ?? 0) > 0) continue;
            const rangeArg = ability.args?.maxCastRange ?? 999;
            const castRange = ability.args?.radius ?? 20;
            if (dist > castRange) continue;
            const cost = ability.resourceUse ?? {};
            if ((cost.stamina ?? 0) > (h.currentStamina ?? 0)) continue;
            if ((cost.energy  ?? 0) > (h.currentEnergy  ?? 0)) continue;
            const dmgScore = (ability.flatDmg?.p ?? 0)  + (ability.flatDmg?.e ?? 0)
                           + (ability.dmgScale?.p ?? 0) * (h.modifiedStats?.pAtk ?? 0)
                           + (ability.dmgScale?.e ?? 0) * (h.modifiedStats?.eAtk ?? 0);
            if (dmgScore > bestScore) { bestScore = dmgScore; bestKey = key; }
        }

        if (bestKey) {
            this.intentRequest.ability  = bestKey;
            this.intentRequest.targetId = this.targetFocus.id;
            this.intentRequest.aimAt    = { x: tx, z: tz };
        }
    }
    writeIntoHost() {
        const h = this.host;
        h.intent = { ...this.intentRequest };
    }
    attachTo(creature) {
        this.host = creature;
        creature.brain = this;
    }
}

let arena = new TemporaryArena(2, 3);
arena.start();

let lastTime = null;
function loop(ts) {
    const dt = lastTime ? Math.min((ts - lastTime) / 1000, 0.05) : 0.016;
    lastTime = ts;

    if (!arena.ended) {
        arena.step(dt);
        arena.draw();
        requestAnimationFrame(loop);
    } else {
        arena.draw(); // draw final state with winner banner
    }
}
requestAnimationFrame(loop);
