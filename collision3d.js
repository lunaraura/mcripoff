// Use Three.js for rendering

let scene = new THREE.Scene();
let camera = new THREE.PerspectiveCamera(75, window.innerWidth/window.innerHeight, 0.1, 2000);
let renderer = new THREE.WebGLRenderer();
renderer.setSize(600, 600);
document.body.appendChild(renderer.domElement);

let blockSize = 50;
let playerSize = 25;
let worldSize = 10; // number of blocks in each direction
let worldSizeY = 2;
let player = {x: 0, y: 1, z: 0};
let vel = {x: 0, y: 0, z: 0};
let blocks = [];
let blockMeshes = [];
let playerMesh;
let cameraOffset = {x: 0, y: 0, z: 0};
let grounded = false;
// const color = 0xFFFFFF;
// const intensity = 50;
// const light = new THREE.DirectionalLight(color, intensity);
// light.position.set(0, 200, -200);
// light.target.position.set(0, 0, 0);
// scene.add(light);
// scene.add(light.target);
// Listen for wasd
document.addEventListener('keydown', (event) => {
    if(event.key === 'w'){
        vel.z -= 1;
    }
    if(event.key === 's'){
        vel.z += 1;
    }
    if(event.key === 'a'){
        vel.x -= 1;
    }
    if(event.key === 'd'){
        vel.x += 1;
    }
    if(event.key === 'e'){
        vel.y += 10;
    }    
    if(event.key === 'q'){
        vel.y -= 1;
    }
    if(event.key === 'i'){
        cameraOffset.z -= 20;
    }
    if(event.key === 'k'){
        cameraOffset.z += 20;
    }
    if(event.key === 'j'){
        cameraOffset.x -= 20;
    }
    if(event.key === 'l'){
        cameraOffset.x += 20;
    }
    if(event.key === 'o'){
        cameraOffset.y += 20;
    }    
    if(event.key === 'u'){
        cameraOffset.y -= 20;
    }
});

function init(){
    // Player mesh
    let geometry = new THREE.BoxGeometry(playerSize, playerSize, playerSize);
    let material = new THREE.MeshBasicMaterial({color: 0xff0000});
    playerMesh = new THREE.Mesh(geometry, material);
    scene.add(playerMesh);

    // Blocks
    let blockGeo = new THREE.BoxGeometry(blockSize, blockSize, blockSize);
    for(let i = -worldSize; i <= worldSize; i++){
        for(let j = -worldSize; j <= worldSize; j++){
                const randomColor = new THREE.Color();
                randomColor.setHSL(Math.random(), Math.random(), Math.random());
            for(let k = 0; k <= worldSizeY; k++){
                let random = Math.random();
                if(random < 0.3){ 
                    let block = {
                        x: i * blockSize,
                        y: k * blockSize,
                        z: j * blockSize,
                        key: `${i},${k},${j}`
                    };
                    blocks.push(block);
                    let blockMat = new THREE.MeshBasicMaterial({color: randomColor});
                    let mesh = new THREE.Mesh(blockGeo, blockMat);
                    mesh.material.color.set(randomColor);
                    mesh.position.set(block.x, block.y, block.z);
                    scene.add(mesh);
                    blockMeshes.push(mesh);
                }
            }
        }
    }
    camera.position.set(0, 200, 400);
    camera.lookAt(0, 0, 0);
}

function move() {
    let resistance = {x:0.99, y:0.99, z:0.99};
    player.x += vel.x;
    player.y += vel.y;
    player.z += vel.z;
    if (player.y > 0 || !grounded){
        vel.y -= 0.5; // Gravity
    }
    console.log(vel.y)
    if (Math.abs(vel.x) < 0.01) { vel.x = 0; }
    if (Math.abs(vel.y) < 0.01) { vel.y = 0; }
    if (Math.abs(vel.z) < 0.01) { vel.z = 0; }

    // Reference player position with block key
    let px = Math.floor(player.x / blockSize);
    let py = Math.floor(player.y / blockSize);
    let pz = Math.floor(player.z / blockSize);
    grounded = false;
    // 27 possible blocks to check for collision (3x3x3 cube around the player)
    let blocksToCheck = [];
    for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
            for (let dz = -1; dz <= 1; dz++) {
                blocksToCheck.push(`${px + dx},${py + dy},${pz + dz}`);
            }
        }
    }

    for (let i = 0; i < blocksToCheck.length; i++) {
        let blockKey = blocksToCheck[i];
        let block = blocks.find(b => b.key === blockKey);
        if (block) {
            let distX = player.x - block.x;
            let distY = player.y - block.y;
            let distZ = player.z - block.z;
            let absDistX = Math.abs(distX);
            let absDistY = Math.abs(distY);
            let absDistZ = Math.abs(distZ);

            if (absDistX < blockSize / 2 + playerSize / 2 && absDistY < blockSize / 2 + playerSize / 2 && absDistZ < blockSize / 2 + playerSize / 2) {
                // Collision detected, resolve it
                if (absDistX > absDistY && absDistX > absDistZ) {
                    if (distX > 0) {
                        player.x = block.x + blockSize / 2 + playerSize / 2;
                        resistance.y -= 0.4; resistance.z -= 0.4;
                        vel.x *= -0.1;
                    } else {
                        player.x = block.x - blockSize / 2 - playerSize / 2;
                        resistance.y -= 0.4; resistance.z -= 0.4;
                        vel.x *= -0.1;
                    }
                } else if (absDistY > absDistX && absDistY > absDistZ) {
                    if (distY > 0) {
                        player.y = block.y + blockSize / 2 + playerSize / 2;
                        resistance.x -= 0.4; resistance.z -= 0.4;
                        vel.y *= -0.1;
                        grounded = true;
                    } else {
                        player.y = block.y - blockSize / 2 - playerSize / 2;
                        resistance.x -= 0.4; resistance.z -= 0.4;
                        vel.y *= -0.1;
                    }
                } else {
                    if (distZ > 0) {
                        player.z = block.z + blockSize / 2 + playerSize / 2;
                        resistance.x -= 0.4; resistance.y -= 0.4;
                        vel.z *= -0.1;
                    } else {
                        player.z = block.z - blockSize / 2 - playerSize / 2;
                        resistance.x -= 0.4; resistance.y -= 0.4;
                        vel.z *= -0.1;
                    }
                }
            }
        }
    }
    vel.x *= resistance.x
    vel.y *= resistance.y
    vel.z *= resistance.z
    camera.position.set(player.x+cameraOffset.x, player.y+cameraOffset.y, player.z+cameraOffset.z);
    camera.lookAt(player.x, player.y, player.z);
}

function animate(){
    requestAnimationFrame(animate);
    move();
    playerMesh.position.set(player.x, player.y, player.z);
    renderer.render(scene, camera);
}

init();
animate();
