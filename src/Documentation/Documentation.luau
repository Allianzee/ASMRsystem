--[[
ASMR SYSTEM SETUP & CONFIGURATION GUIDE (MADE BY ALLIEEEEEEE)
================================================================================
Open this script to see how to name models, add sounds, and configure the system.
]]

local Documentation = {}

Documentation.SystemGuide = {
["1_SOUNDS"] = {
Location = "ReplicatedStorage -> ASMRSounds",
Description = "Drop your Sound instances here. The system matches sounds automatically.",
NamingFormat = "[Category][Action]",
Examples = {
"SlimeEnter  -- Plays when stepping onto Slime",
"SlimeExit   -- Plays when stepping off Slime",
"SlimeStep   -- Plays periodically while walking on Slime",
"TabaEnter   -- Plays on stepping onto TabaPaw",
"Key         -- Base sound name for keyboard key presses",
}
},

["2_MODELS_DEFORMABLES"] = {
Description = "Squishy materials (Slime, NeeDoh, Cheese, Foamball, WaterDroplet, Brainrot).",
Detection = "Include the type in the Model name (e.g., 'Slime_Platform', 'CheeseBlock')",
RequiredParts = {
Surface = "The visual part/mesh. If it has Bones inside, skinning runs automatically.",
Collision = "(Optional) Transparent flat part to act as a solid floor.",
}
},

["3_MODELS_CRACKABLES"] = {
Description = "Cracking/squishing materials (TabaPaw, Dumpling, Pudding, Butter).",
Detection = "Include the type in the Model name (e.g., 'TabaPawModel', 'Dumpling1')",
RequiredParts = {
Surface = "The main frame/shell part.",
Collision = "(Optional) Transparent flat base part.",
Cracks = "Any part inside the model with 'Crack' in its name (e.g., Crack1, Crack2) tilts & slides dynamically.",
}
},

["4_KEYBOARDS"] = {
Location = "Workspace -> Keyboards",
Setup = "Create theme folders inside (Ocean, Candy, Chocolate, Blue, Sunset). Put your key BaseParts inside those folders.",
AutoFeatures = "Letters and press/release animations are generated automatically.",
},

["5_CONFIG_REFERENCE"] = {
["DentDepth"] = "Maximum depth bones deform downward when stepped on",
["DentRadius"] = "Radius of effect around the player's feet",
["DentPressSpeed"] = "How fast it presses down",
["DentReleaseSpeed"] = "How fast it springs back up",
["DentOvershoot"] = "Bounciness factor (spring dampening)",
["MeshDentDepth"] = "Squish depth for static meshes without bones",
["WalkSpeed"] = "Walkspeed applied while the player is on this surface",
["Volume"] = "Volume of the sound effects"
}
}

return Documentation
