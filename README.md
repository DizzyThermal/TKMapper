# TKMapper

NexusTK Map Creator/Editor written in [Godot](https://godotengine.org/) 4.x

![TKMapper](./tkmapper.png)

## Setup

* Install NexusTK

* Import the `project.godot` file in Godot 4.x and Run the
application (F5) - the main scene is: `Apps/TKMapper.tscn`

* If you don't have NexusTK in a predictable location, the program
won't start (see next step)

* `config.json.template` is copied to `config.json` (if
`config.json` does not exist) - Fill out this config to point to
your system's NexusTK directories

* Re-run the application (F5) and TKMapper should hopefully launch

## Usage

* Insert / Delete Keyboard Shortcuts (`i` and `d`):
    * [I]nsert: This allows you to insert tiles/objects
    * [D]elete: This allows you to delete tiles/objects

* The 3 modes are:
    * Tile Mode: Edits the ground tiles
    * Object Mode: Edits the objects
    * Unpassable Mode: Edits the unpassable tiles

### Keyboard Shortcuts

* `s`: Save Map: Opens Save Map Dialog
* `l`: Load Map: Opens Load Map Dialog

* Mode Switching:
    * `d`: Delete Mode: Allows deleting tiles/objects
    * `i`: Insert Mode: Allows inserting tiles/objects

* Mode Type Switching
    * `m`: Toggle Modes: Toggles between modes: Tile -> Object -> Unpassable
    * `t`: Tile Mode: Toggles Tile Mode
    * `o`: Object Mode: Toggles Object Mode
    * `p`: Unpassable Mode: Toggles Unpassable Mode

* Other:
    * `h`: Hide Objects: Toggles Objects (for ground visibility)

### Mouse Shortcuts

* `Scroll Wheel`: Zoom Map
* `CTRL + Left Mouse Button`: Drag/move map

#### Mode Specific Mouse Shortcuts

* Insert Mode (Over Map):
    * `Left Mouse Button`: Inserts/places the currently selected tile or object
    (hovering near mouse)
    * `Right Mouse Button`: Copies the tile or object under the mouse cursor as
    the currently selected tile or object

* Insert Mode (Over Tile/Object Selection):
    * `Left Mouse Button`: Copies the tile or object under the mouse cursor as the
    currently selected tile or object

* Delete Mode (Over Map):
    * `Left Mouse Button`: Deletes the tile or object under the mouse cursor
