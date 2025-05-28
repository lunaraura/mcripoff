let scene, camera, renderer, controls;
const keys   = Object.create(null);
const clock  = new THREE.Clock();
let peer, isInitiator = false;
let worldSeed = null;
const cubeSize = 1;
const cubeGeo = new THREE.BoxGeometry(cubeSize, cubeSize, cubeSize);
const sphere = new THREE.Mesh(
  new THREE.SphereGeometry(0.05),
  new THREE.MeshBasicMaterial({ color: 0xff0000 })
);
const blockMeshes = [];
const raycaster = new THREE.Raycaster();
const dirV      = new THREE.Vector3();
let currentBlockId = 1;
let chunkManager = null;
const blockPalette = {
  1: 0xffffff, // white
  2: 0xff0000, // red
  3: 0xFFA500, // orange
  4: 0xffff00, // yellow
  5: 0x00ff00, // green
  6: 0x0000ff, // blue
  7: 0x00ffff, // cyan
  8: 0xff00ff, // magenta
  9: 0x888888, // gray
  10: 0x000000,  // black
  11: 0x8B4513, // brown
  12: 0x33FF33, // grass
  13: 0x800080, // purple
};
const RAY_LEN = 10;

const worldState = {
  data: {},
  update(x,y,z,id){
    if (!this.data[x])    this.data[x]    = {};
    if (!this.data[x][y]) this.data[x][y] = {};
    this.data[x][y][z] = id;
  }
};
function updateRayViz() {
  // copy current origin + direction
  camera.getWorldDirection(dirV);
  const origin = controls.getObject().position.clone();

  raycaster.set(origin, dirV);
  raycaster.far = RAY_LEN;
  const hit = raycaster.intersectObjects(renderList, false)[0];

  const end = hit ? hit.point : origin.clone().addScaledVector(dirV, RAY_LEN);

  const pos = rayViz.geometry.attributes.position.array;
  pos[0] = origin.x; pos[1] = origin.y; pos[2] = origin.z;
  pos[3] = end.x;    pos[4] = end.y;    pos[5] = end.z;
  rayViz.geometry.attributes.position.needsUpdate = true;
  sphere.position.copy(end);

}
const validatorInput = {
  stack : [],
  world : {
    data : worldState.data,
    setBlock : (x,y,z,id) => worldState.update(x,y,z,id),
    getBlock : (x,y,z,id)    => worldState.data[x]?.[y]?.[z] ?? 0
  },
  ip: 0, halted: false
};

function setupPeer() {
  peer = new SimplePeer({ initiator: isInitiator, trickle: false });

  peer.on("signal", s => {
    console.log("Signal data generated:", s);
    document.getElementById("localSignal").value = JSON.stringify(s);
  });

  peer.on("connect", () => {
    console.log("✅ P2P connected");
    if (isInitiator) {
      worldSeed = Date.now();
      chunkManager = generateInitialChunks(worldSeed, controls);
      peer.send(JSON.stringify({ type: "seed", value: worldSeed }));
    }
  });

  peer.on("data", raw => handleRemote(JSON.parse(raw)));
  peer.on("error", err => console.error("Peer error:", err));
  peer.on("close", () => console.log("Peer connection closed"));
}

function handleRemote(msg){
  if (msg.type === "seed" && !isInitiator) {
    worldSeed = msg.value;
    console.log("Received seed:", worldSeed);
    chunkManager = generateInitialChunks(worldSeed, controls);
    return;
  }

  if (!chunkManager) {
    console.warn("Block update ignored: chunk manager not ready");
    return;
  }

  const id = msg.id ?? 1;
  const script = buildBlockScript(msg.type, msg, msg.type === "place" ? id : 0);

  const state = deepCopyState(validatorInput);
  runValidator(script, state);

  if (msg.type === "place") addBlock(msg.x, msg.y, msg.z, id);
  else removeBlock(msg.x, msg.y, msg.z);

  worldState.update(msg.x, msg.y, msg.z, msg.type === "place" ? id : 0);
}

function initScene(){
  scene  = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(75, innerWidth/innerHeight, 0.1, 1e3);
  camera.position.set(0,1.6,0);

  renderer = new THREE.WebGLRenderer({ antialias:true, canvas:document.querySelector("#canvas") });
  renderer.setSize(innerWidth, innerHeight);
  renderer.setClearColor(0x20202f);

  controls = new THREE.PointerLockControls(camera, renderer.domElement);
  renderer.domElement.addEventListener("click", () => controls.lock());

  scene.add(new THREE.AmbientLight(0xffffff,0.3));
  const sun = new THREE.DirectionalLight(0xffffff,1);
  sun.position.set(5,10,7); scene.add(sun);
  scene.add(sphere);

  const rayGeom = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(0, 0, -RAY_LEN) 
  ]);
  const rayMat = new THREE.LineBasicMaterial({
    color: 0xffff00,
    depthTest: false,
    transparent: true,
    opacity: 1.0,
    linewidth: 2
  });

  rayViz = new THREE.Line(rayGeom, rayMat);
  scene.add(rayViz);

  window.addEventListener("resize", () => {
    camera.aspect = innerWidth/innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight);
  });
  window.addEventListener("keydown", ev => { keys[ev.key.toLowerCase()] = true;
  //if (ev.key==="u") placeBlockInFront(); if (ev.key==="j") destroyBlockInFront();
  if (ev.key === " ") keys[" "] = true;
  });
  window.addEventListener("mousedown", ev => {
  if (ev.button === 2) { 
    placeBlockInFront();
  }
  if (ev.button === 0) { 
    destroyBlockInFront();
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

function mulberry32(a){return _=>{ let t=a+=0x6D2B79F5; t=(t^=t>>>15)* (t|1); t^=t+(t^=t>>>7)*61; return ((t^(t>>>14))>>>0)/4294967296 }}
function setupSignalUI(){
document.body.insertAdjacentHTML("beforeend", `
  <div id="signalUI" style="position:fixed;top:10px;left:10px;background:#0008;padding:12px;font:12px monospace;color:#fff;z-index:999">
    <textarea id="offerBox" placeholder="Paste remote signal here" style="width:240px;height:80px"></textarea><br/>
    <button id="startHost">Start Initiator</button>
    <button id="connectPeer">Connect Peer</button>
    <button id="startSolo">Start Solo</button><br/>
    <textarea id="localSignal" readonly style="width:240px;height:80px;margin-top:5px" placeholder="Your signal to copy"></textarea>
    <button id="applyRemote">Apply Remote Signal</button>
  </div>
`);

document.getElementById("startSolo").onclick = () => {
  worldSeed = Date.now();  // or fixed seed if you want consistent testing
  chunkManager = generateInitialChunks(worldSeed, controls);
  console.log("Solo mode started with seed:", worldSeed);
};
  const offerBox  = document.getElementById("offerBox");
  const localBox  = document.getElementById("localSignal");
  const startHost = document.getElementById("startHost");
  const connectBtn = document.getElementById("connectPeer");
document.getElementById("applyRemote").onclick = () => {
  const signal = JSON.parse(document.getElementById("offerBox").value);
  peer.signal(signal);
};

  startHost.onclick = () => {
    isInitiator = true;
    setupPeer();
  };

  connectBtn.onclick = () => {
    isInitiator = false;
    setupPeer();
    const remoteSignal = JSON.parse(offerBox.value);
    peer.signal(remoteSignal);
  };

  window.applyRemoteSignal = () => {
    const remoteSignal = JSON.parse(offerBox.value);
    peer.signal(remoteSignal);
  };
}

function animate(){
  movePlayer(clock.getDelta());
  updateRayViz();
  updateVisibility(camera);
  renderer.render(scene,camera);
  if (chunkManager) chunkManager.processChunkQueue(1);
  requestAnimationFrame(animate);
}
