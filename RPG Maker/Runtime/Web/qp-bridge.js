// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//
// Injected at document start into every MV/MZ game page.
//
// - Replaces window.localStorage (MV, plugins) and, once the engine has loaded,
//   window.localforage (MZ) with stores persisted by the app, one file per key.
// - Exposes window.__qp for the app: key(), setSpeed(), setPaused(), patchEngine().
(() => {
  "use strict";

  const post = (message) => window.webkit.messageHandlers.qpStorage.postMessage(message);
  const initial = window.__QP_STORE__ || {};

  // Keys are namespaced on the native side: "ls:" = localStorage, "lf:" = localforage.
  function makeNamespace(prefix) {
    const data = new Map();
    for (const [key, value] of Object.entries(initial)) {
      if (key.startsWith(prefix)) data.set(key.slice(prefix.length), value);
    }
    return {
      data,
      get: (key) => (data.has(key) ? data.get(key) : null),
      set: (key, value) => {
        data.set(key, value);
        post({ op: "set", key: prefix + key, value });
      },
      remove: (key) => {
        if (data.delete(key)) post({ op: "remove", key: prefix + key });
      },
      clear: () => {
        for (const key of data.keys()) post({ op: "remove", key: prefix + key });
        data.clear();
      },
    };
  }

  const ls = makeNamespace("ls:");
  const localStorageShim = {
    getItem: (key) => ls.get(String(key)),
    setItem: (key, value) => ls.set(String(key), String(value)),
    removeItem: (key) => ls.remove(String(key)),
    clear: () => ls.clear(),
    key: (index) => Array.from(ls.data.keys())[index] ?? null,
    get length() { return ls.data.size; },
  };
  try {
    Object.defineProperty(window, "localStorage", { value: localStorageShim, configurable: true });
  } catch (error) {
    console.error("qp: cannot replace localStorage", error);
  }

  // localforage stores any value; MZ only stores strings, anything else goes through JSON.
  const lf = makeNamespace("lf:");
  const JSON_MARK = "\u0000qpjson:";
  const encode = (value) => (typeof value === "string" ? value : JSON_MARK + JSON.stringify(value));
  const decode = (value) => (value !== null && value.startsWith(JSON_MARK) ? JSON.parse(value.slice(JSON_MARK.length)) : value);
  const localforageShim = {
    setItem: (key, value) => { lf.set(String(key), encode(value)); return Promise.resolve(value); },
    getItem: (key) => Promise.resolve(decode(lf.get(String(key)))),
    removeItem: (key) => { lf.remove(String(key)); return Promise.resolve(); },
    keys: () => Promise.resolve(Array.from(lf.data.keys())),
    length: () => Promise.resolve(lf.data.size),
    clear: () => { lf.clear(); return Promise.resolve(); },
    ready: () => Promise.resolve(),
    config: () => true,
    createInstance: () => localforageShim,
  };

  let speed = 1;
  let paused = false;

  // Called by the app right after rpg_managers.js / rmmz_managers.js is evaluated.
  function patchEngine() {
    if (window.StorageManager && typeof StorageManager.forageKey === "function") {
      window.localforage = localforageShim;
    }
    // `class` declarations (VorbisDecoder) are globals but not window properties: check the binding.
    if (window.Utils && typeof VorbisDecoder === "function") {
      // MZ: WebKit on iOS claims Ogg support but can't decode Vorbis with decodeAudioData,
      // so use the decoder MZ ships with instead.
      Utils.canPlayOgg = () => false;
    }
    if (window.SceneManager) {
      // The engine only updates while document.hasFocus(), which a web view hosted behind native
      // controls rarely has. The app decides instead: the game runs unless it is paused.
      SceneManager.isGameActive = () => !paused;
    }
    if (window.SceneManager && typeof SceneManager.determineRepeatNumber === "function") {
      // MZ: run several updates per frame when fast-forwarding.
      const original = SceneManager.determineRepeatNumber;
      SceneManager.determineRepeatNumber = function (deltaTime) {
        return original.call(this, deltaTime) * speed;
      };
    }
  }

  function setSpeed(value) {
    speed = value;
    // MV: the fixed-step loop runs an update every _deltaTime seconds.
    if (window.SceneManager && typeof SceneManager.determineRepeatNumber !== "function") {
      SceneManager._deltaTime = 1 / 60 / value;
    }
  }

  // MV/MZ read event.keyCode, which KeyboardEvent's initializer can't set.
  function key(code, isDown) {
    const event = new KeyboardEvent(isDown ? "keydown" : "keyup", { bubbles: true, cancelable: true });
    Object.defineProperty(event, "keyCode", { get: () => code });
    Object.defineProperty(event, "which", { get: () => code });
    document.dispatchEvent(event);
  }

  function setPaused(value) {
    paused = value;
  }

  window.__qp = { patchEngine, setSpeed, setPaused, key };

  // Surface script errors and console warnings in the app's log.
  for (const level of ["error", "warn"]) {
    const original = console[level].bind(console);
    console[level] = (...args) => {
      original(...args);
      post({ op: "log", level, message: args.map(String).join(" ") });
    };
  }
  window.addEventListener("error", (event) => {
    post({ op: "log", level: "error", message: `${event.message} (${event.filename}:${event.lineno})` });
  });
  window.addEventListener("unhandledrejection", (event) => {
    post({ op: "log", level: "error", message: `Unhandled rejection: ${event.reason}` });
  });
})();
