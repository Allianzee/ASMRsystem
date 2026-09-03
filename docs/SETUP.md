# Setup

## 1. Server Script

Place `ASMRServer.luau` inside:

```text
ServerScriptService
```

The server script automatically creates the `ASMRSounds` folder if it does not already exist.

## 2. Client Script

Place `ASMRClient.luau` inside:

```text
StarterPlayer
└── StarterPlayerScripts
```

## 3. Documentation

`Documentation.luau` is the setup and configuration reference for the system.

It can be kept as a ModuleScript alongside the system.

# Sounds

Create:

```text
ReplicatedStorage
└── ASMRSounds
```

Add your Sound instances there.

The system detects sounds by their names.

### Example

```text
ASMRSounds
├── SlimeEnter
├── SlimeExit
├── SlimeStep
├── NeeDohEnter
├── NeeDohExit
├── NeeDohStep
├── TabaEnter
├── TabaExit
├── TabaStep
└── Key
```

The naming format is:

```text
[Category][Action]
```

# Deformable Models

Supported deformable types:

```text
Slime
NeeDoh
Foamball
Cheese
WaterDroplet
BrainrotSquishy
```

The type is detected from the model name.

Examples:

```text
Slime_Platform
NeeDohBlock
Foamball1
CheeseBlock
WaterDroplet
BrainrotSquishy
```

A model should contain a `Surface` part when possible.

Example:

```text
Slime_Platform
├── Surface
└── Collision
```

`Collision` is optional.

If the `Surface` contains Bones, the system automatically uses bone deformation.

# Crackable Models

Supported crackable types:

```text
TabaPaw
Dumpling
Pudding
Butter
```

Example:

```text
Dumpling1
├── Surface
├── Collision
├── Crack1
├── Crack2
└── Crack3
```

Any BasePart containing `Crack` in its name is automatically detected as a crack.

# Keyboards

Create:

```text
Workspace
└── Keyboards
```

Inside it, create theme folders:

```text
Keyboards
├── Ocean
├── Candy
├── Chocolate
├── Blue
└── Sunset
```

Put the keyboard key BaseParts inside the folders.

The server automatically gives them:

```text
ASMRType = KeyboardKey
ASMRTheme = [Theme Name]
```

The client then handles the visual and interaction behavior.

# Configuration

Each object type has its own configuration in `ASMRClient.luau`.

Example:

```lua
DentDepth = 2.8
DentRadius = 18
DentPressSpeed = 6
DentReleaseSpeed = 1.5
DentOvershoot = 0.6
WalkSpeed = 7
Volume = 1.6
```

Changing these values changes how the object feels and behaves.

# Requirements

- Roblox Studio
- Roblox place
- BaseParts/MeshParts for supported objects
- Optional Roblox Bones for advanced deformation
- Sound instances for custom ASMR audio
