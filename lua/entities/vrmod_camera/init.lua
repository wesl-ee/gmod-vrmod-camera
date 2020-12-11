AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("vrmod_camera_create")
util.AddNetworkString("vrmod_camera_remove")

local CAMERA_MODEL = Model( "models/dav0r/camera.mdl" )
local VELOCITY_CONSTANT_TOLERANCE_SQUARED = 100

function ENT:Initialize()
	self:SetModel( CAMERA_MODEL )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid(SOLID_NONE)
	self:DrawShadow(false)

	local phys = self:GetPhysicsObject()

	if (IsValid(phys)) then
		phys:EnableGravity(false)
		phys:Wake()
	end

	-- self:SetLocked(true)
	

	-- Just what are you trying to do?
	if not vrmod then return end

	-- Uninitialized entity
	if not IsValid(self:GetPlayer()) then
		self:Remove()
		return
	end

end

function ENT:Think()
	local p = self:GetPlayer()

	if not self.ConfirmedToClient then
		-- BUG - Message not sent sometimes when starting with VRMod :(
		timer.Simple(1, function()
			net.Start("vrmod_camera_created")
			net.WriteEntity(self)
			net.WriteInt(self.mode, 8)
			net.Send(p)
		end )

		-- Is this expected functionality?
		if vrmod.IsPlayerInVR(p) then
			-- self:CameraOn()
		end

		self.ConfirmedToClient = true
	end

	if not IsValid(p) then
		self:Remove()
		return
	end

	if self.mode == 1 then return end

	if not p:Alive() then
		return
	end

	local playerPos
	local playerAng
	local destPos
	local destAng
	local currPos = self:GetPos()
	local currAng = self:GetAngles()
	local phys = self:GetPhysicsObject()

	if not vrmod.IsPlayerInVR(p) then
		playerPos = p:EyePos()
		playerAng = p:EyeAngles()
	else
		playerPos = vrmod.GetHMDPos(p)
		playerAng = vrmod.GetHMDAng(p)
	end

	destPos = playerPos
	destAng = playerAng
	
	
	if self.stabilize then
		-- Stabilize for comfortable viewing
		destAng.roll = 0
	end

	-- Third-person (flybehind) should not collide with walls
	if self.mode == 2 then
		destPos = destPos - playerAng:Forward() * self.flydist
		-- EyeAngles() because otherwise we rotate about an over-the-shoulder axis
		-- which will vary the height depending on your HMD roll and it looks weird
		destPos = destPos + p:EyeAngles():Right() * self.shoulderOffset
		destPos = destPos + p:EyeAngles():Up() * self.shoulderHeight
		destAng.yaw = destAng.yaw + self.shoulderYaw
		destAng.pitch = destAng.pitch + self.shoulderPitchDown

		local trace = {}
		local endpos = destPos
		trace.start = playerPos
		trace.endpos = endpos
		trace.filter = function(ent)
			if not (ent == p or ent:GetClass() == "vrmod_camera") then return true end
		end 

		-- Initial wall trace
		trace = util.TraceLine(trace)
		if trace.HitPos ~= endpos then
			-- If we would be placed in a wall, instead stick to the side of it
			local diff = trace.HitPos - playerPos
			destPos = trace.HitPos - diff:GetNormalized() * self:BoundingRadius()
			--if trace.HitPos:DistToSqr(playerPos) < NearWallZoneSqr then
			--end
		end

		if self.smoothing <= 0 then
			-- Just teleport each frame
			self:SetPos(destPos)
		else
			-- Smooth motion using calculated velocities to reach destination
			-- local resultantVelocity = self.smoothing*((destPos - currPos))
			local resultantVelocity = (self.smoothing*destPos - self.smoothing*currPos)
			if math.abs(resultantVelocity.x) < 0.2 then
				resultantVelocity.x = 0
			end
			if math.abs(resultantVelocity.y) < 0.2 then
				resultantVelocity.y = 0
			end
			if math.abs(resultantVelocity.z) < 0.2 then
				resultantVelocity.z = 0
			end
			phys:SetVelocity(resultantVelocity)
		end
	elseif self.mode == 3 then
		destPos = playerPos
		destAng = playerAng
	end


	if self.smoothing <= 0 then
		self:SetAngles(destAng)
	else
		currAng:Normalize()
		destAng:Normalize()
		local angleDifference = (destAng - currAng)

		-- Adjust rotation for crossing the world axes
		local differenceAxes = angleDifference:ToTable()
		for k, v in pairs(angleDifference:ToTable()) do
			if v > 180 then
				angleDifference[k] = v - 360
			elseif v < -180 then
				angleDifference[k] = v + 360
			end
		end

		local angleCorrectionVector = Vector(
		angleDifference.roll,
		angleDifference.pitch,
		angleDifference.yaw)

		expectedAngularVelocity = angleCorrectionVector*self.smoothing
		phys:AddAngleVelocity(expectedAngularVelocity - phys:GetAngleVelocity())
	end

	self:NextThink(CurTime())
	return true
end


function ENT:OnRemove()
	hook.Remove("VRMod_Start", "start_vr_camera")
	hook.Remove("VRMod_Exit", "stop_vr_camera")
	if IsValid(self.UsingPlayer) then
		self:CameraOff()
	end

	self:GetPlayer().VRModCamera = nil
end

function MakeCamera( ply, camData, Data )
	if ( not IsValid(ply)) then return false end

	local ent = ents.Create( "vrmod_camera" )
	if (!IsValid(ent)) then return end

	-- First camera created by player
	if not ply.VRModCameras then
		ply.VRModCameras = {}
	end

	duplicator.DoGeneric( ent, Data )

	ent.locked = locked

	ent:SetPlayer( ply )
	ent:SetMode(camData["mode"])
	ent:SetSmoothing(camData["smoothing"])
	ent:SetStabilize(camData["stabilize"])
	ent:SetTracking(NULL, Vector(0))
	ent:SetLocked(camData["locked"])
	ent:SetDraw(camData["draw"])
	ent:SetLefty(camData["lefty"])
	ent:SetFlyDist(camData["flydist"])

	ent:Spawn()

	table.insert(ply.VRModCameras, ent)

	return ent
end

net.Receive("vrmod_camera_create", function(n, p)
	local camData = {}
	camData["locked"] = net.ReadBool()
	camData["mode"] = net.ReadInt(8)
	camData["smoothing"] = net.ReadInt(8)
	camData["stabilize"] = net.ReadBool()
	camData["flydist"] = net.ReadInt(8)
	camData["draw"] = net.ReadBool()
	camData["lefty"] = net.ReadBool()

	local ent

	ent = MakeCamera(p, camData, {Pos = p:EyePos(), Angle = p:EyeAngles()})
end )

net.Receive("vrmod_camera_remove", function(n ,p)
	local c = net.ReadEntity()
	if IsValid(c) then c:Remove() end
end )

hook.Add("PlayerDeath", function(p, _, attacker)
	if p.VRModCamera then
	end
end )


hook.Add("VRMod_Pickup", "vrmod_camera_block_pickup", function(player, ent)
	if ent:GetClass() == "vrmod_camera" then return false end
	return true
end )