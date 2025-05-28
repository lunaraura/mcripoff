let noise;

class ChunkManager {
  constructor(chunkSize = 16) {
    this.chunkSize = chunkSize;
    this.chunks = new Map(); // key: "cx,cz" => { blocks, meshRefs }
    this.pending = [];  // queue of [cx, cz] to build
    this.lastCenter = { cx: null, cz: null };
  }
  scheduleChunk(cx, cz) {
    const key = this.getChunkKey(cx, cz);
    if (!this.chunks.has(key) && !this.pending.find(p => p[0] === cx && p[1] === cz)) {
      this.pending.push([cx, cz]);
    }
  }
  getChunkKey(cx, cz) {
    return `${cx},${cz}`;
  }

  isChunkLoaded(cx, cz) {
    return this.chunks.has(this.getChunkKey(cx, cz));
  }

  generateChunk(cx, cz) {
    const key = this.getChunkKey(cx, cz);
    if (this.chunks.has(key)) return;

    const blocks = [];
    const meshRefs = [];
    const baseX = cx * this.chunkSize;
    const baseZ = cz * this.chunkSize;

    for (let x = 0; x < this.chunkSize; x++) {
      for (let z = 0; z < this.chunkSize; z++) {
        const wx = baseX + x;
        const wz = baseZ + z;
        const h = getHeight(wx, wz);
        for (let y = 0; y <= h; y++) {
          if (worldState.data[wx]?.[y]?.[wz]) continue; // Don't overwrite player data
          const id = y === h ? 12 : 11;
          placeBlockAt(wx, y, wz, id);
          meshRefs.push(`b-${wx}-${y}-${wz}`); // track mesh names
        }
      }
    }
    this.chunks.set(key, { blocks, meshRefs });
    console.log("Generating chunk", cx, cz);

  }

  unloadChunk(cx, cz) {
    const key = this.getChunkKey(cx, cz);
    const chunk = this.chunks.get(key);
    if (!chunk) return;

    for (const name of chunk.meshRefs) {
      const obj = scene.getObjectByName(name);
      if (obj) {
        obj.geometry.dispose();
        obj.material.dispose();
        scene.remove(obj);
      }
    }

    this.chunks.delete(key);
  }

  updateVisibleChunks(playerPos) {
    const { cx, cz } = getChunkCoord(playerPos, this.chunkSize);
    if (cx === this.lastCenter.cx && cz === this.lastCenter.cz) return;
    this.lastCenter = { cx, cz };

    const needed = new Set();
    for (let dx = -LOAD_RADIUS; dx <= LOAD_RADIUS; dx++) {
      for (let dz = -LOAD_RADIUS; dz <= LOAD_RADIUS; dz++) {
        const nx = cx + dx, nz = cz + dz;
        needed.add(this.getChunkKey(nx, nz));
        this.scheduleChunk(nx, nz);  // 👈 schedule instead of generate immediately
      }
    }
    for (const key of this.chunks.keys()) {
      if (!needed.has(key)) {
        const [oldX, oldZ] = key.split(',').map(Number);
        this.unloadChunk(oldX, oldZ);
      }
    }
  }
    processChunkQueue(limit = 1) {
    for (let i = 0; i < limit && this.pending.length; i++) {
      const [cx, cz] = this.pending.shift();
      this.generateChunk(cx, cz);
    }
  }
}

function getHeight(x, z) {
  const scale = 0.1;
  const height = noise.noise2D(x * scale, z * scale);
  return Math.floor(height * 5) + 4;
}

function generateInitialChunks(seed, controls) {
  console.log("Generating initial chunks")
  noise = new SimplexNoise(seed.toString());
  const chunkManager = new ChunkManager(16);
  chunkManager.generateChunk(0, 0);
  chunkManager.generateChunk(1, 0);
  chunkManager.generateChunk(0, 1);
  chunkManager.generateChunk(1, 1);
  controls.getObject().position.set(8, getHeight(8, 8) + 2, 8);
  return chunkManager;
}

//
const CHUNK_SIZE = 8;
const LOAD_RADIUS = 1;

function getChunkCoord(pos, chunkSize) {
  return {
    cx: Math.floor(pos.x / chunkSize),
    cz: Math.floor(pos.z / chunkSize)
  };
}
