include("shared.lua")

local CameraScreen = nil

CreateConVar( "vrmod_camera_track", "1", FCVAR_ARCHIVE, "Should cameras track the player?" )
CreateConVar( "cl_drawcameras", "1", FCVAR_ARCHIVE, "Should cameras be drawn?" )
CreateConVar( "vrmod_camera_lock", "1", FCVAR_ARCHIVE, "Should cameras movable?" )
CreateConVar( "vrmod_camera_fpp", "0", FCVAR_ARCHIVE, "VRMod Camera is first-person perspective" )
CreateConVar( "vrmod_camera_mode", "2", FCVAR_ARCHIVE, "VRMod Camera perspective" )
CreateConVar( "vrmod_camera_smoothing", "10", FCVAR_ARCHIVE, "VRMod Camera smoothing" )
CreateConVar( "vrmod_camera_stabilize", "1", FCVAR_ARCHIVE, "Limit roll on VRMod Camera" )
CreateConVar( "vrmod_camera_flydist", "1", FCVAR_ARCHIVE, "Distance to fly from player" )
CreateConVar( "vrmod_camera_autospawn", "0", FCVAR_ARCHIVE, "Create the camera automatically" )
CreateConVar( "vrmod_camera_draw", "1", FCVAR_ARCHIVE, "Draw VRMod cameras" )
CreateConVar( "vrmod_camera_lefty", "0", FCVAR_ARCHIVE, "Fly behind the left shoulder" )

function ENT:Draw( flags )
	if ( GetConVarNumber( "cl_drawcameras" ) == 0 ) then return end
	self:DrawModel( flags )
end

-- Hide models that would be rendered twice
local function VRCamHideWModels(val)
	if val == true and GetConVar("vrutil_useworldmodels"):GetString("vrutil_useworldmodels", 0) == 1 then return end
	local weps = LocalPlayer().GetWeapons and LocalPlayer():GetWeapons()
	if weps then
		for i=1, #weps do
			weps[i]:SetNoDraw(val)
		end
	end
end

local function CamData()
	return {
		locked = GetConVar("vrmod_camera_lock"):GetBool();
		mode = GetConVar("vrmod_camera_mode"):GetInt();
		smoothing = GetConVar("vrmod_camera_smoothing"):GetInt();
		stabilize = GetConVar("vrmod_camera_stabilize"):GetBool();
		flydist = GetConVar("vrmod_camera_flydist"):GetInt();
		draw = GetConVar("vrmod_camera_draw"):GetBool();
		lefty = GetConVar("vrmod_camera_lefty"):GetBool();
	}
end

local function CreateWithSettings(d)
	net.Start("vrmod_camera_create")
	net.WriteBool(d["locked"])
	net.WriteInt(d["mode"], 8)
	net.WriteInt(d["smoothing"], 8)
	net.WriteBool(d["stabilize"])
	net.WriteInt(d["flydist"], 8)
	net.WriteBool(d["draw"])
	net.WriteBool(d["lefty"])
	net.SendToServer()
end

local function CreateWithCurrentSettings()
	CreateWithSettings(CamData())
end

local function NextCameraId()
	local cams = LocalPlayer().VRModCameras

	for i = 1,#cams do
		if not IsValid(cams[i]) then
			return i
		end
	end

	return #cams+1
end

local function IsCameraSpawned()
	if not LocalPlayer().VRModCameras then
		return false
	end

	return #LocalPlayer().VRModCameras > 0
end

local function StopCamera()
	if IsValid(CameraScreen) then
		CameraScreen:Close()
	end

	if not IsCameraSpawned() then
		LocalPlayer().UsingCamera = nil
		hook.Remove("ShouldDrawLocalPlayer","vrcamera_shoulddrawlocalplayer")
	end

	hook.Remove("VRUtilEventPreRender","vrcamera_prerender")
	hook.Remove("VRUtilEventPreRenderRight","vrcamera_prerenderright")
	hook.Remove("VRUtilEventPostRender", "vrcamera_vrpostrender")
end

local function StartCamera()
	local wmOn = GetConVar("vrmod_useworldmodels"):GetString("vrmod_useworldmodels", 0)
	local camera = LocalPlayer().UsingCamera

	if not IsCameraSpawned() then
		print("No cameras to start >~< spawn some!")
		return
	end

	if not IsValid(camera) then
		camera = LocalPlayer().VRModCameras[1]
	end

	local overlay = {}

	vgui.Register( "VRCameraOverlay", overlay, "Panel" )
	hook.Add("VRUtilEventPreRenderRight","vrcamera_prerenderright", function() VRCamHideWModels(wmOn) end)
	hook.Add("VRUtilEventPreRender","vrcamera_vrprerender", function()
		if wmOn == 1 then return end
		VRCamHideWModels(wmOn)
	end )

	-- BUG - Cannot restore hook once removed!
	hook.Remove("ShouldDrawLocalPlayer", "vrutil_hook_shoulddrawlocalplayer")
	hook.Add("ShouldDrawLocalPlayer","vrcamera_shoulddrawlocalplayer", function() return true end)
	hook.Add("VRUtilEventPostRender", "vrcamera_vrpostrender", function() VRCamHideWModels(false) end)

	-- LocalPlayer().UsingCamera = camera
	camera.UsingPlayer = LocalPlayer()

	CameraScreen = vgui.Create( "DFrame", overlay )
	CameraScreen:SetSize( ScrW(), ScrH() )
	CameraScreen:SetScreenLock(true)
	CameraScreen:ShowCloseButton(false)
	CameraScreen:Dock(FILL)
	CameraScreen:SetTitle("")

	function CameraScreen:Paint( w, h )
		local camera = LocalPlayer().UsingCamera
		if not IsCameraSpawned() or not camera or not g_VR.active then
			self:Close()
			StopCamera()
			return
		end

		if not camera or not camera:IsValid() then
			local t = LocalPlayer().VRModCameras
			LocalPlayer().UsingCamera = t[#t]
			return
		end

		local x, y = self:GetPos()
		-- local vrcam_fov = vrcamera_fov:GetInt("vrcam_fov", 100)
		local vrcam_fov = 100

		render.RenderView( {
			origin = camera:GetPos() + camera:GetAngles():Forward() * 5,
			angles = camera:GetAngles(),
			fov = vrcam_fov,
			znear = 5,
			x = x, y = y,
			w = w, h = h,
			dopostprocess = true,
			bloomtone = false
		} )
	end
end

net.Receive("vrmod_camera_created", function()
	local camera = net.ReadEntity()

	if not LocalPlayer().VRModCameras then
		LocalPlayer().VRModCameras = {}
	end

	if not IsValid(camera) then
		print("Bad camera... :(")
		return
	end

	camera.CameraId = NextCameraId()
	table.insert(LocalPlayer().VRModCameras, camera)

	if not vrmod then return end

	if not IsValid(LocalPlayer().UsingCamera) then
		LocalPlayer().UsingCamera = camera
		if vrmod.IsPlayerInVR() then
			StartCamera()
		end
	end
end )

local function CameraById(id)
	if not LocalPlayer().VRModCameras then
		return nil
	end

	for k, v in pairs(LocalPlayer().VRModCameras) do
		if v.CameraId == id then
			return v
		end
	end

	return nil
end

local function CreateMenu()
	local frame = vgui.Create("DFrame")
	frame:SetTitle("VRMod Camera Controller")
	frame.btnMinim:SetVisible(false)
	frame.btnMaxim:SetVisible(false)

	frame:SetSize(520, 400)

	local modeList = vgui.Create("DListView", frame)
	modeList:SetMultiSelect( false )
	modeList:AddColumn("Movement")
	modeList:AddLine("No movement (static)")
	modeList:AddLine("Third-person (fly-behind)")
	modeList:AddLine("First-person (smoothed)")
	modeList:SetPos(5, 30)
	modeList:SetSize(180, 70)
	modeList:SelectItem(modeList:GetLine(GetConVar("vrmod_camera_mode"):GetInt()))
	modeList.OnRowSelected = function(_, index, row)
		GetConVar("vrmod_camera_mode"):SetInt(index)
	end

	local distList = vgui.Create("DListView", frame)
	distList:SetMultiSelect( false )
	distList:AddColumn("Follow Distance")
	distList:AddLine("Near")
	distList:AddLine("Middle")
	distList:AddLine("Far")
	distList:SetPos(200, 30)
	distList:SetSize(150, 70)
	distList:SelectItem(distList:GetLine(GetConVar("vrmod_camera_flydist"):GetInt()))
	distList.OnRowSelected = function(_, index, row)
		GetConVar("vrmod_camera_flydist"):SetInt(index)
	end

	local smoothSlider = vgui.Create("DNumSlider", frame)
	smoothSlider:SetMax(50)
	smoothSlider:SetMin(0)
	smoothSlider:SetSize(400, 50)
	smoothSlider:SetPos(-160, 120)
	smoothSlider:SetDecimals(0)
	smoothSlider:SetValue(GetConVar("vrmod_camera_smoothing"):GetInt())
	smoothSlider.OnValueChanged = function(_, s)
		GetConVar("vrmod_camera_smoothing"):SetInt(s)
	end

	local smoothLabel = vgui.Create("DLabel", frame)
	smoothLabel:SetPos(5, 110)
	smoothLabel:SetText("Smoothing")

	local drawLabel = vgui.Create("DLabel", frame)
	drawLabel:SetPos(385, 30)
	drawLabel:SetSize(100, 20)
	drawLabel:SetText("Draw Camera")

	local drawCheckbox = vgui.Create("DCheckBox", frame)
	drawCheckbox:SetPos(360, 33)
	drawCheckbox:SetChecked(GetConVar("vrmod_camera_draw"):GetBool())
	drawCheckbox.OnChange = function(_, check)
		GetConVar("vrmod_camera_draw"):SetBool(check)
	end

	local stabilizeLabel = vgui.Create("DLabel", frame)
	stabilizeLabel:SetPos(385, 50)
	stabilizeLabel:SetSize(100, 20)
	stabilizeLabel:SetText("Stabilize")

	local stabilizeCheckbox = vgui.Create("DCheckBox", frame)
	stabilizeCheckbox:SetPos(360, 53)
	stabilizeCheckbox:SetChecked(GetConVar("vrmod_camera_stabilize"):GetBool())
	stabilizeCheckbox.OnChange = function(_, check)
		GetConVar("vrmod_camera_stabilize"):SetBool(check)
	end

	local leftyLabel = vgui.Create("DLabel", frame)
	leftyLabel:SetPos(385, 70)
	leftyLabel:SetSize(100, 20)
	leftyLabel:SetText("Lefty")

	local leftyCheckbox = vgui.Create("DCheckBox", frame)
	leftyCheckbox:SetPos(360, 73)
	leftyCheckbox:SetChecked(GetConVar("vrmod_camera_lefty"):GetBool())
	leftyCheckbox.OnChange = function(_, check)
		GetConVar("vrmod_camera_lefty"):SetBool(check)
	end

	local camerasList = vgui.Create("DListView", frame)
	camerasList:SetMultiSelect(false)
	camerasList:AddColumn("Camera Id")
	camerasList:SetPos(5, 170)
	camerasList:SetSize(70, 120)

	camerasList.OnRowSelected = function(_, i, row)
		if LocalPlayer().UsingCamera then
			hook.Remove("PreDrawHalos", "CameraHalo")
		end

		local oldCamera = LocalPlayer().UsingCamera
		local newCamera = CameraById(row:GetColumnText(1))

		if newCamera then
			LocalPlayer().UsingCamera = newCamera
			if not oldCamera then
				StartCamera()
			end

			hook.Add( "PreDrawHalos", "CameraHalo", function()
				halo.Add({LocalPlayer().UsingCamera}, Color(0, 255, 0 ), 5, 5, 2)
			end )
		end
	end

	if LocalPlayer().VRModCameras then
		for _, v in pairs(LocalPlayer().VRModCameras) do
			camerasList:AddLine(v.CameraId)
		end
	end

	if IsValid(LocalPlayer().UsingCamera) then
		camerasList:SelectItem(camerasList:GetLine(LocalPlayer().UsingCamera.CameraId))
	end

	local cameraDeselect = vgui.Create("DButton", frame)
	cameraDeselect:SetText("Unset")
	cameraDeselect:SetPos(5, 290)
	cameraDeselect:SetSize(70, 20)
	cameraDeselect.DoClick = function(me)
		camerasList:ClearSelection()
		LocalPlayer().UsingCamera = nil
	end

	local startButton = vgui.Create("DButton", frame)
	startButton:SetText("Spawn")
	startButton:SetPos(5, 370)
	startButton:SetSize(60, 20)
	startButton.DoClick = function(me)

		local d = CamData()

		local locked = true;
		local mode, _ = modeList:GetSelectedLine()
		local dist = distList:GetSelectedLine()
		local smoothing = smoothSlider:GetValue()
		local stabilize = stabilizeCheckbox:GetChecked()
		local draw = drawCheckbox:GetChecked()

		if mode == nil then return end
		if mode == 2 and dist == nil then return end

		-- Update convars
		GetConVar("vrmod_camera_lock"):SetBool(locked)
		GetConVar("vrmod_camera_mode"):SetInt(mode)
		GetConVar("vrmod_camera_smoothing"):SetInt(smoothing)
		GetConVar("vrmod_camera_stabilize"):SetBool(stabilize)
		GetConVar("vrmod_camera_flydist"):SetInt(dist)
		GetConVar("vrmod_camera_draw"):SetBool(draw)

		CreateWithCurrentSettings()

		me:GetParent():Close()
	end

	local removeButton = vgui.Create("DButton", frame)
	removeButton:SetText("Remove")
	removeButton:SetPos(75, 370)
	removeButton:SetSize(60, 20)
	removeButton.DoClick = function(me)
		local selected = LocalPlayer().UsingCamera
		if selected then
			table.remove(LocalPlayer().VRModCameras, selected.CameraId)
			table.sort(LocalPlayer().VRModCameras)
			for _, v in pairs(LocalPlayer().VRModCameras) do
				if v.CameraId > selected.CameraId then
					v.CameraId = v.CameraId - 1
				end
			end

			net.Start("vrmod_camera_remove")
			net.WriteEntity(selected)
			net.SendToServer()
		end

		me:GetParent():Close()
	end

	frame.OnClose = function()
		hook.Remove("PreDrawHalos", "CameraHalo")
	end

	return frame
end

local function ShowMenu(camera)
	local frame = CreateMenu()
	frame:Center()
	frame:SetVisible(true)
	frame:MakePopup()
end

hook.Add("VRMod_Start", "vrmod_camera_autospawn", function()
	if not GetConVar("vrmod_camera_autospawn"):GetBool() then return end

	if not IsCameraSpawned() then
		CreateWithCurrentSettings()
	end
end )

hook.Add("VRMod_Start", "vrmod_camera_startwhenvrmod", function()
	if IsCameraSpawned() then
		StartCamera()
	end
end )

hook.Add("VRMod_Exit", "vrmod_camera_stopwhenvrmod", function()
	if IsCameraSpawned() then
		StopCamera()
		hook.Remove("ShouldDrawLocalPlayer","vrcamera_shoulddrawlocalplayer")
	end
end )

concommand.Add("vrmod_camera_menu", function()
	local c = LocalPlayer().UsingCamera
	if c then ShowMenu(c)
	else ShowMenu() end
end, nil, "Control your VRMod camera")

concommand.Add("vrmod_camera_switch", function(_, _, args)
	local i = math.abs(args[1])
	if not i then return end

	if not LocalPlayer().VRModCameras then
		return nil
	end

	for k, v in pairs(LocalPlayer().VRModCameras) do
		if v.CameraId == i then
			LocalPlayer().UsingCamera = v
		end
	end
end, nil, "Control your VRMod camera")

vrmod.AddInGameMenuItem("Camera Settings", 4, 1, function()
	local panel = CreateMenu()
	panel:Center()

	local ang = Angle(0,g_VR.tracking.hmd.ang.yaw-90,45)
	local pos = g_VR.tracking.hmd.pos + Vector(0,0,-20) + Angle(0,g_VR.tracking.hmd.ang.yaw,0):Forward()*30 + ang:Forward()*ScrW()*-0.02 + ang:Right()*ScrH()*-0.02
	pos, ang = WorldToLocal(pos, ang, g_VR.origin, g_VR.originAngle)
	VRUtilMenuOpen("camerasettings", ScrW(), ScrH(), panel, 4, pos, ang, 0.04, true, function()
		if IsValid(panel) then
			panel:Close()
		end
	end )
end )