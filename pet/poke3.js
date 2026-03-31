const canvas = document.getElementById("canvas");
const ctx    = canvas.getContext("2d");const SIZE  = 8;
const HSIZE = SIZE / 2;
let commands = {
    player: { x: 0, y: 0 }, 
    entity: { x: 0, y: 0 }, 
    ab1:    false, 
    bringSlot: null,  
};
function resetCommands() {
    commands = {
        player: { x: 0, y: 0 },
        entity: { x: 0, y: 0 },
        ab1:    false,
        bringSlot: null,
    };
}
let world = null;// Simple key → command mapping
document.addEventListener("keydown", (event) => {
    switch (event.key) {
        case "ArrowUp":
            commands.player.y = -5;
            break;
        case "ArrowDown":
            commands.player.y = 5;
            break;
        case "ArrowLeft":
            commands.player.x = -5;
            break;
        case "ArrowRight":
            commands.player.x = 5;
            break;        case "w":
        case "W":
            commands.entity.y = -1;
            break;
        case "s":
        case "S":
            commands.entity.y = 1;
            break;
        case "a":
        case "A":
            commands.entity.x = -1;
            break;
        case "d":
        case "D":
            commands.entity.x = 1;
            break;
        case "q":
        case "Q":
            commands.ab1 = true;
            break;
        case "1":
            commands.bringSlot = 0;
            break;
        case "2":
            commands.bringSlot = 1;
            break;
        case "3":
            commands.bringSlot = 2;
            break;
    }
});
const abilities = {
    example: { cd: 1, atk: 1, type: "meleeAutoTarget" },
};

class Entity {
    constructor(x, y) {
        this.pos   = { x, y };
        this.team  = 0;   // 0 = neutral / wild, 1 = player, others = future teams
        this.intents = { vel: { x: 0, y: 0 }, ab1: null };
        this.target  = null;
        this.alive   = true;
        this.inWorld = true;
        this.range  = 50;
        this.maxHP  = 10;
        this.hp     = 10;
        this.atk    = 1;
        this.inWorld = true;
    }
    applyIntent(world) {
        this.pos.x += this.intents.vel.x;
        this.pos.y += this.intents.vel.y;
        if (this.intents.ab1 && this.target) {
            const dx   = this.target.pos.x - this.pos.x;
            const dy   = this.target.pos.y - this.pos.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            if (dist <= this.range) {
                this.processAbility(this.intents.ab1, this.target);
            } else {
                console.log("Target out of range!");
            }
            this.intents.ab1 = null;
        }
    }
    processAbility(abilityName, target) {
        if (!target) return;
        const def = abilities[abilityName];
        if (!def) return;
        target.hp -= def.atk;
        console.log(
            `Entity at (${this.pos.x.toFixed(1)}, ${this.pos.y.toFixed(1)}) ` +
            `used ${abilityName} on target at (${target.pos.x.toFixed(1)}, ${target.pos.y.toFixed(1)}). ` +
            `Target HP: ${target.hp}`
        );
    }
    checkAlive() {
        if (this.hp <= 0) {
            this.alive = false;
        }
        return this.alive;
    }
    checkIfInWorld(worldEntityList) {
        return worldEntityList.includes(this);        
    }
    update(world) {
        if (this.alive) {
            this.applyIntent(world);
            this.checkAlive();
        } else {
            captureListen(world, this); 
        }
    }
    draw(ctx) {
        ctx.fillRect(this.pos.x - HSIZE, this.pos.y - HSIZE, SIZE, SIZE);
    }
}
class Bot {
    constructor(entity) {
        this.e = entity;
        this.commandedIntent = { vel: { x: 0, y: 0 }, ab1: null };
        this.outputIntent = { vel: { x: 0, y: 0 }, ab1: null };
        this.bestTarget = null;
        console.log(entity)
    }
    tick(world) {
        if (this.commandedIntent.vel.x === 0 && this.commandedIntent.vel.y === 0) {
            this.e.intents.vel.x = Math.random() - 0.5;
            this.e.intents.vel.y = Math.random() - 0.5;
        } else {
            this.e.intents.vel.x = this.commandedIntent.vel.x;
            this.e.intents.vel.y = this.commandedIntent.vel.y;
        }
        this.findTarget(world);
        this.e.target = this.bestTarget;
        if (this.bestTarget && this.commandedIntent.ab1) {
            const dx   = this.bestTarget.pos.x - this.e.pos.x;
            const dy   = this.bestTarget.pos.y - this.e.pos.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            console.log("beat")
            if (dist <= this.e.range) {
                this.e.intents.ab1 = "example";
            }
        }
        this.commandedIntent = { vel: { x: 0, y: 0 }, ab1: null };
        this.outputIntent = { vel: { x: 0, y: 0 }, ab1: null };
    }
    findTarget(world) {
        let closestDist = Infinity;
        this.bestTarget = null;
        for (let i = 0; i < world.entities.length; i++) {
            const potentialTarget = world.entities[i];
            if (potentialTarget === this.e) continue;
            if (potentialTarget.team === this.e.team) continue;
            const dx   = potentialTarget.pos.x - this.e.pos.x;
            const dy   = potentialTarget.pos.y - this.e.pos.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            if (dist < closestDist) {
                closestDist   = dist;
                this.bestTarget = potentialTarget;
            }
        }
    }
}
class RosterSystem {
    constructor() {
        this.maxSlots = 3;
        this.members  = [];
    }
    canAdd() {
        return this.members.length < this.maxSlots;
    }
    addFromEntity(entity) {
        if (!this.canAdd()) return false;
        this.members.push(entity);
        return true;
    }
}
class StorageSystem {
    constructor() {
        this.maxSlots = 50;
        this.members  = [];
    }
    canAdd() {
        return this.members.length < this.maxSlots;
    }
    addFromEntity(entity) {
        if (!this.canAdd()) return false;
        this.members.push(entity);
        return true;
    }
}
class Player {
    constructor(x, y) {
        this.pos = { x, y };
        this.inventory = [];
        this.roster = new RosterSystem();
        this.storage   = new StorageSystem();
        this.commands = {
            player: { x: 0, y: 0 },
            entity: { x: 0, y: 0 },
            ab1: null,
        };
        this.activeEntity   = null;
        this.activeEntityInWorld = false;
        this.activeEntityBot = null;
    }
    update(commands, world) {
        this.commands.player.x = commands.player.x;
        this.commands.player.y = commands.player.y;
        this.commands.entity.x = commands.entity.x;
        this.commands.entity.y = commands.entity.y;
        this.activeEntity   = this.roster.members[0] || null;

        if (this.activeEntity) {
            this.activeEntityInWorld = this.activeEntity.checkIfInWorld(world.entities);
        } else {
            this.activeEntityInWorld = false;
        }

        this.commands.ab1 = commands.ab1;
        this.sendCommandToPet();
        this.moveSelf();
    }
    sendCommandToPet() {
        if (!this.activeEntityBot) return;
        this.activeEntityBot.commandedIntent.vel.x = this.commands.entity.x;
        this.activeEntityBot.commandedIntent.vel.y = this.commands.entity.y;
        this.activeEntityBot.commandedIntent.ab1   = this.commands.ab1 ? "example" : null;
    }
    moveSelf() {
        //player doesn't really do much, roblox auto caps speed
        this.pos.x += this.commands.player.x;
        this.pos.y += this.commands.player.y;
    }
    draw(ctx) {
        ctx.fillRect(this.pos.x - HSIZE, this.pos.y - HSIZE, SIZE, SIZE);
    }
}
class World {
    constructor() {
        this.player = null;
        this.entities = [];
        this.bots = [];
        this.renderList = [];
        this.debugRenderList = [];
    }
    setPlayer(player) {
        this.player = player;
    }
    addEntity(entity, withBot = false, team = 0) {
        entity.team = team;
        entity.inWorld = true;
        this.entities.push(entity);
        if (withBot) {
            const bot = new Bot(entity);
            this.bots.push(bot);
            return bot;
        }
        return null;
    }
    toggleRosterEntity(slotIndex) {
        if (!this.player) return;
        const roster = this.player.roster;
        const member = roster.members[slotIndex];
        if (!member) return;
        if (!member.inWorld) {
            member.inWorld = true;
            member.team    = 1;
            member.pos.x = this.player.pos.x + 16 * (slotIndex + 1);
            member.pos.y = this.player.pos.y;
            this.entities.push(member);
            const bot = new Bot(member);
            this.bots.push(bot);
            if (!this.player.activeEntity) {
                this.player.activeEntity    = member;
                this.player.activeEntityBot = bot;
            }
        } else {
            member.inWorld = false;
            this.entities = this.entities.filter(e => e !== member);
            for (let i = 0; i < this.bots.length; i++) {
                if (this.bots[i].e === member) {
                    if (this.player.activeEntityBot === this.bots[i]) {
                        this.player.activeEntity    = null;
                        this.player.activeEntityBot = null;
                    }
                    this.bots.splice(i, 1);
                    break;
                }
            }
        }
    }
    update(commands) {
        if (!this.player) return;
        this.player.update(commands, this);
        if (commands.bringSlot !== null) {
            this.toggleRosterEntity(commands.bringSlot);
        }
        for (let i = 0; i < this.bots.length; i++) {
            this.bots[i].tick(this);
        }
        for (let i = 0; i < this.entities.length; i++) {
            this.entities[i].update(this);
        }
        this.entities = this.entities.filter(e => e.alive || e.team === 0);
        this.bots = this.bots.filter(b => b.e.alive);
    }
    render(ctx) {
        if (this.player) {
            this.player.draw(ctx);
        }
        this.renderList = this.entities;
        for (let i = 0; i < this.renderList.length; i++) {
            this.renderList[i].draw(ctx);
        }
    }
    debugUI(ctx) {
        for (let i = 0; i < this.debugRenderList.length; i++) {
            ctx.fillText(this.debugRenderList[i].info, 30, 30 + i * 20);
        }
    }
}
function captureListen(world, entity) {
    if (entity.team !== 0) return;
    const playerPos = world.player.pos;
    const dx   = playerPos.x - entity.pos.x;
    const dy   = playerPos.y - entity.pos.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist >= 20) return;
    const roster = world.player.roster;
    const storage = world.player.storage;
    const canAddR = roster.canAdd();
    const canAddS = storage.canAdd();
    if (!canAddR && !canAddS) {
        console.log("No space in roster or storage.");
        return;
    }
    if (canAddR) {
        roster.addFromEntity(entity);
        console.log("Captured entity -> roster slot", roster.members.length - 1);
    } else {
        storage.addFromEntity(entity);
        console.log("Captured entity -> storage");
    }
    entity.inWorld = false;
    const idx = world.entities.indexOf(entity);
    if (idx > -1) {
        world.entities.splice(idx, 1);
    }
    for (let i = 0; i < world.bots.length; i++) {
        if (world.bots[i].e === entity) {
            world.bots.splice(i, 1);
            break;
        }
    }
}
function spawnCircle(world, x, y, radius, numEntities) {
    const angleIncrement = (2 * Math.PI) / numEntities;
    for (let i = 0; i < numEntities; i++) {
        const angle   = i * angleIncrement;
        const ex      = x + radius * Math.cos(angle);
        const ey      = y + radius * Math.sin(angle);
        const entity  = new Entity(ex, ey);
        world.addEntity(entity, true, 0); 
    }
}
function RosterDebug(){
    console.log("Roster Debug Info:");
    for (let i = 0; i < world.player.roster.members.length; i++){
        const member = world.player.roster.members[i];
        world.debugRenderList.push({ info: `Roster Slot ${i}: HP=${member.hp}/${member.maxHP} Atk=${member.atk}` })
    }
}



class Scene {
    constructor() {
        this.world = null;
        this.scenes = []; 
        this.currentSceneLoop = () => {};
        this.currentIndex = -1;
        this.switchScene = this.switchScene.bind(this);
    }

    addScene(name, { init = null, loop = null } = {}) {
        this.scenes.push({ name, init, loop });
        return this.scenes.length - 1;
    }
    switchScene(indexOrName) {
        let idx = (typeof indexOrName === "number")
            ? indexOrName
            : this.scenes.findIndex(s => s.name === indexOrName);
        if (idx < 0 || idx >= this.scenes.length) return;
        this.currentIndex = idx;
        const scene = this.scenes[idx];
        this.currentSceneLoop = typeof scene.loop === "function" ? scene.loop : (() => {});
        if (typeof scene.init === "function") scene.init(this); 
    }
    start(){
        this.switchScene(0);
    }
    tick() {
        const scene = this.scenes[this.currentIndex];
        if (scene && typeof scene.loop === "function") {
            scene.loop(this);
        }
    }
}
const Scenes = {
    init: {
        started: false,
        init(sm){
            if (!Scenes.init.started) {
                Scenes.init.started = true;
                world = new World();
                const player = new Player(300, 300);
                world.setPlayer(player)
                sm.world = world
                sm.switchScene("choose")
            }
        }
    },
    choose: {
        init(sm){
            world.entities = [];
            world.bots = []
            world.debugRenderList = []
            const starterX = 200;
            const spacing = 80;
            for(let i = 0; i < 3; i++){
                const e = new Entity(starterX + i * spacing, 400)
                world.addEntity(e, false, 0)
            }
            RosterDebug();
        },
        loop(sm){
            world.update(commands);
            world.render(ctx);
            world.debugUI(ctx)
            for (const e of world.entities){
                captureListen(world, e)
            }
            if (world.player.roster.members.length > 0){
                sm.switchScene("normal")
            }
            resetCommands()
        }
    },
    normal:{
        init(sm){
            world.entities = [];
            world.bots = []
            world.debugRenderList = []
            RosterDebug();
            console.log(world.player)
            spawnCircle(world, 400, 400, 100, 10)
        },
        loop(sm){
            world.update(commands);
            world.render(ctx)
            resetCommands();
        }
    }
}
const sceneManager = new Scene()
sceneManager.addScene("init", Scenes.init)
sceneManager.addScene("choose", Scenes.choose)
sceneManager.addScene("normal", Scenes.normal)
sceneManager.start();

function gameLoop() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    sceneManager.tick();
    // requestAnimationFrame(gameLoop);
}

setInterval(() =>gameLoop(), 50)
