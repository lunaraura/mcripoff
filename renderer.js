const renderList = [];
const frustum = new THREE.Frustum();
const camMat = new THREE.Matrix4();
const lastCamMatrix = new THREE.Matrix4();
let lastCull = 0;
const CULL_INTERVAL = 100; // ms

function updateVisibility(camera) {
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
