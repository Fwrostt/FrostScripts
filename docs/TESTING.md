# Verification

Run `python tools/build.py` and `python tools/check.py`. The suite compiles distributable code and the gallery, then runs **12 API**, **16 UI**, and **4 launcher integration** tests against mocked HTTPS and Roblox services. It does not render Roblox or simulate the game servers.

Project checks enforce one player launcher, generated-file consistency, no root scripts, GitHub-only executable source URLs, no filesystem script loading, and no separate game keybind pages.

## In-game checks

1. Execute only `dist/launchers/Loader.lua` through its raw GitHub URL with the documented `?frost=` cache token. Confirm Library displays both cards without starting a game.
2. Verify both complete cards fit without scrolling at 1064×678, 1280×720, 390×844, and 844×390. Verify card names, descriptions, fallback covers, an uploaded image, search, and one/two-column layouts across phone, tablet, and desktop viewports.
3. Launch the matching game. Verify its script is fetched only after selection. Use the back arrow to unload it and return; launch the other card only in its corresponding game.
4. Open module settings and rebind that feature's shortcut there. Check reserved keys, conflicts, clearing, cancellation, and visibility shortcuts.
5. Disable interface animations, background animation, and background decoration individually. Ambient motion should stop while hidden and after unload.
6. Mute sounds, change volume, preview sound, and disable notifications. Confirm preferences survive a trip to a game and back and rerunning the loader within the same client session.
7. Confirm the default is Black. Click all 10 theme previews; verify profile/avatar backgrounds, player name, brand name, keycaps, and selected/hover states follow the palette. Settings/Home must not show search. No dot decorations or missing disclosure glyphs should appear. Exercise controls and themes at normal and large text sizes. Scroll long modules and popup menus. Check readable card descriptions and module labels.
8. Test failed HTTP requests and script initialization; the library should show Retry and remain usable. Rerun the loader and confirm old windows/features are cleaned up.
9. Upload icon.png/icon.jpg beside a game, verify discovery without a build, missing-image fallback, and a changed upload on a new loader session. Edit config/Text.lua and verify subtitles, game controls, dropdown labels, and search while original option values still work.
10. Verify actual game behavior: feature discovery, remotes, farming/harvesting, navigation, overlays, stopping, and respawn.

UI references: [UIGradient](https://create.roblox.com/docs/reference/engine/classes/UIGradient), [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel), and [GuiButton](https://create.roblox.com/docs/reference/engine/classes/GuiButton).
