/* NidoLab native selection adapter for the existing PixNido 1.0 page.
 * No automatic dialogs, no disk access from JavaScript, no PWA modifications.
 * Every action is initiated by a visible Godot editor control.
 */
(function () {
  'use strict';
  if (window.__nidolabNativeDialogsV1) return 'already-installed';

  function trusted() {
    return location.origin === 'https://pixnido.pages.dev' || location.protocol === 'file:';
  }

  function emit(action, ok, message) {
    if (window.godot && typeof window.godot.emit === 'function')
      window.godot.emit('nidolab.native.result', {
        action: action, ok: !!ok, message: String(message).slice(0, 200)
      });
  }

  function applyColor(hex) {
    if (!trusted() || !/^#[0-9a-f]{6}$/i.test(hex)) {
      emit('color', false, 'Untrusted page or invalid RGB color.');
      return;
    }
    var picker = document.getElementById('editPaletteColor');
    var apply = document.getElementById('applyPaletteColor');
    if (!picker || !apply) {
      picker = document.getElementById('customColor');
      apply = document.getElementById('addColorBtn');
    }
    if (!picker || !apply) {
      emit('color', false, 'Open the PixNido palette controls first.');
      return;
    }
    picker.value = hex;
    picker.dispatchEvent(new Event('input', {bubbles: true}));
    picker.dispatchEvent(new Event('change', {bubbles: true}));
    apply.click();
    emit('color', true, 'Color sent to PixNido.');
  }

  function preparePalette(jsonText) {
    if (!trusted() || typeof jsonText !== 'string' || jsonText.length > 32768) {
      emit('palette', false, 'Untrusted page or oversized palette.');
      return;
    }
    var palette;
    try { palette = JSON.parse(jsonText); } catch (_) {
      emit('palette', false, 'Invalid JSON.');
      return;
    }
    if (!palette || typeof palette.name !== 'string' ||
        !palette.name.trim() || palette.name.length > 35 ||
        !Array.isArray(palette.colors) || !palette.colors.length ||
        palette.colors.length > 64 ||
        !palette.colors.every(function (v) {
          return typeof v === 'string' && /^#[0-9a-f]{6}$/i.test(v);
        })) {
      emit('palette', false, 'Palette does not match PixNido schema.');
      return;
    }
    var launcher = document.getElementById('importPaletteBtn');
    if (!launcher) {
      emit('palette', false, 'Open the PixNido palette editor first.');
      return;
    }
    launcher.click();
    var textArea = document.getElementById('paletteImportText');
    if (!textArea || !document.getElementById('confirmImportPalette')) {
      emit('palette', false, 'PixNido import dialog is not available.');
      return;
    }
    textArea.value = JSON.stringify(palette);
    textArea.dispatchEvent(new Event('input', {bubbles: true}));
    emit('palette', true, 'Review palette and press Import in PixNido.');
  }

  window.__nidolabNativeDialogsV1 = {
    applyColor: applyColor,
    preparePalette: preparePalette
  };
  if (trusted()) emit('ready', true, 'Native palette controls connected.');
  return 'installed';
}());
