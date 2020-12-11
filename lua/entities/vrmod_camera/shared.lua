AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "VRMod Camera"
ENT.Category = "VR"
ENT.Spawnable = true

-- local WallAvoid = 10
-- local SafeZoneSquared = 25
-- local MaxAngleDeviation = 30
-- If you get this close to a wall, the camera tracks you, not down range
-- local NearWallZoneSqr = 5000

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "On" )
	self:NetworkVar( "Vector", 0, "vecTrack" )
	self:NetworkVar( "Entity", 0, "entTrack" )
	self:NetworkVar( "Entity", 1, "Player" )

	if SERVER then
		util.AddNetworkString("vrmod_camera_start")
		util.AddNetworkString("vrmod_camera_stop")
		util.AddNetworkString("vrmod_camera_created")
	end
	if CLIENT then
	end

end

function ENT:SetMode(val)
	self.mode = val
	if val == 2 then

	end
end

function ENT:SetFlyDist(val)
	if val == 1 then
		self.flydist = 50
		self.shoulderOffset = 25
		self.shoulderHeight = 10
		self.shoulderYaw = 5
		self.shoulderPitchDown = 13
	elseif val == 2 then
		self.flydist = 75
		self.shoulderOffset = 35
		self.shoulderHeight = 10
		self.shoulderYaw = 5
		self.shoulderPitchDown = 15
	else
		self.flydist = 100
		self.shoulderOffset = 45
		self.shoulderHeight = 20
		self.shoulderYaw = 10
		self.shoulderPitchDown = 20
	end

	if self.lefty then
		self.shoulderOffset = -self.shoulderOffset
		self.shoulderYaw = -self.shoulderYaw
	end
end

function ENT:SetSmoothing(val)
	if val > 0 then
		self.smoothing = 50 / val
	else
		self.smoothing = 0
	end
end

function ENT:SetStabilize(val)
	self.stabilize = val
end

function ENT:SetDraw(val)
	self.draw = val
	if not val then
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
	end
end

function ENT:SetTracking( Ent, LPos )

	if ( IsValid( Ent ) ) then

		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_BBOX )

	else

		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )

	end

	self:NextThink( CurTime() )

	self:SetvecTrack( LPos )
	self:SetentTrack( Ent )

end

function ENT:SetLocked( locked )

	if ( locked ) then
		self.PhysgunDisabled = true
	else

		self.PhysgunDisabled = false

	end

	self.locked = locked

end

function ENT:TrackEntity( ent, lpos )

	if ( !IsValid( ent ) ) then return end

	local WPos = ent:LocalToWorld( lpos )

	if ( ent:IsPlayer() ) then
		WPos = WPos + ent:GetViewOffset() * 0.85
	end

	local CamPos = self:GetPos()
	local Ang = WPos - CamPos

	Ang = Ang:Angle()
	self:SetAngles( Ang )

end
