# ASMR Squishy System

A Roblox ASMR interaction system built for squishy and interactive objects.

The system handles deformation, sounds, crack animations, keyboard interactions, collision handling, and automatic object detection.

## Features

- Bone-based deformation
- Mesh deformation for objects without bones
- Multiple squish types
- Sphere and axis-based squishing
- Crackable object animations
- Dynamic ASMR sound system
- Sound pooling
- Sound variation with pitch and volume jitter
- Distance-based object culling
- Automatic model detection
- Runtime object detection
- Keyboard system with multiple themes
- Keyboard press/release animations
- Dynamic keyboard letters
- NoCollisionConstraint handling
- Configurable movement speed
- Tween-based animations
- Configurable deformation settings

## Supported Objects

### Deformable

- Slime
- NeeDoh
- Foamball
- Cheese
- WaterDroplet
- BrainrotSquishy

### Crackable

- TabaPaw
- Dumpling
- Pudding
- Butter

### Keyboard Themes

- Ocean
- Candy
- Chocolate
- Blue
- Sunset

## How It Works

The server automatically detects supported models based on their names and assigns an `ASMRType` attribute.

The client registers handlers for each supported type.

When the player steps onto an object, the system:

1. Detects the player's position.
2. Determines whether they are standing on the object.
3. Applies the appropriate deformation.
4. Plays the corresponding sound.
5. Handles collision behavior.
6. Updates the object's state while the player moves.
7. Restores the object when the player leaves.

Objects can use either Roblox Bones or regular BaseParts/Meshes for deformation.

## Sound System

Sounds are stored in:

```text
ReplicatedStorage
└── ASMRSounds
```

The system automatically finds sounds based on their names.

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

Examples:

```text
SlimeEnter
SlimeExit
SlimeStep
```

The sound system includes:

- Sound pooling
- Maximum concurrent sounds
- Random pitch variation
- Random volume variation
- 3D rolloff
- Automatic cleanup
- Sound fallback IDs

## Model Setup

A supported model can contain:

```text
Model
├── Surface
├── Collision
└── Crack1
```

### Surface

`Surface` is the main visual part of the object.

If the Surface contains Roblox Bones, the system automatically uses bone deformation.

### Collision

`Collision` is optional.

It can be used as the physical floor while the visual object is deformed separately.

### Cracks

For crackable objects, any BasePart containing `Crack` in its name is automatically treated as a crack.

Example:

```text
TabaPawModel
├── Surface
├── Collision
├── Crack1
├── Crack2
└── Crack3
```

## Keyboard Setup

Create:

```text
Workspace
└── Keyboards
```

Inside `Keyboards`, create your theme folders:

```text
Keyboards
├── Ocean
├── Candy
├── Chocolate
├── Blue
└── Sunset
```

Put the keyboard key BaseParts inside their corresponding theme folder.

The server automatically assigns:

```text
ASMRType = KeyboardKey
ASMRTheme = ThemeName
```

The client then handles:

- Key colors
- Random letters
- Key press detection
- Key release detection
- Press animations
- Release animations
- Keyboard sounds

## Deformation

The system supports two main deformation methods.

### Bone Deformation

If an object contains Bones, the system uses the Bones to create localized dents around the player's feet.

This allows different areas of the object to deform depending on where the player is standing.

### Mesh Deformation

Objects without Bones can still deform.

The system modifies:

- Part Size
- Mesh Scale
- Position
- CFrame

Supported styles include:

- Normal squish
- Sphere squish
- Axis-based squish

## Configuration

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

Available settings include:

```text
DentDepth
DentRadius
DentPressSpeed
DentReleaseSpeed
DentOvershoot
DentFalloff
MeshDentDepth
SinkSpeed
RiseSpeed
WalkSpeed
Volume
VolumeJitter
Pitch
PitchJitter
StepGap
StepSpeedMin
```

Crackable objects also support:

```text
SquishYDrop
BaseOutward
BaseTilt
SquishSizeXZ
SquishSizeY
FootBonus
FootRadius
FootTiltBonus
```

This allows each object type to have its own behavior.

## Collision Handling

The system automatically manages collisions while the player interacts with an object.

`NoCollisionConstraint` objects are created when necessary so the player's character does not interfere with visual parts while maintaining the required collision behavior.

Collision states are also reset when the player leaves the object.

## Performance

The system uses distance culling to avoid processing objects outside the configured interaction range.

The default culling distance is:

```lua
local cullDistance = 120
```

The sound system also limits simultaneous sounds and reuses Sound instances through a pool.

## Runtime Detection

Objects can be added to Workspace while the game is running.

The server watches for new descendants and automatically checks whether they match a supported ASMR type.

This allows supported objects to be added dynamically without manually registering every object.

## Project Structure

```text
ASMR-Squishy-System/
├── README.md
├── .gitignore
│
├── src/
│   ├── Client/
│   │   └── ASMRClient.luau
│   │
│   ├── Server/
│   │   └── ASMRServer.luau
│   │
│   └── Documentation/
│       └── Documentation.luau
│
├── docs/
│   └── SETUP.md
│
└── showcase/
    └── README.md
```

## Requirements

- Roblox Studio
- A Roblox place
- BaseParts or MeshParts for supported objects
- Optional Roblox Bones for advanced deformation
- Sound instances for custom ASMR audio

## Setup

See [`docs/SETUP.md`](docs/SETUP.md) for the complete setup guide.

## Showcase

See the `showcase` folder for demonstration media.

## Author

Created by Allie.
