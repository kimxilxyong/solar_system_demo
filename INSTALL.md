# Solar System Demo - Installation and Running

## Requirements

- **Godot Engine 4.4.1 or higher** (The voxel plugin requires minimum compatibility with Godot 4.4.1)
- **Linux**: libstdc++ with GLIBCXX_3.4.32 support

## libstdc++ Fix (Linux only)

On Linux systems where Godot reports libstdc++ version errors, use the following workaround:

```bash
# Find a libstdc++ with GLIBCXX_3.4.32 support
# Typically found at /usr/lib/libstdc++.so.6.0.36 or similar

# Run Godot with LD_PRELOAD
LD_PRELOAD=/usr/lib/libstdc++.so.6.0.36 godot

# Or use the provided run script
./run.sh
```

## Quick Start

### First Time Setup

1. **Open the project in Godot Editor**:
   ```bash
   # With libstdc++ fix (Linux)
   LD_PRELOAD=/usr/lib/libstdc++.so.6.0.36 godot -e --path /path/to/solar_system_demo
   
   # Without fix (Windows/macOS)
   godot -e --path /path/to/solar_system_demo
   ```

2. **Wait for resources to import**: The first run will import all resources and create `.import` files in the `.godot/` directory. This may take a minute.

3. **The project should now be ready** to run or export.

### Running the Game

Once resources are imported, you can:

- **Run in editor**: Click the Play button in Godot
- **Export**: Use the Export menu to create an executable
- **Use the run script** (Linux):
  ```bash
  ./run.sh
  ```

## Configuration Changes

This project has been updated to support the voxel plugin as a GDExtension:

- `project.godot`: Updated to enable voxel GDExtension
- `addons/zylann.voxel/`: Added voxel plugin with binaries for all platforms

## Troubleshooting

### "Could not find type VoxelLodTerrain" or similar

This error occurs when:
1. The voxel GDExtension is not loaded
2. Running in headless mode (--check-project, --server)

**Solution**: Open the project in Godot Editor first to load the GDExtension.

### Missing .import files

If you see errors about missing `.godot/imported/` files:
- Open the project in Godot Editor
- Let it complete the resource import process
- The files will be created automatically

### Font loading errors

If you see errors about Hack-Regular.ttf:
- This has been fixed by creating a FontFile resource
- If you still see errors, run Godot Editor to regenerate .import files

## Project Structure

- `project.godot`: Main project configuration
- `addons/zylann.voxel/`: Voxel plugin (GDExtension)
- `addons/zylann.atmosphere/`: Atmosphere rendering plugin
- `addons/zylann.debug_draw/`: Debug drawing utilities
- `solar_system/`: Main game logic
- `ship/`: Player ship
- `character/`: Player character

## Known Issues

1. **First run takes time**: The project needs to import ~200+ resources
2. **GDExtension in headless mode**: Voxel plugin classes may not be available in --check-project mode
3. **libstdc++ compatibility**: On Linux, you may need LD_PRELOAD workaround

## Commands

```bash
# Linux with libstdc++ fix
LD_PRELOAD=/usr/lib/libstdc++.so.6.0.36 godot -e --path .

# Run the game directly
LD_PRELOAD=/usr/lib/libstdc++.so.6.0.36 godot main.tscn

# Test compilation (after importing resources)
LD_PRELOAD=/usr/lib/libstdc++.so.6.0.36 godot --check-project --path .
```
