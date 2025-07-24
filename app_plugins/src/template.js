/*
 *     Copyright (C) 2025 Akash Patel
 *     https://ko-fi.com/akashskypatel
*/

//#region Globals
var window = {};
var document = {};
var module = { exports: {} };
var exports = module.exports;
var define = function (deps, factory) {
  if (typeof deps === "function") {
    module.exports = deps();
  } else {
    module.exports = factory();
  }
  define.amd = {};
};
var globalThis = typeof globalThis !== "undefined" ? globalThis : {};
var global = globalThis;
var self = globalThis;
//#endregion

//#region MANIFEST
// ====== Dependency Manifest ======
const __PLUGIN_DEPENDENCY_MANIFEST__ = {
  name: "RealDebridClient",
  version: "1.0.0",
  //Only UMD (Universal Module Definition) ES2023 JavaScript dependencies are compatible
  dependencies: [
    {
      name: "ExampleDependency",
      url: "https://Example.com/ExampleDependency.js",
      text_input: "",
      drop_down: "",
      switch: true,
      
    },
  ],
  settings: {    
    source: "C:\\reverbio_plugin.js", //TODO add automatic plugin update from source
  },
  widgets: [
    {
      id: "text_input",
      label: "Example Text Input",
      type: "TextInput",
      context: "settings",
      onTapOutside: { methodName: "updateSettings", isAsync: false },
      onSubmitted: { methodName: "updateSettings", isAsync: false },
      icon: "key",
    },
    {
      id: "drop_down",
      label: "Example Drop Down",
      type: "DropDownMenu",
      context: "settings",
      options: ["One", "Two", "Three"],
      onSelected: { methodName: "updateSettings", isAsync: false },
      icon: "headphones_wave",
    },
    {
      id: "switch",
      label: "Example Switch",
      type: "Switch",
      context: "settings",
      onChanged: { methodName: "updateSettings", isAsync: false },
      icon: "cloud_sync",
    },
    {
      id: "song_bar_dropdown",
      type: "SongBarDropDown",
      context: "song_bar",
      label: "Example Song Bar Dropdown Menu Button",
      onTap: { methodName: "exampleFunction", isAsync: true, isBackground: true },
      icon: "cloud_up",
    },
    {
      id: "song_list_header",
      type: "SongListHeader",
      context: "song_list",
      label: "Example Song List Header Button",
      onPressed: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
      icon: "cloud_up",
    },
    {
      id: "album_header",
      type: "AlbumPageHeader",
      context: "album_header",
      label: "Example Album Header Button",
      onPressed: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
      icon: "cloud_up",
    },
    {
      id: "artist_header",
      type: "ArtistPageHeader",
      context: "artist_header",
      label: "Example Artist Header Button",
      onPressed: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
      icon: "cloud_up",
    },
    {
      id: "playlist_header",
      type: "PlaylistPageHeader",
      context: "playlist_header",
      label: "Example Playlist Header Button",
      onPressed: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
      icon: "cloud_up",
    },
  ],
  hooks: {
    onQueueSong: {
      //This hook is always executed asynchronously in the main thread
      id: "queue_song",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: false,
      },
    },
    onEntityLiked: {
      //This hook is always executed asynchronously in the background
      id: "entity_liked",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
    },
    onPlaylistPlay: {
      //This hook is always executed asynchronously in the background
      id: "playlist_play",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
    },
    onPlaylistSongAdd: {
      //This hook is always executed asynchronously in the background
      id: "playlist_song_add",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
    },
    onPlaylistAdd: {
      //This hook is always executed asynchronously in the background
      id: "playlist_add",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: true,
      },
    },
    onGetSongUrl: {
      //This hook is always executed asynchronously in the main thread
      id: "get_song_url",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: false,
      },
    },
    onGetArtistInfo: {
      //This hook is always executed asynchronously in the main thread
      id: "get_artist_info",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: false,
      },
    },
    onGetSongInfo: {
      //This hook is always executed asynchronously in the main thread
      id: "get_song_info",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: false,
      },
    },
    onGetAlbumInfo: {
      //This hook is always executed asynchronously in the main thread
      id: "get_album_info",
      onTrigger: {
        methodName: "exampleFunction",
        isAsync: true,
        isBackground: false,
      },
    },
  },
};
//#endregion

//#region DefaultFunctions
//Default functions. Do not modify. Modifying these may break all plugin functionality in app.
const manifest = __PLUGIN_DEPENDENCY_MANIFEST__;

const pluginName = () => manifest["name"];
const pluginVersion = () => manifest["version"];
const pluginManifest = () => JSON.stringify(manifest);
const pluginSettings = () => JSON.stringify(manifest["settings"]);
const pluginWidgets = () => JSON.stringify(manifest["widgets"]);
const pluginHooks = () => JSON.stringify(manifest["hooks"]);

function merge(target, source) {
  for (const key in source) {
    if (typeof target[key] === "object" && typeof source[key] === "object") {
      target[key] = merge(target[key] || {}, source[key]);
    } else {
      target[key] = source[key];
    }
  }
  return target;
}

function updateSettings(value) {
  manifest["settings"] = merge(manifest["settings"], value);
  return { message: "Settings updated!" };
}

function loadSettings(defaults, user) {
  manifest["settings"] = {};
  updateSettings(defaults);
  updateSettings(user);
}

function print(message) {
  console.log(
    `${new Date(Date.now()).toLocaleString()}: ${pluginName()} - ${message}`
  );
}

print(`Plugin ${pluginName()} (${pluginVersion()}) Loaded.`);

//#endregion

//#region ExampleDependency

//#endregion

//****** ====================IMPORTANT==================== ******/
//INCLUDE THIS AFTER EVERY DEPENDENCY REGION TO UPDATE GLOBALS
//CHANGE THIS TO UPDATE GLOBALS BASED ON THE DEPENDENCY
typeof globalThis !== 'undefined' ? globalThis : global || self, global.ExampleDependency = module.exports;

ExampleDependency = global.ExampleDependency;


//#region CustomFunctions
//Define your custom functions here
function exampleFunction() {
    return 'Hello World!';
}
//#endregion