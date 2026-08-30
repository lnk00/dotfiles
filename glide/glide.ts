/**
 * Entry point. Browser options live here; everything else is a module
 * under `config/`.
 *
 * Note: each included file is evaluated in its *own* sandbox, so top-level
 * helpers are NOT shared between files. Every module must be self-contained.
 * Paths are resolved relative to the file doing the including.
 */

glide.o.native_tabs = "hide";

glide.include("config/prefs.glide.ts");
glide.include("config/styles.glide.ts");
glide.include("config/open.glide.ts");
glide.include("config/tabs.glide.ts");
glide.include("config/history.glide.ts");
glide.include("config/bookmarks.glide.ts");

// >>> eink theme (generated -- edit ~/.config/theme/eink.toml) >>>
glide.include("config/eink.glide.ts");
// <<< eink theme <<<
