# Description

Please include a summary of the change and which issue is fixed. Please also include relevant motivation and context. List any dependencies that are required for this change.

Fixes # (issue)

## Type of change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

# Testing Checklist

## Application

Make sure the application launches without errors.

- [ ] Make sure the application launches without errors.
- [ ] Verify cache data is created in application directory.

## Home page

Complete or verify all features on Home Page.

- [ ] Suggested Playlists loads with Image and Labels successfully.
- [ ] Suggested Artists loads with Image and Labels successfully.
- [ ] Recommended for you loads with Image and Labels successfully.
- [ ] Refresh Home Page completes successfully.
- [ ] Liking artist, playlist, and song completes successfully.
- [ ] Recommended for you toolbox opens and closes successfully.
- [ ] Recommended for you songs can be played successfully (if stream found).
- [ ] If song stream found, can be opened in youtube successfully.
- [ ] Recommended for you songs can be queued, played, shuffled, and sorted successfully.
- [ ] A Recommended for you Song can be liked, added to playlist, added to queue, and added to offline successfully.
- [ ] A Recommended for you Song can be disliked, removed from playlist, removed from queue, and removed from offline successfully.
- [ ] Double tapping a song likes/dislikes a song.

## Search page

Complete or verify all features on Search Page.

- [ ] Typing in search bar is successful and shows suggestions successfully.
- [ ] Submitting search query shows search results successfully.
- [ ] Clicking on search suggestions shows search results successfully.
- [ ] Search result pages can successfully be iterated up and down for all search entities.
- [ ] Search result entities can be liked/disliked successfully.
- [ ] Search result songs can be played successfully (if stream found).
- [ ] If song stream found, can be opened in youtube successfully.
- [ ] Song results can be queued, played, shuffled, and sorted successfully.
- [ ] A Song result can be liked, added to playlist, added to queue, and added to offline successfully.
- [ ] A Song result can be disliked, removed from playlist, removed from queue, and removed from offline successfully.
- [ ] Double tapping a song likes/dislikes a song.

## Library page

Complete or verify all features on Library Page.

- [ ] Add a custom playlist using YouTube link.
- [ ] Add a local custom playlist.
- [ ] Confirm liked playlist from home page shows under liked playlists.
- [ ] Search for playlist in library and clear searched filter.
- [ ] Remove liked playlist.
- [ ] Remove added playlist.
- [ ] Remove local playlist.
- [ ] Navigate to each library page- Recently Played, Liked Songs, Liked Artists, Liked Albums, and Offline Songs.

## Recently Played page

Complete or verify all features on Recently Played Page.

- [ ] Confirm recently played songs show in the list

## Liked Songs page

Complete or verify all features on Liked Songs Page.

- [ ] Confirm liked songs show in the list.
- [ ] Confirm the list can be rearranged.

## Liked Artists page

Complete or verify all features on Liked Artists Page.

- [ ] Confirm liked Artists show in the list.
- [ ] Confirm genres for liked artists show in the list.
- [ ] Confirm searching for genre filters genre list.
- [ ] Confirm searching for artist filters artist list.
- [ ] Confirm clicking on genre filters artist list.
- [ ] Confirm clearing filter clears both genres and artist filters.
- [ ] Confirm genre list can be sorted.

## Liked Albums page

Complete or verify all features on Liked Albums Page.

- [ ] Confirm liked Albums show in the list.
- [ ] Confirm genres for liked albums show in the list.
- [ ] Confirm searching for genre filters genre list.
- [ ] Confirm searching for albums filters albums list.
- [ ] Confirm clicking on genre filters albums list.
- [ ] Confirm clearing filter clears both genres and albums filters.
- [ ] Confirm genre list can be sorted.

## Offline Songs page

Complete or verify all features on Offline Songs Page.

- [ ] Confirm offline songs show in the list.

## Song Queue page

Complete or verify all features on Song Queue Page.

- [ ] Confirm queued songs show in the list.
- [ ] Confirm queued songs can be added to existing playlist.
- [ ] Confirm queued songs can be saved as new playlist.
- [ ] Confirm queued songs can be rearranged by dragging and dropping.
- [ ] Confirm queued songs can be sorted, shuffled, and played.
- [ ] Confirm queued songs can be cleared.

## Mini-player

Complete or verify all features on Mini-player.

- [ ] Confirm volume changes work.
- [ ] Confirm song playback slider works.
- [ ] Confirm song playback controls work:- play, pause, stop, next, previous.
- [ ] Confirm tapping on like button likes the song.
- [ ] Confirm closing mini-player works.
- [ ] Confirm tapping on mini-player artist name open artist page.
- [ ] Confirm tapping on mini-player blank space or song name opens Now Playing page.

## Now Playing Page

Complete or verify all features on Now Playing Page.

- [ ] Confirm now playing page shows artwork, controls, and queue (if on large screen mode).
- [ ] Confirm tapping on artwork shows lyrics (if available for song).
- [ ] Confirm tapping on artist name opens artist page.
- [ ] Confirm song controls work.
- [ ] Confirm tapping on like button likes the song.

## Settings Page

Complete or verify all features on Settings Page.

- [ ] Confirm Accent Color changes work.
- [ ] Confirm Theme Mode changes work.
- [ ] Confirm Client changes work.
- [ ] Confirm Language changes work.
- [ ] Confirm Audio Quality changes work.
- [ ] Confirm Dynamic Accent Color changes work.
- [ ] Confirm Pure black theme changes work.
- [ ] Confirm Predictive Black changes work.
- [ ] Confirm Offline Mode changes work.
- [ ] Confirm Skip Sponsor Segment changes work.
- [ ] Confirm Skip non-music segment changes work.
- [ ] Confirm prepare next song works.
- [ ] Confirm proxy servers works.
- [ ] Confirm Clear Cache works.
- [ ] Confirm Clear Search History works.
- [ ] Confirm Clear Recently Played works.
- [ ] Confirm Backup user data works.
- [ ] Confirm Restore user data works.
- [ ] Confirm Sponsor the project works.
- [ ] Confirm Licenses works.
- [ ] Confirm Copy Log works.
- [ ] Confirm About works.

## Offline Mode

Complete or verify all features in Offline Mode Works.

- [ ] Toggle offline mode to ON on settings page and confirm the app does not close when cancelling the change.
- [ ] Confirm app closes when confirming offline mode ON.
- [ ] Restart app and confirm only Offline Songs, Queue, and Settings pages show. (Home should be the same as Offline songs).
- [ ] Confirm offline songs are showed correctly in Offline Songs list.
- [ ] Confirm offline songs play correctly.
- [ ] Toggle offline mode to OFF on settings page and confirm the app does not close when cancelling the change.
- [ ] Confirm app closes when confirming offline mode OFF.
- [ ] Restart app and confirm it resumes normal Online mode.

## Plugins

Complete or verify all features for Plugins

- [ ] Verify plugins can be enables successfully
- [ ] Verify plugin bottom sheet opens when plugins are enabled
- [ ] Verify a plugin can be added (use template plugin under /app_plugins/src/template.js)
- [ ] Verify plugin can be reloaded individually and in batch
- [ ] Verify plugin can be deleted
- [ ] Verify plugin settings page opens when tapping on individual plugin under plugin list
- [ ] Verify all plugin settings widgets load correctly with default values as defined in template.js manifest
- [ ] Verify each setting can be changed, reverted, reset to default and saved.
- [ ] Verify all button actions product log entries and function correctly on the settings page
- [ ] Verify background jobs generated by action buttons are added to background job list, complete, queue, and can be cancelled or deleted correctly.
- [ ] Verify plugin generates log entries for Artist, Song, Album, and Playlist entities when each of these entities are loaded or navigated to.
- [ ] Verify plugin buttons load and generate log entries when tapped in the following areas:
  - [ ] Song list
  - [ ] Song bar menu
  - [ ] Liked artists header
  - [ ] Liked albums header
  - [ ] Artist header
  - [ ] Album header
  - [ ] Playlist header