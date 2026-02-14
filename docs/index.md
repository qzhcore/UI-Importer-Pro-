# UI Importer Pro Documentation

Welcome to the technical documentation for UI Importer Pro.

## Quick Start
1. Select your imported UI in the Explorer.
2. Click the **Fix & Scale** button in the toolbar.
3. The plugin will recursively convert all Offsets to Scale and apply AspectRatio constraints.

## Architecture
The system uses a modular Luau stack:
- **Logic**: Scaling algorithms
- **Plugin**: Studio API integration
- **Shared**: Configuration constants
