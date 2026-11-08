/* Deterministic, dependency-free test of the JS side of the PixNido export bridge. */
"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const script = fs.readFileSync("addons/pixnido_panel_lab/pixnido_export_bridge.js", "utf8");

function makePage(src, title="Sprite") {
  const events=[];
  const preview=src===null?null:{src};
  const context={
    window:{godot:{emit:(event,data)=>events.push({event,data})}},
    document:{getElementById:(id)=>{
      if(id==="exportPreviewImage")return preview;
      if(id==="projectName")return {textContent:"Cuadro prueba"};
      if(id==="modalTitle")return {textContent:title};
      return null;
    }}
  };
  vm.runInNewContext(script,context);
  return {api:context.window.__pixnidoGodotExportV1,events};
}

function count(events,event){return events.filter(x=>x.event===event).length;}

const data="QUJD".repeat(7000);
const page=makePage("data:image/png;base64,"+data,"Hoja de sprites PNG");
page.api.start("nonce-1");
assert.equal(count(page.events,"pixnido.export.begin"),1);
const begin=page.events[0].data;
assert.equal(begin.count,Math.ceil(data.length/8192));
assert.equal(begin.length,data.length);
assert.match(begin.stem,/sprites/);
page.api.start("nonce-2");
assert.equal(count(page.events,"pixnido.export.error"),1);
for(let i=0;i<begin.count;i++){
  page.api.next("nonce-wrong",i);
  assert.equal(count(page.events,"pixnido.export.chunk"),i);
  page.api.next("nonce-1",i);
}
page.api.next("nonce-1",begin.count);
assert.equal(count(page.events,"pixnido.export.end"),1);
assert.equal(page.events.filter(x=>x.event==="pixnido.export.chunk").map(x=>x.data.data).join(""),data);
assert.equal(page.events.filter(x=>x.event==="pixnido.export.chunk").some(x=>x.data.data.length>8192),false);

const missing=makePage(null);
missing.api.start("no-preview");
assert.equal(count(missing.events,"pixnido.export.error"),1);
const unsupported=makePage("data:image/svg+xml;base64,QUJD");
unsupported.api.start("mime-reject");
assert.equal(count(unsupported.events,"pixnido.export.error"),1);
const huge=makePage("data:image/webp;base64,"+"QUJD".repeat(11184813));
huge.api.start("too-large");
assert.equal(count(huge.events,"pixnido.export.error"),1);

const canceled=makePage("data:image/webp;base64,QUJD");
canceled.api.start("cancel-me");
canceled.api.cancel("cancel-me");
canceled.api.next("cancel-me",0);
assert.equal(count(canceled.events,"pixnido.export.chunk"),0);
console.log("[PixNido] JS bridge tests passed: chunks, order, token, missing/invalid/oversized previews, cancel");
