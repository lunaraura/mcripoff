const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
let camera = {x: 0, z: 0}; // top-down camera
let player = {x: canvas.width/2, z: canvas.height/2}; // player position
let blocks = []; // array of blocks
let blockSize = 20;
let vel = {x: 0, z: 0};
let worldSize = canvas.width/blockSize; // size of world
let playerSize = 5; // size of player (half the block size)



// listen for wasd
document.addEventListener('keydown', (event) => {
    if(event.key === 'w'){
        vel.z -= 2;
    }
    if(event.key === 's'){
        vel.z += 2;
    }
    if(event.key === 'a'){
        vel.x -= 2;
    }
    if(event.key === 'd'){
        vel.x += 2;
    }
});

function init(){
    // Initialize blocks
    for(let i = -worldSize; i <= worldSize; i++){
        for(let j = -worldSize; j <= worldSize; j++){
            let random = Math.random();
            if(random < 0.3){ 
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
    //vel.z += 0.1; // gravity
    player.x += vel.x;
    player.z += vel.z;
    vel.x *= 0.99;
    vel.z *= 0.99;

    if (Math.abs(vel.x) < 0.01){ vel.x = 0; }
    if (Math.abs(vel.z) < 0.01){ vel.z = 0; }
    // reference player position with block key
    let playerKey = `${Math.floor(player.x / blockSize)},${Math.floor(player.z / blockSize)}`;
    // 9 possible blocks to check for collision
    let blocksToCheck = [
        playerKey,
        `${Math.floor(player.x / blockSize) + 1},${Math.floor(player.z / blockSize)}`,
        `${Math.floor(player.x / blockSize) - 1},${Math.floor(player.z / blockSize)}`,
        `${Math.floor(player.x / blockSize)},${Math.floor(player.z / blockSize) + 1}`,
        `${Math.floor(player.x / blockSize)},${Math.floor(player.z / blockSize) - 1}`,
        `${Math.floor(player.x / blockSize) + 1},${Math.floor(player.z / blockSize) + 1}`,
        `${Math.floor(player.x / blockSize) - 1},${Math.floor(player.z / blockSize) - 1}`,
        `${Math.floor(player.x / blockSize) + 1},${Math.floor(player.z / blockSize) - 1}`,
        `${Math.floor(player.x / blockSize) - 1},${Math.floor(player.z / blockSize) + 1}`
    ];
    //grab distance of blocks
    for(let i = 0; i < blocksToCheck.length; i++){
        let blockKey = blocksToCheck[i];
        let block = blocks.find(b => b.key === blockKey);
        if(block){
            let distX = player.x - block.x;
            let distZ = player.z - block.z;
            let absDistX = Math.abs(distX);
            let absDistZ = Math.abs(distZ);
            if(absDistX < blockSize / 2 + playerSize / 2 && absDistZ < blockSize / 2 + playerSize / 2){
                // Collision detected, resolve it
                //also add friction
                if(absDistX > absDistZ){
                    if(distX > 0){
                        player.x = block.x + blockSize / 2 + playerSize / 2;
                        vel.x *= -0.1;
                    }else{
                        player.x = block.x - blockSize / 2 - playerSize / 2;
                        vel.x *= -0.1;
                    }
                }else{
                    if(distZ > 0){
                        player.z = block.z + blockSize / 2 + playerSize / 2;
                        vel.z *= -0.1;
                    }else{
                        player.z = block.z - blockSize / 2 - playerSize / 2;
                        vel.z *= -0.1;
                    }
                }
            }
        }
    }

}
function draw(){
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = 'red';
    ctx.fillRect(player.x - playerSize / 2, player.z - playerSize / 2, playerSize, playerSize);
    for(let i = 0; i < blocks.length; i++){
        let block = blocks[i];
        ctx.fillStyle = 'black';
        ctx.beginPath();
        ctx.moveTo(block.edges[0].x, block.edges[0].z);
        for(let j = 1; j < block.edges.length; j++){
            ctx.lineTo(block.edges[j].x, block.edges[j].z);
        }
        ctx.lineTo(block.edges[0].x, block.edges[0].z);
        ctx.fill();
    }
}
function animate(){
    requestAnimationFrame(animate);
    move();
    draw();
}
init();
animate();
