/* Verify NidoLab bridge against a fake PixNido DOM (no Servo required). */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = fs.readFileSync('addons/pixnido_panel_lab/pixnido_native_dialogs.js', 'utf8');

function boot(origin = 'https://pixnido.pages.dev') {
  const events = [];
  const nodes = new Map();
  const clicks = {color: 0, imported: 0, confirmed: 0};
  const swatch = {value: '#000000', dispatchEvent() {}};
  const colorButton = {click() {clicks.color++;}};
  const importButton = {click() {
    clicks.imported++;
    nodes.set('paletteImportText', {value: '', dispatchEvent() {}});
    nodes.set('confirmImportPalette', {click() {clicks.confirmed++;}});
  }};
  nodes.set('customColor', swatch);
  nodes.set('addColorBtn', colorButton);
  nodes.set('importPaletteBtn', importButton);
  const context = {
    window: {godot: {emit: (name, packet) => events.push({name, packet})}},
    document: {getElementById: id => nodes.get(id) || null},
    location: {origin, protocol: origin === 'file://' ? 'file:' : 'https:'},
    Event: class Event {constructor(type) {this.type=type;}}
  };
  vm.runInNewContext(script, context);
  return {bridge: context.window.__nidolabNativeDialogsV1, events, clicks, nodes, swatch};
}
function latest(session) {return session.events.at(-1).packet;}

const ok = boot();
assert.ok(ok.bridge);
assert.equal(latest(ok).action, 'ready');
ok.bridge.applyColor('#12Abee');
assert.equal(ok.swatch.value, '#12Abee');
assert.equal(ok.clicks.color, 1);
assert.equal(latest(ok).ok, true);
ok.bridge.applyColor('javascript:bad');
assert.equal(ok.clicks.color, 1);
assert.equal(latest(ok).ok, false);
ok.nodes.set('editPaletteColor', {value:'#000000', dispatchEvent() {}});
ok.nodes.set('applyPaletteColor', {click() {ok.clicks.color++;}});
ok.bridge.applyColor('#abcdef');
assert.equal(ok.nodes.get('editPaletteColor').value, '#abcdef');
assert.equal(ok.clicks.color, 2);

const palette = {name:'Mi paleta', colors:['#112233','#AABBCC']};
ok.bridge.preparePalette(JSON.stringify(palette));
assert.equal(ok.clicks.imported, 1);
assert.equal(ok.clicks.confirmed, 0, 'user must confirm within PixNido');
assert.equal(JSON.parse(ok.nodes.get('paletteImportText').value).name, 'Mi paleta');
assert.equal(latest(ok).ok, true);
ok.bridge.preparePalette(JSON.stringify({name:'X', colors:['red']}));
assert.equal(latest(ok).ok, false);
assert.equal(ok.clicks.imported, 1);
const foreign = boot('https://example.org');
assert.equal(foreign.events.length, 0);
foreign.bridge.applyColor('#112233');
foreign.bridge.preparePalette(JSON.stringify(palette));
assert.equal(foreign.clicks.color, 0);
assert.equal(foreign.clicks.imported, 0);
assert.equal(latest(foreign).ok, false);
console.log('[NidoLab] Native dialogs JavaScript tests passed');
