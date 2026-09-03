local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local SoundFolderName = "ASMRSounds"
local cullDistance = 120
local rng = Random.new()

local soundList, liveCount, pool = {}, {}, {}

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild(SoundFolderName, 10)
	if not folder then return end

	local function add(s)
		if s:IsA("Sound") and s.SoundId ~= "" then
			table.insert(soundList, s)
		end
	end

	for _, s in ipairs(folder:GetChildren()) do
		add(s)
	end

	folder.ChildAdded:Connect(add)
end)

local function withPrefix(prefix)
	local out = {}

	for _, s in ipairs(soundList) do
		if string.sub(s.Name, 1, #prefix) == prefix then
			table.insert(out, s)
		end
	end

	return out
end

local function PlaySound(category, parent, cfg, subset)
	if not parent or not parent.Parent then return end

	local n = liveCount[category] or 0
	if n >= (cfg.MaxConcurrent or 6) then return end

	local candidates = {}

	if #soundList > 0 then
		if subset then
			candidates = withPrefix(category .. subset)

			if #candidates == 0 then
				candidates = withPrefix(category)
			end
		else
			candidates = withPrefix(category)
		end
	end

	local fallbackId = "rbxasset://sounds/splat.wav"
	local cl = category:lower()

	if cl:find("crack")
		or cl:find("wax")
		or cl:find("taba")
		or cl:find("dumpling")
		or cl:find("pudding")
		or cl:find("butter") then

		fallbackId = "rbxasset://sounds/snap.wav"

	elseif cl:find("key") then
		fallbackId = "rbxasset://sounds/button.wav"
	end

	local snd = table.remove(pool) or Instance.new("Sound")

	snd.Name = "ASMRSound"

	snd.SoundId =
		(#candidates > 0)
		and candidates[rng:NextInteger(1, #candidates)].SoundId
		or fallbackId

	snd.Volume = math.max(
		0,
		(cfg.Volume or 1)
			+ rng:NextNumber(
				-(cfg.VolumeJitter or 0),
				cfg.VolumeJitter or 0
			)
	)

	snd.PlaybackSpeed = math.max(
		0.1,
		(cfg.Pitch or 1)
			+ rng:NextNumber(
				-(cfg.PitchJitter or 0),
				cfg.PitchJitter or 0
			)
	)

	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = cfg.RollOffMin or 8
	snd.RollOffMaxDistance = cfg.RollOffMax or 50
	snd.Parent = parent

	liveCount[category] = n + 1

	local done, conn = false, nil

	local function cleanup()
		if done then return end

		done = true

		if conn then
			conn:Disconnect()
		end

		liveCount[category] =
			math.max(0, (liveCount[category] or 1) - 1)

		snd:Stop()
		snd.SoundId = ""
		snd.Parent = nil

		if #pool < 48 then
			table.insert(pool, snd)
		else
			snd:Destroy()
		end
	end

	conn = snd.Ended:Connect(cleanup)

	snd:Play()

	task.delay(6, cleanup)
end

local character, humanoid
local contactParts = {}

local defaultWalkSpeed = 16
local isSteppingOnASMR = false
local currentSpeedTarget = 16
local lastAppliedSpeed = nil

local function setSpeed(speed)
	if humanoid and lastAppliedSpeed ~= speed then
		lastAppliedSpeed = speed
		humanoid.WalkSpeed = speed
	end
end

local function getLowestFootPosition(char)
	local lowestY, lowestPos = math.huge, nil

	for _, p in ipairs(contactParts) do
		if p and p.Parent then
			local y = p.Position.Y - p.Size.Y / 2

			if y < lowestY then
				lowestY = y
				lowestPos = Vector3.new(
					p.Position.X,
					y,
					p.Position.Z
				)
			end
		end
	end

	if lowestPos then
		return lowestPos
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")

	if hrp then
		return hrp.Position
			- Vector3.new(
				0,
				(humanoid and humanoid.HipHeight or 2) + 1.5,
				0
			)
	end

	return Vector3.zero
end

local function bind(char)
	character, humanoid = char, nil

	table.clear(contactParts)

	lastAppliedSpeed = nil

	for _, c in ipairs(char:GetDescendants()) do
		if c:IsA("BasePart") then
			table.insert(contactParts, c)
		end
	end

	char.DescendantAdded:Connect(function(c)
		if character == char and c:IsA("BasePart") then
			table.insert(contactParts, c)
		end
	end)

	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)

		if character ~= char or not hum then return end

		humanoid = hum

		defaultWalkSpeed =
			hum.WalkSpeed > 0
			and hum.WalkSpeed
			or 16

		hum:SetStateEnabled(
			Enum.HumanoidStateType.Ragdoll,
			false
		)

		hum:SetStateEnabled(
			Enum.HumanoidStateType.FallingDown,
			false
		)

		hum:SetStateEnabled(
			Enum.HumanoidStateType.PlatformStanding,
			false
		)
	end)
end

local player = Players.LocalPlayer

if player.Character then
	bind(player.Character)
end

player.CharacterAdded:Connect(bind)

local handlers, objects, unclaimed = {}, {}, {}

local function consider(inst)
	if not inst:IsA("Model") then return end

	local t = inst:GetAttribute("ASMRType")

	if type(t) ~= "string" or objects[inst] then
		return
	end

	local h = handlers[t]

	if not h then
		unclaimed[inst] = t
		return
	end

	unclaimed[inst] = nil

	objects[inst] = {
		Model = inst,
		Type = t,
		Handler = h,
		State = {},
		Resolved = false,
		Active = false,
		Occupied = false,
		NextResolve = 0,
		ResolveDeadline = os.clock() + 15,
		Warned = false,
	}
end

for _, d in ipairs(Workspace:GetDescendants()) do
	consider(d)
end

Workspace.DescendantAdded:Connect(consider)

Workspace.DescendantRemoving:Connect(function(d)
	local obj = objects[d]

	if obj then
		if obj.Handler.Cleanup then
			obj.Handler.Cleanup(obj, humanoid)
		end

		objects[d] = nil
	end

	unclaimed[d] = nil
end)

local function RegisterHandler(handler)
	if handlers[handler.Type] then return end

	handlers[handler.Type] = handler

	for model, t in pairs(unclaimed) do
		if t == handler.Type then
			consider(model)
		end
	end
end

local function updateNoCollisionConstraints(s, enable)
	if not s.NoCollideParts or #s.NoCollideParts == 0 then
		return
	end

	if enable then
		if not s.Constraints then
			s.Constraints = {}

			for _, target in ipairs(s.NoCollideParts) do
				if target and target.Parent then
					for _, bodyPart in ipairs(contactParts) do
						if bodyPart and bodyPart.Parent then
							local c =
								Instance.new("NoCollisionConstraint")

							c.Part0 = bodyPart
							c.Part1 = target
							c.Parent = target

							table.insert(s.Constraints, c)
						end
					end
				end
			end
		end

		for _, c in ipairs(s.Constraints) do
			c.Enabled = true
		end
	else
		if s.Constraints then
			for _, c in ipairs(s.Constraints) do
				c.Enabled = false
			end
		end
	end
end

local function setupVisualNoCollide(s, surface, collisionPart)
	s.NoCollideParts = {}
	s.Constraints = nil

	local function add(p)
		if p and p.Parent and p ~= collisionPart then
			table.insert(s.NoCollideParts, p)
		end
	end

	add(surface)

	for _, m in ipairs(s.MeshStates or {}) do
		add(m.Part)
	end
end

local function isProtectedPart(part, surface, collisionPart)
	if not part or not part:IsA("BasePart") then
		return true
	end

	if part == collisionPart then
		return true
	end

	if part == surface then
		return false
	end

	local n = part.Name:lower()

	if n == "humanoidrootpart"
		or n == "head"
		or n == "torso"
		or n == "upper torso"
		or n == "lower torso"
		or n == "left arm"
		or n == "right arm"
		or n == "left leg"
		or n == "right leg"
		or n == "left hand"
		or n == "right hand"
		or n == "left foot"
		or n == "right foot"
		or n == "leftupperarm"
		or n == "rightupperarm"
		or n == "leftlowerarm"
		or n == "rightlowerarm"
		or n == "leftupperleg"
		or n == "rightupperleg"
		or n == "leftlowerleg"
		or n == "rightlowerleg" then

		return true
	end

	if n:find("rig")
		or n:find("dummy")
		or n:find("npc")
		or n:find("handle")
		or n:find("inner")
		or n:find("core")
		or n:find("brain")
		or n:find("prop") then

		return true
	end

	if part:FindFirstChildOfClass("Motor6D")
		or part:FindFirstAncestorOfClass("Humanoid") then

		return true
	end

	return false
end

local function applyMeshSquish(s, sinkAlpha)
	if s.HasBones
		or not s.MeshStates
		or not s.OrigSize
		or not s.OrigCFrame then

		return
	end

	local maxDeform = -(s.OrigSize.Y * 0.85)

	local currentDeform =
		math.clamp(
			sinkAlpha,
			maxDeform,
			0
		)

	local scaleY =
		math.clamp(
			(s.OrigSize.Y + currentDeform)
				/ math.max(0.001, s.OrigSize.Y),
			0.1,
			1.0
		)

	local widen = (1 - scaleY) * 0.45

	local restBottom =
		s.OrigCFrame.Position.Y
		- (s.OrigSize.Y * 0.5)

	local newH = s.OrigSize.Y * scaleY

	local newY =
		restBottom
		+ (newH * 0.5)

	local newSurfaceCF =
		(s.OrigCFrame - s.OrigCFrame.Position)
		+ Vector3.new(
			s.OrigCFrame.Position.X,
			newY,
			s.OrigCFrame.Position.Z
		)

	for _, mState in ipairs(s.MeshStates) do
		local part = mState.Part

		if part
			and part.Parent
			and part ~= s.CollisionPart then

			part.Size = Vector3.new(
				mState.OrigSize.X * (1 + widen),
				mState.OrigSize.Y * scaleY,
				mState.OrigSize.Z * (1 + widen)
			)

			if mState.SpecialMesh
				and mState.OrigMeshScale then

				mState.SpecialMesh.Scale = Vector3.new(
					mState.OrigMeshScale.X * (1 + widen),
					mState.OrigMeshScale.Y * scaleY,
					mState.OrigMeshScale.Z * (1 + widen)
				)
			end

			local localPos =
				mState.OrigLocalCF.Position

			local scaledLocalPos =
				Vector3.new(
					localPos.X * (1 + widen),
					localPos.Y * scaleY,
					localPos.Z * (1 + widen)
				)

			part.CFrame =
				newSurfaceCF
				* (
					(mState.OrigLocalCF - localPos)
					+ scaledLocalPos
				)

			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function applySphereSquish(s, sinkAlpha)
	if s.HasBones
		or not s.MeshStates
		or not s.OrigSize
		or not s.OrigCFrame then

		return
	end

	local flatten =
		math.clamp(
			-sinkAlpha,
			0,
			s.OrigSize.Y * 0.92
		)

	local scaleY =
		(s.OrigSize.Y - flatten)
		/ math.max(0.001, s.OrigSize.Y)

	local widen = (1 - scaleY) * 0.55

	local restBottom =
		s.OrigCFrame.Position.Y
		- s.OrigSize.Y * 0.5

	local newH =
		s.OrigSize.Y * scaleY

	local newCF =
		(s.OrigCFrame - s.OrigCFrame.Position)
		+ Vector3.new(
			s.OrigCFrame.Position.X,
			restBottom + newH * 0.5,
			s.OrigCFrame.Position.Z
		)

	for _, m in ipairs(s.MeshStates) do
		local part = m.Part

		if part
			and part.Parent
			and part ~= s.CollisionPart then

			part.Size = Vector3.new(
				m.OrigSize.X * (1 + widen),
				m.OrigSize.Y * scaleY,
				m.OrigSize.Z * (1 + widen)
			)

			if m.SpecialMesh
				and m.OrigMeshScale then

				m.SpecialMesh.Scale = Vector3.new(
					m.OrigMeshScale.X * (1 + widen),
					m.OrigMeshScale.Y * scaleY,
					m.OrigMeshScale.Z * (1 + widen)
				)
			end

			local localPos =
				m.OrigLocalCF.Position

			local scaledLocal =
				Vector3.new(
					localPos.X * (1 + widen),
					localPos.Y * scaleY,
					localPos.Z * (1 + widen)
				)

			part.CFrame =
				newCF
				* (
					(m.OrigLocalCF - localPos)
					+ scaledLocal
				)

			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function applyAxisSquish(s, sinkAlpha, axis)
	if s.HasBones
		or not s.MeshStates
		or not s.OrigSize
		or not s.OrigCFrame then

		return
	end

	axis = string.upper(axis or "Y")

	local ox, oy, oz =
		s.OrigSize.X,
		s.OrigSize.Y,
		s.OrigSize.Z

	local axisLen =
		(axis == "X" and ox)
		or (axis == "Z" and oz)
		or oy

	local flatten =
		math.clamp(
			-sinkAlpha,
			0,
			axisLen * 0.92
		)

	local scaleA =
		(axisLen - flatten)
		/ math.max(0.001, axisLen)

	local widen = (1 - scaleA) * 0.55

	local restCF = s.OrigCFrame

	local axisWorld =
		(axis == "X" and restCF.RightVector)
		or (axis == "Z" and restCF.LookVector)
		or restCF.UpVector

	if axisWorld:Dot(Vector3.yAxis) < 0 then
		axisWorld = -axisWorld
	end

	local lost =
		axisLen * (1 - scaleA)

	local centerShift =
		-axisWorld * (lost * 0.5)

	local newCF =
		restCF + centerShift

	for _, m in ipairs(s.MeshStates) do
		local part = m.Part

		if part
			and part.Parent
			and part ~= s.CollisionPart then

			local sx, sy, sz =
				m.OrigSize.X,
				m.OrigSize.Y,
				m.OrigSize.Z

			local mx =
				m.OrigMeshScale
				and m.OrigMeshScale.X
				or 1

			local my =
				m.OrigMeshScale
				and m.OrigMeshScale.Y
				or 1

			local mz =
				m.OrigMeshScale
				and m.OrigMeshScale.Z
				or 1

			if axis == "X" then
				sx = sx * scaleA
				sy = sy * (1 + widen)
				sz = sz * (1 + widen)

				mx = mx * scaleA
				my = my * (1 + widen)
				mz = mz * (1 + widen)

			elseif axis == "Z" then
				sz = sz * scaleA
				sx = sx * (1 + widen)
				sy = sy * (1 + widen)

				mz = mz * scaleA
				mx = mx * (1 + widen)
				my = my * (1 + widen)

			else
				sy = sy * scaleA
				sx = sx * (1 + widen)
				sz = sz * (1 + widen)

				my = my * scaleA
				mx = mx * (1 + widen)
				mz = mz * (1 + widen)
			end

			part.Size = Vector3.new(sx, sy, sz)

			if m.SpecialMesh
				and m.OrigMeshScale then

				m.SpecialMesh.Scale =
					Vector3.new(mx, my, mz)
			end

			local lp =
				m.OrigLocalCF.Position

			local slp

			if axis == "X" then
				slp = Vector3.new(
					lp.X * scaleA,
					lp.Y * (1 + widen),
					lp.Z * (1 + widen)
				)

			elseif axis == "Z" then
				slp = Vector3.new(
					lp.X * (1 + widen),
					lp.Y * (1 + widen),
					lp.Z * scaleA
				)

			else
				slp = Vector3.new(
					lp.X * (1 + widen),
					lp.Y * scaleA,
					lp.Z * (1 + widen)
				)
			end

			part.CFrame =
				newCF
				* (
					(m.OrigLocalCF - lp)
					+ slp
				)

			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function applyConfiguredSquish(s, cfg, sinkAlpha)
	if s.HasBones then return end

	if cfg.SphereSquish then
		applySphereSquish(s, sinkAlpha)
	elseif cfg.SquishAxis then
		applyAxisSquish(s, sinkAlpha, cfg.SquishAxis)
	else
		applyMeshSquish(s, sinkAlpha)
	end
end

local RestX, RestY, RestZ =
	"_RestX",
	"_RestY",
	"_RestZ"

local function dentAt(cfg, boneXZ, playerXZ)
	if not playerXZ then return 0 end

	local d =
		(boneXZ - playerXZ).Magnitude

	if d >= (cfg.DentRadius or 14) then
		return 0
	end

	local t =
		1 - (d / cfg.DentRadius)

	return
		-(cfg.DentDepth or 1.6)
		* (t ^ (cfg.DentFalloff or 2))
end

local function updateBones(s, cfg, dt, playerXZ)
	if not s.HasBones then return false end

	local moving = false

	local overshoot =
		cfg.DentOvershoot or 0

	local pressSpeed =
		cfg.DentPressSpeed or 9

	local releaseSpeed =
		cfg.DentReleaseSpeed or 3

	for _, bone in ipairs(s.Bones) do
		if bone.Parent then
			local boneXZ =
				s.BoneWorld[bone]
				or Vector2.zero

			local target =
				dentAt(
					cfg,
					boneXZ,
					playerXZ
				)

			local cur =
				s.BoneY[bone]
				or 0

			local nxt

			if overshoot > 0
				and target > cur then

				local vel =
					s.BoneVel[bone]
					or 0

				local k =
					releaseSpeed * 6

				vel += (
					(target - cur) * k
					- vel
						* (
							2
							* math.sqrt(k)
							* (1 - overshoot)
						)
				) * dt

				nxt =
					cur + vel * dt

				s.BoneVel[bone] = vel
			else
				local rate =
					(target < cur)
					and pressSpeed
					or releaseSpeed

				nxt =
					cur
					+ (target - cur)
						* math.min(
							1,
							rate * dt
						)

				s.BoneVel[bone] = 0
			end

			if math.abs(nxt - target) < 0.002 then
				nxt = target
			end

			if nxt ~= cur then
				bone.Position =
					Vector3.new(
						bone:GetAttribute(RestX)
							or 0,

						(bone:GetAttribute(RestY)
							or 0) + nxt,

						bone:GetAttribute(RestZ)
							or 0
					)
			end

			s.BoneY[bone] = nxt

			if nxt ~= 0 then
				moving = true
			end
		end
	end

	return moving
end

local function RegisterDeformable(typeName, cfg)
	local soundName =
		cfg.SoundName
		or typeName

	RegisterHandler({
		Type = typeName,

		Resolve = function(obj)
			local model = obj.Model

			local collisionPart =
				model:FindFirstChild(
					"Collision",
					true
				)

			local surface =
				model:FindFirstChild(
					"Surface",
					true
				)

			if not surface then
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("BasePart")
						and d ~= collisionPart
						and not d.Name:lower():find("hitbox")
						and not d.Name:lower():find("trigger")
						and not d.Name:lower():find("crack")
						and not isProtectedPart(
							d,
							nil,
							collisionPart
						) then

						surface = d
						break
					end
				end
			end

			if not surface then
				return false
			end

			local bones, sinkBones = {}, {}

			for _, d in ipairs(surface:GetDescendants()) do
				if d:IsA("Bone")
					and d.Name ~= "Root" then

					table.insert(bones, d)
					table.insert(sinkBones, d)
				end
			end

			local s = obj.State

			s.CollisionPart = collisionPart
			s.Surface = surface
			s.HasBones = #bones > 0
			s.OrigSize = surface.Size
			s.OrigCFrame = surface.CFrame
			s.VisualParts = {}
			s.PassingThrough = false

			if collisionPart then
				collisionPart.Anchored = true
				collisionPart.CanCollide = true
				collisionPart.CanQuery = true
				s.CollOrigCFrame =
					collisionPart.CFrame
			end

			s.MeshStates = {}

			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart")
					and d ~= collisionPart
					and not d.Name:lower():find("hitbox")
					and not d.Name:lower():find("trigger")
					and not d.Name:lower():find("crack")
					and not isProtectedPart(
						d,
						surface,
						collisionPart
					) then

					d.Anchored = true
					d.CanCollide = true
					d.CanQuery = true

					table.insert(
						s.VisualParts,
						d
					)

					local sm =
						d:FindFirstChildOfClass(
							"SpecialMesh"
						)

					table.insert(
						s.MeshStates,
						{
							Part = d,
							OrigSize = d.Size,
							OrigLocalCF =
								surface.CFrame:ToObjectSpace(
									d.CFrame
								),
							SpecialMesh = sm,
							OrigMeshScale =
								sm
								and sm.Scale
								or nil,
						}
					)
				end
			end

			if #s.MeshStates == 0 then
				local sm =
					surface:FindFirstChildOfClass(
						"SpecialMesh"
					)

				table.insert(
					s.VisualParts,
					surface
				)

				table.insert(
					s.MeshStates,
					{
						Part = surface,
						OrigSize = surface.Size,
						OrigLocalCF = CFrame.new(),
						SpecialMesh = sm,
						OrigMeshScale =
							sm
							and sm.Scale
							or nil,
					}
				)
			end

			if s.HasBones then
				s.Bones = bones
				s.SinkBones = sinkBones
				s.BoneY = {}
				s.BoneVel = {}
				s.BoneWorld = {}

				for _, bone in ipairs(bones) do
					if bone:GetAttribute(RestY) == nil then
						local p = bone.Position

						bone:SetAttribute(
							RestX,
							p.X
						)

						bone:SetAttribute(
							RestY,
							p.Y
						)

						bone:SetAttribute(
							RestZ,
							p.Z
						)
					end

					s.BoneY[bone] = 0
					s.BoneVel[bone] = 0

					s.BoneWorld[bone] =
						Vector2.new(
							bone.WorldPosition.X,
							bone.WorldPosition.Z
						)
				end
			end

			setupVisualNoCollide(
				s,
				surface,
				collisionPart
			)

			s.SinkAlpha = 0
			s.LastStep = 0
			s.Inside = false
			s.WasInside = false
			s.Settled = true

			obj.Root = surface

			return true
		end,

		Reset = function(obj)
			local s = obj.State

			s.PassingThrough = false

			updateNoCollisionConstraints(
				s,
				false
			)

			if s.HasBones then
				for _, bone in ipairs(s.Bones or {}) do
					if bone.Parent then
						s.BoneY[bone] = 0
						s.BoneVel[bone] = 0

						bone.Position =
							Vector3.new(
								bone:GetAttribute(RestX)
									or 0,

								bone:GetAttribute(RestY)
									or 0,

								bone:GetAttribute(RestZ)
									or 0
							)
					end
				end
			else
				applyConfiguredSquish(
					s,
					cfg,
					0
				)

				for _, m in ipairs(
					s.MeshStates or {}
				) do
					if m.Part
						and m.Part.Parent then

						m.Part.Size =
							m.OrigSize

						if m.SpecialMesh
							and m.OrigMeshScale then

							m.SpecialMesh.Scale =
								m.OrigMeshScale
						end
					end
				end
			end

			if s.Surface
				and s.OrigCFrame then

				s.Surface.CFrame =
					s.OrigCFrame
			end

			if s.CollisionPart
				and s.CollOrigCFrame then

				s.CollisionPart.CFrame =
					s.CollOrigCFrame

				s.CollisionPart.CanCollide =
					true
			end

			s.SinkAlpha = 0
			s.Inside = false
			s.WasInside = false
			s.Settled = true
		end,

		Cleanup = function(obj)
			obj.Handler.Reset(obj)
		end,

		Update = function(obj, dt, core, char, hum)
			local s = obj.State

			local hrp =
				char:FindFirstChild(
					"HumanoidRootPart"
				)

			s.WasInside = s.Inside

			s.Inside =
				obj.Occupied
				and hrp ~= nil

			if s.Settled
				and not s.Inside
				and not s.WasInside then

				return
			end

			local playerXZ =
				s.Inside
				and Vector2.new(
					hrp.Position.X,
					hrp.Position.Z
				)
				or nil

			local moving = false

			if s.HasBones then
				moving =
					updateBones(
						s,
						cfg,
						dt,
						playerXZ
					)
			else
				local sinkSpeed =
					cfg.SinkSpeed
					or 4

				local riseSpeed =
					cfg.RiseSpeed
					or 3

				if s.Inside then
					local target =
						-(cfg.MeshDentDepth or 1.2)

					local diff =
						target - s.SinkAlpha

					if math.abs(diff) < 0.005 then
						s.SinkAlpha = target
					else
						s.SinkAlpha +=
							diff
							* math.min(
								1,
								sinkSpeed * dt
							)
					end

					applyConfiguredSquish(
						s,
						cfg,
						s.SinkAlpha
					)

					moving =
						s.SinkAlpha ~= 0

				elseif s.SinkAlpha ~= 0 then
					s.SinkAlpha +=
						(0 - s.SinkAlpha)
						* math.min(
							1,
							riseSpeed * dt
						)

					if math.abs(
						s.SinkAlpha
					) < 0.01 then

						s.SinkAlpha = 0

						applyConfiguredSquish(
							s,
							cfg,
							0
						)
					else
						applyConfiguredSquish(
							s,
							cfg,
							s.SinkAlpha
						)

						moving = true
					end
				end
			end

			if s.Inside then
				isSteppingOnASMR = true

				currentSpeedTarget =
					cfg.WalkSpeed
					or defaultWalkSpeed
			end

			s.Settled =
				(not moving)
				and s.SinkAlpha == 0

			if s.Inside
				and not s.WasInside then

				PlaySound(
					soundName,
					s.Surface,
					cfg,
					"Enter"
				)

			elseif s.WasInside
				and not s.Inside then

				PlaySound(
					soundName,
					s.Surface,
					cfg,
					"Exit"
				)
			end

			if s.Inside and hrp then
				local v =
					hrp.AssemblyLinearVelocity

				local now =
					os.clock()

				if Vector2.new(
					v.X,
					v.Z
				).Magnitude
					> (cfg.StepSpeedMin or 4)
					and (now - s.LastStep)
						> (cfg.StepGap or 0.35) then

					s.LastStep = now

					PlaySound(
						soundName,
						s.Surface,
						cfg,
						"Step"
					)
				end
			end
		end,
	})
end

RegisterDeformable("Slime", {
	SoundName = "Slime",
	DentDepth = 2.8,
	DentRadius = 18,
	DentPressSpeed = 6,
	DentReleaseSpeed = 1.5,
	DentOvershoot = 0.6,
	SinkSpeed = 3.0,
	RiseSpeed = 1.8,
	DentFalloff = 1.5,
	StepGap = 0.45,
	Volume = 1.6,
	WalkSpeed = 7,
})

RegisterDeformable("NeeDoh", {
	SoundName = "NeeDoh",
	DentDepth = 2.0,
	DentRadius = 10,
	DentPressSpeed = 10,
	DentReleaseSpeed = 2,
	DentOvershoot = 0.4,
	SinkSpeed = 4.0,
	RiseSpeed = 1.8,
	DentFalloff = 2,
	StepGap = 0.5,
	Volume = 1.4,
	WalkSpeed = 12,
})

RegisterDeformable("Foamball", {
	SoundName = "Foamball",
	SphereSquish = true,
	DentDepth = 3.5,
	DentRadius = 14,
	DentPressSpeed = 8,
	DentReleaseSpeed = 0.8,
	MeshDentDepth = 2.2,
	DentOvershoot = 0,
	SinkSpeed = 5.0,
	RiseSpeed = 1.2,
	DentFalloff = 1.5,
	StepGap = 0.5,
	Volume = 1.6,
	WalkSpeed = 7,
})

RegisterDeformable("Cheese", {
	SoundName = "Cheese",
	DentDepth = 1.6,
	DentRadius = 9,
	DentPressSpeed = 8,
	DentReleaseSpeed = 3.0,
	MeshDentDepth = 1.5,
	DentOvershoot = 0.2,
	SinkSpeed = 6.0,
	RiseSpeed = 3.5,
	DentFalloff = 2,
	StepGap = 0.4,
	Volume = 1.4,
	WalkSpeed = 12,
})

RegisterDeformable("WaterDroplet", {
	SoundName = "WaterDroplet",
	SquishAxis = "X",
	DentDepth = 3.2,
	DentRadius = 12,
	DentPressSpeed = 9,
	DentReleaseSpeed = 2.5,
	MeshDentDepth = 2.0,
	DentOvershoot = 0.15,
	SinkSpeed = 6.0,
	RiseSpeed = 3.5,
	DentFalloff = 1.8,
	StepGap = 0.4,
	Volume = 1.5,
	WalkSpeed = 10,
})

RegisterDeformable("BrainrotSquishy", {
	SoundName = "BrainrotSquishy",
	DentDepth = 1.8,
	DentRadius = 11,
	DentPressSpeed = 9,
	DentReleaseSpeed = 2.5,
	MeshDentDepth = 1.4,
	DentOvershoot = 0.3,
	SinkSpeed = 3.5,
	RiseSpeed = 2.0,
	DentFalloff = 1.8,
	StepGap = 0.5,
	Volume = 1.4,
	WalkSpeed = 12,
})

local function computePressPose(
	cfg,
	data,
	footPos,
	sinkDepth
)
	local bonusOut, bonusTilt = 0, 0

	if footPos and data.RestCF then
		local pieceXZ =
			Vector2.new(
				data.RestCF.Position.X,
				data.RestCF.Position.Z
			)

		local footXZ =
			Vector2.new(
				footPos.X,
				footPos.Z
			)

		local d =
			(pieceXZ - footXZ).Magnitude

		if d < cfg.FootRadius then
			local w =
				1 - (d / cfg.FootRadius)

			w = w * w

			bonusOut =
				cfg.FootBonus * w

			bonusTilt =
				cfg.FootTiltBonus * w
		end
	end

	local tiltAmount =
		cfg.BaseTilt + bonusTilt

	local tiltCF =
		CFrame.new(
			0,
			data.HalfH,
			0
		)
		* CFrame.fromAxisAngle(
			data.TiltAxis,
			tiltAmount
		)
		* CFrame.new(
			0,
			-data.HalfH,
			0
		)

	local outAmount =
		cfg.BaseOutward + bonusOut

	local maxAllowedDrop =
		data.HalfH * 0.6

	local rawDrop =
		math.max(
			0,
			(sinkDepth
				or cfg.SquishYDrop
				or 0.6) - 0.25
		)

	local yDrop =
		math.clamp(
			rawDrop,
			0,
			maxAllowedDrop
		)

	local goalCF =
		data.RestCF
		* tiltCF
		+ data.Outward * outAmount
		+ Vector3.new(
			0,
			-yDrop,
			0
		)

	local goalSize =
		Vector3.new(
			data.RestSize.X
				* cfg.SquishSizeXZ,

			data.RestSize.Y
				* cfg.SquishSizeY,

			data.RestSize.Z
				* cfg.SquishSizeXZ
		)

	return goalCF, goalSize
end

local function RegisterCrackable(
	typeName,
	cfg,
	tweens
)
	RegisterHandler({
		Type = typeName,

		Resolve = function(obj)
			local model = obj.Model

			local surface =
				model:FindFirstChild(
					"Surface",
					true
				)

			local collisionPart =
				model:FindFirstChild(
					"Collision",
					true
				)

			if not surface then
				for _, d in ipairs(
					model:GetDescendants()
				) do
					if d:IsA("BasePart")
						and not d.Name:lower():find("crack")
						and not d.Name:lower():find("hitbox")
						and not d.Name:lower():find("collision")
						and d ~= collisionPart
						and not isProtectedPart(
							d,
							nil,
							collisionPart
						) then

						surface = d
						break
					end
				end
			end

			if not surface then
				return false
			end

			local s = obj.State

			s.Surface = surface
			s.CollisionPart = collisionPart
			s.OrigCFrame = surface.CFrame
			s.OrigSize = surface.Size
			s.PassingThrough = false

			if collisionPart then
				collisionPart.Anchored = true
				collisionPart.CanCollide = true
				collisionPart.CanQuery = true

				s.CollOrigCFrame =
					collisionPart.CFrame
			end

			s.MeshStates = {}
			s.VisualParts = {}

			for _, d in ipairs(
				model:GetDescendants()
			) do
				if d:IsA("BasePart")
					and d ~= collisionPart
					and not d.Name:lower():find("crack")
					and not d.Name:lower():find("hitbox")
					and not d.Name:lower():find("trigger")
					and not isProtectedPart(
						d,
						surface,
						collisionPart
					) then

					d.Anchored = true
					d.CanCollide = true
					d.CanQuery = true

					table.insert(
						s.VisualParts,
						d
					)

					local sm =
						d:FindFirstChildOfClass(
							"SpecialMesh"
						)

					table.insert(
						s.MeshStates,
						{
							Part = d,
							OrigSize = d.Size,
							OrigLocalCF =
								surface.CFrame:ToObjectSpace(
									d.CFrame
								),
							SpecialMesh = sm,
							OrigMeshScale =
								sm
								and sm.Scale
								or nil,
						}
					)
				end
			end

			local bones, sinkBones = {}, {}

			for _, part in ipairs(
				s.VisualParts
			) do
				for _, d in ipairs(
					part:GetDescendants()
				) do
					if d:IsA("Bone")
						and d.Name ~= "Root" then

						table.insert(
							bones,
							d
						)

						if part == surface then
							table.insert(
								sinkBones,
								d
							)
						end
					end
				end
			end

			if #sinkBones == 0
				and #bones > 0 then

				sinkBones = bones
			end

			s.HasBones = #bones > 0

			if s.HasBones then
				s.Bones = bones
				s.SinkBones = sinkBones
				s.BoneY = {}
				s.BoneVel = {}
				s.BoneWorld = {}

				for _, bone in ipairs(
					bones
				) do
					if bone:GetAttribute(RestY) == nil then
						bone:SetAttribute(
							RestX,
							bone.Position.X
						)

						bone:SetAttribute(
							RestY,
							bone.Position.Y
						)

						bone:SetAttribute(
							RestZ,
							bone.Position.Z
						)
					end

					s.BoneY[bone] = 0
					s.BoneVel[bone] = 0

					s.BoneWorld[bone] =
						Vector2.new(
							bone.WorldPosition.X,
							bone.WorldPosition.Z
						)
				end
			end

			s.Cracks = {}

			local anchorPos =
				surface.Position

			for _, d in ipairs(
				model:GetDescendants()
			) do
				if d:IsA("BasePart")
					and d.Name:lower():find("crack") then

					local offset =
						d.Position
						- anchorPos

					local flat =
						Vector3.new(
							offset.X,
							0,
							offset.Z
						)

					local outward =
						flat.Magnitude > 0.001
						and flat.Unit
						or Vector3.zero

					local tiltAxis =
						Vector3.new(
							math.random() - 0.5,
							0,
							math.random() - 0.5
						)

					if tiltAxis.Magnitude > 0.001 then
						tiltAxis =
							tiltAxis.Unit
					else
						tiltAxis =
							Vector3.new(
								1,
								0,
								0
							)
					end

					local restCF =
						d:GetAttribute(
							"RestCFrame"
						)
						or d.CFrame

					local restSize =
						d:GetAttribute(
							"RestSize"
						)
						or d.Size

					local sm =
						d:FindFirstChildOfClass(
							"SpecialMesh"
						)

					s.Cracks[d] = {
						RestCF = restCF,
						RestSize = restSize,
						HalfH = restSize.Y / 2,
						Outward = outward,
						TiltAxis = tiltAxis,
						OrigMat = d.Material,
						Tweens = {},
						SpecialMesh = sm,
						RestMeshScale =
							sm
							and sm.Scale
							or nil,
					}

					d.CanCollide = true
					d.CanQuery = true
					d.CanTouch = false
					d.Anchored = true
				end
			end

			setupVisualNoCollide(
				s,
				surface,
				collisionPart
			)

			for part in pairs(
				s.Cracks
			) do
				table.insert(
					s.NoCollideParts,
					part
				)
			end

			s.SinkAlpha = 0
			s.LastStep = 0
			s.LastFootUpdate = 0
			s.Inside = false
			s.WasInside = false
			s.Settled = true

			obj.Root = surface

			return true
		end,

		Reset = function(obj)
			local s = obj.State

			s.PassingThrough = false

			updateNoCollisionConstraints(
				s,
				false
			)

			if s.HasBones then
				for _, bone in ipairs(
					s.Bones or {}
				) do
					if bone.Parent then
						s.BoneY[bone] = 0
						s.BoneVel[bone] = 0

						bone.Position =
							Vector3.new(
								bone:GetAttribute(RestX)
									or 0,

								bone:GetAttribute(RestY)
									or 0,

								bone:GetAttribute(RestZ)
									or 0
							)
					end
				end
			else
				applyConfiguredSquish(
					s,
					cfg,
					0
				)

				for _, m in ipairs(
					s.MeshStates or {}
				) do
					if m.Part
						and m.Part.Parent then

						m.Part.Size =
							m.OrigSize

						if m.SpecialMesh
							and m.OrigMeshScale then

							m.SpecialMesh.Scale =
								m.OrigMeshScale
						end
					end
				end
			end

			for part, data in pairs(
				s.Cracks or {}
			) do
				if part and part.Parent then
					for _, t in ipairs(
						data.Tweens
					) do
						pcall(function()
							t:Cancel()
						end)
					end

					table.clear(
						data.Tweens
					)

					part.CFrame =
						data.RestCF

					part.Size =
						data.RestSize

					part.Material =
						data.OrigMat

					if data.SpecialMesh
						and data.RestMeshScale then

						data.SpecialMesh.Scale =
							data.RestMeshScale
					end
				end
			end

			if s.CollisionPart
				and s.CollOrigCFrame then

				s.CollisionPart.CFrame =
					s.CollOrigCFrame

				s.CollisionPart.CanCollide =
					true
			end

			s.SinkAlpha = 0
			s.Inside = false
			s.WasInside = false
			s.Settled = true
		end,

		Cleanup = function(obj)
			obj.Handler.Reset(obj)
		end,

		Update = function(obj, dt, core, char, hum)
			local s = obj.State

			local hrp =
				char:FindFirstChild(
					"HumanoidRootPart"
				)

			s.WasInside = s.Inside

			s.Inside =
				obj.Occupied
				and hrp ~= nil

			if s.Settled
				and not s.Inside
				and not s.WasInside then

				return
			end

			local moving = false

			local playerXZ =
				s.Inside
				and Vector2.new(
					hrp.Position.X,
					hrp.Position.Z
				)
				or nil

			if s.HasBones then
				moving =
					updateBones(
						s,
						cfg,
						dt,
						playerXZ
					)
					or moving
			else
				local targetSink =
					s.Inside
					and -(cfg.MeshDentDepth or 0.6)
					or 0

				local rate =
					(targetSink < s.SinkAlpha)
					and (cfg.SinkSpeed or 5)
					or (cfg.RiseSpeed or 3.5)

				local diff =
					targetSink
					- s.SinkAlpha

				if math.abs(diff) < 0.005 then
					s.SinkAlpha =
						targetSink
				else
					s.SinkAlpha +=
						diff
						* math.min(
							1,
							rate * dt
						)

					moving = true
				end

				applyMeshSquish(
					s,
					s.SinkAlpha
				)
			end

			if s.Inside then
				isSteppingOnASMR = true

				currentSpeedTarget =
					cfg.WalkSpeed
					or 11
			end

			local footPos =
				s.Inside
				and getLowestFootPosition(
					char
				)
				or nil

			local activeSinkDepth =
				s.HasBones
				and math.abs(
					s.SinkAlpha
				)
				or (cfg.MeshDentDepth or 0.6)

			if s.Inside
				and not s.WasInside then

				for part, data in pairs(
					s.Cracks
				) do
					if part and part.Parent then
						for _, t in ipairs(
							data.Tweens
						) do
							pcall(function()
								t:Cancel()
							end)
						end

						table.clear(
							data.Tweens
						)

						local goalCF, goalSize =
							computePressPose(
								cfg,
								data,
								footPos,
								activeSinkDepth
							)

						local tw =
							TweenService:Create(
								part,
								tweens.Squish,
								{
									CFrame = goalCF,
									Size = goalSize
								}
							)

						tw:Play()

						table.insert(
							data.Tweens,
							tw
						)

						if data.SpecialMesh
							and data.RestMeshScale then

							local goalMeshScale =
								Vector3.new(
									data.RestMeshScale.X
										* cfg.SquishSizeXZ,

									data.RestMeshScale.Y
										* cfg.SquishSizeY,

									data.RestMeshScale.Z
										* cfg.SquishSizeXZ
								)

							local twMesh =
								TweenService:Create(
									data.SpecialMesh,
									tweens.Squish,
									{
										Scale =
											goalMeshScale
									}
								)

							twMesh:Play()

							table.insert(
								data.Tweens,
								twMesh
							)
						end

						part.Material =
							Enum.Material.Glass

						task.delay(
							0.18,
							function()
								if part
									and part.Parent then

									part.Material =
										data.OrigMat
								end
							end
						)
					end
				end

				PlaySound(
					cfg.SoundName,
					s.Surface,
					cfg,
					"Enter"
				)

				s.LastFootUpdate =
					os.clock()

			elseif s.Inside
				and s.WasInside then

				local now =
					os.clock()

				if now - s.LastFootUpdate
					> 0.35 then

					s.LastFootUpdate =
						now

					for part, data in pairs(
						s.Cracks
					) do
						if part
							and part.Parent then

							for _, t in ipairs(
								data.Tweens
							) do
								pcall(function()
									t:Cancel()
								end)
							end

							table.clear(
								data.Tweens
							)

							local goalCF, goalSize =
								computePressPose(
									cfg,
									data,
									footPos,
									activeSinkDepth
								)

							local tw =
								TweenService:Create(
									part,
									TweenInfo.new(
										0.35,
										Enum.EasingStyle.Quad,
										Enum.EasingDirection.Out
									),
									{
										CFrame = goalCF,
										Size = goalSize
									}
								)

							tw:Play()

							table.insert(
								data.Tweens,
								tw
							)

							if data.SpecialMesh
								and data.RestMeshScale then

								local goalMeshScale =
									Vector3.new(
										data.RestMeshScale.X
											* cfg.SquishSizeXZ,

										data.RestMeshScale.Y
											* cfg.SquishSizeY,

										data.RestMeshScale.Z
											* cfg.SquishSizeXZ
									)

								local twMesh =
									TweenService:Create(
										data.SpecialMesh,
										TweenInfo.new(
											0.35,
											Enum.EasingStyle.Quad,
											Enum.EasingDirection.Out
										),
										{
											Scale =
												goalMeshScale
										}
									)

								twMesh:Play()

								table.insert(
									data.Tweens,
									twMesh
								)
							end
						end
					end
				end

			elseif s.WasInside
				and not s.Inside then

				for part, data in pairs(
					s.Cracks
				) do
					if part and part.Parent then
						for _, t in ipairs(
							data.Tweens
						) do
							pcall(function()
								t:Cancel()
							end)
						end

						table.clear(
							data.Tweens
						)

						local tw =
							TweenService:Create(
								part,
								tweens.Restore,
								{
									CFrame =
										data.RestCF,

									Size =
										data.RestSize
								}
							)

						tw:Play()

						table.insert(
							data.Tweens,
							tw
						)

						if data.SpecialMesh
							and data.RestMeshScale then

							local twMesh =
								TweenService:Create(
									data.SpecialMesh,
									tweens.Restore,
									{
										Scale =
											data.RestMeshScale
									}
								)

							twMesh:Play()

							table.insert(
								data.Tweens,
								twMesh
							)
						end

						moving = true
					end
				end

				PlaySound(
					cfg.SoundName,
					s.Surface,
					cfg,
					"Exit"
				)
			end

			if not s.Inside
				and s.SinkAlpha == 0 then

				for _, data in pairs(
					s.Cracks
				) do
					for _, t in ipairs(
						data.Tweens
					) do
						if t.PlaybackState
							== Enum.PlaybackState.Playing then

							moving = true
							break
						end
					end

					if moving then
						break
					end
				end
			end

			s.Settled =
				(not moving)
				and s.SinkAlpha == 0

			if s.Inside and hrp then
				local v =
					hrp.AssemblyLinearVelocity

				local now =
					os.clock()

				if Vector2.new(
					v.X,
					v.Z
				).Magnitude
					> (cfg.StepSpeedMin or 4)
					and (now - s.LastStep)
						> (cfg.StepGap or 0.35) then

					s.LastStep = now

					PlaySound(
						cfg.SoundName,
						s.Surface,
						cfg,
						"Step"
					)
				end
			end
		end,
	})
end

RegisterCrackable("TabaPaw", {
	SoundName = "Taba",
	DentDepth = 1.4,
	DentRadius = 12,
	DentPressSpeed = 8,
	DentReleaseSpeed = 2.2,
	DentFalloff = 1.8,
	DentOvershoot = 0.25,
	MeshDentDepth = 0.6,
	SquishYDrop = 0.6,
	SinkSpeed = 5,
	RiseSpeed = 3.5,
	BaseOutward = 0.5,
	BaseTilt = 0.12,
	SquishSizeXZ = 1.10,
	SquishSizeY = 0.84,
	FootBonus = 0.55,
	FootRadius = 6,
	FootTiltBonus = 0.08,
	StepGap = 0.4,
	StepSpeedMin = 4,
	Volume = 1.5,
	WalkSpeed = 11,
}, {
	Squish = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Restore = TweenInfo.new(
		1.2,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	),
})

RegisterCrackable("Dumpling", {
	SoundName = "Dumpling",
	DentDepth = 1.4,
	DentRadius = 12,
	DentPressSpeed = 8,
	DentReleaseSpeed = 2.2,
	DentFalloff = 1.8,
	DentOvershoot = 0.25,
	MeshDentDepth = 0.7,
	SquishYDrop = 0.7,
	SinkSpeed = 4.5,
	RiseSpeed = 2.5,
	BaseOutward = 0.3,
	BaseTilt = 0.08,
	SquishSizeXZ = 1.05,
	SquishSizeY = 0.9,
	FootBonus = 0.3,
	FootRadius = 5,
	FootTiltBonus = 0.05,
	StepGap = 0.42,
	StepSpeedMin = 4,
	Volume = 1.5,
	WalkSpeed = 9,
}, {
	Squish = TweenInfo.new(
		0.3,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	),

	Restore = TweenInfo.new(
		1.2,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	),
})

RegisterCrackable("Pudding", {
	SoundName = "Pudding",
	DentDepth = 2.0,
	DentRadius = 14,
	DentPressSpeed = 10,
	DentReleaseSpeed = 3.5,
	DentFalloff = 1.5,
	DentOvershoot = 0.5,
	MeshDentDepth = 1.6,
	SquishYDrop = 1.6,
	SinkSpeed = 7,
	RiseSpeed = 4,
	BaseOutward = 0.2,
	BaseTilt = 0.05,
	SquishSizeXZ = 1.12,
	SquishSizeY = 0.75,
	FootBonus = 0.2,
	FootRadius = 7,
	FootTiltBonus = 0.05,
	StepGap = 0.4,
	StepSpeedMin = 4,
	Volume = 1.6,
	WalkSpeed = 12,
}, {
	Squish = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	),

	Restore = TweenInfo.new(
		1.2,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	),
})

RegisterCrackable("Butter", {
	SoundName = "Butter",
	DentDepth = 1.2,
	DentRadius = 12,
	DentPressSpeed = 6,
	DentReleaseSpeed = 1.5,
	DentFalloff = 2.0,
	DentOvershoot = 0.1,
	MeshDentDepth = 0.6,
	SquishYDrop = 0.6,
	SinkSpeed = 4,
	RiseSpeed = 2,
	BaseOutward = 0.4,
	BaseTilt = 0.08,
	SquishSizeXZ = 1.05,
	SquishSizeY = 0.85,
	FootBonus = 0.4,
	FootRadius = 6,
	FootTiltBonus = 0.05,
	StepGap = 0.45,
	StepSpeedMin = 4,
	Volume = 1.5,
	WalkSpeed = 10,
}, {
	Squish = TweenInfo.new(
		0.35,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	Restore = TweenInfo.new(
		2.5,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	),
})

local Themes = {
	Ocean = {
		Color3.fromRGB(24, 54, 62),
		Color3.fromRGB(95, 151, 170),
		Color3.fromRGB(45, 95, 110),
		Color3.fromRGB(62, 136, 165),
		Color3.fromRGB(147, 196, 209)
	},

	Candy = {
		Color3.fromRGB(255, 182, 193),
		Color3.fromRGB(255, 105, 180),
		Color3.fromRGB(173, 216, 230),
		Color3.fromRGB(152, 251, 152),
		Color3.fromRGB(221, 160, 221),
		Color3.fromRGB(255, 253, 208),
		Color3.fromRGB(255, 218, 185)
	},

	Chocolate = {
		Color3.fromRGB(62, 39, 35),
		Color3.fromRGB(136, 92, 62),
		Color3.fromRGB(93, 48, 11),
		Color3.fromRGB(77, 39, 0),
		Color3.fromRGB(156, 104, 78)
	},

	Blue = {
		Color3.fromRGB(60, 120, 255),
		Color3.fromRGB(90, 150, 255),
		Color3.fromRGB(120, 180, 255),
		Color3.fromRGB(40, 90, 220)
	},

	Sunset = {
		Color3.fromRGB(242, 196, 71),
		Color3.fromRGB(247, 98, 24),
		Color3.fromRGB(255, 29, 104),
		Color3.fromRGB(177, 0, 101),
		Color3.fromRGB(116, 5, 128)
	},
}

local alphabet = {
	"A","B","C","D","E","F","G","H","I","J","K","L","M",
	"N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
}

local previousLetter = ""

local KeyboardConfig = {
	DropDistance = 1.4,
	PressTime = 0.12,
	ReleaseTime = 0.18,
	Volume = 1.4,
	VolumeJitter = 0.08,
	Pitch = 1.1,
	PitchJitter = 0.1,
	MaxConcurrent = 8
}

local trackedKeys = {}

local function addLetter(key)
	if key:FindFirstChild("KeyGui") then
		return
	end

	local gui =
		Instance.new("SurfaceGui")

	gui.Name = "KeyGui"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode =
		Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 81
	gui.Parent = key

	local label =
		Instance.new("TextLabel")

	label.Size =
		UDim2.fromScale(1, 1)

	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 =
		Color3.new(0, 0, 0)

	local letter

	repeat
		letter =
			alphabet[
				rng:NextInteger(
					1,
					#alphabet
				)
			]
	until letter ~= previousLetter

	previousLetter = letter

	label.Text = letter
	label.Parent = gui

	local stroke =
		Instance.new("UIStroke")

	stroke.Thickness = 1.5
	stroke.Parent = label
end

local function setupKey(key)
	if not key:IsA("BasePart")
		or key:GetAttribute("ASMRType")
			~= "KeyboardKey"
		or trackedKeys[key] then

		return
	end

	local theme =
		Themes[
			key:GetAttribute(
				"ASMRTheme"
			)
			or "Blue"
		]

	if theme then
		key.Color =
			theme[
				rng:NextInteger(
					1,
					#theme
				)
			]
	end

	addLetter(key)

	trackedKeys[key] = {
		originalCFrame = key.CFrame,
		pressed = false,
		currentTween = nil
	}
end

for _, d in ipairs(
	Workspace:GetDescendants()
) do
	setupKey(d)
end

Workspace.DescendantAdded:Connect(
	function(d)
		task.wait(0.05)
		setupKey(d)
	end
)

local function isPlayerOnKey(
	key,
	hrpPos
)
	local p, s =
		key.Position,
		key.Size

	return
		math.abs(
			hrpPos.X - p.X
		)
		<= s.X / 2 + 1
		and math.abs(
			hrpPos.Z - p.Z
		)
		<= s.Z / 2 + 1
		and hrpPos.Y
			<= p.Y + 6
		and hrpPos.Y
			>= p.Y - 2
end

local function pressKey(
	key,
	data
)
	if data.pressed then
		return
	end

	data.pressed = true

	PlaySound(
		"Key",
		key,
		KeyboardConfig
	)

	if data.currentTween then
		data.currentTween:Cancel()
	end

	data.currentTween =
		TweenService:Create(
			key,
			TweenInfo.new(
				KeyboardConfig.PressTime,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				CFrame =
					data.originalCFrame
					* CFrame.new(
						0,
						-KeyboardConfig.DropDistance,
						0
					)
			}
		)

	data.currentTween:Play()
end

local function releaseKey(
	key,
	data
)
	if not data.pressed then
		return
	end

	data.pressed = false

	if data.currentTween then
		data.currentTween:Cancel()
	end

	data.currentTween =
		TweenService:Create(
			key,
			TweenInfo.new(
				KeyboardConfig.ReleaseTime,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				CFrame =
					data.originalCFrame
			}
		)

	data.currentTween:Play()
end

local function deactivate(obj)
	if not obj.Active then
		return
	end

	obj.Active = false
	obj.Occupied = false

	if obj.Handler
		and obj.Handler.Cleanup then

		obj.Handler.Cleanup(
			obj,
			humanoid
		)
	end

	if obj.Resolved
		and obj.Handler
		and obj.Handler.Reset then

		obj.Handler.Reset(obj)
	end
end

RunService.Heartbeat:Connect(
	function(dt)
		if not (
			character
			and humanoid
			and humanoid.Health > 0
		) then
			return
		end

		local hrp =
			character:FindFirstChild(
				"HumanoidRootPart"
			)

		if not hrp
			or #contactParts == 0 then

			return
		end

		local origin =
			hrp.Position

		local footWorldPos =
			getLowestFootPosition(
				character
			)

		local now =
			os.clock()

		local cull2 =
			cullDistance
			* cullDistance

		isSteppingOnASMR = false

		for model, obj in pairs(
			objects
		) do
			local root = obj.Root

			if not (
				root
				and root.Parent
			) then

				deactivate(obj)

				obj.Resolved = false

				if now >= obj.NextResolve then
					obj.NextResolve =
						now + 0.5

					if obj.Handler.Resolve(
						obj
					) then

						obj.Resolved =
							true

					elseif not obj.Warned
						and now
							> obj.ResolveDeadline then

						obj.Warned = true

						warn(
							("[ASMR] '%s' (%s) resolve failed")
								:format(
									model:GetFullName(),
									obj.Type
								)
						)
					end
				end

				if not obj.Resolved then
					continue
				end

				root = obj.Root
			end

			if (
				root.Position - origin
			):Dot(
				root.Position - origin
			) > cull2 then

				deactivate(obj)
				continue
			end

			obj.Active = true

			local s =
				obj.State

			local surface =
				s.Surface
				or root

			local cf =
				s.OrigCFrame
				or surface.CFrame

			local size =
				s.OrigSize
				or surface.Size

			local hx =
				size.X * 0.5

			local hy =
				size.Y * 0.5

			local hz =
				size.Z * 0.5

			local minX =
				math.huge

			local minY =
				math.huge

			local minZ =
				math.huge

			local maxX =
				-math.huge

			local maxY =
				-math.huge

			local maxZ =
				-math.huge

			for _, ox in ipairs({
				-hx,
				hx
			}) do

				for _, oy in ipairs({
					-hy,
					hy
				}) do

					for _, oz in ipairs({
						-hz,
						hz
					}) do

						local wp =
							(
								cf
								* CFrame.new(
									ox,
									oy,
									oz
								)
							).Position

						minX =
							math.min(
								minX,
								wp.X
							)

						maxX =
							math.max(
								maxX,
								wp.X
							)

						minY =
							math.min(
								minY,
								wp.Y
							)

						maxY =
							math.max(
								maxY,
								wp.Y
							)

						minZ =
							math.min(
								minZ,
								wp.Z
							)

						maxZ =
							math.max(
								maxZ,
								wp.Z
							)
					end
				end
			end

			local foot =
				footWorldPos

			local pad = 0.35

			local horizontallyInside =
				foot.X >=
					(minX - pad)
				and foot.X <=
					(maxX + pad)
				and foot.Z >=
					(minZ - pad)
				and foot.Z <=
					(maxZ + pad)

			local topBand =
				math.max(
					0.75,
					(maxY - minY)
						* 0.25
				)

			local atTopSurface =
				foot.Y >=
					(maxY - topBand)
				and foot.Y <=
					(maxY + 3.0)

			if horizontallyInside
				and atTopSurface
				and not s.PassingThrough then

				s.PassingThrough = true
			end

			if s.PassingThrough then
				local safelyAbove =
					foot.Y
					> maxY + 0.6

				local safelyOutside =
					not horizontallyInside

				if safelyAbove
					or safelyOutside then

					s.PassingThrough =
						false
				end
			end

			updateNoCollisionConstraints(
				s,
				s.PassingThrough
					== true
			)

			obj.Occupied =
				(
					s.PassingThrough
					== true
				)
				and horizontallyInside

			obj.Handler.Update(
				obj,
				dt,
				nil,
				character,
				humanoid
			)
		end

		setSpeed(
			isSteppingOnASMR
			and currentSpeedTarget
			or defaultWalkSpeed
		)

		for key, data in pairs(
			trackedKeys
		) do
			if key and key.Parent then
				if (
					key.Position - origin
				):Dot(
					key.Position - origin
				) <= cull2 then

					if isPlayerOnKey(
						key,
						origin
					) then

						pressKey(
							key,
							data
						)
					else
						releaseKey(
							key,
							data
						)
					end
				else
					releaseKey(
						key,
						data
					)
				end
			else
				trackedKeys[key] =
					nil
			end
		end
	end
)
