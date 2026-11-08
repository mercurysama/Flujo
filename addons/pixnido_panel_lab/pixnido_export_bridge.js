/* PixNido 1.0 export adapter. Injected only after Servo loads.
   No implicit writes: the Godot Save button must request a transfer. */
(function () {
  'use strict';
  if (window.__pixnidoGodotExportV1) return 'installed';
  var pending = null;
  var CHUNK = 8192, MAX_LENGTH = 44739248;
  function emit(event, value) {
    if (window.godot && typeof window.godot.emit === 'function')
      window.godot.emit(event, value);
  }
  function start(token) {
    if (pending) {
      emit('pixnido.export.error', {token: token, message: 'Transfer already active.'});
      return;
    }
    var preview = document.getElementById('exportPreviewImage');
    var result = preview && /^data:(image\/(?:png|webp));base64,([a-zA-Z0-9+/=]+)$/.exec(preview.src);
    if (!result || result[2].length > MAX_LENGTH || result[2].length % 4) {
      emit('pixnido.export.error', {token: token, message: 'Export PNG/WebP in PixNido before saving, or reduce image size.'});
      return;
    }
    var nameElement = document.getElementById('projectName');
    var stem = nameElement ? nameElement.textContent : 'sprite';
    var titleElement = document.getElementById('modalTitle');
    if (titleElement && /sprites/i.test(titleElement.textContent)) stem += '-sprites';
    pending = {
      token: token, base64: result[2], index: 0,
      total: Math.ceil(result[2].length / CHUNK)
    };
    emit('pixnido.export.begin', {
      token: token, mime: result[1], stem: String(stem).slice(0, 120),
      length: result[2].length, count: pending.total
    });
  }
  function next(token, index) {
    if (!pending || pending.token !== token || pending.index !== index) return;
    if (index === pending.total) {
      emit('pixnido.export.end', {token: token, count: pending.total});
      pending = null;
      return;
    }
    var chunk = pending.base64.slice(index * CHUNK, (index + 1) * CHUNK);
    pending.index += 1;
    emit('pixnido.export.chunk', {token: token, index: index, data: chunk});
  }
  function cancel(token) {
    if (pending && pending.token === token) pending = null;
  }
  window.__pixnidoGodotExportV1 = {start: start, next: next, cancel: cancel};
  return 'ready';
}());
