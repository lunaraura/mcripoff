/* =========================================================
   0. BOOTSTRAP
   ========================================================= */
//math helper functions
//definitions: 
//composites of creatures
//abilities
//Effects:
// temperatureStates
// soakEffects
// special effects for composite
//species

//Essential global work:
//time logic, space class with helper functions
//camera, world, spawnfield for each player.

//battle work
//player, creature extending wildCreature and PetCreature
//ability manager, effectManager for creatures
//world entities: aoe, projectiles, barriers
//player managing work:
//RosterService, InventoryService, ItemService
//morph, level service for creature
//attractionservice, baiting and taming creatures
//exploring work:
//Chunk, interactables hosted by world
//entity physics validating
//biome affliction towards spawnfield, entity morphs


const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

class Game {
    constructor() {
        this.input = new InputManager();
        this.world = new World();
        this.ui = new UIManager();

        this.lastTime = 0;
        this.isRunning = false;
    }

    initialize() {
        this.input.bind();

        this.world.initialize({
            seed: 12345,
            width: 3000,
            height: 3000
        });

        this.ui.initialize(this.world);
        this.isRunning = true;
    }

    update(dt) {
        this.world.update(dt, this.input);
        this.ui.update(dt, this.world, this.input);
    }

    draw() {
        this.world.draw(ctx);
        this.ui.draw(ctx, this.world);
    }

    loop(ts) {
        if (!this.isRunning) return;

        const dt = this.lastTime
            ? Math.min((ts - this.lastTime) / 1000, 0.05)
            : 0.016;

        this.lastTime = ts;

        this.update(dt);
        this.draw();

        requestAnimationFrame((next) => this.loop(next));
    }

    start() {
        this.initialize();
        requestAnimationFrame((ts) => this.loop(ts));
    }
}
/* =========================================================
   1. HELPERS / SHARED UTILS
   ========================================================= */

function clamp(v,min,max){return Math.max(min,Math.min(max,v))}
function lerp(a, b, t) {}
function dist2D(ax, az, bx, bz) {}
function normalize2D(x, z) {}
function deepClone(obj){return JSON.parse(JSON.stringify(obj))}
function randInt(min, max) {}
function randRange(min, max) {}

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

function addStats(a, b) {}
function multStats(a, b) {}
/* =========================================================
   2. DEFINITIONS / REGISTRIES
   ========================================================= */

// materials / creature body composites
const composites = {
    example: {
        name: "example", effectiveness:{physical: 1, energy: 1}, 
        eHurtScale: {tempChange: 1, chem: 1, water: 0.75, electric: 1},
        pHurtScale: {pierce: 1, slash: 1, impact: 1, drill: 1},
        baselines: {temp: 0.5, water: 0, electric: 0.0, chemical: 0}, //The ratio of capacity soaks that it will bleed to.
        capacityScale: {water: 1, electric: 1, chemical: 1},
        tempCapHot: 1,   // how much positive temp deviation it can absorb per size unit
        tempCapCold: 1,  // how much negative temp deviation it can absorb per size unit
        tempThresholds: {hot: 0.6, cold: 0.4},
        statBoost: {pAtk: 1, eAtk: 0, maxHP:1, spd: 0},
        specialEffects: []
    },
};

// abilities / moves
const abilities = {};

// thermal states
const tempStates = {
    sweltering: { effect: "melt", vulnerability: ["slash", "pierce", "drill"] },
    freezing:   { effect: "brittle", vulnerability: ["impact"] },
    normal:     { effect: "none", vulnerability: [] }
}
// soak states
const soakEffects = {
    water:    {name: "water",    effect: "none",   vulnerability: ["electric"], boost: "none",   dmgPer: 1},
    electric: {name: "electric", effect: "damage", vulnerability: [],           boost: "energy", dmgPer: 1},
    chemical: {name: "chemical", effect: "damage", vulnerability: [],           boost: "none",   dmgPer: 1},
}
// special rule hooks
const specialEffects = {
    waterVolt: {
        name: "Retain Voltage",
        desc: "...",
        effect: (creature, dt) => {
            // runs each tick when condition is met
        },
        condition: (creature) => creature.soaks.water > 0
    }
}
// species / morph definitions
const species = {
    example: {
        name: "example species", baseStats: temporary.baseStats, maxVariation: temporary.maxVariation,
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
};

// items / food / tools / bait
const items = {
    goldenBerry: {} //100% tame rate, given once at start of game
};

// biome definitions and spawn tables
const biomes = {
    //in each,
    //start with worldgen arguments for ChunkManager
    //then spawnrates for interactables
    //then spawnrates for spawnField whenever its in its position
    //structures and morph "gem" droprates come later 
    //then if farming is implemented, plant/berry growth rates 
    //some composites oriented better in certain places
    desert: {
        dominantComposites: ["fire", "rock"],   // spawn weight bonus, morph point affinity
        hostileComposites: ["frost", "water"],   // spawn weight penalty
        morphPointSources: { fire: 0.8, rock: 0.4 },  // per second from biome exposure
        spawnTable: [],
        interactableTable: [],
        worldgenArgs: {}
    },
    taiga:{}, //frost
    volcano: {}, //lava
    polar: {}, //ice
    forest:{}, //animal
    jungle:{}, //plant
    hills: {}, //
    mountain: {}, //rock
    ocean: {}, //water
    swamp: {}, //
    bog: {}, //

};

// optional world event definitions
const worldEvents = {
    //bosses in later versions, drops stuff
    //required for kaiju, eldritch morph maybe,
    //but most likely just a heap of normal morph stones
};
/* =========================================================
   3. PERSISTENT PLAYER / CREATURE DATA
   ========================================================= */
class PlayerProfile {
    constructor() {
        this.id       = crypto.randomUUID();
        this.name     = "";
        this.currency = 0;

        this.inventory = new InventoryContainer();
        this.party     = new PartyService(6);
        this.storage   = new CreatureStorage();

        this.activePartyIndex = 0;

        // milestone / story flags: key → bool or value
        this.flags       = {};
        // tracks seen species, items, biomes
        this.discoveries = {
            species:  new Set(),
            items:    new Set(),
            biomes:   new Set(),
            morphs:   new Set(),
        };

        this.playtime  = 0;   // seconds, increment each update
        this.saveSlot  = null;
    }

    discoverSpecies(speciesKey) {
        this.discoveries.species.add(speciesKey);
    }
    discoverItem(itemKey) {
        this.discoveries.items.add(itemKey);
    }
    discoverBiome(biomeKey) {
        this.discoveries.biomes.add(biomeKey);
    }
    discoverMorph(morphKey) {
        this.discoveries.morphs.add(morphKey);
    }

    hasFlag(key)        { return !!this.flags[key]; }
    setFlag(key, val = true) { this.flags[key] = val; }

    // Called by World.update each tick
    tickPlaytime(dt) { this.playtime += dt; }

    // Minimal serialisable snapshot — expand when save system is built
    serialize() {
        return {
            id: this.id, name: this.name, currency: this.currency,
            activePartyIndex: this.activePartyIndex,
            flags: { ...this.flags },
            discoveries: {
                species: [...this.discoveries.species],
                items:   [...this.discoveries.items],
                biomes:  [...this.discoveries.biomes],
                morphs:  [...this.discoveries.morphs],
            },
            playtime:  this.playtime,
            saveSlot:  this.saveSlot,
            inventory: this.inventory.serialize(),
            party:     this.party.serialize(),
            storage:   this.storage.serialize(),
        };
    }

    static deserialize(data) {
        const p = new PlayerProfile();
        p.id   = data.id;
        p.name = data.name;
        p.currency = data.currency;
        p.activePartyIndex = data.activePartyIndex;
        p.flags    = { ...data.flags };
        p.playtime = data.playtime ?? 0;
        p.saveSlot = data.saveSlot ?? null;
        p.discoveries = {
            species: new Set(data.discoveries.species),
            items:   new Set(data.discoveries.items),
            biomes:  new Set(data.discoveries.biomes),
            morphs:  new Set(data.discoveries.morphs),
        };
        p.inventory = InventoryContainer.deserialize(data.inventory);
        p.party     = PartyService.deserialize(data.party);
        p.storage   = CreatureStorage.deserialize(data.storage);
        return p;
    }
}

// ─────────────────────────────────────────────────────────

class InventoryContainer {
    constructor() {
        this.items = new Map(); // itemKey → qty
    }

    add(itemKey, qty = 1) {
        this.items.set(itemKey, (this.items.get(itemKey) ?? 0) + qty);
    }

    // Returns false if not enough stock, otherwise removes and returns true
    remove(itemKey, qty = 1) {
        const current = this.items.get(itemKey) ?? 0;
        if (current < qty) return false;
        const next = current - qty;
        if (next === 0) this.items.delete(itemKey);
        else this.items.set(itemKey, next);
        return true;
    }

    has(itemKey, qty = 1) {
        return (this.items.get(itemKey) ?? 0) >= qty;
    }

    count(itemKey) {
        return this.items.get(itemKey) ?? 0;
    }

    // Returns array of { itemKey, qty } sorted by key for stable UI ordering
    all() {
        return [...this.items.entries()]
            .map(([itemKey, qty]) => ({ itemKey, qty }))
            .sort((a, b) => a.itemKey.localeCompare(b.itemKey));
    }

    // Filtered view — useful for "show only bait" etc.
    allOfCategory(category) {
        return this.all().filter(({ itemKey }) => {
            const def = items[itemKey];
            return def?.category === category;
        });
    }

    serialize() {
        return Object.fromEntries(this.items);
    }

    static deserialize(data = {}) {
        const inv = new InventoryContainer();
        for (const [key, qty] of Object.entries(data)) {
            inv.items.set(key, qty);
        }
        return inv;
    }
}

// ─────────────────────────────────────────────────────────

class PartyService {
    constructor(size = 6) {
        this.slots = new Array(size).fill(null); // creature IDs or null
        this.size  = size;
    }

    get(slotIndex) {
        return this.slots[slotIndex] ?? null;
    }

    // Returns false if slot is out of range
    set(slotIndex, creatureId) {
        if (slotIndex < 0 || slotIndex >= this.size) return false;
        this.slots[slotIndex] = creatureId;
        return true;
    }

    swap(a, b) {
        if (a < 0 || b < 0 || a >= this.size || b >= this.size) return false;
        [this.slots[a], this.slots[b]] = [this.slots[b], this.slots[a]];
        return true;
    }

    // Returns the ID at the given active index (wraps around living members)
    getActiveId(activeIndex) {
        const filled = this.slots.filter(Boolean);
        if (filled.length === 0) return null;
        return filled[activeIndex % filled.length];
    }

    firstOpenSlot() {
        return this.slots.findIndex(s => s === null);
    }

    isFull() {
        return this.slots.every(s => s !== null);
    }

    count() {
        return this.slots.filter(Boolean).length;
    }

    // Returns IDs of all occupied slots in order
    allIds() {
        return this.slots.filter(Boolean);
    }

    // Remove by creature ID regardless of slot position
    removeById(creatureId) {
        const idx = this.slots.indexOf(creatureId);
        if (idx === -1) return false;
        this.slots[idx] = null;
        return true;
    }

    contains(creatureId) {
        return this.slots.includes(creatureId);
    }

    serialize() {
        return [...this.slots];
    }

    static deserialize(data = []) {
        const ps = new PartyService(data.length || 6);
        ps.slots = [...data];
        return ps;
    }
}

// ─────────────────────────────────────────────────────────

class CreatureStorage {
    constructor() {
        this.records = new Map(); // creatureId → OwnedCreatureData
    }

    add(record) {
        if (!record.id) record.id = crypto.randomUUID();
        this.records.set(record.id, record);
        return record.id;
    }

    get(id) {
        return this.records.get(id) ?? null;
    }

    remove(id) {
        return this.records.delete(id);
    }

    has(id) {
        return this.records.has(id);
    }

    all() {
        return [...this.records.values()];
    }

    filter(fn) {
        return this.all().filter(fn);
    }

    // Convenience filters
    bySpecies(speciesKey) {
        return this.filter(r => r.speciesKey === speciesKey);
    }

    byMorphStage(stage) {
        return this.filter(r => r.morphStage === stage);
    }

    count() {
        return this.records.size;
    }

    serialize() {
        return this.all().map(r => r.serialize());
    }

    static deserialize(data = []) {
        const cs = new CreatureStorage();
        for (const raw of data) {
            cs.records.set(raw.id, OwnedCreatureData.deserialize(raw));
        }
        return cs;
    }
}

// ─────────────────────────────────────────────────────────

class OwnedCreatureData {
    constructor() {
        this.id      = crypto.randomUUID();
        this.ownerId = null;

        this.speciesKey = null;
        this.nickname   = "";

        this.level  = 1;
        this.xp     = 0;
        this.nextXP = 10;

        // baseStats: rolled at creation, never change
        // modifiedStats: recomputed from base + level + morph bonuses
        this.baseStats     = makeStats(0);
        this.modifiedStats = makeStats(0);

        this.moveset       = [];   // currently equipped (max 4)
        this.unlockedMoves = [];   // all moves this creature has learned

        this.composites = { inner: null, outer: null };

        this.morphStage  = 0;
        this.morphPath   = null;
        this.morphPoints = {}; // materialKey → accumulated points

        // Social / taming stats
        this.bond        = 0;    // 0–100, grows through battles and care
        this.loyalty     = 0;    // 0–100, affects obedience in pet mode
        this.temperament = "neutral"; // neutral, bold, timid, aggressive, gentle

        // Capture context
        this.caughtBiome  = null;
        this.caughtLevel  = 1;

        // Flexible tag system for filtering/UI
        this.tags = []; // e.g. ["favourite", "for trade", "breedable"]
    }

    // Bond helpers
    gainBond(amount) {
        this.bond = Math.min(100, this.bond + amount);
    }

    gainLoyalty(amount) {
        this.loyalty = Math.min(100, this.loyalty + amount);
    }

    // Move management
    learnMove(moveKey) {
        if (!this.unlockedMoves.includes(moveKey)) {
            this.unlockedMoves.push(moveKey);
        }
    }

    equipMove(moveKey, slot) {
        if (!this.unlockedMoves.includes(moveKey)) return false;
        if (slot < 0 || slot > 3) return false;
        this.moveset[slot] = moveKey;
        return true;
    }

    hasTag(tag)    { return this.tags.includes(tag); }
    addTag(tag)    { if (!this.hasTag(tag)) this.tags.push(tag); }
    removeTag(tag) { this.tags = this.tags.filter(t => t !== tag); }

    serialize() {
        return {
            id: this.id, ownerId: this.ownerId,
            speciesKey: this.speciesKey, nickname: this.nickname,
            level: this.level, xp: this.xp, nextXP: this.nextXP,
            baseStats:     { ...this.baseStats },
            modifiedStats: { ...this.modifiedStats },
            moveset:        [...this.moveset],
            unlockedMoves:  [...this.unlockedMoves],
            composites:    deepClone(this.composites),
            morphStage:    this.morphStage,
            morphPath:     this.morphPath,
            morphPoints:   { ...this.morphPoints },
            bond:          this.bond,
            loyalty:       this.loyalty,
            temperament:   this.temperament,
            caughtBiome:   this.caughtBiome,
            caughtLevel:   this.caughtLevel,
            tags:          [...this.tags],
        };
    }

    static deserialize(data) {
        const r = new OwnedCreatureData();
        Object.assign(r, {
            ...data,
            baseStats:     { ...data.baseStats },
            modifiedStats: { ...data.modifiedStats },
            moveset:       [...data.moveset],
            unlockedMoves: [...data.unlockedMoves],
            composites:    deepClone(data.composites),
            morphPoints:   { ...data.morphPoints },
            tags:          [...data.tags],
        });
        return r;
    }
}
/* =========================================================
   4. PLAYER IN THE WORLD
   ========================================================= */

class PlayerEntity {
    constructor(profile, x, z) {
        this.profile = profile;

        this.pos = { x, z };
        this.vel = { x: 0, z: 0 };
        this.angle = 0;

        this.spd = 140;
        this.interactRange = 40;

        this.controlMode = "player"; // player, pet_manual, pet_command, menu
        this.intent = this.makeEmptyIntent();

        this.summonedCreatureId = null;
        this.manualControlCreatureId = null;

        this.alive = true;
    }

    makeEmptyIntent() {
        return {
            move: { x: 0, z: 0 },
            interact: false,
            summonToggle: false,
            recall: false,
            useItem: null,
            partyNext: false,
            partyPrev: false,
            manualControl: false,
            targetPos: null
        };
    }

    readInput(inputManager) {}
    update(dt, world) {}
    applyMovement(dt, world) {}
    handleInteraction(world) {}
    handlePartyControl(world) {}
    handlePetControl(world) {}
}

/* =========================================================
   5. WORLD / TERRAIN / BIOME
   ========================================================= */
class Space {
    constructor(width, height) {
        this.width  = width;
        this.height = height;
    }

    clamp(x, z) {
        return {
            x: Math.max(0, Math.min(this.width,  x)),
            z: Math.max(0, Math.min(this.height, z)),
        };
    }

    clampEntity(entity) {
        entity.pos.x = Math.max(0, Math.min(this.width,  entity.pos.x));
        entity.pos.z = Math.max(0, Math.min(this.height, entity.pos.z));
    }

    randomPoint() {
        return {
            x: Math.random() * this.width,
            z: Math.random() * this.height,
        };
    }

    randomPointInRing(cx, cz, innerR, outerR) {
        // Used by SpawnField to avoid spawning right on top of the player
        for (let i = 0; i < 20; i++) {
            const angle = Math.random() * Math.PI * 2;
            const dist  = innerR + Math.random() * (outerR - innerR);
            const x = cx + Math.cos(angle) * dist;
            const z = cz + Math.sin(angle) * dist;
            if (this.contains(x, z)) return { x, z };
        }
        return null; // all attempts clipped outside world bounds
    }

    contains(x, z) {
        return x >= 0 && x <= this.width && z >= 0 && z <= this.height;
    }

    // Returns the chunk coordinate for a world position
    toChunkCoord(x, z, chunkSize) {
        return {
            cx: Math.floor(x / chunkSize),
            cz: Math.floor(z / chunkSize),
        };
    }

    // World-unit rect of a chunk
    chunkBounds(cx, cz, chunkSize) {
        return {
            x:  cx * chunkSize,
            z:  cz * chunkSize,
            x2: (cx + 1) * chunkSize,
            z2: (cz + 1) * chunkSize,
        };
    }
}

// ─────────────────────────────────────────────────────────

const CHUNK_SIZE = 200; // world units per chunk side

class Chunk {
    constructor(cx, cz) {
        this.cx = cx;
        this.cz = cz;
        this.key = `${cx},${cz}`;

        // Flat terrain grid within this chunk — null until generated
        // Each cell is a biomeKey string for now; extend to object if needed
        this.terrain = null;

        this.biomeKey    = null;  // dominant biome for this chunk
        this.generated   = false;
        this.resourcesDepleted = false;

        // Interactable nodes that live in this chunk (by world entity id)
        this.interactableIds = [];
    }
}

class ChunkManager {
    constructor(world) {
        this.world        = world;
        this.seed         = 0;
        this.loadedChunks = new Map(); // "cx,cz" → Chunk
        this.chunkSize    = CHUNK_SIZE;
        this.loadRadius   = 2; // chunks loaded around player (2 = 5×5 grid)
    }

    initialize(seed) {
        this.seed = seed;
        // Seed a simple noise function or RNG here
        // Generate the starting chunks around world center
        this.ensureChunksAround(
            this.world.space.width  / 2,
            this.world.space.height / 2
        );
    }

    chunkKey(cx, cz) {
        return `${cx},${cz}`;
    }

    worldToChunk(x, z) {
        return {
            cx: Math.floor(x / this.chunkSize),
            cz: Math.floor(z / this.chunkSize),
        };
    }

    getChunk(cx, cz) {
        return this.loadedChunks.get(this.chunkKey(cx, cz)) ?? null;
    }

    ensureChunksAround(x, z) {
        const { cx: pcx, cz: pcz } = this.worldToChunk(x, z);
        const r = this.loadRadius;

        for (let dcx = -r; dcx <= r; dcx++) {
            for (let dcz = -r; dcz <= r; dcz++) {
                const cx = pcx + dcx;
                const cz = pcz + dcz;
                const key = this.chunkKey(cx, cz);
                if (!this.loadedChunks.has(key)) {
                    this.loadedChunks.set(key, this.generateChunk(cx, cz));
                }
            }
        }
    }

    unloadFarChunks(playerPos) {
        const { cx: pcx, cz: pcz } = this.worldToChunk(playerPos.x, playerPos.z);
        const limit = this.loadRadius + 2; // generous unload margin

        for (const [key, chunk] of this.loadedChunks) {
            const dx = Math.abs(chunk.cx - pcx);
            const dz = Math.abs(chunk.cz - pcz);
            if (dx > limit || dz > limit) {
                // Remove interactables that belong to this chunk before unloading
                for (const id of chunk.interactableIds) {
                    this.world.removeInteractableById(id);
                }
                this.loadedChunks.delete(key);
            }
        }
    }

    generateChunk(cx, cz) {
        const chunk   = new Chunk(cx, cz);
        chunk.biomeKey = this.world.biomeService.getBiomeAt(
            cx * this.chunkSize + this.chunkSize / 2,
            cz * this.chunkSize + this.chunkSize / 2
        );
        chunk.generated = true;

        this.spawnChunkInteractables(chunk);
        // Resources (ore nodes, berry bushes) spawned separately
        // so they can respect depletion state on re-load later
        if (!chunk.resourcesDepleted) {
            this.spawnChunkResources(chunk);
        }

        return chunk;
    }

    spawnChunkResources(chunk) {
        const table = this.world.biomeService.getInteractableSpawnTable(chunk.biomeKey);
        if (!table) return;

        const bounds = this.world.space.chunkBounds(chunk.cx, chunk.cz, this.chunkSize);

        for (const entry of table) {
            // entry: { nodeType, density, itemKey }
            const count = Math.floor(entry.density + Math.random());
            for (let i = 0; i < count; i++) {
                const x = bounds.x + Math.random() * this.chunkSize;
                const z = bounds.z + Math.random() * this.chunkSize;
                const node = this.world.spawnInteractable(entry.nodeType, x, z);
                if (node) chunk.interactableIds.push(node.id);
            }
        }
    }

    spawnChunkInteractables(chunk) {
        // Non-resource interactables: signs, portals, structures — stub for now
    }

    getTerrainAt(x, z) {
        const { cx, cz } = this.worldToChunk(x, z);
        const chunk = this.getChunk(cx, cz);
        return chunk?.biomeKey ?? null;
    }

    // Not needed for a top-down RPG with no block editing,
    // but kept as a stub in case destructible terrain is added
    setTerrainAt(x, z, value) {
        const { cx, cz } = this.worldToChunk(x, z);
        const chunk = this.getChunk(cx, cz);
        if (chunk) chunk.terrain = value; // refine when terrain grid is real
    }

    isLoaded(x, z) {
        const { cx, cz } = this.worldToChunk(x, z);
        return this.loadedChunks.has(this.chunkKey(cx, cz));
    }
}

// ─────────────────────────────────────────────────────────

class BiomeService {
    constructor(world) {
        this.world = world;
    }

    // Primary lookup — maps a world position to a biome key
    // Replace the noise stub with a real noise function when ready
    getBiomeAt(x, z) {
        if (!biomes || Object.keys(biomes).length === 0) return "forest";

        // Placeholder: tile the world into rough regions by position
        // Replace with Voronoi / simplex noise seeded by ChunkManager.seed
        const nx = x / this.world.space.width;
        const nz = z / this.world.space.height;
        const keys = Object.keys(biomes);
        const idx  = Math.floor((nx + nz) * 0.5 * keys.length) % keys.length;
        return keys[idx];
    }

    getBiomeDef(biomeKey) {
        return biomes[biomeKey] ?? null;
    }

    // Returns [{ speciesKey, weight }] for wild spawning
    getCreatureSpawnTable(biomeKey) {
        return biomes[biomeKey]?.spawnTable ?? [];
    }

    // Returns [{ nodeType, density, itemKey }] for resource nodes
    getInteractableSpawnTable(biomeKey) {
        return biomes[biomeKey]?.interactableTable ?? [];
    }

    // Returns { materialKey: pointsPerSecond } for biome exposure morphing
    getMorphPointRules(biomeKey) {
        return biomes[biomeKey]?.morphPointSources ?? {};
    }

    // Dominant composites affect spawn weight modifiers in SpawnField
    getDominantComposites(biomeKey) {
        return biomes[biomeKey]?.dominantComposites ?? [];
    }

    getHostileComposites(biomeKey) {
        return biomes[biomeKey]?.hostileComposites ?? [];
    }

    // Weighted random pick from a spawn table
    rollSpawnTable(table) {
        if (!table || table.length === 0) return null;
        const total = table.reduce((sum, e) => sum + (e.weight ?? 1), 0);
        let roll = Math.random() * total;
        for (const entry of table) {
            roll -= entry.weight ?? 1;
            if (roll <= 0) return entry;
        }
        return table[table.length - 1];
    }
}
/* =========================================================
   6. WORLD ENTITIES / NODES / ENCOUNTERS
   ========================================================= */

class WorldEntity {
    constructor(x, z) {
        this.pos = { x, z };
        this.alive = true;
    }

    update(dt, world) {}
    draw(ctx, camera) {}
}

class InteractableNode extends WorldEntity {
    constructor(x, z, nodeType) {
        super(x, z);
        this.nodeType = nodeType;
        this.state = "ready";
        this.cooldown = 0;
    }

    canInteract(actor) {}
    interact(actor, world) {}
}

class BerryBush extends InteractableNode {}
class Shrub extends InteractableNode {}
class OreNode extends InteractableNode {}
class Barrier extends InteractableNode {}

class Encounter {
    constructor(creature, playerID, sourceType, radius) {
        this.creature = creature;
        this.encounteredBy = playerID;
        this.sourceType = sourceType; // wild, biome, event, lure
        this.state = "idle";          // idle, engaged, fled, captured, defeated
        this.visible = true;
        this.boundaryRadius = radius;
        this.cancelable = true;
    }

    canStart(playerEntity) {}
    start(playerEntity, world) {}
    resolve(result, world) {}
}
/* =========================================================
   7. CREATURE RUNTIME
   ========================================================= */

class CreatureRuntime {
    constructor(x, z, speciesKey, team = 0) {
        this.id = null;

        this.pos = { x, z };
        this.vel = { x: 0, z: 0 };
        this.angle = 0;

        this.speciesKey = speciesKey;
        this.team = team;
        this.isDead = false;

        this.baseStats = makeStats(0);
        this.modifiedStats = makeStats(0);

        this.currentHP = 0;
        this.currentStamina = 0;
        this.currentEnergy = 0;

        this.composites = { inner: null, outer: null };

        this.moveset = [];
        this.cooldowns = {};

        this.abilityManager = null;
        this.effectManager = null;

        this.soaks = {
            water: 0,
            electric: 0,
            chemical: 0,
            temp: 0
        };

        this.soakCap = {
            water: 0,
            electric: 0,
            chemical: 0
        };

        this.soakBaseline = {
            water: 0,
            electric: 0,
            chemical: 0,
            temp: 0
        };

        this.tempCapHot = 0;
        this.tempCapCold = 0;
        this.tempRatio = 0;

        this.intent = null;
        this.brain = null;

        this.ownerId = null;
        this.runtimeMode = "wild"; // wild, pet, summoned, hostile

        this.morphStage = 0;
        this.morphPath = null;
        this.morphPoints = {};
    }

    tick(dt, world) {}
    applyRecovery(dt) {}
    applyMovement(dt, world) {}
    updateFacing() {}
    draw(ctx, camera) {}
}

/* =========================================================
   8. CREATURE CREATION / SYNC
   ========================================================= */

class CreatureFactory {
    constructor() {}
// OwnedCreatureData → CreatureRuntime
    // Called when summoning or loading a creature into the world
    hydrateRuntime(record, spawnPos, team = 0) {
        const runtime = new CreatureRuntime(spawnPos.x, spawnPos.z, record.speciesKey, team);
        
        runtime.id        = record.id;
        runtime.ownerId   = record.ownerId;
        runtime.morphPath  = record.morphPath;
        runtime.morphStage = record.morphStage;
        runtime.morphPoints = { ...record.morphPoints };
        runtime.moveset   = [...record.moveset];
        runtime.composites = deepClone(record.composites);

        // Recompute everything derived from the record
        runtime.baseStats     = deepClone(record.baseStats);
        runtime.modifiedStats = this.computeModifiedStats(record);

        // Init resource pools from computed stats — always full on summon
        runtime.currentHP      = runtime.modifiedStats.maxHP;
        runtime.currentStamina = runtime.modifiedStats.stamina;
        runtime.currentEnergy  = runtime.modifiedStats.energy;

        // Init soak system
        const allComps = this.getAllCompKeys(runtime.composites);
        runtime.soakCap      = this.initSoakCaps(runtime.modifiedStats.size, allComps);
        runtime.soakBaseline = this.initSoakBaselines(allComps);
        const tempCaps       = this.initTempCaps(runtime.modifiedStats.size, allComps);
        runtime.tempCapHot   = tempCaps.hot;
        runtime.tempCapCold  = tempCaps.cold;
        runtime.soaks        = { ...runtime.soakBaseline, temp: 0 };
        runtime.tempRatio    = this.calcTempRatio(runtime);

        // Wire up managers
        runtime.abilityManager = new AbilityManager(runtime);
        runtime.abilityManager.initFromMoveset(runtime.moveset);
        runtime.effectManager = new EffectManager(runtime);

        return runtime;
    }
    dehydrateRuntime(runtime, record) {
        record.level       = runtime.level ?? record.level;
        record.xp          = runtime.xp    ?? record.xp;
        record.morphPath   = runtime.morphPath;
        record.morphStage  = runtime.morphStage;
        record.morphPoints = { ...runtime.morphPoints };
        record.moveset     = [...runtime.moveset];

        // Stats only write back if they were changed in-world
        // (level up, morph) — base variation never changes
        record.baseStats = deepClone(runtime.baseStats);

        // bond/loyalty would update here too once implemented
    }
    createWild(speciesKey, spawnPos, biomeKey) {}
    createFromOwnedData(record, spawnPos, team = 0) {}
    writeBackToOwned(runtimeCreature, ownedRecord) {}

    rollEntityStats(speciesKey, compositeKeys) {}
    rollStarterMoves(speciesKey) {}
    generateVariation(maxVariation) {}
    scaleStats(statBoost, multiplier) {}

    initSoakCaps(size, compKeys) {}
    initTempCaps(size, compKeys) {}
    initSoakBaselines(compKeys) {}
    calcTempRatio(creature) {}
    getAllCompKeys(composites) {
        const inner = Array.isArray(composites.inner) ? composites.inner : [composites.inner];
        const outer = Array.isArray(composites.outer) ? composites.outer : [composites.outer];
        return [...inner, ...outer].filter(Boolean);
    }
}

/* =========================================================
   9. PROGRESSION / MORPH / MATERIAL HELPERS
   ========================================================= */

const LevelService = {
    ensure(creatureOrRecord) {},
    xpNeeded(level) {},
    addXP(creatureOrRecord, amount) {},
    recomputeStats(creatureOrRecord) {}
};

const MorphService = {
    canMorph(creatureOrRecord, morphKey) {},
    applyMorph(creatureOrRecord, morphKey) {},
    grantMorphPoints(creatureOrRecord, materialKey, amount) {}
};

function recomputeModifiedStats(creatureOrRecord) {}

function getCompositeList(creature) {}
function getCompositeThresholds(creature) {}
function getTempState(creature) {}

function applyDamage(target, amount, damageType, ability) {}
function applySoak(target, soakType, amount) {}
function decaySoaks(creature, dt) {}
function applyCompositeSpecialEffects(creature, dt) {}

/* =========================================================
   10. COMBAT / ABILITIES / EFFECTS
   ========================================================= */

class AbilityManager {
    constructor(creature) {
        this.host = creature;
        this.cooldowns = {};
        this.slots = [null, null, null, null];
    }

    initFromMoveset(movesetKeys) {}
    tick(dt) {}
    canUse(key) {}
    use(key, world, aimAt, targetId = null) {}
    execute(key, world, aimAt, targetId = null) {}
    entitiesInRadius(world, center, radius) {}
}

class EffectManager {
    constructor(creature) {
        this.host = creature;
        this.activeEffects = [];
    }

    add(effectKey, source = null) {}
    remove(effectKey) {}
    tick(dt, world) {}
}

class CombatService {
    constructor(world) {
        this.world = world;
    }

    resolveAbilityUse(source, abilityKey, targetOrPoint) {}
    resolveMeleeHit(source, target, ability) {}
    resolveProjectileHit(projectile, target) {}
    resolveAreaEffect(areaEffect, targets) {}
}
/* =========================================================
   11. PROJECTILES / AOE / ADJACENT COMBAT ENTITIES
   ========================================================= */

class Projectile extends WorldEntity {
    constructor(x, z, ownerId, team, payload) {
        super(x, z);
        this.ownerId = ownerId;
        this.team = team;
        this.payload = payload;

        this.vel = { x: 0, z: 0 };
        this.life = 0.75;
        this.radius = 5;
    }

    update(dt, world) {}
    onHit(target, world) {}
}

class HomingProjectile extends Projectile {
    constructor(x, z, ownerId, team, payload) {
        super(x, z, ownerId, team, payload);
        this.targetId = null;
        this.turnRate = 3;
    }

    update(dt, world) {}
}

class AreaEffect extends WorldEntity {
    constructor(x, z, payload) {
        super(x, z);
        this.payload = payload;
        this.radius = 30;
        this.life = 1.0;
    }

    update(dt, world) {}
}

/* =========================================================
   12. AI / BRAINS
   ========================================================= */

class Brain {
    constructor() {
        this.host = null;

        this.type = "wild";
        this.mode = "auto";
        this.nature = "passive";

        this.aggroRange = 60;
        this.followDistance = 0;
        this.leashDistance = 0;
        this.wanderEnable = false;

        this.targetFocus = null;
        this.intentRequest = this.makeEmptyIntent();

        this.observedCreatures = [];
        this.enemyCreatures = [];
        this.observedProjectiles = [];
        this.enemyProjectiles = [];
    }

    makeEmptyIntent() {
        return {
            move: { x: 0, z: 0 },
            ability: null,
            targetId: null,
            aimAt: null,
            dodge: false
        };
    }

    attachTo(creature) {}
    think(world, dt) {}

    scanEntities(world) {}
    decideTarget() {}
    decideAction() {}
    decideMovement() {}
    decideAbility(dt) {}
    writeIntoHost() {}
}

class PlayerControlledBrain extends Brain {
    constructor(playerEntity) {
        super();
        this.playerEntity = playerEntity;
    }

    think(world, dt) {
        // convert player input into creature intent
    }
}

/* =========================================================
   13. WORLD SERVICES
   ========================================================= */

class SpawnField {
    constructor(world, player, options = {}) {
        this.world = world;
        this.player = player;

        this.radius = options.radius ?? 160;
        this.innerNoSpawn = options.innerNoSpawn ?? 40;
        this.maxWild = options.maxWild ?? 8;
        this.spawnInterval = options.spawnInterval ?? 2;
        this.timer = 0;
    }

    update(dt) {}
    trySpawnWild() {}
    randomSpawnPoint() {}
    cleanupFarCreatures() {}
}

class SpawnService {
    constructor(world, creatureFactory) {
        this.world = world;
        this.creatureFactory = creatureFactory;
    }

    spawnWild(speciesKey, pos, biomeKey) {}
    despawnCreature(creatureId) {}
    findValidSpawnPointNear(pos, radius) {}
}

class SummonService {
    constructor(world, creatureFactory) {
        this.world = world;
        this.creatureFactory = creatureFactory;
    }

    summonActiveCreature(playerEntity) {
        const record  = profile.storage.get(activeId);
        const runtime = this.creatureFactory.hydrateRuntime(record, spawnPos, team);
        this.world.addCreature(runtime);
    }
    recallCreature(playerEntity) {
        const record = profile.storage.get(runtime.id);
        this.creatureFactory.dehydrateRuntime(runtime, record);
        this.world.removeCreature(runtime);
    }
    findSummonPointNearPlayer(playerEntity) {}
}

class InteractionService {
    constructor(world) {
        this.world = world;
    }

    findInteractTarget(actor) {}
    validateInteraction(actor, target, itemKey = null) {}
    applyInteraction(actor, target, itemKey = null) {}
}

class EncounterService {
    constructor(world) {
        this.world = world;
    }

    buildEncounterForCreature(creature, sourceType = "wild") {}
    tryStartEncounter(playerEntity, targetCreature) {}
    resolveEncounter(encounter, result) {}
}

class AttractionService {
    constructor(world) {
        this.world = world;
    }

    getAttractionScore(playerEntity, biomeKey, speciesKey) {}
    getSpawnWeightModifier(playerEntity, biomeKey, speciesKey) {}
}

class MorphPointService {
    constructor(world) {
        this.world = world;
    }

    grantFromBattle(creatureOrRecord, result) {}
    grantFromBiomeExposure(creatureOrRecord, biomeKey, dt) {}
    grantFromInteraction(creatureOrRecord, nodeType, result) {}
}

class ItemService {
    constructor(world) {
        this.world = world;
    }

    canUseItem(playerEntity, itemKey, target = null) {}
    useItem(playerEntity, itemKey, target = null) {}
}
/* =========================================================
   14. WORLD CONTAINER
   ========================================================= */

class World {
    constructor() {
        this.space = null;
        this.chunkManager = null;
        this.biomeService = null;

        this.creatureFactory = null;
        this.spawnService = null;
        this.summonService = null;
        this.interactionService = null;
        this.encounterService = null;
        this.attractionService = null;
        this.morphPointService = null;
        this.itemService = null;
        this.combatService = null;

        this.player = null;
        this.camera = null;

        this.creatures = [];
        this.projectiles = [];
        this.areaEffects = [];
        this.interactables = [];
        this.spawnFields = [];

        this.pendingAdds = [];
        this.pendingRemoves = [];

        this.time = 0;
        this.activeEvent = null;
    }

    initialize(config) {
        // create world bounds
        // create chunk manager and generate starting area
        // create services
        // create player profile and player entity
        // create camera and follow player
        // create spawnfield(s)
    }

    update(dt, inputManager) {
        // 1. advance world time
        // 2. read player input
        // 3. update player
        // 4. update chunk loading around player
        // 5. update spawn fields
        // 6. run brains for creatures
        // 7. tick creatures
        // 8. tick projectiles and area effects
        // 9. tick interactables
        // 10. apply cleanup
        // 11. update camera
    }

    draw(ctx) {
        // background / terrain
        // interactables
        // creatures
        // projectiles
        // area effects
        // player
        // overlays
    }

    addCreature(creature) {}
    addProjectile(projectile) {}
    addAreaEffect(areaEffect) {}
    addInteractable(entity) {}

    queryCreaturesInRadius(x, z, radius) {}
    queryInteractablesInRadius(x, z, radius) {}
    cleanup() {}
}
/* =========================================================
   15. CAMERA / INPUT
   ========================================================= */

class Camera {
    constructor() {
        this.x = 0;
        this.z = 0;
        this.zoom = 1;
        this.target = null;
    }

    follow(entity) {}
    update(dt) {}
    worldToScreen(x, z) {}
    screenToWorld(sx, sz) {}
}

class InputManager {
    constructor() {
        this.keys = {};
        this.mouse = {};
    }

    bind() {}
    isDown(code) {}
    consumePress(code) {}
}

/* =========================================================
   16. UI / MENUS
   ========================================================= */

class UIManager {
    constructor() {
        this.hud = null;
        this.creatureMenu = null;
        this.inventoryMenu = null;
    }

    initialize(world) {
        this.hud = new HUD(world);
        this.creatureMenu = new CreatureMenuUI(world.player.profile);
        this.inventoryMenu = new InventoryUI(world.player.profile);
    }

    update(dt, world, inputManager) {}
    draw(ctx, world) {}
}

class HUD {
    constructor(world) {
        this.world = world;
    }

    draw(ctx) {}
}

class CreatureMenuUI {
    constructor(playerProfile) {
        this.playerProfile = playerProfile;
        this.visible = false;
        this.selectedCreatureId = null;
    }

    open() {}
    close() {}
    draw(ctx) {}

    showParty() {}
    showStorage() {}
    inspectCreature(recordId) {}
    moveCreatureToParty(recordId, slot) {}
    moveCreatureToStorage(recordId) {}
    renameCreature(recordId, newName) {}
}

class InventoryUI {
    constructor(playerProfile) {
        this.playerProfile = playerProfile;
        this.visible = false;
    }

    open() {}
    close() {}
    draw(ctx) {}
}

const game = new Game();
game.start();