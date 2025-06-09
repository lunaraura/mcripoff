let noise;
const chunkSize = 16;
let scene = new THREE.Scene();
let camera = new THREE.PerspectiveCamera(75, window.innerWidth/window.innerHeight, 0.1, 2000);
let renderer = new THREE.WebGLRenderer();
renderer.setSize(600, 600);
document.body.appendChild(renderer.domElement);
const keys   = Object.create(null);
const renderList = [];
const frustum = new THREE.Frustum();
raycaster = new THREE.Raycaster(); // Initialize raycaster
dirV = new THREE.Vector3(); // Direction vector


const camMat = new THREE.Matrix4();
const lastCamMatrix = new THREE.Matrix4();
let lastCull = 0;
const CULL_INTERVAL = 100; // ms
function render(){
  let displayRadius = 2
  //player position relative to current chunk
  //display certain amount of meshes: displayRadius
}
let cameraData = { x:0, y:0, z:0, vx:0, vy:0, vz:0 }

function updateVisibility(camera) {
  // cameraData.x += cameraData.vx
  // cameraData.y += cameraData.vy
  // cameraData.z += cameraData.vz
  // camera.position.set(cameraData.x, cameraData.y, cameraData.z);
  // cameraData.vx *=0.9;
  // cameraData.vy *=0.9;
  // cameraData.vz *=0.9;
  const now = performance.now();
  if (now - lastCull < CULL_INTERVAL) return;

  if (camera.matrixWorld.equals(lastCamMatrix)) return;

  lastCull = now;
  lastCamMatrix.copy(camera.matrixWorld);

  camMat.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
  frustum.setFromProjectionMatrix(camMat);

  for (const mesh of renderList) {
    mesh.visible = frustum.intersectsObject(mesh);
  }
}
function updateRayViz() {
  // copy current origin + direction
  camera.getWorldDirection(dirV);
  const origin = controls.getObject().position.clone();

  raycaster.set(origin, dirV);
  raycaster.far = RAY_LEN;

}

class ChunkManager {
  constructor(chunkSize = 16) {
    this.chunkSize = chunkSize;
    this.chunks = new Map(); // key: "cx,cz" => Chunk instance
    this.pending = []; // Queue of [cx, cz] to build
    this.lastCenter = { cx: null, cz: null };
  }

  getChunkKey(cx, cz) {
    return `${cx},${cz}`;
  }

  scheduleChunk(cx, cz) {
    const key = this.getChunkKey(cx, cz);
    if (!this.chunks.has(key) && !this.pending.find(p => p[0] === cx && p[1] === cz)) {
      this.pending.push([cx, cz]);
    }
  }

  generateChunk(cx, cz, getHeight, placeBlockAt) {
    const key = this.getChunkKey(cx, cz);
    if (this.chunks.has(key)) return;

    const chunk = new Chunk(cx, cz, this.chunkSize);
    chunk.generateBlocks(getHeight, placeBlockAt);
    this.chunks.set(key, chunk);
  }

  unloadChunk(cx, cz, scene) {
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

  updateVisibleChunks(playerPos, getChunkCoord, LOAD_RADIUS, scene, getHeight, placeBlockAt) {
    const { cx, cz } = getChunkCoord(playerPos, this.chunkSize);
    if (cx === this.lastCenter.cx && cz === this.lastCenter.cz) return;
    this.lastCenter = { cx, cz };

    const needed = new Set();
    for (let dx = -LOAD_RADIUS; dx <= LOAD_RADIUS; dx++) {
      for (let dz = -LOAD_RADIUS; dz <= LOAD_RADIUS; dz++) {
        const nx = cx + dx, nz = cz + dz;
        needed.add(this.getChunkKey(nx, nz));
        this.scheduleChunk(nx, nz);
      }
    }

    for (const key of this.chunks.keys()) {
      if (!needed.has(key)) {
        const [oldX, oldZ] = key.split(',').map(Number);
        this.unloadChunk(oldX, oldZ, scene);
      }
    }
  }
  processChunkQueue(limit = 1, getHeight, placeBlockAt) {
    for (let i = 0; i < limit && this.pending.length; i++) {
      const [cx, cz] = this.pending.shift();
      this.generateChunk(cx, cz, getHeight, placeBlockAt);
    }
  }
  addBlock(x, y, z, id, scene) {
    const cx = Math.floor(x / this.chunkSize);
    const cz = Math.floor(z / this.chunkSize);
    const key = this.getChunkKey(cx, cz);
    const chunk = this.chunks.get(key);
    if (chunk) {
      chunk.addBlock(x, y, z, id, scene);
    }
  }

  removeBlock(x, y, z, scene) {
    const cx = Math.floor(x / this.chunkSize);
    const cz = Math.floor(z / this.chunkSize);
    const key = this.getChunkKey(cx, cz);
    const chunk = this.chunks.get(key);
    if (chunk) {
      chunk.removeBlock(x, y, z, scene);
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
  chunkManager.generateChunk(0, 0);
  chunkManager.generateChunk(1, 0);
  chunkManager.generateChunk(0, 1);
  chunkManager.generateChunk(1, 1);
  chunkManager.generateChunk(0, -1);
  chunkManager.generateChunk(-1, 0);
  chunkManager.generateChunk(-1, -1);
  // chunkManager.generateChunk(-1, -2);
  controls.getObject().position.set(8, getHeight(8, 8) + 2, 8);
  return chunkManager;
}
function getChunkCoord(pos, chunkSize) {
  return {
    cx: Math.floor(pos.x / chunkSize),
    cz: Math.floor(pos.z / chunkSize)
  };
}

let chunkManager = new ChunkManager(16);

//perChunk
class Chunk {
  constructor(cx, cz, chunkSize) {
    this.cx = cx;
    this.cz = cz;
    this.chunkSize = chunkSize;
    this.blocks = new Map();
    this.meshRefs = []; 
    this.mesh = null; 
  }

  generateBlocks() {
    const baseX = this.cx * this.chunkSize;
    const baseZ = this.cz * this.chunkSize;
    const geometries = [];

    for (let x = 0; x < this.chunkSize; x++) {
      for (let z = 0; z < this.chunkSize; z++) {
        const wx = baseX + x;
        const wz = baseZ + z;
        const h = getHeight(wx, wz);

        for (let y = 0; y <= h; y++) {
          const id = y === h ? 2 : 1;
          const geometry = new THREE.BoxGeometry(1, 1, 1);
          geometry.translate(wx+0.5, y, wz+0.5); 
          geometries.push(geometry); 
          const key = `${wx},${y},${wz}`;
          this.blocks.set(key, { x: wx, y: y, z: wz, id: id });
        }
      }
    }

    // Merge all block geometries into one
    const mergedGeometry = THREE.BufferGeometryUtils.mergeBufferGeometries(geometries);
    const material = new THREE.MeshNormalMaterial({ flatShading: true });
    this.mesh = new THREE.Mesh(mergedGeometry, material);
    this.mesh.name = `chunk-${this.cx}-${this.cz}`; // Name the chunk mesh
    scene.add(this.mesh); // Add the chunk mesh to the scene
  }

  unload(scene) {
    if (this.mesh) {
      this.mesh.geometry.dispose();
      this.mesh.material.dispose();
      scene.remove(this.mesh);
      this.mesh = null;
    }
  }
  updateMesh(scene) {
    // Remove the existing mesh from the scene
    if (this.mesh) {
        scene.remove(this.mesh);
        this.mesh.geometry.dispose();
        this.mesh.material.dispose();
    }

    // Generate new geometry based on the current blocks
    const geometries = [];
    for (const block of this.blocks.values()) {
        const geometry = new THREE.BoxGeometry(1, 1, 1);
        geometry.translate(block.x + 0.5, block.y, block.z + 0.5); // Center the block
        geometries.push(geometry);
    }

    // Merge all block geometries into one
    const mergedGeometry = THREE.BufferGeometryUtils.mergeBufferGeometries(geometries);
    const material = new THREE.MeshNormalMaterial({ flatShading: true });
    this.mesh = new THREE.Mesh(mergedGeometry, material);
    this.mesh.name = `chunk-${this.cx}-${this.cz}`; // Name the chunk mesh

    // Add the new mesh to the scene
    scene.add(this.mesh);
}
  addBlock(x, y, z, id) {
    const key = `${x},${y},${z}`;
    this.blocks.set(key, { x, y, z, id }); 
    this.updateMesh(scene)
  }
  removeBlock(x, y, z) {
    const key = `${x},${y},${z}`;
    this.blocks.delete(key); 
    this.updateMesh(scene)
  }

  getBlock(x, y, z) {
    const key = `${x},${y},${z}`;
    return this.blocks.get(key); // Retrieve block from the map
  }
}

//player
let speed = 0.1;
const RAY_LEN = 10; 
const blockMeshes = []; 
class Entity {
  constructor(x,y,z,size){
    this.x = x;
    this.y = y;
    this.z = z;
    this.vx = 0;
    this.vy = 0;
    this.vz = 0;
    this.size = size; //{x,y,z}
  }
  move(){
    this.x += this.vx;
    this.y += this.vy;
    this.z += this.vz;
    this.vy -= 0.01
    this.vx *= 0.95;
    this.vy *= 0.95;
    this.vz *= 0.95;
    collision(this);
  };
  collision(){};
}
class Player extends Entity {
  constructor(x, y, z, size) {
    super(x, y, z, size);
  }
  move(){
    controls.getObject().position.set(this.x, this.y, this.z);
    const dir = new THREE.Vector3(
      (keys.d ? 1 : 0) - (keys.a ? 1 : 0),
      0,
      (keys.w ? 1 : 0) - (keys.s ? 1 : 0)
    ).normalize();
    controls.moveRight(dir.x * speed);
    controls.moveForward(dir.z * speed);
    collision(this);
    this.x = controls.getObject().position.x
    collision(this);
    this.z = controls.getObject().position.z
    collision(this);
    if (!grounded){
      this.vy -= 0.01;}
    this.y += this.vy;
    collision(this);
    this.vx *= 0.95;
    this.vy *= 0.95;
    this.vz *= 0.95;
  };
  rayCastHit(offset = 0) {
    camera.getWorldDirection(dirV); 
    const origin = controls.getObject().position.clone();
    raycaster.set(origin, dirV);
    raycaster.far = RAY_LEN;

    const hit = raycaster.intersectObjects(blockMeshes, false)[0];

    if (!hit) return null;
    console.log(hit)
    const normal = hit.face.normal.clone(); 
    const basePos = hit.object.position.clone(); 
    const targetPos = basePos.clone().addScaledVector(normal, offset).floor(); 

    return {
      x: targetPos.x,
      y: targetPos.y,
      z: targetPos.z,
      face: normal,
      hitPos: hit.point,
      block: basePos
    };
  }
  placeBlock() {
    const hit = this.rayCastHit(1);
    if (hit) {
      chunkManager.addBlock(hit.x, hit.y, hit.z, this.blockHolding, scene); 
    }
  }
  removeBlock() {
    const hit = this.rayCastHit(0);
    if (hit) {
      chunkManager.removeBlock(hit.x, hit.y, hit.z, scene);
    }
  }
}


document.addEventListener('keydown', (event) => {
    // if(event.key === 'w'){
    //     player.vz -= speed ;
    // }
    // if(event.key === 's'){
    //     player.vz += speed ;
    // }
    // if(event.key === 'a'){
    //     player.vx -= speed ;
    // }
    // if(event.key === 'd'){
    //     player.vx += speed ;
    // }
    if(event.key === 'e'){
        player.vy += speed * 2;
    }    
    if(event.key === 'q'){
        player.vy -= speed ;
    }
})

//pre-defined collisionBoxes
const standardSize = 1;
const playerSize = standardSize;
const blockSize = standardSize;
const half = playerSize / 2;
const height = playerSize * 2;
const checkRadius = {x:Math.ceil(playerSize/blockSize), y:Math.ceil(height/blockSize), z:Math.ceil(playerSize/blockSize)}

function collision(entity){
   grounded = false;
   const min = {x: entity.x - half, y: entity.y, z: entity.z - half};
   const max = {x: entity.x + half, y: entity.y + height, z: entity.z + half};

   for(let dx = -checkRadius.x; dx <= checkRadius.x; dx++){
     for(let dy = -checkRadius.y; dy <= checkRadius.y; dy++){
        for(let dz = -checkRadius.z; dz <= checkRadius.z; dz++){
          const wx = Math.floor(entity.x + dx);
          const wz = Math.floor(entity.z + dz);
          const cx = Math.floor(wx / chunkSize);
          const cz = Math.floor(wz / chunkSize);
          const chunkKey = `${cx},${cz}`;

          const chunk = chunkManager.chunks.get(chunkKey);
          if (!chunk) continue;
          const block = chunk.getBlock(wx, Math.floor(entity.y + dy), wz);
          if (!block) continue;
           let bx = block.x;
           let by = block.y;
           let bz = block.z;
           let bmin = {x: bx, y:by, z: bz};
           let bmax = {x: bx + blockSize, y: by + blockSize, z: bz + blockSize}
           
           if (
             max.x > bmin.x && min.x < bmax.x &&
             max.y > bmin.y && min.y < bmax.y &&
             max.z > bmin.z && min.z < bmax.z
           ) {
             const overlapX = Math.min(max.x - bmin.x, bmax.x - min.x)
             const overlapY = Math.min(max.y - bmin.y, bmax.y - min.y)
             const overlapZ = Math.min(max.z - bmin.z, bmax.z - min.z)
             if (overlapY <= overlapX && overlapY <= overlapZ){
                if (entity.y > by){
                   entity.y += overlapY;
                   grounded = true;
                } else {
                   entity.y -= overlapY;
                }
                entity.vy = 0
             }
             else if (overlapX <=overlapY && overlapX <= overlapZ){
                if (entity.x > bx) entity.x += overlapX;
                else entity.x -= overlapX;
                entity.vx = 0
             } else {
                if (entity.z > bz) entity.z += overlapZ;
                else entity.z -= overlapZ;
                entity.vz = 0;
             }
            min.x = entity.x - half;
            max.x = entity.x + half;
            min.y = entity.y;
            max.y = entity.y + height; // Corrected
            min.z = entity.z - half;   // Corrected
            max.z = entity.z + half;   // Corrected
           }
        }
     }
   }
}
function init(){
  controls = new THREE.PointerLockControls(camera, renderer.domElement);
  renderer.domElement.addEventListener("click", () => controls.lock());
  worldSeed = Date.now(); 
  chunkManager = generateInitialChunks(worldSeed, controls);
  scene.add(new THREE.AmbientLight(0xffffff,0.3));
  const sun = new THREE.DirectionalLight(0xffffff,1);
  sun.position.set(5,10,7); scene.add(sun);
  initKeys();
}
//
function initKeys(){
  window.addEventListener("resize", () => {
    camera.aspect = innerWidth/innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight);
  });
  window.addEventListener("keydown", ev => { keys[ev.key.toLowerCase()] = true;
  if (ev.key === " ") keys[" "] = true;
  });
  window.addEventListener("mousedown", ev => {
  if (ev.button === 2) { 
    player.rayCastHit();
    player.placeBlock();
  }
  if (ev.button === 0) { 
    player.rayCastHit();
    player.removeBlock();
  }
  });
  window.addEventListener("keydown", ev => {
    const key = ev.key.toLowerCase();
    keys[key] = true;
    if (key >= "1" && key <= "9") {
      currentBlockId = parseInt(key);
      console.log(`Switched to block ID ${currentBlockId}`);
    }
  });

  window.addEventListener("contextmenu", ev => ev.preventDefault());
  window.addEventListener("keyup",   ev => keys[ev.key.toLowerCase()] = false); 
}
let player = new Player(0,10,0,{x:1,y:2,z:1})
function animate(){
    player.move();
    camera.position.set(player.x, player.y + 1, player.z)
    requestAnimationFrame(animate);
    updateVisibility(camera);
    updateRayViz();
    renderer.render(scene, camera);
}
init();
animate();
