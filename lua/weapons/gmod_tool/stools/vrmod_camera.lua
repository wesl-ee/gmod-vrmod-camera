TOOL.Category = "Render"
TOOL.Name = "VRMod Camera"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then

	TOOL.Information = {

		{ name = "info", stage = 1 },
		{ name = "left" },
		{ name = "right" },

	}

	language.Add( "tool.vrmod_camera.name", "VRMod Camera" )
	language.Add( "tool.vrmod_camera.desc", "Cameras for VRMod" )
	language.Add( "tool.vrmod_camera.right", "Clear Camera" )
	language.Add( "tool.vrmod_camera.1", "See information in the context menu" )
	language.Add( "tool.vrmod_camera.left", "Create a VRMod Camera" )

end

function TOOL:LeftClick( trace )
	local ply = self:GetOwner()

	local camData = {
		locked = GetConVar("vrmod_camera_lock"):GetBool();
		mode = GetConVar("vrmod_camera_mode"):GetInt();
		smoothing = GetConVar("vrmod_camera_smoothing"):GetInt();
		stabilize = GetConVar("vrmod_camera_stabilize"):GetBool();
		flydist = GetConVar("vrmod_camera_flydist"):GetInt();
	}

	local ent = ply.VRModCamera
	if IsValid(ent) then
		UpdateCamera(ply, camData, { Pos = trace.StartPos, Angle = ply:EyeAngles() })
		return true, ent
	end

	ent = MakeCamera( ply, camData, { Pos = trace.StartPos, Angle = ply:EyeAngles() } )

	undo.Create( "VRMod Camera" )
		undo.AddEntity( ent )
		undo.SetPlayer( ply )
	undo.Finish()

	return true, ent

end

function TOOL:RightClick()
	local ply = self:GetOwner()

	ClearCamera(ply)
end

function ClearCamera(ply)
	if not IsValid(ply) then return false end

	for id, camera in pairs( ents.FindByClass( "vrmod_camera" ) ) do
		if ( IsValid( ply ) && IsValid( camera:GetPlayer() ) && ply != camera:GetPlayer() ) then continue end
		camera:Remove()
	end
end

function TOOL.BuildCPanel(panel)
	-- panel:AddControl( "CheckBox", { Label = "Track Player", Command = "vrmod_camera_track" } )
	panel:AddControl( "CheckBox", { Label = "Lock Cameras", Command = "vrmod_camera_lock" } )
	panel:AddControl( "ListBox", { Label = "Camera Mode", Options = {
		["Static Mode"] = { vrmod_camera_mode = 1 };
		["Fly-behind"] = { vrmod_camera_mode = 2 };
		["First-person Smoothed"] = { vrmod_camera_mode = 3 }; } } )
	panel:AddControl("Slider", {
		Label = "Smoothing",
		Type = "Int",
		Min = "0",
		Max = "50",
		Command = "vrmod_camera_smoothing"
	})
	panel:AddControl( "ListBox", { Label = "Flying Distance", Options = {
		["Near"] = { vrmod_camera_flydist = 1 };
		["Middle"] = { vrmod_camera_flydist = 2 };
		["Far"] = { vrmod_camera_flydist = 3 }; } } )
	panel:AddControl( "CheckBox", { Label = "Stabilize Camera", Command = "vrmod_camera_stabilize" } )
end

function TOOL:DrawToolScreen( width, height )
	-- Draw black background
	surface.SetDrawColor( Color( 20, 20, 20 ) )
	surface.DrawRect( 0, 0, width, height )
	
	-- Draw white text in middle
	draw.SimpleText( "VRMod Camera", "DermaLarge", width / 2, height / 2, Color( 200, 200, 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end
duplicator.RegisterEntityClass( "vrmod_camera", MakeCamera, "controlkey", "locked", "toggle", "Data" )