# Mekalingus Server

The Mekalingus Server is a headless Godot project responsible for all core
gameplay logic in the Mekalingus universe. It handles game rules, simulation
of turns, AI decision-making, and state management independently from the
client.

Although built using Godot, it runs without rendering, designed to be
executed in server/headless mode.

## Features

- Turn-based combat engine
- AI decision logic for enemy units
- Execution of modules, effects, and cooldowns
- Mek and item balancing tools
- Profile and save file handling
- Full separation from rendering or UI concerns

## Requirements

- Godot Engine 4.x
- No additional dependencies

## Running the Server

Simply open the project in Godot and start it like any other scene
(if debugging locally).

The main scene is `scenes/ui/server_gui.tscn`.

## Folder Structure

- `addons/`: Godot addons files
- `data/`: JSON files with details of Meks and Items
- `assets/`: Placeholder assets and tilemaps
- `scenes/`: Godot scene files
- `scripts/`: Core gameplay and UI logic
- `themse/`: Themes related file

## Communication with Client

The server is designed to operate independently, but can be extended to
communicate with a front-end client over a network or via shared save files.

## Contributing

Pull requests are welcome! If you'd like to contribute:

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Make your changes, ensuring your code is clean and well-commented.
4. Submit a pull request with a clear description of what you’ve changed and why.

Please try to keep changes focused and avoid mixing unrelated fixes in
a single PR.

## License
This project is licensed under the MIT License. See `LICENSE.md` for
more information.
