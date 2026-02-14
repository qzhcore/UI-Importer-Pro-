# UI-Importer-Pro-

[![CI](https://github.com/your-username/ui-importer-pro/actions/workflows/ci.yml/badge.svg)](https://github.com/your-username/ui-importer-pro/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Wally](https://img.shields.io/badge/Wally-v0.3.1-blue)](https://wally.run/)

**UI Importer Pro** is a professional-grade Roblox Studio plugin designed to bridge the gap between static UI imports and responsive, and production-ready interfaces. UI Importer Pro automates the tedious process of manual scaling, sontraint mangement, and hierarchy cleanup.

# Architecture Overview
Built with a **Modular Singleton** pattern, the codebase is strictly decoupled to ensure the core scaling logic remains independent of the Studio environment.

### Directory Structure
- **`src/Logic/`**: Pure mathematical engines for spatial conversion.
- **`src/Plugin/`**: Management of Studio-side signals, toolbars, and history waypoints.
- **`src/Shared/`**: Centralized source of truth for constants, type definitions, and configurations.
- **`src/Components/`**: Declarative UI elements for the plugin interface.

## Technical Specifications
### Responsive Engine
The engine utilizes a recursive traversal algorithm to convert absolute pixel offsets into relative scalar values. Unlike basic scripts, UI Importer Pro calculates the **Global Displacement Ratio** relative to the nearest `GuiAncestor`.

**Mathematical Core:**
- **Scaling**: $Scale = \frac{AbsoluteSize_{child}}{AbsoluteSize_{parent}}$
- **Constraints**: Auto-calculates $AspectRatio = \frac{W}{H}$ and applies `UIAspectRatioConstraint` to prevent stretching across non-native aspect ratios.

### Toolchain Integration
This project requires **Aftman** for toolchain versioning. 
- **Rojo**: For filesystem-to-Studio synchronization.

## Installation & Setup

### For Developers
1. Clone the repoistory
```bash
   git clone [https://github.com/qzhcore/ui-importer-pro.git](https://github.com/username/ui-importer-pro.git) 

2. Install the toolchain:
 aftman install

 3. Initialize dependencies:
 wally install

 4. Build the plugin binary:
 rojo build -o "UIImporter.rbxm"

 # API Reference
 ScalingEngine.Process(root: Instance): ()
Recursively processes a UI tree. It identifies GuiObjects, converts their dimensions to Scale, and injects appropriate UIAspectRatioConstraints while maintaining visual parity with the source.

FileParser.Identify(selection: {Instance}): {GuiObject}
Filters a generic Studio selection to isolate valid UI candidates for processing, preventing accidental modification of non-UI instances.

# Contributions
🛠️ Contributing
We maintain strict coding standards to ensure long-term maintainability:

- Typing: All modules must utilize --!strict Luau typing.
- Formatting: Run stylua . before committing.
- Linting: Ensure selene src returns no warnings.
