# Verification

Run `python tools/build.py` then `python tools/check.py`. The suite compiles all distributable code with Luau and runs API tests against mocked Roblox service boundaries. It does not simulate a live Roblox game.

## In-game checks

1. Launch the correct game entry point, in both HTTP and local mode. Confirm the game title and its feature list.
2. Open every tab and module. Adjust toggles, sliders, single/multiple selections, numeric inputs, color controls, and keybinds. Check labels at normal and large text sizes.
3. Exercise all themes, hover states, enabled toggles, monitors and notifications; colors should remain consistent after switching themes.
4. Resize the viewport through desktop, tablet, and phone sizes. All navigation and controls must remain reachable. Scroll long pages and menus.
5. Search module names and control labels. Verify matching cards, empty results, clearing the search, and changing tabs.
6. Hide with the header button and reopen with the floating Frost button or configured key. Drag the window to the screen edges and resize the viewport.
7. Start a feature before character readiness; confirm the toggle rolls back and an error status is visible. Type in inputs while flight/clicking is active.
8. Disable or unload while work is active. Relaunch twice; check that there is only one window, no duplicate listeners, and no lingering flight constraints or movement tweens.
9. Confirm game-specific behavior in each game: feature discovery, remotes, farming/harvesting, navigation, overlays, and respawn. Neither launcher should download the other game script.

UI implementation references: [UIScale](https://create.roblox.com/docs/reference/engine/classes/UIScale) and [GuiButton.Activated](https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated).
