const canvas = document.getElementById("canvas");
const ctx    = canvas.getContext("2d");

const keys = {};
//mouse x y
window.addEventListener("mousemove", e => {
    const rect = canvas.getBoundingClientRect();
    keys["mousex"] = e.clientX - rect.left;
    keys["mousey"] = e.clientY - rect.top;
});
// mouse
window.addEventListener("mousedown", e => keys["mouse"+e.button] = true);
window.addEventListener("mouseup",   e => keys["mouse"+e.button] = false);
// keyboard
window.addEventListener("keydown", e => keys[e.key.toLowerCase()] = true);
window.addEventListener("keyup",   e => keys[e.key.toLowerCase()] = false);

const solid="solid", liquid="liquid", gas="gas", plasma="plasma";
const composites = {
  stone:{name:"stone",matter:solid,tough:0.30,hard:0.8,energy:0.0,elastic:0.0,tempBaseline:0.5,chemResist:0.6,electroResist:1.0,density:0.9,porosity:0.0,thermCond:0.05,electCond:0.1},
  crystalline:{name:"crystalline",matter:solid,tough:0.15,hard:0.9,energy:0.0,elastic:0.0,tempBaseline:0.5,chemResist:0.5,electroResist:1.0,density:0.8,porosity:0.0,thermCond:0.05,electCond:0.5},
  metal:{name:"metal",matter:solid,tough:0.80,hard:0.7,energy:0.0,elastic:0.2,tempBaseline:0.5,chemResist:0.55,electroResist:0.1,density:0.95,porosity:0.05,thermCond:1.0,electCond:0.95},
  water:{name:"water",matter:liquid,tough:0.00,hard:0.00,energy:0.50,elastic:1.00,tempBaseline:0.45,chemResist:0.00,electroResist:0.10,density:0.50,porosity:0.20,thermCond:0.90,electCond:0.90},
  lava:{name:"lava",matter:liquid,tough:0.60,hard:0.20,energy:0.70,elastic:0.30,tempBaseline:1.00,chemResist:0.30,electroResist:0.60,density:0.85,porosity:0.40,thermCond:0.10,electCond:0.10},
  gas:{name:"gas",matter:gas,tough:0.00,hard:0.00,energy:0.80,elastic:1.00,tempBaseline:0.60,chemResist:0.30,electroResist:0.60,density:0.05,porosity:0.00,thermCond:0.10,electCond:0.05},
  fire:{name:"fire",matter:plasma,tough:0.00,hard:0.00,energy:0.90,elastic:1.00,tempBaseline:1.00,chemResist:0.90,electroResist:0.80,density:0.02,porosity:0.00,thermCond:0.00,electCond:0.05},
  frost:{name:"frost",matter:gas,tough:0.00,hard:0.10,energy:1.00,elastic:0.00,tempBaseline:0.00,chemResist:0.90,electroResist:0.80,density:0.06,porosity:0.00,thermCond:0.00,electCond:0.05},
  arcane:{name:"arcane",matter:plasma,tough:0.00,hard:0.00,energy:0.90,elastic:1.00,tempBaseline:1.00,chemResist:0.90,electroResist:0.50,density:0.10,porosity:0.00,thermCond:0.00,electCond:0.30},

  organicMammal:{name:"organicMammal",matter:solid,tough:0.60,hard:0.30,energy:0.20,elastic:0.70,tempBaseline:0.50,chemResist:0.20,electroResist:0.30,density:0.60,porosity:0.50,thermCond:0.40,electCond:0.45},
  organicReptile:{name:"organicReptile",matter:solid,tough:0.55,hard:0.35,energy:0.20,elastic:0.60,tempBaseline:0.55,chemResist:0.25,electroResist:0.35,density:0.62,porosity:0.45,thermCond:0.35,electCond:0.40},
  organicAmphibian:{name:"organicAmphibian",matter:solid,tough:0.50,hard:0.25,energy:0.25,elastic:0.75,tempBaseline:0.48,chemResist:0.22,electroResist:0.32,density:0.55,porosity:0.55,thermCond:0.38,electCond:0.42},
  organicBird:{name:"organicBird",matter:solid,tough:0.45,hard:0.25,energy:0.25,elastic:0.80,tempBaseline:0.48,chemResist:0.18,electroResist:0.35,density:0.45,porosity:0.55,thermCond:0.35,electCond:0.42},
  organicAnthropod:{name:"organicAnthropod",matter:solid,tough:0.40,hard:0.40,energy:0.20,elastic:0.50,tempBaseline:0.50,chemResist:0.25,electroResist:0.35,density:0.50,porosity:0.40,thermCond:0.30,electCond:0.35},

  organicAnimal:{name:"organicAnimal",matter:solid,tough:0.60,hard:0.30,energy:0.20,elastic:0.70,tempBaseline:0.50,chemResist:0.20,electroResist:0.30,density:0.60,porosity:0.50,thermCond:0.40,electCond:0.45},
  organicPlant:{name:"organicPlant",matter:solid,tough:0.40,hard:0.50,energy:0.40,elastic:0.60,tempBaseline:0.45,chemResist:0.15,electroResist:0.40,density:0.55,porosity:0.30,thermCond:0.30,electCond:0.40},
  slime:{name:"slime",matter:solid,tough:0.50,hard:0.10,energy:0.40,elastic:1.00,tempBaseline:0.40,chemResist:0.15,electroResist:0.20,density:0.40,porosity:0.60,thermCond:0.60,electCond:0.50},
  //for very late versions/iterations
  dinosaurAugments:{},
  oceanAugments:{},
  kaijuAugments:{},
  insectAugments:{},
  eldritchAugments:{},
};
const entityFamilies = {
  felidae:{baseSize:5, baseComposites:{in:"organicMammal", out:"organicMammal"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  canidae:{baseSize:10, baseComposites:{in:"organicMammal", out:"organicMammal"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  ursidae:{baseSize:10, baseComposites:{in:"organicMammal", out:"organicMammal"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  urodela:{baseSize:4, baseComposites:{in:"organicAmphibian", out:"organicAmphibian"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  anura:{baseSize:4, baseComposites:{in:"organicAmphibian", out:"organicAmphibian"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  arachnid:{baseSize:3, baseComposites:{in:"organicAnthropod", out:"organicAnthropod"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  pterygota:{baseSize:3, baseComposites:{in:"organicAnthropod", out:"organicAnthropod"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  squamata:{baseSize:3, baseComposites:{in:"organicReptile", out:"organicReptile"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  testudine:{baseSize:3, baseComposites:{in:"organicReptile", out:"organicReptile"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  columbiformes:{baseSize:3, baseComposites:{in:"organicBird", out:"organicBird"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
  accipitriformes:{baseSize:3, baseComposites:{in:"organicBird", out:"organicBird"},
    statVariation:{pAtk:{m:0.5,r:1}, eAtk:{m:0.5,r:1}, maxHP:{m:0.5,r:1}, speed:{m:0,r:1}, def:{m:0.5,r:1}, castSpd:{m:0.5,r:1}}},
};
const moveCat = {PHY: "physical", ENR: "energy"}
const moveAtkTypes = {
    blunt: {cat: moveCat.PHY, percentBypass: [], flatBypass: [{hard: 0.2}], resistedBy: [{elastic: 0.2}]},
    drill: {cat: moveCat.PHY, percentBypass: [], flatBypass: [{tough: 0.2}, {hard: 0.2}], resistedBy: [{porosity: 0.2}]},
    pierce: {cat: moveCat.PHY, percentBypass: [], flatBypass: [{porosity: 0.3}], resistedBy: [{hard: 0.3}]},
    slice: {cat: moveCat.PHY, percentBypass: [], flatBypass: [{elastic: 0.3}], resistedBy: [{tough: 0.3}]},
    smash: {cat: moveCat.PHY, percentBypass: [], flatBypass: [{hard: 0.3}], resistedBy: [{tough: 0.3}]},
    corrode: {cat: moveCat.PHY, percentBypass: [], flatBypass: [], resistedBy: [{chemResist:1.0}]},
    fumes: {cat: moveCat.ENR, percentBypass: [], flatBypass: [], resistedBy: [{chemResist: 0.5}]},
    frost: {cat: moveCat.ENR, percentBypass: [], flatBypass: [], resistedBy: [{thermCond: 0.3}]},
    heat: {cat: moveCat.ENR, percentBypass: [], flatBypass: [], resistedBy: [{thermCond: 0.3}]},
    zap: {cat: moveCat.ENR, percentBypass: [], flatBypass: [], resistedBy: [{electroResist: 0.3}]},
}
const meleeMoves = {
  fang: {name:'fang',atkType: "pierce", baseAtk:{pAtk: 10, eAtk: 0}, atkMult: {pAtk: 0.2, eAtk: 1}, soak: 0.8,
    selfEfct: [], allyEfct: [], targetEfct: [],enmyEfct: [], castTime: 1, cooldown: 0.2, extraRange: 100},
  peck: {name:'peck',atkType: "pierce", baseAtk:{pAtk: 3, eAtk: 0}, atkMult: {pAtk: 0.2, eAtk: 1}, soak: 0.8,
    selfEfct: [], allyEfct: [], targetEfct: [],enmyEfct: [], castTime: 0.2, cooldown: 0.5, extraRange: 1},
  headbutt: {name:'headbutt',atkType: "blunt", baseAtk: {pAtk: 20, eAtk: 0}, atkMult: {pAtk: 0.2, eAtk: 0.5}, soak: 0.1,
    selfEfct: [], allyEfct: [], targetEfct: [],enmyEfct: [], castTime: 1, cooldown: 2, extraRange: 5},
  scratch: {name:'scratch', atkType: "blunt", baseAtk: {pAtk: 5, eAtk: 0}, atkMult: {pAtk: 0.2, eAtk: 0.5}, soak: 0.1,
    selfEfct: [0], allyEfct: [], targetEfct: [],enmyEfct: [], castTime: 1, cooldown: 1, extraRange: 5},
}
// -----------------------------------------------------
// Abilities service (Roblox-style)
// -----------------------------------------------------
const Abilities = (() => {
    const REGISTRY = {};

    function def(defn) {
        REGISTRY[defn.id] = defn;
        return defn;
    }

    function ensureCDTable(entity) {
        if (!entity.cooldowns) entity.cooldowns = {};
        return entity.cooldowns;
    }

    function isReady(entity, id) {
        const cds = ensureCDTable(entity);
        return (cds[id] || 0) <= 0;
    }

    function beginCD(entity, id, seconds) {
        const cds = ensureCDTable(entity);
        cds[id] = seconds;
    }

    function tickCooldowns(dt, world) {
        for (const e of world.entities) {
            const cds = e.cooldowns;
            if (!cds) continue;
            for (const id in cds) {
                const t = cds[id] - dt;
                cds[id] = t > 0 ? t : 0;
                console.log(`Cooldown for ${id}: ${cds[id]}`); // Debugging
            }
        }
    }

    function cast(id, ctx) {
        const defn = REGISTRY[id];
        if (!defn) return;
        defn.cast(ctx);
    }

    // ---- Ability definitions ----
    // Example: melee Fang (maps to Q)
    def({
        id:    "fang",
        key:   "Q",
        label: "Fang",
        cd:    0.4,
        cast(ctx) {
            const { world, caster } = ctx;
            if (!caster || !caster.alive) return;
            if (!isReady(caster, "fang")) return;

            const move  = meleeMoves.fang;
            const range = move.extraRange || 10;
            const target = world.findMeleeTarget(caster, range);
            if (!target) return;

            const dmg = computeMeleeDamage(caster, target, move);
            target.data.hp -= dmg;
            if (target.data.hp <= 0) target.alive = false;

            beginCD(caster, "fang", 0.4);
        }
    });

    return {
        REGISTRY,
        def,
        cast,
        tickCooldowns,
        isReady,
        beginCD
    };
})();

const movementMoves = {
  dash: { speed: 420, time: 0.16, cooldown: 1.2, iFrames: 0.10 } // seconds
};
const projectileMoves = {
  spikeThrow: {
    name: "Throw Spike", atkType: "pierce",
    speed: 260, life: 1.2, radius: 4,
    baseAtk: { pAtk: 3, eAtk: 4 }, atkMult: { pAtk: 0.15, eAtk: 0.35 },
    cooldown: 0.6
  }
};

class TimeManager {
    constructor() {
        this.systems = [];
    }
    add(system) {
        this.systems.push(system);
    }
    remove(system) {
        this.systems = this.systems.filter(s => s !== system);
    }
    update(dt) {
        for (const s of this.systems) {
            if (s && typeof s.update === "function") {
                s.update(dt);
            }
        }
    }
}

class AbilityManager {
    constructor(world) {
        this.world = world;
        this.queue = []; // [{ caster, target, data, ... }]
    }
    enqueue(ability) {
        this.queue.push(ability);
    }
    update(dt) {
        for (let i = 0; i < this.queue.length; ) {
            const a = this.queue[i];
            const alive = a.update ? a.update(dt, this.world) : false;
            if (!alive) this.queue.splice(i, 1);
            else i++;
        }
    }
}
let NEXT_ID = 1;

class WorldEntity {
    constructor(world, x = 0, z = 0) {
        this.id    = NEXT_ID++;
        this.world = world;
        this.x     = x;
        this.z     = z;
        this.vx    = 0;
        this.vz    = 0;
        this.alive = true;
    }
    update(dt /*, world */) {
        this.x += this.vx * dt;
        this.z += this.vz * dt;
    }
    draw(ctx, camera) {
    }
}
class AreaEffect extends WorldEntity {
}

class Projectile extends WorldEntity {
    constructor(world, x, z) {
        super(world, x, z);
        this.lifetime = 1.5; // seconds
        this.radius   = 4;
    }
    update(dt, world) {
        super.update(dt, world);
        this.lifetime -= dt;
        if (this.lifetime <= 0) this.alive = false;
    }
    draw(ctx, camera) {
        const { sx, sz } = camera.worldToScreen(this.x, this.z);
        ctx.fillStyle = "yellow";
        ctx.beginPath();
        ctx.arc(sx, sz, this.radius * camera.zoom * 0.5, 0, Math.PI * 2);
        ctx.fill();
    }
}

class Collidables extends WorldEntity {
    constructor(world, x, z, radius = 8) {
        super(world, x, z);
        this.radius = radius;
    }
}

class Space {
    constructor(width, height) {
        this.width  = width;
        this.height = height;
    }
    clamp(x, z) {
        return {
            x: Math.max(0, Math.min(this.width,  x)),
            z: Math.max(0, Math.min(this.height, z))
        };
    }
    randomPoint() {
        return {
            x: Math.random() * this.width,
            z: Math.random() * this.height
        };
    }
}

// -----------------------------------------------------
// Camera
// -----------------------------------------------------
class Camera {
    constructor() {
        this.x      = 0;
        this.z      = 0;
        this.zoom   = 3;
        this.target = null;
    }
    follow(entity) {
        this.target = entity;
    }
    update(dt) {
        if (!this.target) return;
        const lerp = 10 * dt;
        this.x += (this.target.x - this.x) * lerp;
        this.z += (this.target.z - this.z) * lerp;
    }
    worldToScreen(x, z) {
        return {
            sx: (x - this.x) * this.zoom + canvas.width  / 2,
            sz: (z - this.z) * this.zoom + canvas.height / 2
        };
    }
    screenToWorld(sx, sz) {
        return {
            x: (sx - canvas.width  / 2) / this.zoom + this.x,
            z: (sz - canvas.height / 2) / this.zoom + this.z
        };
    }
}

class World {
    constructor(space) {
        this.space       = space;
        this.entities    = [];
        this.projectiles = [];
        this.areaEffects = [];
        this.spawnField = null;
    }
    addEntity(e)      { this.entities.push(e);      return e; }
    addProjectile(p)  { this.projectiles.push(p);   return p; }
    addAreaEffect(a)  { this.areaEffects.push(a);   return a; }
   setSpawnField(field) {
        this.spawnField = field;
    }
    update(dt) {
            if (this.spawnField) {
            this.spawnField.update(dt);
        }
        this.entities.forEach(e    => e.update(dt, this));
        this.projectiles.forEach(p => p.update(dt, this));
        this.areaEffects.forEach(a => a.update(dt, this));

        this.entities    = this.entities.filter(e => e.alive);
        this.projectiles = this.projectiles.filter(p => p.alive);
        this.areaEffects = this.areaEffects.filter(a => a.alive);
    }

    draw(ctx, camera) {
        ctx.fillStyle = "#6aa56a";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        this.areaEffects.forEach(a => a.draw(ctx, camera));
        this.entities.forEach(e    => e.draw(ctx, camera));
        this.projectiles.forEach(p => p.draw(ctx, camera));
    }
}
World.prototype.findMeleeTarget = function(attacker, range) {
    const r2 = range * range;
    let best = null;
    let bestD2 = r2;

    for (const e of this.entities) {
        if (e === attacker) continue;
        if (!(e instanceof Entity)) continue;        // only real combatants
        if (e.team === attacker.team) continue;      // skip allies

        const dx = e.x - attacker.x;
        const dz = e.z - attacker.z;
        const d2 = dx*dx + dz*dz;
        if (d2 < bestD2) {
            bestD2 = d2;
            best = e;
        }
    }
    return best;
};
class SpawnField {
    constructor(world, player, options = {}) {
        this.world  = world;
        this.player = player;

        // Configurable
        this.radius          = options.radius || 120;
        this.innerNoSpawn    = options.innerNoSpawn || 40; // avoid spawning on top of player
        this.maxWild         = options.maxWild || 6;
        this.spawnInterval   = options.spawnInterval || 2.5;

        this.timer = 0;
        this.speciesPool = options.speciesPool || [ SpeciesDB.Cat, SpeciesDB.Dog ];
    }

    update(dt) {
        this.timer += dt;

        // try spawn
        if (this.timer >= this.spawnInterval) {
            this.timer = 0;
            this.trySpawn();
        }

        // despawn out of radius
        this.cleanup();
    }

    trySpawn() {
        const currentWild = this.world.entities.filter(e => e instanceof WildEntity).length;
        if (currentWild >= this.maxWild) return;

        // Choose random species
        const species = this.speciesPool[
            Math.floor(Math.random() * this.speciesPool.length)
        ];

        // Get a random spawn point
        const pos = this.randomSpawnPoint();
        if (!pos) return;

        this.world.addEntity(new WildEntity(this.world, species, pos.x, pos.z));
    }

    randomSpawnPoint() {
        const px = this.player.x;
        const pz = this.player.z;

        for (let i = 0; i < 10; i++) { // try up to 10 random samples
            const angle = Math.random() * Math.PI * 2;
            const dist  = this.innerNoSpawn + Math.random() * (this.radius - this.innerNoSpawn);

            const x = px + Math.cos(angle) * dist;
            const z = pz + Math.sin(angle) * dist;

            // clamp inside space
            if (x < 0 || x > this.world.space.width) continue;
            if (z < 0 || z > this.world.space.height) continue;

            return { x, z };
        }

        return null; // couldn't find spot
    }

    cleanup() {
        const px = this.player.x;
        const pz = this.player.z;

        this.world.entities = this.world.entities.filter(e => {
            if (!(e instanceof WildEntity)) return true;

            const dx = e.x - px;
            const dz = e.z - pz;
            const dist = Math.hypot(dx, dz);

            if (dist > this.radius * 1.8) {  // smaller pop in/out by adding buffer
                return false; // despawn
            }

            return true;
        });
    }
}

// -----------------------------------------------------
// Player  // pretend base Roblox player
// -----------------------------------------------------
//read in tick
class Player extends Collidables {
    constructor(world, x, z) {
        super(world, x, z, 10);
        this.speed         = 80;
        this.roster        = []; // RosterEntity list
        this.activeCreature = null;
        this.activeCreatureCommands = null;
        this.autoCommands = {creatureFollow: false};
        this._prevMouse0 = false;
        this._prevQ = false;
        this._prevE = false;
        this._prevR = false;
        this._prevF = false;
    }

    update(dt, world) {
        let dx = 0, dz = 0;
        if (keys["w"]) dz -= 1;
        if (keys["s"]) dz += 1;
        if (keys["a"]) dx -= 1;
        if (keys["d"]) dx += 1;

        const len = Math.hypot(dx, dz) || 1;
        this.vx = (dx / len) * this.speed;
        this.vz = (dz / len) * this.speed;

        super.update(dt, world);

        const clamped = world.space.clamp(this.x, this.z);
        this.x = clamped.x;
        this.z = clamped.z;
        this.handlePetInput(world);
    }
    inputToPlayerCommands() {
        const clickLocation = { x: keys["mousex"], y: keys["mousey"] };
        return { clickLocation };
    }
    mapInputToActiveCreatureCommands() {

    }
    handlePetInput(world) {
        const pet = this.activeCreature || this.roster[0];
        if (!pet || !pet.brain) return;

        const mouseDown = !!keys["mouse0"];
        if (mouseDown && !this._prevMouse0) {
            const mx = keys["mousex"];
            const my = keys["mousey"];
            if (typeof mx === "number" && typeof my === "number") {
                const worldPos = camera.screenToWorld(mx, my);
                pet.brain.moveTarget = { x: worldPos.x, z: worldPos.z };
            }
        }
        this._prevMouse0 = mouseDown;

        // --- abilities: Q/E/R/F ---
        const qDown = !!keys["q"];
        const eDown = !!keys["e"];
        const rDown = !!keys["r"];
        const fDown = !!keys["f"];

        if (qDown && !this._prevQ) {
            pet.applyCommand({ type: COMMAND.ABILITY, ability: "Q" });
        }
        if (eDown && !this._prevE) {
            pet.applyCommand({ type: COMMAND.ABILITY, ability: "E" });
        }
        if (rDown && !this._prevR) {
            pet.applyCommand({ type: COMMAND.ABILITY, ability: "R" });
        }
        if (fDown && !this._prevF) {
            pet.applyCommand({ type: COMMAND.ABILITY, ability: "F" });
        }

        this._prevQ = qDown;
        this._prevE = eDown;
        this._prevR = rDown;
        this._prevF = fDown;
    }


    draw(ctx, camera) {
        const { sx, sz } = camera.worldToScreen(this.x, this.z);
        ctx.fillStyle = "#222";
        ctx.fillRect(sx - 6, sz - 6, 12, 12);
    }
}

function computeMeleeDamage(attacker, target, move) {
    // move.atkType -> e.g. "pierce"
    const atkTypeDef = moveAtkTypes[move.atkType];
    const targetComp = composites[target.compositeKey] || composites.organicAnimal;

    // base contributions
    const baseP = move.baseAtk.pAtk || 0;
    const baseE = move.baseAtk.eAtk || 0;

    const multP = move.atkMult.pAtk || 0;
    const multE = move.atkMult.eAtk || 0;

    const fromStatsP = attacker.data.pAtk * multP;
    const fromStatsE = attacker.data.eAtk * multE;

    let dmg = baseP + baseE + fromStatsP + fromStatsE;

    // optional soak – interpret as "portion of damage that gets through"
    if (typeof move.soak === "number") {
        dmg *= move.soak; // you can adjust later if you want the inverse
    }

    // very simple resistance using atkTypeDef.resistedBy
    if (atkTypeDef && Array.isArray(atkTypeDef.resistedBy)) {
        let res = 0;
        for (const r of atkTypeDef.resistedBy) {
            const key = Object.keys(r)[0];   // e.g. "hard"
            const weight = r[key];          // e.g. 0.3
            const val = targetComp[key] ?? 0;
            res += val * weight;
        }
        // clamp resistance so it never fully nulls out damage
        if (res > 0.8) res = 0.8;
        dmg *= (1 - res);
    }

    return Math.max(0, dmg);
}

const COMMAND = {
    MOVE: "move",
    ABILITY: "ability",
    FOLLOW: "follow",
    STOP: "stop"
};
const NATURE_BIAS = {
    aggressive: 0.7,
    neutral:    0.0,
    timid:     -0.7,
};

function makePetBrain(nature = "aggressive") {
    return {
        type:           "pet",
        mode:           "auto",
        nature,
        speed:          80,
        followDistance: 50,
        attackRange:    40,
        leashRadius:    200,
        focus:          null,
        requestedPos:   null,
        commandPos:     null,
        commandExpire:  0,
    };
}

function makeWildBrain(nature = "neutral") {
    return {
        type:        "wild",
        mode:        "auto",
        nature,
        speed:       70,
        aggroRange:  160,
        attackRange: 40,
        roamRadius:  120,
        homePos:     null,
        roamTarget:  null,
        roamTimer:   0,
        focus:       null,
        requestedPos:null,
    };
}

function observe(ctx, world) {
    ctx.observed = [];
    const self = ctx.entity;
    for (const other of world.entities) {
        if (other !== self && other.alive) ctx.observed.push(other);
    }
}

function weighSelf(ctx) {
    const e = ctx.entity;
    const hp  = e.data.hp;
    const max = e.data.maxHP || hp || 1;
    ctx.selfHealth = Math.max(0, Math.min(1, hp / max));

    const bias = NATURE_BIAS[ctx.brain.nature || "neutral"] ?? 0;
    let raw = (ctx.selfHealth - 0.5) * 2 + bias;
    if (raw >  1) raw =  1;
    if (raw < -1) raw = -1;
    ctx.totalFightFlight = raw;
}

function scanEntities(ctx) {
    ctx.enemyPressures = [];
    ctx.teamPressures  = [];

    const e  = ctx.entity;
    const ex = e.x, ez = e.z;

    for (const other of ctx.observed) {
        if (other instanceof Player) continue;
        const dx = other.x - ex;
        const dz = other.z - ez;
        const dist  = Math.hypot(dx, dz);
        const angle = Math.atan2(dz, dx);

        const ohp  = other.data.hp;
        const omax = other.data.maxHP || ohp || 1;
        const health = Math.max(0, Math.min(1, ohp / omax));

        const p = { entity: other, dist, angle, health };
        if (other.team !== e.team) ctx.enemyPressures.push(p);
        else                       ctx.teamPressures.push(p);
        console.log(p)
    }
}

function chooseFocus(ctx) {
    const e     = ctx.entity;
    const brain = ctx.brain;
    let best = null;
    let bestScore = -Infinity;

    for (const p of ctx.enemyPressures) {
        let s = (1 - p.health) + (1 / (1 + p.dist));

        if (brain.type === "pet" && e.owner) {
            const ox = e.owner.x, oz = e.owner.z;
            const dx = p.entity.x - ox;
            const dz = p.entity.z - oz;
            const dOwner = Math.hypot(dx, dz);
            const leash  = brain.leashRadius ?? 200;
            if (dOwner > leash + 40) s = -Infinity;
        }

        if (s > bestScore) {
            bestScore = s;
            best = p.entity;
        }
    }
    ctx.focus = best;
}

function computeFollowPositionForPet(ctx) {
    const e     = ctx.entity;
    const brain = ctx.brain;
    const owner = e.owner;
    if (!owner) return { x: e.x, z: e.z };

    const desired = brain.followDistance ?? 50;
    const offX = -desired * 0.7;
    const offZ =  desired * 0.7;

    let fx = owner.x + offX;
    let fz = owner.z + offZ;

    const dx = fx - e.x, dz = fz - e.z;
    const d  = Math.hypot(dx, dz);
    const maxStep = desired * 2;

    if (d > maxStep && d > 0) {
        const s = maxStep / d;
        fx = e.x + dx * s;
        fz = e.z + dz * s;
    }
    return { x: fx, z: fz };
}

function chooseSpot(ctx) {
    const e     = ctx.entity;
    const brain = ctx.brain;
    let basePos;

    if (brain.type === "pet") {
        basePos = computeFollowPositionForPet(ctx);
    } else {
        if (!brain.homePos) brain.homePos = { x: e.x, z: e.z };
        basePos = brain.homePos;
    }

    if (!ctx.focus) {
        ctx.requestedPos = basePos;
        return;
    }

    const fx = ctx.focus.x, fz = ctx.focus.z;
    const dx = fx - e.x, dz = fz - e.z;
    const dist = Math.hypot(dx, dz);
    if (dist < 1e-3) {
        ctx.requestedPos = { x: e.x, z: e.z };
        return;
    }

    const dirX = dx / dist, dirZ = dz / dist;
    const desiredRange = brain.attackRange ?? 40;

    const ff = ctx.totalFightFlight || 0;
    let targetDist = desiredRange - ff * 20;
    if (targetDist < 15) targetDist = 15;
    if (targetDist > 80) targetDist = 80;

    let tx = fx - dirX * targetDist;
    let tz = fz - dirZ * targetDist;

    if (brain.type === "pet" && e.owner) {
        const ox = e.owner.x, oz = e.owner.z;
        const vx = tx - ox,   vz = tz - oz;
        const d  = Math.hypot(vx, vz);
        const leash = brain.leashRadius ?? 200;
        if (d > leash && d > 0) {
            const s = leash / d;
            tx = ox + vx * s;
            tz = oz + vz * s;
        }
    }

    ctx.requestedPos = { x: tx, z: tz };
}

function decideAttacks(ctx) {
    const brain = ctx.brain;
    const e     = ctx.entity;
    if (brain.mode === "manual" || brain.mode === "semi") return;
    if (!ctx.focus) return;

    const dx = ctx.focus.x - e.x;
    const dz = ctx.focus.z - e.z;
    const dist = Math.hypot(dx, dz);
    const range = brain.attackRange ?? 40;

    const rules = [
        { id: "fang", cond: () => dist <= range } // single melee for now
    ];

    for (const r of rules) {
        if (r.cond()) {
            e.applyCommand({ type: COMMAND.ABILITY, ability: "Q" });
            return;
        }
    }
}

function decideMovement(ctx) {
    const brain = ctx.brain;
    const e     = ctx.entity;

    if (brain.mode === "manual") return;
    if (!ctx.requestedPos) {
        e.applyCommand({ type: COMMAND.STOP });
        return;
    }

    const dx = ctx.requestedPos.x - e.x;
    const dz = ctx.requestedPos.z - e.z;
    const dist = Math.hypot(dx, dz);
    if (dist < 1) {
        e.applyCommand({ type: COMMAND.STOP });
        return;
    }
    e.applyCommand({ type: COMMAND.MOVE, dx, dz });
}

function tickOne(entity, dt, world) {
    const brain = entity.brain;
    if (!brain || !entity.alive) return;
    if (entity.data.hp <= 0) {
        entity.applyCommand({ type: COMMAND.STOP });
        return;
    }

    const ctx = {
        entity,
        brain,
        dt,
        selfHealth:       1,
        totalFightFlight: 0,
        observed:         [],
        enemyPressures:   [],
        teamPressures:    [],
        focus:            null,
        requestedPos:     null,
    };

    observe(ctx, world);
    weighSelf(ctx);
    scanEntities(ctx);
    chooseFocus(ctx);
    chooseSpot(ctx);
    decideAttacks(ctx);
    decideMovement(ctx);
}

const BrainService = {
    makePetBrain,
    makeWildBrain,
    stepAll(world, dt) {
        for (const e of world.entities) {
            if (e.brain) tickOne(e, dt, world);
        }
    }
};
class Entity extends Collidables {
    constructor(world, species, x, z) {
        super(world, x, z, 8);
        this.species = species;
        this.team = species.team ?? 0; // default team 0
        this.data = {
            maxHP: species.baseHP,
            hp:    species.baseHP,
            pAtk:  species.basePATK || species.baseATK || 10, // physical
            eAtk:  species.baseEATK || 0,                     // energy
            spd:   species.baseSPD
        };
        this.compositeKey = species.compositeKey || "organicAnimal";

        this.currentCommand = null;
        this.brain = null;
    }

    applyCommand(cmd) {
        this.currentCommand = cmd;
    }

    update(dt, world) {
        if (this.currentCommand) {
            switch (this.currentCommand.type) {
                case COMMAND.MOVE: {
                    const {dx, dz} = this.currentCommand;
                    const len = Math.hypot(dx, dz) || 1;
                    this.vx = (dx / len) * this.data.spd;
                    this.vz = (dz / len) * this.data.spd;
                    break;
                }
                case COMMAND.STOP:
                    this.vx = 0;
                    this.vz = 0;
                    break;

                case COMMAND.ABILITY:
                    this.handleAbility(world, this.currentCommand);
                    break;
            }
            this.currentCommand = null;
        }
        super.update(dt, world);
    }
    handleAbility(world, cmd) {
        // Map input key → ability id
        let abilityId = cmd.ability;

        if (abilityId === "Q") abilityId = "fang";
        // later: if (abilityId === "E") abilityId = "dash"; etc.

        if (!abilityId) return;

        Abilities.cast(abilityId, {
            world,
            caster: this
        });
    }

    draw(ctx, camera) {
        const { sx, sz } = camera.worldToScreen(this.x, this.z);
        ctx.fillStyle = this.species.color || "#f0f";
        ctx.fillRect(sx - 5, sz - 5, 10, 10);
        if (this.data){
            ctx.fillText(this.data.hp, sx + 10, sz - 30)
            ctx.fillText(this.data.maxHP, sx + 10, sz - 10)
            ctx.fillText(this.data.pAtk, sx + 10, sz + 10)
            ctx.fillText(this.data.spd, sx + 10, sz +30)
        }
    }
}
class RosterEntity extends Entity {
    constructor(world, species, owner, x, z) {
        super(world, species, x, z);
        this.owner = owner;
        this.team  = 1;
        this.brain = BrainService.makePetBrain("aggressive");
    }

    update(dt, world) {
        // interpret any currentCommand from BrainService
        if (this.currentCommand) {
            switch (this.currentCommand.type) {
                case COMMAND.MOVE: {
                    const {dx, dz} = this.currentCommand;
                    const len = Math.hypot(dx, dz) || 1;
                    this.vx = (dx / len) * this.data.spd;
                    this.vz = (dz / len) * this.data.spd;
                    break;
                }
                case COMMAND.STOP:
                    this.vx = 0;
                    this.vz = 0;
                    break;
                case COMMAND.ABILITY:
                    this.handleAbility(world, this.currentCommand);
                    this.currentCommand = null;
                    break;
            }
        }
        super.update(dt, world);
    }
}

class WildEntity extends Entity {
    constructor(world, species, x, z) {
        super(world, species, x, z);
        this.brain = BrainService.makeWildBrain("neutral");
    }

    update(dt, world) {
        if (this.currentCommand) {
            switch (this.currentCommand.type) {
                case COMMAND.MOVE: {
                    const {dx, dz} = this.currentCommand;
                    const len = Math.hypot(dx, dz) || 1;
                    this.vx = (dx / len) * this.data.spd;
                    this.vz = (dz / len) * this.data.spd;
                    break;
                }
                case COMMAND.STOP:
                    this.vx = 0;
                    this.vz = 0;
                    break;
                case COMMAND.ABILITY:
                    this.handleAbility(world, this.currentCommand);
                    this.currentCommand = null;
                    break;
            }
        }
        super.update(dt, world);
    }
}


class BossEntity extends Entity {
    constructor(world, species, x, z) {
        super(world, species, x, z);
        this.phase  = 1;
        this.enrage = false;
        // TODO: scripted patterns
    }
}

const SpeciesDB = {
    Cat: {
        name: "Cat",
        baseHP: 40,
        baseATK: 10,
        baseSPD: 30,
        color: "#f6863a",
        compositeKey: "organicMammal"
    },
    Dog: {
        name:    "Dog",
        baseHP:  55,
        baseATK:  8,
        baseSPD: 24,
        color:   "#3a8df6",
        compositeKey: "organicMammal"
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
        const base = creature.baseStats;
        const L = creature.level;
        const hpMul   = 1 + 0.2 * (L - 1);
        const statMul = 1 + 0.1 * (L - 1);
        creature.stats = {
            maxHP: Math.floor(base.maxHP * hpMul),
            pAtk:  Math.floor(base.pAtk  * statMul),
            eAtk:  Math.floor(base.eAtk  * statMul),
            def:   Math.floor(base.def   * statMul),
            spd:   Math.floor(base.spd   * statMul)
        };
        creature.hp = Math.min(creature.hp, creature.stats.maxHP);
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

const space      = new Space(300, 300);
const world      = new World(space);
const camera     = new Camera();
const abilities  = new AbilityManager(world);
const time       = new TimeManager();

const player = world.addEntity(new Player(world, 150, 150));
camera.follow(player);

const pet = world.addEntity(
    new RosterEntity(world, SpeciesDB.Cat, player, 120, 150)
);

const pet2 = world.addEntity(
    new RosterEntity(world, SpeciesDB.Cat, player, 140, 150)
);
player.roster.push(pet);
player.roster.push(pet2);

const spawnField = new SpawnField(world, player, {
    radius: 140,
    innerNoSpawn: 50,
    maxWild: 8,
    spawnInterval: 2.2,
    speciesPool: [ SpeciesDB.Cat, SpeciesDB.Dog ]
});

world.setSpawnField(spawnField);

time.add({
    update(dt) {
        BrainService.stepAll(world, dt);        // AI
        Abilities.tickCooldowns(dt, world);     // ability cooldowns
        world.update(dt);                       // physics, spawn field
        camera.update(dt);
        world.draw(ctx, camera);
    }
});

let last = performance.now();

function frame(now) {
    const dt = Math.min((now - last) / 1000, 0.033);
    last = now;
    time.update(dt);
    requestAnimationFrame(frame);
}

requestAnimationFrame(frame);