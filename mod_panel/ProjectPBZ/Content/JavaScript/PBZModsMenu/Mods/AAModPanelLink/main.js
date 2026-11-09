"use strict";
// Mod Panel's link to the JavaScript mods Mods Menu runs (D173). Those mods register their settings with Mods Menu
// (globalThis.PBZModsMenu.push), which keeps them in the game's script memory only, where Mod Panel, a UE4SS mod,
// cannot see them. This file, started by Mods Menu's loader like any of its mods, notes each registration as it passes
// and writes them, with the settings file Mods Menu reads (PBZModsMenu.settingsPath), to <UE4SS>/Mods/ModPanel/
// ModPanel-jsmods.json. Mod Panel reads that file and shows those mods; it writes their Key=Value files itself.
// Its folder starts with AA: the loader starts mods in the order of their ids, so this one starts before the others and
// sees their registrations. Nothing is written while Mod Panel is not installed. Read only: it never changes a mod's
// registration, it passes each one on to Mods Menu as it came.
exports.stop = function () { throw new Error("Restart the game to update or disable AAModPanelLink"); };

(function modPanelLink() {
    const UE = require("ue");
    const puerts = require("puerts");
    const KSL = UE.KismetSystemLibrary;
    const NAME = "AAModPanelLink";
    const LIST = "ModPanel/ModPanel-jsmods.json"; // one dot: the game's text saver cuts a file name at its first dot
    const STORES = ["steam", "epicgamestore", "wegame", "taptap", "migu"]; // PBZ\platform\<store>
    const MAX_MODS = 64, MAX_BYTES = 1024 * 1024; // as Mod Panel reads the list
    const EVERY_MS = 2000; // a registration reaches the list within this
    const AGAIN_MS = 30000; // the list is written again this often anyway: a settings file can move (store: "saved")
    const MARK = "__modPanelLink";

    const log = (message) => { try { console.log("[" + NAME + "] " + message); } catch (_) { } };
    const seen = new Map(); // id -> the registration as the mod gave it, the last one for an id
    let dirty = true, lastText = "", lastWrite = 0, failures = 0;

    function note(raw) {
        if (raw && typeof raw == "object" && typeof raw.id == "string" && /^[A-Za-z0-9_]{1,64}$/.test(raw.id)) {
            seen.delete(raw.id); // a later registration of an id replaces the earlier one, at the end
            seen.set(raw.id, raw);
            dirty = true;
        }
    }

    // Wraps the push of whatever globalThis.PBZModsMenu is now: the array mods fill before Mods Menu runs, or Mods
    // Menu's own object. Done again whenever Mods Menu has put a new one in place.
    function hook() {
        let menu = globalThis.PBZModsMenu;
        if (menu === undefined)
            menu = globalThis.PBZModsMenu = [];
        if (!menu || typeof menu.push != "function" || menu[MARK])
            return;
        if (Array.isArray(menu))
            menu.forEach(note);
        const push = menu.push;
        Object.defineProperty(menu, "push", { configurable: true, writable: true, enumerable: false,
            value: function (...mods) { mods.forEach(note); return push.apply(this, mods); } });
        Object.defineProperty(menu, MARK, { value: true, enumerable: false });
    }

    let ue4ssDir;
    function ue4ss() {
        if (ue4ssDir === undefined) {
            const d = KSL.GetProjectContentDirectory(), content = d + (/[\\/]$/.test(d) ? "" : "/");
            const at = (s, f) => KSL.ConvertToAbsolutePath(content + "../../platform/" + s + "/" + f);
            const has = (s) => UE.BlueprintPathsLibrary.FileExists(at(s, "PBZ.exe"));
            const store = has("steam") ? "steam" : STORES.find(has) || "steam";
            // The absolute path may lose a folder's last slash: one is added back, never doubled.
            ue4ssDir = at(store, "ue4ss/Mods").replace(/[\\/]+$/, "") + "/";
        }
        return ue4ssDir;
    }

    function settingsPath(menu, id) {
        try { return menu && typeof menu.settingsPath == "function" ? menu.settingsPath(id) : undefined; }
        catch (_) { return undefined; }
    }

    // The list's text: each mod with its settings file and what it registered, functions left out.
    function listText() {
        const menu = globalThis.PBZModsMenu, mods = [];
        for (const raw of seen.values()) {
            if (mods.length >= MAX_MODS)
                break;
            const path = settingsPath(menu, raw.id);
            if (typeof path != "string" || !Array.isArray(raw.settings))
                continue; // Mods Menu refused it, or has not run yet
            try {
                mods.push(JSON.parse(JSON.stringify({ id: raw.id, title: raw.title, description: raw.description,
                    version: raw.version, greyedUnless: raw.greyedUnless, path, settings: raw.settings })));
            }
            catch (e) { log(raw.id + " left out: " + (e && e.message || e)); }
        }
        // ASCII only: the engine's text saver writes UTF-16 as soon as a character is beyond it, which Mod Panel does
        // not read. JSON.stringify writes no raw control character, so every character out of space to tilde is one to
        // write as \uXXXX: the same JSON, and one character is one byte, so the bound below counts bytes.
        const ascii = (list) => JSON.stringify({ version: 1, mods: list }).replace(/[^ -~]/g,
            (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0"));
        let text = ascii(mods);
        while (text.length > MAX_BYTES && mods.length) {
            mods.pop();
            text = ascii(mods);
        }
        return text;
    }

    function write() {
        const panel = ue4ss() + "ModPanel/";
        if (!UE.BlueprintPathsLibrary.FileExists(panel + "Scripts/main.lua"))
            return; // Mod Panel is not installed
        const text = listText();
        if (text === lastText)
            return;
        const path = ue4ss() + LIST;
        const out = puerts.$ref("");
        const ok = !!UE.EasyCsv.SaveStringToFileWithFullPath(text, path)
            && UE.EasyCsv.LoadStringFromLocalFile(path, out) && String(puerts.$unref(out)) === text;
        if (ok) {
            lastText = text;
            log("list written: " + JSON.parse(text).mods.map((m) => m.id).join(", "));
        }
        else if (failures++ < 5)
            log("the list could not be written to " + LIST);
    }

    function tick() {
        try {
            hook();
            const now = Date.now();
            if (dirty || now - lastWrite >= AGAIN_MS) {
                dirty = false;
                lastWrite = now;
                write();
            }
        }
        catch (e) {
            if (failures++ < 5)
                log("tick threw: " + (e && e.message || e));
        }
        setTimeout(tick, EVERY_MS);
    }

    hook();
    setTimeout(tick, EVERY_MS);
    log("started");
})();
