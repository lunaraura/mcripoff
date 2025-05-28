 const OPCODES = Object.freeze({
  PUSH   : 0x01,
  POP    : 0x02,
  PLACE  : 0x10,
  REMOVE : 0x11,
  HALT   : 0xFF
});


 function compileScript(opcode, args, playerHash = "") {
  return {
    opcode,
    args,
    playerHash,
    sig:     null,
    source:  null,
    timestamp: Date.now()
  };
}

function buildBlockScript(type, { x, y, z }, id = 1) {
  const opcode = type === "place" ? OPCODES.PLACE : OPCODES.REMOVE;
  const args   = type === "place"
    ? [x, y, z, id]
    : [x, y, z];
  console.log(compileScript(opcode, args, "playerABC"));
  return compileScript(opcode, args, "playerABC");
}


const MAX_CYCLES   = 100;
const ALLOWED_DRIFT = 1_000;   // ms

 function runValidator(script, state) {
  const stack = state.stack;
  const tick  = script.timestamp ?? Date.now();
  if (Math.abs(Date.now() - tick) > ALLOWED_DRIFT)
    throw new Error("Tick drift exceeded");

  for (const v of script.args) stack.push(v);

    switch (script.opcode) {
  case OPCODES.PUSH: {
    for (let i = 0; i < script.args.length; i++) {
      stack.push(script.args[i]);
    }
    break;
  }

  case OPCODES.PLACE: {
    ensureStack(4);
    const id = stack.pop(),
          z  = stack.pop(),
          y  = stack.pop(),
          x  = stack.pop();
    state.world.setBlock(x, y, z, id);
    break;
  }

  case OPCODES.REMOVE: {
    ensureStack(3);
    const z = stack.pop(),
          y = stack.pop(),
          x = stack.pop();
    state.world.setBlock(x, y, z, 0);
    break;
  }

  case OPCODES.HALT:
    break;

  default:
    throw new Error(`Unknown opcode: 0x${script.opcode.toString(16)}`);

  }

  state.outputHash = hashWorldState(state.world);
  return state;

  function ensureStack(n) {
    if (stack.length < n) throw new Error(`Stack underflow (${n} needed)`);
  }
}

 function safeRun(script, globalState, expectedHash, playerId, flagFn) {
  const local = deepCopyState(globalState);
  try {
    runValidator(script, local);
    if (local.outputHash !== expectedHash) {
      flagFn?.(playerId);
      return null;
    }
    return local;
  } catch (err) {
    console.warn("Validator crash:", err.message);
    flagFn?.(playerId);
    return null;
  }
}

 function deepCopyState(src) {
  const dstWorld = JSON.parse(JSON.stringify(src.world.data));
  return {
    stack : [...src.stack],
    world : {
      data: dstWorld,
      setBlock: (x,y,z,id) => {
        if (!dstWorld[x])     dstWorld[x]     = {};
        if (!dstWorld[x][y])  dstWorld[x][y]  = {};
        dstWorld[x][y][z] = id;
      },
      getBlock: (x,y,z) => dstWorld[x]?.[y]?.[z] ?? 0
    },
    ip     : 0,
    halted : false
  };
}

 function hashWorldState(world) {
  let s = "";
  for (const x of Object.keys(world.data).sort())
    for (const y of Object.keys(world.data[x]).sort())
      for (const z of Object.keys(world.data[x][y]).sort()) {
        const id = world.data[x][y][z];
        if (id) s += `${x},${y},${z}:${id}|`;
      }
  return simpleHash(s);
}

function simpleHash(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++)
    h = (h << 5) - h + str.charCodeAt(i) | 0;
  return h >>> 0;
}

window.Validator = {
  OPCODES,
  compileScript,
  buildBlockScript,
  runValidator,
  safeRun,
  deepCopyState,
  hashWorldState
};
