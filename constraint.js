const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

let playerPos = {x:canvas.width, y:0, z:canvas.height};
let playerVelocity = {x:0, y:0, z:0};
const playerBoundary = {horizontal: 2, vertical: 4};
const gravity = -1;
const jumpForce = 5;
const speed = 1;
let grounded = false;
let canJump = true;
const blockSize = 10
const numberOfBlocks = canvas.width / blockSize;
let blocks = [];

document.addEventListener('keydown', (event) => {
    switch(event.key) {
        case 'w':
            playerVelocity.z += speed;
            break;
        case 's':
            playerVelocity.z -= speed;
            break;
        case 'a':
            playerVelocity.x -= speed;
            break;
        case 'd':
            playerVelocity.x += speed;
            break;
        case ' ':
            if (canJump) {
                playerVelocity.y = jumpForce;
                canJump = false;
            }
            break;
    }
});

function init() {
    let y = 0;
    for (let i = 0; i < numberOfBlocks; i++) {
        for (let j = 0; j < numberOfBlocks; j++) {
            let random = Math.random();
            if (random < 0.3) {
                const block = {
                    x: i * blockSize,
                    y: 0,
                    z: j * blockSize,
                    key: `${i},${y},${j}`,
                };
                blocks.push(block);
            }
        }
    }
}

function move(){
    playerPos.x += playerVelocity.x;
    playerPos.y += playerVelocity.y;
    playerPos.z += playerVelocity.z;

    if (playerPos.y <= 0) {
        playerPos.y = 0;
        canJump = true;
        playerVelocity.y = 0;
    } else {
        playerVelocity.y += gravity;
    }

    for (let block of blocks) {
        if (Math.abs(playerPos.x - block.x) < playerBoundary.horizontal && Math.abs(playerPos.z - block.z) < playerBoundary.horizontal) {
            grounded = true;
            break;
        }
    }
    if (!grounded) {
        canJump = false;
    }
    playerVelocity.x *= 0.9;
    playerVelocity.z *= 0.9;
}

function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (let block of blocks) {
        ctx.fillStyle = 'green';
        ctx.fillRect(block.x, block.z, blockSize, blockSize);
    }
    ctx.fillStyle = 'red';
    ctx.fillRect(playerPos.x, playerPos.z, playerBoundary.horizontal*20,playerBoundary.vertical*20);
    ctx.fillText('Player', playerPos.x, playerPos.z);
    ctx.stroke();
}
function animate() {
    move();
    draw();
    requestAnimationFrame(animate);
}
init();
animate();