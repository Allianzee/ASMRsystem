local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local soundsFolder = ReplicatedStorage:FindFirstChild("ASMRSounds")
if not soundsFolder then
	soundsFolder = Instance.new("Folder")
	soundsFolder.Name = "ASMRSounds"
	soundsFolder.Parent = ReplicatedStorage
end

local smoothPhysics = PhysicalProperties.new(0.7, 0.4, 0.0, 1.0, 100.0)

local function tagKeyboardKey(part, folderName)
	if not part:IsA("BasePart") or part:GetAttribute("ASMRType") then return end

	part:SetAttribute("ASMRType", "KeyboardKey")
	part:SetAttribute("ASMRTheme", folderName)
	part.CustomPhysicalProperties = smoothPhysics
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
end

local function cleanModelCollisions(model)
	local collisionPart = model:FindFirstChild("Collision", true)
	local surface = model:FindFirstChild("Surface", true)

	if not surface then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart")
				and d ~= collisionPart
				and not d.Name:lower():find("hitbox")
				and not d.Name:lower():find("trigger")
				and not d.Name:lower():find("crack") then
				surface = d
				break
			end
		end
	end

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CustomPhysicalProperties = smoothPhysics
			d.Anchored = true

			local n = d.Name:lower()
			if d == surface or d == collisionPart then
				d.CanCollide = true
				d.CanTouch = true
				d.CanQuery = true
			elseif n:find("crack") then
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			elseif n:find("hitbox") or n:find("trigger") then
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = true
			else
				d.CanCollide = false
			end
		end
	end
end

local function tagModel(model)
	if not model:IsA("Model") or model:GetAttribute("ASMRType") then return end
	local nameL = model.Name:lower()

	if nameL:find("slime") then
		model:SetAttribute("ASMRType", "Slime")
		cleanModelCollisions(model)
	elseif nameL:find("needoh") or nameL:find("squish") then
		model:SetAttribute("ASMRType", "NeeDoh")
		cleanModelCollisions(model)
	elseif nameL:find("brainrot") then
		model:SetAttribute("ASMRType", "BrainrotSquishy")
		cleanModelCollisions(model)
	elseif nameL:find("foamball") or nameL:find("foam") then
		model:SetAttribute("ASMRType", "Foamball")
		cleanModelCollisions(model)
	elseif nameL:find("cheese") then
		model:SetAttribute("ASMRType", "Cheese")
		cleanModelCollisions(model)
	elseif nameL:find("waterdroplet") or nameL:find("water_droplet") or nameL:find("water droplet") or nameL:find("droplet") then
		model:SetAttribute("ASMRType", "WaterDroplet")
		cleanModelCollisions(model)
	elseif nameL:find("taba") or nameL:find("paw") or nameL:find("wax") then
		model:SetAttribute("ASMRType", "TabaPaw")
		cleanModelCollisions(model)
	elseif nameL:find("dumpling") then
		model:SetAttribute("ASMRType", "Dumpling")
		cleanModelCollisions(model)
	elseif nameL:find("pudding") then
		model:SetAttribute("ASMRType", "Pudding")
		cleanModelCollisions(model)
	elseif nameL:find("butter") then
		model:SetAttribute("ASMRType", "Butter")
		cleanModelCollisions(model)
	end
end

local keyboardsFolder = Workspace:FindFirstChild("Keyboards")
if keyboardsFolder then
	for _, folder in ipairs(keyboardsFolder:GetChildren()) do
		if folder:IsA("Folder") then
			for _, desc in ipairs(folder:GetDescendants()) do
				tagKeyboardKey(desc, folder.Name)
			end

			folder.DescendantAdded:Connect(function(desc)
				task.wait(0.05)
				tagKeyboardKey(desc, folder.Name)
			end)
		end
	end
end

for _, d in ipairs(Workspace:GetDescendants()) do
	tagModel(d)
end

Workspace.DescendantAdded:Connect(function(d)
	task.wait(0.1)
	tagModel(d)
end)
