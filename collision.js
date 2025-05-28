let camera = {x: 0, z: 0}; // top-down camera
let player = {x: 0, z: 0}; // player position
let blocks = []; // array of blocks
let blockSize = 5;
let vel = {x: 0, z: 0};
let worldSize = 50; // size of world
let playerSize = 5; // size of player (half the block size)

const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');

// listen for wasd
document.addEventListener('keydown', (event) => {
    if(event.key === 'w'){
        vel.z -= 0.1;
    }
    if(event.key === 's'){
        vel.z += 0.1;
    }
    if(event.key === 'a'){
        vel.x -= 0.1;
    }
    if(event.key === 'd'){
        vel.x += 0.1;
    }
});

function init(){
    // Initialize blocks
    for(let i = -worldSize; i <= worldSize; i++){
        for(let j = -worldSize; j <= worldSize; j++){
            let random = Math.random();
            if(random < 0.6){ // 10% chance to create a block
                blocks.push({x: i * blockSize, z: j * blockSize, key: `${i},${j}`,
                edges: [
                    {x: i * blockSize - blockSize / 2, z: j * blockSize - blockSize / 2},
                    {x: i * blockSize + blockSize / 2, z: j * blockSize - blockSize / 2},
                    {x: i * blockSize + blockSize / 2, z: j * blockSize + blockSize / 2},
                    {x: i * blockSize - blockSize / 2, z: j * blockSize + blockSize / 2}
                ]});
            }
        }
    }
}

function move(){
    // Move player based on velocity
    player.x += vel.x;
    player.z += vel.z + 0.05;
    vel.x *= 0.8;
    vel.z *= 0.8;
    camera.x = player.x;
    camera.z = player.z;

    if (Math.abs(vel.x) < 0.01){ vel.x = 0; }
    if (Math.abs(vel.z) < 0.01){ vel.z = 0; }

    // Check for collisions with blocks
    for(let i = 0; i < blocks.length; i++){
        let block = blocks[i];
        let distX = player.x - block.x;
        let distZ = player.z - block.z;
        let absDistX = Math.abs(distX);
        let absDistZ = Math.abs(distZ);

        if(absDistX < blockSize / 2 + playerSize / 2 && absDistZ < blockSize / 2 + playerSize / 2){
            // Collision detected, resolve it
            if(absDistX > absDistZ){
                if(distX > 0){
                    player.x = block.x + blockSize / 2 + playerSize / 2;
                } else {
                    player.x = block.x - blockSize / 2 - playerSize / 2;
                }
            } else {
                if(distZ > 0){
                    player.z = block.z + blockSize / 2 + playerSize / 2;
                } else {
                    player.z = block.z - blockSize / 2 - playerSize / 2;
                }
            }
        }
    }
}

function draw(){
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = 'black';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    move();

    // Draw blocks
    for(let i = 0; i < blocks.length; i++){
        let block = blocks[i];
        ctx.fillStyle = 'white';
        ctx.fillRect((block.x - camera.x) * blockSize + canvas.width / 2 - blockSize,
        (block.z - camera.z) * blockSize + canvas.height / 2 - blockSize, blockSize, blockSize);
    }

    // Draw player
    ctx.fillStyle = 'red';
    ctx.fillRect((player.x - camera.x) * blockSize + canvas.width / 2 - playerSize / 2, (player.z - camera.z) * blockSize + canvas.height / 2 - playerSize / 2, playerSize, playerSize);
}

function animate(){
    draw();
    requestAnimationFrame(animate);
}

init();
animate();
