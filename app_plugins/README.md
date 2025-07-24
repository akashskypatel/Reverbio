<a id="readme-top"></a>

# Reverbio Plugin Development Documentation

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#overview">Overview</a></li>
    <li>
      <a href="#plugin-architecture">Plugin Architecture</a>
    </li>
    <li><a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#plugin-template">Plugin Template</a></li>
        <li><a href="#basic-requirements">Basic Requirements</a></li>
        <li><a href="#plugin-manifest">Plugin Manifest</a></li>
      </ul>
    </li>
    <li><a href="#widget-options">Widget Options</a>
      <ul>
        <li><a href="#method-execution-options">Method Execution Options</a></li>
        <li><a href="#contexts">Contexts</a></li>
        <li><a href="#icons">Icons</a></li>
      </ul>
    <li><a href="#widget-types">Widget Types</a>
    <ul>
        <li><a href="#textinput">TextInput</a></li>
        <li><a href="#textbutton">TextButton</a></li>
        <li><a href="#dropdownmenu">DropDownMenu</a></li>
        <li><a href="#switch">Switch</a></li>
        <li><a href="#songbardropdown">SongBarDropDown</a></li>
        <li><a href="#iconbutton">IconButton</a></li>
        <li><a href="#header-buttons">Header Buttons</a></li>
        <ul>
          <li><a href="#header-buttons">SongListHeader</a></li>
          <li><a href="#header-buttons">AlbumPageHeader</a></li>
          <li><a href="#header-buttons">ArtistPageHeader</a></li>
          <li><a href="#header-buttons">AlbumsPageHeader</a></li>
          <li><a href="#header-buttons">ArtistsPageHeader</a></li>
          <li><a href="#header-buttons">PlaylistPageHeader</a></li>
        </ul>
      </ul>
    </li>
    <li><a href="#hooks">Hooks</a></li>
    <li><a href="#plugin-lifecycle">Plugin Lifecycle</a></li>
    <li><a href="#best-practices">Best Practices</a></li>
    <li><a href="#debugging">Debugging</a></li>
    <li><a href="#distribution">Distribution</a></li>
  </ol>
</details>

## Overview

This document provides comprehensive guidance for developing plugins for Reverbio, a music application. The plugin system allows developers to extend Reverbio's functionality through JavaScript plugins that can interact with the app's UI and backend services. Plugins can provide additional processing on the following entities: Songs, Albums, and Artists. Plugins can be used to provide alternative source for songs.

## Plugin Architecture

The plugin system consists of three main components:

1. JavaScript Plugin File: Contains the plugin logic and manifest
2. JavaScript is executed using <a href="https://pub.dev/packages/flutter_js">FlutterJS</a>. See <a href="https://pub.dev/documentation/flutter_js/latest/">FlutterJS documentation</a> for more details on JavaScript Environment.
3. Plugin actions are single thread operations, therefore multiple method executions on the same plugin cannot be performed while another action is running.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Getting Started
### Plugin Template

Use the `template.js` file as a starting point for your plugin. It includes:

- Required global variables
- Plugin manifest structure
- Basic functions (pluginName, pluginVersion, etc.)
- Example dependency region
- Custom functions area

### Basic Requirements

- Your plugin must define a manifest in `__PLUGIN_DEPENDENCY_MANIFEST__`
- Your plugin manifest must define `name`, `version`, and `settings`.

### Plugin Manifest

The manifest defines your plugin's metadata, dependencies, UI widgets, and hooks. Here's the complete structure:

```javascript
const __PLUGIN_DEPENDENCY_MANIFEST__ = {
  name: "PluginName",          // Your plugin's name
  version: "1.0.0",           // Version number
  dependencies: [             // List of external dependencies
    {
      name: "DependencyName",
      url: "https://example.com/dependency.js",
      // Additional widget bindings for settings:
      text_input: "",         // Links to TextInput widget ID
      drop_down: "",          // Links to DropDownMenu widget ID
      switch: true            // Links to Switch widget ID
    }
  ],
  settings: {                // Plugin settings
    source: "plugin_source_path.js"  // Source file for auto-updates
  },
  widgets: [ /* Widget definitions */ ],  // UI components
  hooks: { /* Event hooks */ }            // Event handlers
};
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Widget Options

### Method Execution Options

When defining widget actions or hooks, you can specify execution behavior:

```javascript
trigger: {
  methodName: "yourMethod",
  isAsync: true,       // Whether the method is asynchronous
  isBackground: true   // Whether to run in background queue
}
```
### Contexts

Where the UI element would appear in the app: `settings`, `song_bar`, `song_list`, `album_header`, `albums_header`, `artist_header`, `artists_header`, and `playlist_header`.

### Icons

Available icons

<table>
<tr><th>Icon Name</th><th>Icon</th></tr>
<tr><th>access_time</th><th> 
<svg fill="none" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <foreignObject width="100%" height="100%">
    <img 
      src="https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Access%20Time/SVG/ic_fluent_access_time_24_filled.svg?sanitize=true&color=808080#gh-dark-mode-only" 
      style="filter: brightness(0) invert(0.7) saturate(0);"
    />
  </foreignObject>
</svg>

 ![access_time](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Access%20Time/SVG/ic_fluent_access_time_24_filled.svg?sanitize=true#gh-light-mode-only)![access_time](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Access%20Time/SVG/ic_fluent_access_time_24_filled.svg?sanitize=true&color=808080#gh-dark-mode-only)
</th></tr>
<tr><th>add</th><th>

![add_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Add/SVG/ic_fluent_add_24_filled.svg?raw=true)

</th></tr>
<tr><th>alert</th><th>

![alert_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Alert/SVG/ic_fluent_alert_24_filled.svg?raw=true)

</th></tr>
<tr><th>arrow_left</th><th>

![arrow_left_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Arrow%20Left/SVG/ic_fluent_arrow_left_24_filled.svg?raw=true)

</th></tr>
<tr><th>arrow_right</th><th>

![arrow_right_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Arrow%20Right/SVG/ic_fluent_arrow_right_24_filled.svg?raw=true)

</th></tr>
<tr><th>calendar</th><th>

![calendar_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Calendar/SVG/ic_fluent_calendar_24_filled.svg?raw=true) 

</th></tr>
<tr><th>checkmark</th><th>

![checkmark_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Checkmark/SVG/ic_fluent_checkmark_24_filled.svg?raw=true)

</th></tr>
<tr><th>chevron_down</th><th>

![chevron_down_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Chevron%20Down/SVG/ic_fluent_chevron_down_24_filled.svg?raw=true)

</th></tr>
<tr><th>close</th><th>

![dismiss_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Dismiss/SVG/ic_fluent_dismiss_24_filled.svg?raw=true)

</th></tr>
<tr><th>cloud</th><th>

![cloud_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Cloud/SVG/ic_fluent_cloud_24_filled.svg?raw=true)

</th></tr>
<tr><th>cloud_off</th><th>

![cloud_off_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Cloud%20Off/SVG/ic_fluent_cloud_off_24_filled.svg?raw=true)

</th></tr>
<tr><th>cloud_down</th><th>

![cloud_arrow_down_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Cloud%20Arrow%20Down/SVG/ic_fluent_cloud_arrow_down_24_filled.svg?raw=true)

</th></tr>
<tr><th>cloud_up</th><th>

![cloud_arrow_up_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Cloud%20Arrow%20Up/SVG/ic_fluent_cloud_arrow_up_24_filled.svg?raw=true)

</th></tr>
<tr><th>cloud_check</th><th>

![cloud_checkmark_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Cloud%20Checkmark/SVG/ic_fluent_cloud_checkmark_24_filled.svg?raw=true)

</th></tr>
<tr><th>cloud_dismiss</th><th>

![cloud_dismiss_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Cloud%20Dismiss/SVG/ic_fluent_cloud_dismiss_24_filled.svg?raw=true)

</th></tr>
<tr><th>cloud_sync</th><th>

![cloud_sync_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Cloud%20Sync/SVG/ic_fluent_cloud_sync_24_filled.svg?raw=true)

</th></tr>
<tr><th>cog</th><th>

![settings_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Settings/SVG/ic_fluent_settings_24_filled.svg?raw=true)

</th></tr>
<tr><th>delete</th><th>

![delete_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Delete/SVG/ic_fluent_delete_24_filled.svg?raw=true)

</th></tr>
<tr><th>download</th><th>

![arrow_download_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Arrow%20Download/SVG/ic_fluent_arrow_download_24_filled.svg?raw=true)

</th></tr>
<tr><th>edit</th><th>

![edit_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Edit/SVG/ic_fluent_edit_24_filled.svg?raw=true)

</th></tr>
<tr><th>email</th><th>

![mail_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Mail/SVG/ic_fluent_mail_24_filled.svg?raw=true)

</th></tr>
<tr><th>error</th><th>

![error_circle_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Error%20Circle/SVG/ic_fluent_error_circle_24_filled.svg?raw=true)

</th></tr>
<tr><th>eye</th><th>

![eye_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Eye/SVG/ic_fluent_eye_24_filled.svg?raw=true)

</th></tr>
<tr><th>eye_off</th><th>

![eye_off_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Eye%20Off/SVG/ic_fluent_eye_off_24_filled.svg?raw=true)

</th></tr>
<tr><th>filter</th><th>

![filter_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Filter/SVG/ic_fluent_filter_24_filled.svg?raw=true)

</th></tr>
<tr><th>folder</th><th>

![folder_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Folder/SVG/ic_fluent_folder_24_filled.svg?raw=true)

</th></tr>
<tr><th>folder_link</th><th>

![folder_link_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Folder%20Link/SVG/ic_fluent_folder_link_24_filled.svg?raw=true)

</th></tr>
<tr><th>headphones_wave</th><th>

![headphones_sound_wave_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Headphones%20Sound%20Wave/SVG/ic_fluent_headphones_sound_wave_24_filled.svg?raw=true)

</th></tr>
<tr><th>heart</th><th>

![heart_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Heart/SVG/ic_fluent_heart_24_filled.svg?raw=true)

</th></tr>
<tr><th>home</th><th>

![home_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Home/SVG/ic_fluent_home_24_filled.svg?raw=true)

</th></tr>
<tr><th>info</th><th>

![info_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Info/SVG/ic_fluent_info_24_filled.svg?raw=true)

</th></tr>
<tr><th>key</th><th>

![key_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Key/SVG/ic_fluent_key_24_filled.svg?raw=true)

</th></tr>
<tr><th>menu</th><th>

![line_horizontal_3_24_filled](https://github.com/microsoft/fluentui-system-icons/blob/main/assets/Line%20Horizontal%203/SVG/ic_fluent_line_horizontal_3_48_regular.svg?raw=true)

</th></tr>
<tr><th>more</th><th>

![more_vertical_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/More%20Vertical/SVG/ic_fluent_more_vertical_24_filled.svg?raw=true)

</th></tr>
<tr><th>notification</th><th>

![alert_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Alert/SVG/ic_fluent_alert_24_filled.svg?raw=true)

</th></tr>
<tr><th>person</th><th>

![person_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Person/SVG/ic_fluent_person_24_filled.svg?raw=true)

</th></tr>
<tr><th>search</th><th>

![search_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Search/SVG/ic_fluent_search_24_filled.svg?raw=true)

</th></tr>
<tr><th>send</th><th>

![send_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Send/SVG/ic_fluent_send_24_filled.svg?raw=true)

</th></tr>
<tr><th>share</th><th>

![share_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Share/SVG/ic_fluent_share_24_filled.svg?raw=true)

</th></tr>
<tr><th>star</th><th>

![star_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Star/SVG/ic_fluent_star_24_filled.svg?raw=true)

</th></tr>
<tr><th>upload</th><th>

![arrow_upload_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Arrow%20Upload/SVG/ic_fluent_arrow_upload_24_filled.svg?raw=true)

</th></tr>
<tr><th>warning</th><th>

![warning_24_filled](https://github.com/microsoft/fluentui-system-icons/raw/main/assets/Warning/SVG/ic_fluent_warning_24_filled.svg?raw=true)

</th></tr>
</table>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Widget Types

Reverbio `WidgetFactory` supports several widget types that can be defined in your manifest:

(*Required fields)

### TextInput

A text input field for user input.

#### Properties:

- `type`*: `TextInput`
- `id`*: Widget Id
- `context`*: Always `settings`
- `label`*: Widget text label
- `onTapOutside`: Method to call when tapping outside
- `onSubmitted`: Method to call when submitted
- `icon`: Icon name (from predefined set)

Example:

```javascript
{
  id: "api_key_input",
  label: "API Key",
  type: "TextInput",
  context: "settings",
  onTapOutside: { methodName: "updateSettings", isAsync: false },
  onSubmitted: { methodName: "updateSettings", isAsync: false },
  icon: "key"
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### TextButton

A button with text and icon.

#### Properties:

- `type`*: `TextButton`
- `id`*: Widget Id
- `label`*: Widget text label
- `context`*: Always `settings`
- `onPressed`*: Method to call when tapped
- `backgroundColor`: `#RRGGBB` Background color of the button
- `icon`: Icon name (from predefined set)

Example:

```javascript
{
  id: "text_button",
  label: "Button",
  type: "TextButton",
  context: "settings",
  backgroundColor: "#ffffff",
  onPressed: { methodName: "updateSettings", isAsync: false },
  icon: "folder"
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### DropDownMenu

A dropdown selection menu.

#### Properties:

- `type`*: `TextInput`
- `id`*: Widget Id
- `context`*: Always `settings`
- `label`*: Widget text label
- `options`*: Array of options
- `onSelected`: Method to call when an option is selected
- `icon`: Icon name (from predefined set)

Example:
```javascript
{
  id: "quality_select",
  label: "Audio Quality",
  type: "DropDownMenu",
  context: "settings",
  options: ["Low", "Medium", "High"],
  onSelected: { methodName: "updateSettings", isAsync: false },
  icon: "headphones_wave"
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Switch

A toggle switch.

#### Properties:

- `type`*: `Switch`
- `id`*: Widget Id
- `context`*: Always `settings`
- `label`*: Widget text label
- `onChanged`: Method to call when toggled
- `icon`: Icon name (from predefined set)

Example:
```javascript
{
  id: "enable_cache",
  label: "Enable Caching",
  type: "Switch",
  context: "settings",
  onChanged: { methodName: "updateSettings", isAsync: false },
  icon: "cloud_sync"
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### SongBarDropDown

A menu item in the song bar context menu. Relevant song data is passed as function parameters to the method.

#### Properties:

- `type`*: `SongBarDropDown`
- `id`*: Widget Id
- `context`*: Always `song_bar`
- `label`*: Widget text label
- `onTap`: Method to call when clicked
- `icon`: Icon name (from predefined set)

Example:
```javascript
{
  id: "download_song",
  type: "SongBarDropDown",
  context: "song_bar",
  label: "Download Song",
  onTap: { methodName: "downloadSong", isAsync: true, isBackground: true },
  icon: "cloud_down"
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### IconButton

A button with text and icon.

#### Properties:

- `type`*: `IconButton`
- `id`*: Widget Id
- `label`*: Widget text label
- `context`*: `settings`, `song_bar`, `song_list`, `album_header`, `albums_header`, `artist_header`, `artists_header`, or `playlist_header`.
- `onPressed`*: Method to call when tapped
- `icon`: Icon name (from predefined set)

Example:

```javascript
{
  id: "icon_button",
  label: "Button",
  type: "TextButton",
  context: "settings",
  onPressed: { methodName: "updateSettings", isAsync: false },
  icon: "folder"
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Header Buttons

Buttons that appear in various section headers. Relevant entity (artist, song, or album) data is passed as function parameters to the method.

#### Types:

- `SongListHeader`
- `AlbumPageHeader`
- `ArtistPageHeader`
- `PlaylistPageHeader`
- `AlbumsPageHeader` (liked albums page)
- `ArtistsPageHeader` (liked artists page)

#### Properties:

- `type`*: `AlbumPageHeader`
- `id`*: Widget Id
- `context`*: `song_list`, `album_header`, `albums_header`, `artist_header`, `artists_header`, or `playlist_header`.
- `label`*: Widget text label
- `onPressed`: Method to call when clicked
- `icon`: Icon name (from predefined set)

Example:
```javascript
{
  id: "refresh_albums",
  type: "AlbumPageHeader",
  context: "album_header",
  label: "Refresh Albums",
  onPressed: { methodName: "refreshAlbums", isAsync: true },
  icon: "cloud_sync"
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Hooks

Hooks allow your plugin to respond to system events:
```javascript
hooks: {
  onEntityLiked: {
    id: "cache_liked",
    onTrigger: {
      methodName: "cacheLikedSong",
      isAsync: true,
      isBackground: true
    }
  },
  onGetSongUrl: {
    id: "get_song_url",
    onTrigger: {
      methodName: "getCustomSongUrl",
      isAsync: true,
      isBackground: false
    }
  }
}
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Available Hooks:

#### `onEntityLiked`

Triggered when a artist/song/album is liked. App will pass a JSON object as string containing, depending on requested object, artist name, album name, annd song name.

``` JSON
{
  "id": "mb=abcd1234", //may or may not include MusicBrainz, YouTube and Discogs ids in URL parameter format for requested object
  "artist": "artist name", //guranteed to not be null when entity is artist, song or album
  "album": "album name", //guranteed to not be null when entity is album
  "song": "song name", //guranteed to not be null when entity is song
}
```

#### `onGetSongUrl`

Triggered when a song URL is requested before playing. App will pass a JSON object as string containing, at a minimum, artist name, song name, and album name (if available and relevant).

``` JSON
{
  "id": "mb=abcd1234", //may or may not include MusicBrainz, YouTube and Discogs ids in URL parameter format for requested object.
  "artist": "artist name", //guranteed to not be null
  "album": "album name", //can be null
  "song": "song name", //guranteed to not be null
}
```

#### `onQueueSong` 

Triggered when user adds a song to the queue. Data returned by plugin is merged into existing `Map`. 

``` JSON
{
  "id": "mb=abcd1234", //may or may not include MusicBrainz, YouTube and Discogs ids in URL parameter format for requested object
  "artist": "artist name", //guranteed to not be null
  "album": "album name", //may or maynot be null
  "song": "song name", //guranteed to not be null
}
```

#### `onPlaylistPlay` 

Triggered when user plays a playlist

#### `onPlaylistSongAdd` 

Triggered when user adds a song to a playlist

#### `onPlaylistAdd` 

Triggered when user adds a new playlist

#### `onGetArtistInfo` 

Triggered when the app queries artist info

#### `onGetSongInfo` 

Triggered when the app queries song info

#### `onGetAlbumInfo` 

Triggered when the app queries album info


<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Plugin Lifecycle

1. Initialization: Plugin is loaded and evaluated
2. Settings Loaded: `loadSettings()` is called with default and user settings
3. Ready: Plugin is available for interaction
4. Background Processing: Async tasks are queued and processed
5. Update/Sync: Plugin can be updated from source
6. Disposal: Plugin is removed and resources cleaned up
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Best Practices

- Use isBackground: true for long-running operations
- Prefix your plugin name (e.g., `MyPlugin_Settings`)
- Use the dependency system for shared functionality
- Test your plugin with both async and sync execution
- Handle errors gracefully and provide user feedback
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Debugging

- Use `print()` function in your JavaScript to log to console
- Check background job queue for async task status
- Validate your manifest structure
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Distribution

Package your plugin as a single JS file with all dependencies included in their respective regions.
<p align="right">(<a href="#readme-top">back to top</a>)</p>