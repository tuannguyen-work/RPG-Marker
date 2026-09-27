// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//
// DEBUG only, injected when the app is launched with `-smoketest`: logs every scene change and
// presses Enter a few times to get from the title screen into the game.
(() => {
  "use strict";
  const log = (message) => console.warn("smoke " + message);
  let lastScene = "";
  setInterval(() => {
    const scene = window.SceneManager && SceneManager._scene;
    const name = scene ? scene.constructor.name : "none";
    if (name !== lastScene) {
      lastScene = name;
      log("scene=" + name);
    }
  }, 250);
  const press = () => {
    if (!window.__qp) return;
    window.__qp.key(13, true);
    setTimeout(() => window.__qp.key(13, false), 120);
    log("Enter (scene=" + lastScene + ")");
  };
  for (const delay of [9000, 14000, 16000, 18000, 20000]) setTimeout(press, delay);

  // Name the file behind any audio decoding failure (MV decodes right after its XHR loads).
  const context = window.AudioContext || window.webkitAudioContext;
  if (context && window.WebAudio && WebAudio.prototype._onXhrLoad) {
    let currentUrl = null;
    const onXhrLoad = WebAudio.prototype._onXhrLoad;
    WebAudio.prototype._onXhrLoad = function (xhr) {
      currentUrl = this._url;
      return onXhrLoad.call(this, xhr);
    };
    const decode = context.prototype.decodeAudioData;
    context.prototype.decodeAudioData = function (buffer, ...callbacks) {
      const url = currentUrl;
      const result = decode.call(this, buffer, ...callbacks);
      if (result && result.catch) result.catch(() => log("decode failed: " + url + " (" + buffer.byteLength + " bytes)"));
      return result;
    };
  }
  setTimeout(() => window.Graphics && log("resolution=" + Graphics.width + "x" + Graphics.height), 10000);
})();
