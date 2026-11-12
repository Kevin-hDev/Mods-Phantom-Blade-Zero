-- Whether Dynamic FOV's own panel can be opened. Off since 1.0.9 (Kevin, 12 November 2026): the mod is set in Mod
-- Panel or in Mods Menu. Off, not removed: the panel's code and its tests stay, so it can come back one day. Off, the
-- panel key is never bound and the panel never built, and its two settings, PanelOpacity and PanelKey, are neither
-- written to the settings file nor left in it (dynamic_fov_settings_file.lua): a menu would show each as a row that
-- does nothing. To turn the panel back on: true here, and the heading and the two rows of settings-panel-rows.json,
-- kept next to the mod's tests, back at the end of DynamicFOV.modsmenu.json.

return { ON = false }
