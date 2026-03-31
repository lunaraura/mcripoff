//definitions
const biomes = {
    hills: {amp: 20, freq: 0.01},
    plains: {amp: 5, freq: 0.05},
    desert: {amp: 3, freq: 0.02},
    mountains: {amp: 40, freq: 0.005}
}
const floraTypes = {
    tree: {key: "tree", height: 5, density: 0.1},
    bush: {key: "bush", height: 2, density: 0.3},
    flower: {key: "flower", height: 1, density: 0.5}
}

// World generator: deterministic, seeded value-noise + FBM based
class WorldGenerator {
    constructor(seed = 1337) {
        this.seed = seed >>> 0;
    }

    // 32-bit integer hash -> [0,1)
    hash(ix, iy) {
        let x = (ix | 0) + 0x9e3779b9;
        let y = (iy | 0) + 0x85ebca6b;
        let h = (x * 374761393) ^ (y * 668265263) ^ this.seed;
        h = (h ^ (h >>> 13)) * 1274126177;
        return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
    }

    // smooth interpolation
    smooth(t) { return t * t * (3 - 2 * t); }
    lerp(a, b, t) { return a + (b - a) * t; }

    // value noise at fractional coordinates
    noise(x, y) {
        const ix = Math.floor(x);
        const iy = Math.floor(y);
        const fx = x - ix;
        const fy = y - iy;

        const v00 = this.hash(ix, iy);
        const v10 = this.hash(ix + 1, iy);
        const v01 = this.hash(ix, iy + 1);
        const v11 = this.hash(ix + 1, iy + 1);

        const ux = this.smooth(fx);
        const uy = this.smooth(fy);

        const a = this.lerp(v00, v10, ux);
        const b = this.lerp(v01, v11, ux);
        return this.lerp(a, b, uy);
    }

    // Fractional Brownian Motion (FBM)
    fbm(x, y, octaves = 4, lacunarity = 2.0, gain = 0.5) {
        let sum = 0;
        let amp = 1;
        let freq = 1;
        let norm = 0;
        for (let i = 0; i < octaves; i++) {
            sum += amp * this.noise(x * freq, y * freq);
            norm += amp;
            amp *= gain;
            freq *= lacunarity;
        }
        return sum / norm;
    }

    biomeFromValue(v) {
        if (v < 0.35) return 'desert';
        if (v < 0.55) return 'plains';
        if (v < 0.75) return 'hills';
        return 'mountains';
    }

    // Generate a biome map for a chunk (returns array length size*size of biome keys)
    generateBiomeMap(cx, cz, size = 16, opts = {}) {
        const scale = opts.scale || 0.01;
        const map = new Array(size * size);
        for (let z = 0; z < size; z++) {
            for (let x = 0; x < size; x++) {
                const wx = (cx * size + x) * scale;
                const wz = (cz * size + z) * scale;
                const v = this.fbm(wx, wz, opts.octaves || 4);
                map[z * size + x] = this.biomeFromValue(v);
            }
        }
        return map;
    }

    // Generate heightmap (integers) based on biome map
    generateHeightmap(biomeMap, cx, cz, size = 16, opts = {}) {
        const heights = new Array(size * size);
        const baseHeight = (opts.baseHeight === undefined) ? 64 : opts.baseHeight;
        for (let z = 0; z < size; z++) {
            for (let x = 0; x < size; x++) {
                const idx = z * size + x;
                const biome = biomeMap[idx];
                const b = biomes[biome] || biomes.plains;
                const wx = (cx * size + x) * (b.freq || 0.01);
                const wz = (cz * size + z) * (b.freq || 0.01);
                const n = this.fbm(wx, wz, opts.octaves || 5);
                const h = Math.floor(baseHeight + (n - 0.5) * 2 * (b.amp || 5));
                heights[idx] = h;
            }
        }
        return heights;
    }

    // Water map from heightmap
    generateWaterMap(heightmap, seaLevel = 64) {
        const map = new Array(heightmap.length);
        for (let i = 0; i < heightmap.length; i++) map[i] = (heightmap[i] <= seaLevel);
        return map;
    }

    // Place flora deterministically per cell
    generateFloraMap(biomeMap, heightmap, waterMap, cx, cz, size = 16) {
        const flora = [];
        for (let z = 0; z < size; z++) {
            for (let x = 0; x < size; x++) {
                const idx = z * size + x;
                if (waterMap[idx]) continue;
                const biome = biomeMap[idx];
                const candidates = [];
                // simple rules: plains -> flowers/trees, hills -> trees/bush, desert -> sparse bushes
                if (biome === 'plains') candidates.push('flower', 'tree');
                if (biome === 'hills') candidates.push('bush', 'tree');
                if (biome === 'mountains') candidates.push('bush');
                if (biome === 'desert') candidates.push('bush', 'flower');

                if (candidates.length === 0) continue;

                // deterministic chance per cell
                const chance = this.hash(cx * 374761 + x, cz * 668265 + z);
                // choose flora based on biome density
                const chosen = candidates[Math.floor(chance * candidates.length) % candidates.length];
                const density = floraTypes[chosen] ? floraTypes[chosen].density : 0.1;
                if (this.hash(x, z + this.seed) < density) {
                    flora.push({x, z, type: chosen, height: floraTypes[chosen].height});
                }
            }
        }
        return flora;
    }

    // Convenience: generate full chunk
    generateChunk(cx, cz, size = 16, opts = {}) {
        const biomeMap = this.generateBiomeMap(cx, cz, size, opts);
        const heightmap = this.generateHeightmap(biomeMap, cx, cz, size, opts);
        const seaLevel = (opts.seaLevel === undefined) ? 64 : opts.seaLevel;
        const waterMap = this.generateWaterMap(heightmap, seaLevel);
        const flora = this.generateFloraMap(biomeMap, heightmap, waterMap, cx, cz, size);
        return {cx, cz, size, biomeMap, heightmap, waterMap, flora};
    }
}

// Attach generator for easy debugging in browser
if (typeof window !== 'undefined') {
    window.WorldGenerator = WorldGenerator;
    window.generateChunk = (cx, cz, seed = 1337, size = 16, opts = {}) => {
        const g = new WorldGenerator(seed);
        return g.generateChunk(cx, cz, size, opts);
    };
}

//mediator definitions/keys
const entitySpawns = {
    hills: ['goat', 'eagle'],
    plains: ['deer', 'rabbit'],
    desert: ['scorpion', 'lizard'],
    mountains: ['bear', 'wolf']
}

//precondition
class ChunkManage{
    constructor(){
        this.chunkSize = 16;
        this.worldHeight = 256;
        this.renderDistance = 8;
        this.createdChunks = new Map();
    }
    chunkPos(playerPos){
        return {
            x: Math.floor(playerPos.x / this.chunkSize),
            y: Math.floor(playerPos.y / this.chunkSize),
            z: Math.floor(playerPos.z / this.chunkSize)
        }
    }
    ifExists(cx,cz){
        return this.createdChunks.has(`${cx},${cz}`);
    }
    loadChunk(cx,cz){
        //load chunk data from server or local storage
        //mostly for graphics/processing memory power
    }
    biomeNoise(x,z){
        //basic wrapper for biome noise (delegates to WorldGenerator when used)
        const gen = new WorldGenerator();
        return gen.fbm(x, z, 3);
    }

    // Generate a chunk and optionally spawn entities into it
    createChunk(cx, cz, seed = 1337, size = this.chunkSize, opts = {}, entityManager = null){
        const gen = new WorldGenerator(seed);
        const chunkData = gen.generateChunk(cx, cz, size, opts);
        this.createdChunks.set(`${cx},${cz}`, chunkData);
        if (entityManager && typeof entityManager.spawnForChunk === 'function') {
            entityManager.spawnForChunk(chunkData, cx, cz, seed, opts);
        }
        return chunkData;
    }
    unloadChunk(cx,cz){
        //remove chunk data from memory
        //mostly for graphics/processing memory power
        this.createdChunks.delete(`${cx},${cz}`);
    }
}
class Chunk{
    constructor(){
        this.entities = []; //entities in this chunk
        this.heightmap = new Array(16*16); //heightmap data
        //simplified for roblox 2d terrain
        this.flora = []; //flora data
    }
}

// Simple mediators (stubs) to avoid runtime errors and allow future expansion
class DataMediator {
    constructor() { }
}
class ActionMediator {
    constructor() { }
}

// Entity manager: tracks entities, can spawn deterministically per-chunk
class EntityManage {
    constructor() {
        this.entities = new Map();
        this._nextId = 1;
    }
    add(entity) {
        const id = this._nextId++;
        entity.id = id;
        this.entities.set(id, entity);
        return entity;
    }
    remove(id) {
        return this.entities.delete(id);
    }
    get(id) {
        return this.entities.get(id);
    }
    // spawn entities for a chunkData produced by WorldGenerator
    spawnForChunk(chunkData, cx, cz, seed = 1337, opts = {}) {
        const gen = new WorldGenerator(seed);
        const size = chunkData.size || 16;
        const placed = [];
        for (let z = 0; z < size; z++) {
            for (let x = 0; x < size; x++) {
                const idx = z * size + x;
                const biome = chunkData.biomeMap[idx];
                const candidates = entitySpawns[biome] || [];
                if (!candidates.length) continue;
                // small spawn chance per cell (tweakable)
                const spawnChance = opts.spawnChance || 0.03;
                const r = gen.hash(cx * 73856093 + x, cz * 19349663 + z);
                if (r < spawnChance) {
                    const species = candidates[Math.floor(r * candidates.length) % candidates.length];
                    const worldX = cx * size + x + 0.5;
                    const worldZ = cz * size + z + 0.5;
                    const y = (chunkData.heightmap && chunkData.heightmap[idx]) || 64;
                    let ent = null;
                    if (typeof EntityFactory !== 'undefined') {
                        ent = EntityFactory.createCreature(species, {x: worldX, y, z: worldZ});
                    } else if (typeof Entity !== 'undefined') {
                        ent = new Entity(1, species, {x: worldX, y, z: worldZ});
                    } else {
                        ent = {type: 'wildCreature', subtype: species, position: {x: worldX, y, z: worldZ}};
                    }
                    this.add(ent);
                    placed.push(ent);
                    if (!chunkData.entities) chunkData.entities = [];
                    chunkData.entities.push(ent);
                }
            }
        }
        return placed;
    }
    // basic tick (no movement implemented yet)
    update(dt) {
        // call individual entity updates if implemented
        for (const e of this.entities.values()) {
            if (typeof e.update === 'function') {
                try { e.update(dt); } catch (err) { /* ignore per-entity errors */ }
            }
        }
    }
}


//generate world
class World {
    constructor(){
        this.chunks = new ChunkManage(); //chunk block data, etc
        this.entities = new EntityManage(); //entity in physicality (creatures, projectiles, etc)
        this.dataFlow = new DataMediator(); //mediator of physicality
        this.requests = new ActionMediator();

    }
    // Convenience: generate and load a chunk, spawning entities into the world's EntityManage
    generateAndLoadChunk(cx, cz, seed = 1337, size = 16, opts = {}){
        return this.chunks.createChunk(cx, cz, seed, size, opts, this.entities);
    }
}

// debug API: spawn entities for a chunk without attaching to a world instance
if (typeof window !== 'undefined') {
    window.spawnEntitiesForChunk = (cx, cz, seed = 1337, size = 16, opts = {}) => {
        const gen = new WorldGenerator(seed);
        const chunk = gen.generateChunk(cx, cz, size, opts);
        const em = new EntityManage();
        return em.spawnForChunk(chunk, cx, cz, seed, opts);
    };
    window.World = World;
}
