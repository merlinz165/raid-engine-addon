import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const luaFiles = readdirSync(root).filter((file) => file.endsWith('.lua'));
assert.deepEqual(luaFiles.sort(), ['RaidEngine.lua', 'RaidEngine_Contract.lua', 'RaidEngine_Json.lua', 'RaidEngine_Loadout.lua', 'RaidEngine_Plan.lua']);
for (const file of luaFiles) {
  const result = spawnSync('luajit', ['-b', join(root, file), '/tmp/raid-engine-addon-bytecode'], { encoding: 'utf8' });
  assert.equal(result.status, 0, `${file} failed Lua syntax validation: ${result.stderr}`);
}
const addon = readFileSync(join(root, 'RaidEngine.lua'), 'utf8');
assert.match(addon, /RaidEngineSavedVariables/);
assert.match(addon, /confirmed_plan/);
assert.match(addon, /不执行任何受保护游戏动作/);
for (const file of ['RaidEngine_Contract.lua', 'RaidEngine_Loadout.lua', 'RaidEngine_Plan.lua']) {
  const content = readFileSync(join(root, file), 'utf8');
  assert.doesNotMatch(content, /WCL_CLIENT_SECRET|WCL_CLIENT_ID|API_KEY|OAuth/i);
}
const behavior = spawnSync('luajit', ['tests/behavior.lua'], { cwd: root, encoding: 'utf8' });
assert.equal(behavior.status, 0, `Lua behavior checks failed: ${behavior.stderr || behavior.stdout}`);
console.log(`addon static checks passed (${luaFiles.length} Lua files)`);
