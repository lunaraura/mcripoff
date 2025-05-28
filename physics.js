// A common 3D physics updater using worldState.data for collisions.
window.updatePhysics3D = function(player, vel, dt, worldState, options) {
  // options: { gravity, blockSize, playerSize }
  // Apply gravity (simple Euler integration)
  vel.y += options.gravity * dt;
  // Update position (scale velocity by dt)
  player.x += vel.x * dt;
  player.y += vel.y * dt;
  player.z += vel.z * dt;

  // Collision resolution: check nearby cells (assuming blocks are axis‐aligned cubes)
  const bx = Math.floor(player.x);
  const by = Math.floor(player.y);
  const bz = Math.floor(player.z);
  for (let dx = -1; dx <= 1; dx++) {
    for (let dy = -1; dy <= 1; dy++) {
      for (let dz = -1; dz <= 1; dz++) {
        const cx = bx + dx;
        const cy = by + dy;
        const cz = bz + dz;
        if (!worldState.data[cx]?.[cy]?.[cz]) continue;
        // assume block center at (cell+0.5, …)
        const blockCenter = { x: cx + 0.5, y: cy + 0.5, z: cz + 0.5 };
        const diff = {
          x: player.x - blockCenter.x,
          y: player.y - blockCenter.y,
          z: player.z - blockCenter.z,
        };
        // Compute penetration depth (assuming cubes)
        const overlapX = options.playerSize/2 + options.blockSize/2 - Math.abs(diff.x);
        const overlapY = options.playerSize/2 + options.blockSize/2 - Math.abs(diff.y);
        const overlapZ = options.playerSize/2 + options.blockSize/2 - Math.abs(diff.z);
        if (overlapX > 0 && overlapY > 0 && overlapZ > 0) {
          // Resolve along the smallest penetration axis
          if (overlapX < overlapY && overlapX < overlapZ) {
            player.x += diff.x > 0 ? overlapX : -overlapX;
            vel.x *= -0.1;
          } else if (overlapY < overlapX && overlapY < overlapZ) {
            player.y += diff.y > 0 ? overlapY : -overlapY;
            vel.y *= -0.1;
          } else {
            player.z += diff.z > 0 ? overlapZ : -overlapZ;
            vel.z *= -0.1;
          }
        }
      }
    }
  }
}
