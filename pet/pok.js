//pok simulator
const types = { //immuneAgainst/cantdamage
    normal:  {name: "normal",  immune: ['ghost'], weak: ['rock','steel'], strong: []},
    fire:    {name: "fire",    immune: [], weak: ['fire','water','rock','dragon'], strong: ['grass','ice','bug','steel']},
    water:   {name: "water",   immune: [], weak: ['water','grass','dragon'], strong: ['fire','ground','rock']},
    electric:{name: "electric",immune: ['ground'], weak: ['electric','grass','dragon'], strong: ['water','flying']},
    grass:   {name: "grass",   immune: [], weak: ['fire','grass','poison','flying','bug','dragon','steel'], strong: ['water','ground','rock']},
    ice:     {name: "ice",     immune: [], weak: ['fire','water','ice','steel'], strong: ['grass','ground','flying','dragon']},
    fighting:{name: "fighting",immune: ['ghost'], weak: ['flying','poison','psychic','bug','fairy'], strong: ['normal','ice','rock','dark','steel']},
    poison:  {name: "poison",  immune: ['steel'], weak: ['poison','ground','rock','ghost'], strong: ['grass','fairy']},
    ground:  {name: "ground",  immune: ['flying'], weak: ['grass','bug'], strong: ['fire','electric','poison','rock','steel']},
    flying:  {name: "flying",  immune: [], weak: ['electric','rock','steel'], strong: ['grass','fighting','bug']},
    psychic: {name: "psychic", immune: ['dark'], weak: ['psychic','steel'], strong: ['fighting','poison']},
    bug:     {name: "bug",     immune: [], weak: ['fire','fighting','poison','flying','ghost','steel','fairy'], strong: ['grass','psychic','dark']},
    rock:    {name: "rock",    immune: [], weak: ['fighting','ground','steel'], strong: ['fire','ice','flying','bug']},
    ghost:   {name: "ghost",   immune: ['normal'], weak: ['dark'], strong: ['ghost','psychic']},
    dragon:  {name: "dragon",  immune: ['fairy'], weak: ['steel'], strong: ['dragon']},
    dark:    {name: "dark",    immune: [], weak: ['fighting','dark','fairy'], strong: ['ghost','psychic']},
    steel:   {name: "steel",   immune: [], weak: ['fire','water','electric','steel'], strong: ['ice','rock','fairy']},
    fairy:   {name: "fairy",   immune: [], weak: ['fire','poison','steel'], strong: ['fighting','dragon','dark']},
    none:    {name: "none",    immune: [], weak: [], strong: []}
};

const encountersOfEach = [
    {priType: "fire", secType: "none", amt: 12},//cinderace 7, torkoal 5
    {priType: "fire", secType: "fighting", amt: 5}, //blaziken, infernape
    {priType: "dragon", secType: "flying", amt: 4},//
    {priType: "fire", secType: "dark", amt: 2},//
    {priType: "water", secType: "none", amt: 8},//
    {priType: "water", secType: "grass", amt: 8}, //water ogerpon
    {priType: "water", secType: "electric", amt: 9}, //rotom wash
    {priType: "water", secType: "poison", amt: 3},//
    {priType: "water", secType: "dragon", amt: 12}, //walking wake
    {priType: "water", secType: "dark", amt: 4},//
    {priType: "electric", secType: "none", amt: 8},//
    {priType: "electric", secType: "dragon", amt: 13}, //raging bolt
    {priType: "grass", secType: "none", amt: 9}, //rillaboom 5, seperior 4
    {priType: "grass", secType: "ice", amt: 1},//
    {priType: "grass", secType: "rock", amt: 5}, //stone ogerpon
    {priType: "grass", secType: "ghost", amt: 2},// sinistcha
    {priType: "grass", secType: "dark", amt: 5}, //meowscarada
    {priType: "ice", secType: "none", amt: 2},//
    {priType: "fighting", secType: "none", amt: 9}, //zamazenta
    {priType: "fighting", secType: "ground", amt: 15}, //greattusk
    {priType: "fighting", secType: "fairy", amt: 7}, //iron valiant
    {priType: "poison", secType: "none", amt: 2},//
    {priType: "ground", secType: "none", amt: 2},//
    {priType: "ground", secType: "flying", amt: 17}, //gliscor, landorus
    {priType: "flying", secType: "dragon", amt: 9}, //dragonite
    {priType: "flying", secType: "steel", amt: 9},//corviknight
    {priType: "psychic", secType: "fairy", amt: 9},//hatterene
    {priType: "bug", secType: "rock", amt: 8}, //kleavor
    {priType: "rock", secType: "none", amt: 9}, //nacl
    {priType: "rock", secType: "poison", amt: 6}, //glimmora
    {priType: "ghost", secType: "dragon", amt: 4},// dragapult
    {priType: "ghost", secType: "steel", amt: 15}, //gholdengo
    {priType: "ghost", secType: "fairy", amt: 4},// mimikyu
    {priType: "dark", secType: "none", amt: 3}, //
    {priType: "dark", secType: "steel", amt: 15}, //kingambit
]

function getEffectiveness(move, targetType, types) {
    if (!targetType) return 1;
    const moveData = types[move];
    if (moveData.immune.includes(targetType)) return 0;
    if (moveData.strong.includes(targetType)) return 2;
    if (moveData.weak.includes(targetType)) return 0.5;
    return 1;
}

function scoreMoveAgainst(enc, move, types) {
    const eff1 = getEffectiveness(move, enc.priType, types);
    const eff2 = getEffectiveness(move, enc.secType, types);
    return eff1 * eff2;
}

function scoreMoveset(moveset, encounters, types) {
    let total = 0;
    for (const enc of encounters) {
        let best = 0;

        for (const move of moveset) {
            const eff = scoreMoveAgainst(enc, move, types);
            if (eff > best) best = eff;
        }

        total += best * enc.amt;
    }
    return total;
}
function scoreDefense(type1, type2, encounters, types) {
    let totalWeakness = 0;

    for (const enc of encounters) {
        // For each encounter, consider its attacking types
        const atkTypes = Object.keys(types).filter(t => t !== "none");

        for (const atk of atkTypes) {
            const eff1 = getEffectiveness(atk, type1, types);
            const eff2 = getEffectiveness(atk, type2, types);
            const eff = eff1 * eff2;
            if (eff === 0.5) totalWeakness -= enc.amt * 0.5;
            if (eff === 0)   totalWeakness -= enc.amt * 1;

            if (eff === 2) totalWeakness += enc.amt * 4;
            if (eff === 4) totalWeakness += enc.amt * 8;


        }
    }

    return totalWeakness;
}

function hasSuperEffective(moveset, encounter, types) {
    for (const move of moveset) {
        const eff1 = getEffectiveness(move, encounter.priType, types);
        const eff2 = getEffectiveness(move, encounter.secType, types);
        if (eff1 * eff2 >= 2) return true;
    }
    return false;
}
function pickRandomEncounter(encounters) {
    const total = encounters.reduce((sum, e) => sum + e.amt, 0);
    let r = Math.random() * total;

    for (const e of encounters) {
        if (r < e.amt) return e;
        r -= e.amt;
    }
}
function pickRandomAttackType(enc) {
    if (enc.secType === "none") return enc.priType;
    return Math.random() < 0.5 ? enc.priType : enc.secType;
}
function testMovesetCoverage(moveset, encounters, types, trials = 20000) {
    let hits = 0;

    for (let i = 0; i < trials; i++) {
        const enc = pickRandomEncounter(encounters);
        if (hasSuperEffective(moveset, enc, types)) hits++;
    }

    return hits / trials;
}
function simulateDefense(type1, type2, encounters, types, trials = 20000) {
    let score = 0;

    for (let i = 0; i < trials; i++) {
        const enc = pickRandomEncounter(encounters);

        const atk1 = enc.priType;
        const atk2 = enc.secType !== "none" ? enc.secType : null;

        const eff1 = getEffectiveness(atk1, type1, types) * getEffectiveness(atk1, type2, types);
        const eff2 = atk2 ? getEffectiveness(atk2, type1, types) * getEffectiveness(atk2, type2, types) : 1;

        const eff = Math.max(eff1, eff2);

        if (eff === 0) score -= 2;
        else if (eff === 0.5) score -= 1;
        else if (eff === 2) score += 2;
        else if (eff === 4) score += 4;
    }

    return score;
}

function getBestMovesets(types, encounters, topN = 10) {
    const typeList = Object.keys(types).filter(t => t !== "none");
    const combos = [];
    for (let i = 0; i < typeList.length; i++) {
        for (let j = i+1; j < typeList.length; j++) {
            for (let k = j+1; k < typeList.length; k++) {
                for (let l = k+1; l < typeList.length; l++) { //4
                    for (let m = l+1; m <typeList.length;m++){
                        for (let n = m+1; n < typeList.length; n++){
                            const moveset = [typeList[i], typeList[j], typeList[k], typeList[l], typeList[m], typeList[n]];
                            const score = scoreMoveset(moveset, encounters, types);
                            combos.push({ moveset, score });
                        }
                    }
                }
            }
        }
    }
    return combos
        .sort((a, b) => b.score - a.score)
        .slice(0, topN);
}
function getBestDefensiveTypings(types, encounters, topN = 5) {
    const typeList = Object.keys(types).filter(t => t !== "none");
    const results = [];

    for (let i = 0; i < typeList.length; i++) {
        for (let j = i; j < typeList.length; j++) {
            const t1 = typeList[i];
            const t2 = typeList[j];
            const score = simulateDefense(t1, t2, encounters, types);
            results.push({ typing: [t1, t2], score });
        }
    }
    return results.sort((a, b) => a.score - b.score).slice(0, topN);
}


//6 instantaneous 1-turn moves, win if at least one is super effective.
//realistic 2mon offense-defense tba
console.log(getBestMovesets(types,encountersOfEach,4))
const best = getBestMovesets(types, encountersOfEach, 1)[0];
console.log(best);

const coverage = testMovesetCoverage(best.moveset, encountersOfEach, types);
console.log("Coverage:", coverage);
console.log(getBestDefensiveTypings(types, encountersOfEach, 10));


// {moveset: Array(6), score: 561}
// moveset
// : 
// (6) ['electric', 'ice', 'fighting', 'ground', 'bug', 'fairy']
// score
// : 
// 561
// [[Prototype]]
// : 
// Object
//Coverage: 0.9447

// moveset: (6) ['ice', 'fighting', 'ground', 'bug', 'steel', 'fairy']score: 614[[Prototype]]: Object
// pok.js:213 Coverage: 0.9692

// 0
// : 
// score
// : 
// 3082
// typing
// : 
// (2) ['ghost', 'dark']
// [[Prototype]]
// : 
// Object
// 1
// : 
// score
// : 
// 4478
// typing
// : 
// (2) ['normal', 'ghost']
// [[Prototype]]
// : 
// Object
// 2
// : 
// score
// : 
// 4735
// typing
// : 
// (2) ['dragon', 'steel']
// [[Prototype]]
// : 
// Object
// 3
// : 
// score
// : 
// 4792
// typing
// : 
// (2) ['steel', 'fairy']
// [[Prototype]]
// : 
// Object
