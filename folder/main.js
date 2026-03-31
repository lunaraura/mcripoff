const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

const inputs = {};
document.addEventListener("keydown", (e) => {
    inputs[e.key.toLowerCase()] = true;
});
document.addEventListener("keyup", (e) => {
    inputs[e.key.toLowerCase()] = false;
});


class SceneManager { 
    constructor() {
        this.registry = new Map();
        this.stack = [];
        this.input = {up: false, down: false, left: false, right: false,
            q: false, w: false, e: false, r: false}
    }
    register(name, factory){
        this.registry.set(name, factory);
    }
    push(name, args){
        const s = this.registry.get(name)?.(args);
        if (!s) return;
        this.stack.push(s);
        s.init?.(this);
        s.onPush?.(this)
    }
    pop() {
        const s = this.stack.pop();
        s?.onPop?.(this);
    }
    switchRoot(name, args) {
        while (this.stack.length) this.pop();
        this.push(name, args);
    }
    update(dt) {
        const top = this.stack[this.stack.length - 1];
        top?.update?.(this, dt);
    }
    render(ctx) {
        for (const s of this.stack) {
            s.render?.(this, ctx);
        }
    }
    handleInput(input) {
        const top = this.stack[this.stack.length - 1];
        return top?.handleInput?.(this, input);
    }
}

function makeMenuScene(def) {
    return {
        name: "menu",
        selected: 0,
        cooldown: 0,
        init(sm) { this.cooldown = 0;  },
        update(sm, dt){
            this.cooldown = Math.max(0, this.cooldown - dt);
        },
        handleInput(sm, input) {
            
            if (this.cooldown > 0) return;
            if (input.down) {
                this.selected = (this.selected + 1) % def.items.length;
                this.cooldown = 0.2;
            }
            if (input.up) {
                this.selected = (this.selected - 1 + def.items.length) % def.items.length;
                this.cooldown = 0.2;
            }
            if (input.q) {
                def.items[this.selected].action();
                this.cooldown = 0.2;
            }
        },
        render(sm, ctx) {
            ctx.fillStyle = "black";
            ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
            ctx.fillStyle = "white";
            ctx.font = "20px Arial";
            def.items.forEach((item, index) => {
                if (index === this.selected) {
                    ctx.fillStyle = "yellow";
                } else {
                    ctx.fillStyle = "white";
                }
                ctx.fillText(item.label, 50, 50 + index * 30);
            });
        }
    };
}
//choose between three buttons. After, go to gameScene
function makeChooseScene(def){
    return{
        name: "choose",
        init(sm){},
        update(sm, dt){},
        handleInput(sm, input){
            if(input.q){
                def.options[0].action();
            }
            if(input.w){
                def.options[1].action();
            }
            if(input.e){
                def.options[2].action();
            }
        },
        render(sm, ctx){
            ctx.fillStyle = "blue";
            ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
            ctx.fillStyle = "white";
            ctx.font = "20px Arial";
            ctx.fillText("Choose your option:", 50, 50);
            def.options.forEach((option, index) => {
                ctx.fillText(option.label, 50, 100 + index * 30);
            });
        }
    }
}

function loop(sm, lastTime = 0) {
    const now = performance.now();
    const dt = (now - lastTime) / 1000;

    // map raw key names to the SceneManager input shape
    sm.input.up    = !!(inputs["arrowup"] || inputs["w"]);
    sm.input.down  = !!(inputs["arrowdown"] || inputs["s"]);
    sm.input.left  = !!(inputs["arrowleft"] || inputs["a"]);
    sm.input.right = !!(inputs["arrowright"] || inputs["d"]);
    sm.input.q     = !!inputs["q"];
    sm.input.w     = !!inputs["w"];
    sm.input.e     = !!inputs["e"];
    sm.input.r     = !!inputs["r"];

    // send input to top scene
    sm.handleInput(sm.input);

    sm.update(dt);
    sm.render(ctx);
    requestAnimationFrame((time) => loop(sm, now));
}
const sm = new SceneManager();
sm.register("menu", () => makeMenuScene({
    items: [
        {label: "Start Game", action: () => sm.push("choose", {
            options: [
                {label: "Option 1", action: () => console.log("Option 1 chosen")},
                {label: "Option 2", action: () => console.log("Option 2 chosen")},
                {label: "Option 3", action: () => console.log("Option 3 chosen")},
            ]
        }).switchRoot("choose")},
        {label: "Options", action: () => console.log("Options")},
        {label: "Exit", action: () => console.log("Exit")},
    ]
}));
sm.switchRoot("menu");
loop(sm);