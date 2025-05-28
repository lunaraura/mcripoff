const playerVelocity = new THREE.Vector3(0, 0, 0);
const gravity = -25;
const jumpForce = 10;
const playerSize = 1; // Player radius
let canJump = false;
let rayViz;                 // THREE.Line instance

function placeBlockInFront() {
  const t = trace(1);
  if (!t) return;

  const script = buildBlockScript("place", t, currentBlockId);
  const clone = deepCopyState(validatorInput);
  const res = runValidator(script, clone);
  runValidator(script, validatorInput);

  if (res.outputHash !== hashWorldState(validatorInput.world)) {
    console.warn("Local divergence?");
    return;
  }

  addBlock(t.x, t.y, t.z, currentBlockId);
  worldState.update(t.x, t.y, t.z, currentBlockId);

  if (peer?.connected) {
    peer.send(JSON.stringify({ type: "place", id: currentBlockId, ...t }));
  }
}

function destroyBlockInFront() {
  const t = trace(0);
  if (!t) return;

  removeBlock(t.block.x, t.block.y, t.block.z);
  worldState.update(t.block.x, t.block.y, t.block.z, 0);
  if (peer?.connected) peer.send(JSON.stringify({ type: "remove", x: t.block.x, y: t.block.y, z: t.block.z }));
}
///

function movePlayer(dt) {
  if (!controls.isLocked || !chunkManager) return;

  const pos = controls.getObject().position;
  const vel = playerVelocity;

  /* ---- WASD movement (camera-relative) ---- */
  const move = new THREE.Vector3(
    (keys.d ? 1 : 0) - (keys.a ? 1 : 0),
    0,
    (keys.w ? 1 : 0) - (keys.s ? 1 : 0)
  );
  if (move.lengthSq()) {
    const forward = new THREE.Vector3();
    camera.getWorldDirection(forward).setY(0).normalize();
    const right = new THREE.Vector3().crossVectors(forward,new THREE.Vector3(0,1,0)).normalize();
    move.normalize().multiplyScalar(5 * dt);
    pos.addScaledVector(forward,  move.z);
    pos.addScaledVector(right,    move.x);
  }

  /* ---- vertical motion ---- */
  if (canJump && keys[" "]) { vel.y = jumpForce; canJump = false; }
  vel.y += gravity * dt;
  pos.y += vel.y * dt;

  /* ---- face collision resolve ---- */
  constrainPlayerXYZ(pos, vel);

  /* ---- ground reset ---- */
  canJump = vel.y === 0;

  /* ---- keep camera in sync ---- */
  controls.getObject().position.copy(pos);
}
function constrainPlayerXYZ(player, vel) {
  const playerSize = 0.6;
  const blockSize = 1;
  let resistance = { x: 0.99, y: 0.99, z: 0.99 };
  const px = Math.floor(player.x);
  const py = Math.floor(player.y);
  const pz = Math.floor(player.z);

  grounded = false;
  // Iterate over candidate grid cells (assuming worldState.data holds block info keyed by coordinates)
  for (let dx = -1; dx <= 1; dx++) {
    for (let dy = -1; dy <= 1; dy++) {
      for (let dz = -1; dz <= 1; dz++) {
        const bx = px + dx;
        const by = py + dy;
        const bz = pz + dz;
        // Check if a block exists at this grid coordinate
        if (!worldState.data[bx]?.[by]?.[bz]) continue;
        // Use block center at (bx+0.5, by+0.5, bz+0.5)
        let distX = player.x - (bx + 0.5);
        let distY = player.y - (by + 0.5);
        let distZ = player.z - (bz + 0.5);
        let absDistX = Math.abs(distX);
        let absDistY = Math.abs(distY);
        let absDistZ = Math.abs(distZ);

        if (
          absDistX < blockSize / 2 + playerSize / 2 &&
          absDistY < blockSize / 2 + playerSize / 2 &&
          absDistZ < blockSize / 2 + playerSize / 2
        ) {
          // Collision detected, resolve along deepest penetration axis
          if (absDistX > absDistY && absDistX > absDistZ) {
            if (distX > 0) {
              player.x = bx + blockSize / 2 + playerSize / 2;
              resistance.y -= 0.4; resistance.z -= 0.4;
              vel.x *= -0.1;
            } else {
              player.x = bx - blockSize / 2 - playerSize / 2;
              resistance.y -= 0.4; resistance.z -= 0.4;
              vel.x *= -0.1;
            }
          } else if (absDistY > absDistX && absDistY > absDistZ) {
            if (distY > 0) {
              player.y = by + blockSize / 2 + playerSize / 2;
              resistance.x -= 0.4; resistance.z -= 0.4;
              vel.y *= -0.1;
              grounded = true;
            } else {
              player.y = by - blockSize / 2 - playerSize / 2;
              resistance.x -= 0.4; resistance.z -= 0.4;
              vel.y *= -0.1;
            }
          } else {
            if (distZ > 0) {
              player.z = bz + blockSize / 2 + playerSize / 2;
              resistance.x -= 0.4; resistance.y -= 0.4;
              vel.z *= -0.1;
            } else {
              player.z = bz - blockSize / 2 - playerSize / 2;
              resistance.x -= 0.4; resistance.y -= 0.4;
              vel.z *= -0.1;
            }
          }
        }
      }
    }
  }
    vel.x *= resistance.x
    vel.y *= resistance.y
    vel.z *= resistance.z
}
////
function addBlock(x, y, z, id) {
  const name = `b-${x}-${y}-${z}`;
  if (scene.getObjectByName(name)) return; // Prevent duplicate

  const color = blockPalette[id] ?? 0xffffff;
  const mat = new THREE.MeshStandardMaterial({ color });
  const mesh = new THREE.Mesh(cubeGeo, mat);
  mesh.position.set(x, y, z);
  mesh.name = name;
  scene.add(mesh);
  blockMeshes.push(mesh);
  renderList.push(mesh);
}

function removeBlock(x, y, z) {
  const name = `b-${x}-${y}-${z}`;
  const obj = scene.getObjectByName(name);
  if (obj) {
    obj.geometry.dispose();
    obj.material.dispose();
    scene.remove(obj);

    const i = blockMeshes.indexOf(obj);
    if (i !== -1) blockMeshes.splice(i, 1);
    if (i !== -1) renderList.splice(i, 1);
  }

  if (worldState.data[x]?.[y]?.[z]) {
    delete worldState.data[x][y][z];
    if (Object.keys(worldState.data[x][y]).length === 0) delete worldState.data[x][y];
    if (Object.keys(worldState.data[x]).length === 0) delete worldState.data[x];
  }
}

function placeBlockAt(x, y, z, id) {
  addBlock(x, y, z, id);
  worldState.update(x, y, z, id);
}

function trace(offset = 0) {
  camera.getWorldDirection(dirV);
  const origin = controls.getObject().position.clone();
  raycaster.set(origin, dirV);
  raycaster.far = RAY_LEN;

  const hit = raycaster.intersectObjects(renderList, false)[0];
  if (!hit) return null;

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

// Make movePlayer globally accessible for gameLoader.js
window.movePlayer = movePlayer;