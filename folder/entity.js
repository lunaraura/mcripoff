//definitions
const entEnum = {
    1: "wildCreature",
    2: "tameCreature",
    3: "bossCreature",
    4: "projectile",
    5: "aoe",
}
const creatureFamilies = {
    canine: {speed: 10, health: 50, attack: 15, baseSize: 1.0},
    feline: {speed: 12, health: 40, attack: 20, baseSize: 0.8},
    avian: {speed: 15, health: 30, attack: 10, baseSize: 0.6},
    reptile: {speed: 8, health: 60, attack: 25, baseSize: 1.2},
    ungulate: {speed: 9, health: 45, attack: 8, baseSize: 1.1},
    rodent: {speed: 14, health: 20, attack: 4, baseSize: 0.4},
    ursine: {speed: 7, health: 120, attack: 30, baseSize: 1.8}
}
const tameableCreatures = ["canine", "feline", "avian"]
const projectileMoves = {
    arrow: {speed: 25, damage: 10, range: 50},
    fireball: {speed: 15, damage: 20, range: 30},
    iceShard: {speed: 20, damage: 15, range: 40},
}
const aoeEffects = {
    explosion: {radius: 5, damage: 30, duration: 0},
    poisonCloud: {radius: 4, damage: 5, duration: 10},
    healingAura: {radius: 6, heal: 10, duration: 15},
}

//helpers
function getCreatureStats(family) {
    return creatureFamilies[family] || null;
}

// map species names (used by world generator) to creature families
const speciesToFamily = {
    goat: 'ungulate',
    eagle: 'avian',
    deer: 'ungulate',
    rabbit: 'rodent',
    scorpion: 'reptile',
    lizard: 'reptile',
    bear: 'ursine',
    wolf: 'canine'
};
function isTameable(family) {
    return tameableCreatures.includes(family);
}
function getProjectileMove(type) {
    return projectileMoves[type] || null;
}
function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
}
function collides(pos1, radius1, pos2, radius2) {
    const dx = pos1.x - pos2.x;
    const dy = pos1.y - pos2.y;
    const distanceSq = dx * dx + dy * dy;
    const radiusSum = radius1 + radius2;
    return distanceSq <= radiusSum * radiusSum;
}

// Entity class
class Entity {
    constructor(type, subtype, position) {
        this.type = entEnum[type] || "unknown";
        this.subtype = subtype;
        this.position = position;
        this.stats = this.initializeStats();
    }
}
class Creature extends Entity {
    constructor(family, position, isTamed = false) {
        super(isTamed ? 2 : 1, family, position);
        this.isTamed = isTamed;
    }
    initializeStats() {
        // subtype may be a species (e.g., 'goat') — map to family if necessary
        const family = speciesToFamily[this.subtype] || this.subtype;
        const base = getCreatureStats(family) || {speed: 8, health: 30, attack: 5, baseSize: 1};
        return {
            family,
            maxHealth: base.health,
            health: base.health,
            speed: base.speed,
            attack: base.attack,
            size: base.baseSize
        };
    }

    // simple update: wander randomly a bit
    update(dt = 1/60) {
        const s = (this.stats && this.stats.speed) ? this.stats.speed : 5;
        // small random walk; scale by dt
        const dx = (Math.random() - 0.5) * s * dt * 0.5;
        const dz = (Math.random() - 0.5) * s * dt * 0.5;
        if (!this.position) this.position = {x:0,y:0,z:0};
        this.position.x += dx;
        this.position.z += dz;
    }
}
class Projectile extends Entity {
    constructor(moveType, position, direction) {
        super(4, moveType, position);
        this.direction = direction;
    }
    initializeStats() {
        return getProjectileMove(this.subtype);
    }
}
class AOE extends Entity {
    constructor(effectType, position) {
        super(5, effectType, position);
    }
    initializeStats() {
        return aoeEffects[this.subtype] || null;
    }
}

//flow api
class EntityFactory {
    static createCreature(family, position, isTamed = false) {
        return new Creature(family, position, isTamed);
    }
    static createProjectile(moveType, position, direction) {
        return new Projectile(moveType, position, direction);
    }
    static createAOE(effectType, position) {
        return new AOE(effectType, position);
    }
}