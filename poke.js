class PseudoWorld {
    constructor() {
        this.creatureEntities = [];
        this.projectiles = [];
        this.areaEffects = [];
        this.time = 0;
    }
    addCreature(c)  {this.creatureEntities.push(c);return c;}
    addProjectile(p){this.projectiles.push(p);return p;}
    addAreaEffect(a){this.areaEffects.push(a);return a;}
    run(dt) {
        this.time += dt;
        for (const c of this.creatureEntities) {
            if (!c.alive) continue;
            if (c.brain) {
                const intent = c.brain.think(this, dt);
                c.setIntent(intent);
            }
        }
        for (const c of this.creatureEntities) {
            if (c.alive) c.tick(this, dt);
        }
        for (const p of this.projectiles) {
            if (p.alive) p.tick(this, dt);
        }
        for (const a of this.areaEffects) {
            if (a.alive) a.tick(this, dt);
        }
        this.creatureEntities = this.creatureEntities.filter(c => c.alive);
        this.projectiles = this.projectiles.filter(p => p.alive);
        this.areaEffects = this.areaEffects.filter(a => a.alive);
    }
}

class Creature {
    constructor() {
        this.pos = { x: 0, y: 0 };
        this.vel = { x: 0, y: 0 };
        this.speed = 4;

        this.alive = true;

        this.brain = null;
        this.intent = { move: { x: 0, y: 0 }, ability: null };

        this.cooldowns = {};
        this.winding = false;
        this.castState = {active:false,timer:0,ability:null}

        this.can = { move: true, ability: true };
    }

    setIntent(intent) {
        this.intent = intent ?? { move: { x: 0, y: 0 }, ability: null };
    }
    applyMovement(dt) {
        const mv = this.intent.move;
        const mag = Math.hypot(mv.x, mv.y);

        if (mag > 0) {
            this.vel.x = (mv.x / mag) * this.speed;
            this.vel.y = (mv.y / mag) * this.speed;
        } else {
            this.vel.x = 0;
            this.vel.y = 0;
        }
        this.pos.x += this.vel.x * dt;
        this.pos.y += this.vel.y * dt;
    }
    tryAbility(world) {
        const ability = this.intent.ability;
        if (!ability || !this.can.ability) return;

        if (this.cooldowns[ability.name] > 0) return;

        // Start winding
        this.winding = true;
        setTimeout(() => {
            ability.execute(world, this);
            this.cooldowns[ability.name] = ability.cooldown;
            this.winding = false;
        }, ability.windup * 1000);
    }
    cooldownTick(dt) {
        for (const key in this.cooldowns) {
            this.cooldowns[key] = Math.max(0, this.cooldowns[key] - dt);
        }
    }

    tick(world, dt) {
        if (!this.alive) return;

        this.cooldownTick(dt);

        if (!this.winding) {
            if (this.can.move) this.applyMovement(dt);
            if (this.can.ability) this.tryAbility(world);
        }
    }
}
function emptyIntent(){
    return { move: { x: 0, y: 0 }, ability: null };
}
class Brain {
    constructor() {
        this.host = null;
        this.AIType = "generic";
    }
    think(world, dt) {
        return { move: { x: 0, y: 0 }, ability: null };
    }
}
class Projectile {
    constructor() {
        this.pos = { x: 0, y: 0 };
        this.vel = { x: 0, y: 0 };
        this.alive = true;
        this.caster = null;
        this.lifetime = 1.5;
        this.radius = 4;
    }
    tick(world, dt) {
        this.pos.x += this.vel.x * dt;
        this.pos.y += this.vel.y * dt;
        this.lifetime -= dt;
        if (this.lifetime <= 0) this.alive = false;
    }
}
