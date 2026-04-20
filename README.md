# Notes Plugin (Godot 4.5)

A simple docked notes plugin for Godot that helps you keep project notes, todos, ideas, and context directly inside the editor.

## Features

- Docked notes editor inside Godot
- Slide-in file panel for quick note switching
- Create notes from the panel
- Delete notes with confirmation
- Delete current note from the main toolbar
- Auto-save while typing
- Auto-close file panel when opening or creating a note
- Close file panel with:
  - `Close` button
  - `Esc`
  - clicking outside the panel
- `Welcome.txt` opens by default when present
- Notes shown in creation order (newest at the bottom)
- Filesystem rescans after create/delete so changes appear in Godot’s FileSystem dock

## Folder Structure

Notes are stored here:

`res://addons/Notes/files/`

The plugin also keeps an internal ordering file:

`res://addons/Notes/files/.notes_order`

## Installation

1. Copy this plugin into your project at:

   `res://addons/Notes/`

2. In Godot, open:

   `Project > Project Settings > Plugins`

3. Enable the **Notes** plugin.

## Usage

1. Open the docked **Notes** panel.
2. Use **Files** to open the side panel.
3. Click a note name to open it.
4. Type in the editor area to auto-save changes.
5. Create a new note from the input at the bottom of the side panel.
6. Delete notes with the red `x` buttons (confirmation required).

## Starter Notes

The plugin can include starter files like:

- `Welcome.txt`
- `Notes.txt`
- `Todo.txt`
- `Ideas.txt`

If `Welcome.txt` exists, it is opened first on startup.

## Known Notes

- This plugin is designed for Godot 4 (`@tool` scripts).
- If the editor caches older script state after updates, disable/re-enable the plugin once.

## License

MIT (or your preferred license).
