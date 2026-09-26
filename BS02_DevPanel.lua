--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	while not Players.LocalPlayer do task.wait() end
	LocalPlayer = Players.LocalPlayer
end

local WHITELIST: { [number]: boolean } = {
	[@vazo_sn] = true,
}

if not WHITELIST[LocalPlayer.UserId] then
	warn("[БЕЗОПАСНОСТЬ]: Доступ заблокирован.")
	return
end

type StateType = {
	Fly: boolean, FlySpeed: number, Noclip: boolean, SpeedHack: boolean, WalkSpeed: number,
	JumpHack: boolean, JumpPower: number, InfJump: boolean, NoFall: boolean,
	CustomFOV: boolean, FOVValue: number, ThirdPerson: boolean, Fullbright: boolean,
	NoFog: boolean, XRay: boolean, ESP: boolean,
	Crosshair: boolean, NoRecoil: boolean, RapidFire: boolean, AimAssist: boolean,
	GodMode: boolean, AntiAFK: boolean,
	FlyUpKey: Enum.KeyCode, FlyDownKey: Enum.KeyCode, PanicKey: Enum.KeyCode,
}

_G.CheatState = {
	Fly = false, FlySpeed = 50, Noclip = false, SpeedHack = false, WalkSpeed = 16,
	JumpHack = false, JumpPower = 50, InfJump = false, NoFall = false,
	CustomFOV = false, FOVValue = 70, ThirdPerson = false, Fullbright = false,
	NoFog = false, XRay = false, ESP = false,
	Crosshair = false, NoRecoil = false, RapidFire = false, AimAssist = false,
	GodMode = false, AntiAFK = false,
	FlyUpKey = Enum.KeyCode.Space, FlyDownKey = Enum.KeyCode.LeftControl, PanicKey = Enum.KeyCode.End,
}
local State: StateType = _G.CheatState

_G.OriginalLighting = { Ambient = Lighting.Ambient, GlobalShadows = Lighting.GlobalShadows, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd }
_G.OriginalCameraProperties = { FieldOfView = 70, CameraMaxZoomDistance = 12.5, CameraMode = Enum.CameraMode.Classic }
_G.CheatConnections = {}
_G.ESPPool = {}

local NotificationGui = Instance.new("ScreenGui")
NotificationGui.Name = "NotificationSystem_Roblox"
NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
NotificationGui.DisplayOrder = 1000
pcall(function() NotificationGui.Parent = CoreGui end)
if not NotificationGui.Parent then NotificationGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local NotificationContainer = Instance.new("Frame")
NotificationContainer.Size = UDim2.new(1, 0, 0, 200)
NotificationContainer.Position = UDim2.new(0, 0, 1, -220)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.Parent = NotificationGui

local NotificationLayout = Instance.new("UIListLayout")
NotificationLayout.FillDirection = Enum.FillDirection.Vertical
NotificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
NotificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotificationLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotificationLayout.Padding = UDim.new(0, 8)
NotificationLayout.Parent = NotificationContainer

function _G.Notify(text: string)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 300, 0, 35)
	toast.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	toast.BackgroundTransparency = 1
	
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(90, 90, 130)
	stroke.Transparency = 1
	stroke.Parent = toast
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = toast
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(240, 240, 245)
	label.TextSize = 13
	label.Text = text
	label.TextTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = toast
	
	toast.Parent = NotificationContainer
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
	
	task.delay(2, function()
		local t1 = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
		local t2 = TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1})
		local t3 = TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
		t1:Play(); t2:Play(); t3:Play()
		t1.Completed:Connect(function() toast:Destroy() end)
	end)
end
_G.Notify("Часть 1 загружена")
-- ЧАСТЬ 2 (ОСНОВА GUI)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AdvancedExploitPanel_Luau"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
_G.MainScreenGui = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 420)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
MainFrame.BackgroundTransparency = 0.05

local SavedPos = game:GetService("Players").LocalPlayer:GetAttribute("Panel_PositionOffset")
if SavedPos and typeof(SavedPos) == "Vector2" then
	MainFrame.Position = UDim2.new(0, SavedPos.X, 0, SavedPos.Y)
else
	MainFrame.Position = UDim2.new(0.5, -130, 0.4, -210)
end
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.Color = Color3.fromRGB(70, 70, 100)
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 5)
HeaderFix.Position = UDim2.new(0, 0, 1, -5)
HeaderFix.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 12)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "EXPLORER TOOLKIT v4.0"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextColor3 = Color3.fromRGB(230, 230, 250)
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -35, 0, 2)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Text = "—"
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextColor3 = Color3.fromRGB(150, 150, 180)
MinimizeBtn.TextSize = 14
MinimizeBtn.Parent = Header

local FastOpenBtn = Instance.new("TextButton")
FastOpenBtn.Size = UDim2.new(0, 40, 0, 40)
FastOpenBtn.Position = UDim2.new(0, 15, 0, 15)
FastOpenBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
FastOpenBtn.Visible = false
FastOpenBtn.Text = "BS"
FastOpenBtn.Font = Enum.Font.GothamBold
FastOpenBtn.TextColor3 = Color3.fromRGB(60, 180, 90)
FastOpenBtn.TextSize = 14
FastOpenBtn.Parent = ScreenGui
_G.FastOpenBtn = FastOpenBtn

local FastOpenCorner = Instance.new("UICorner")
FastOpenCorner.CornerRadius = UDim.new(0, 6)
FastOpenCorner.Parent = FastOpenBtn

local FastOpenStroke = Instance.new("UIStroke")
FastOpenStroke.Thickness = 1.5
FastOpenStroke.Color = Color3.fromRGB(70, 70, 100)
FastOpenStroke.Parent = FastOpenBtn

local Dragging = false
local DragInput: InputObject? = nil
local DragStart = Vector3.new()
local StartPosition = UDim2.new()

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		Dragging = true; DragStart = input.Position; StartPosition = MainFrame.Position
		input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then Dragging = false end end)
	end
end)

Header.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then DragInput = input end end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
	if input == DragInput and Dragging then
		local delta = input.Position - DragStart
		local newPos = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + delta.Y)
		MainFrame.Position = newPos
		game:GetService("Players").LocalPlayer:SetAttribute("Panel_PositionOffset", Vector2.new(newPos.X.Offset, newPos.Y.Offset))
	end
end)

MinimizeBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; FastOpenBtn.Visible = true; _G.Notify("Панель свернута") end)
FastOpenBtn.MouseButton1Click:Connect(function() FastOpenBtn.Visible = false; MainFrame.Visible = true; _G.Notify("Панель развернута") end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 30)
TabBar.Position = UDim2.new(0, 0, 0, 35)
TabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local TabBarLayout = Instance.new("UIListLayout")
TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
TabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabBarLayout.Parent = TabBar

local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -10, 1, -75)
PagesContainer.Position = UDim2.new(0, 5, 0, 70)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

_G.CheatPages = {}
local Pages = _G.CheatPages
local TabButtons = {}
local TabNames = {"Движение", "Визуал", "Бой", "Опции"}

local function SwitchToTab(targetTab: string)
	for name, page in pairs(Pages) do page.Visible = (name == targetTab) end
	for name, btn in pairs(TabButtons) do
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if name == targetTab then
			btn.TextColor3 = Color3.fromRGB(250, 250, 250)
			if stroke then stroke.Color = Color3.fromRGB(60, 180, 90) end
		else
			btn.TextColor3 = Color3.fromRGB(130, 130, 160)
			if stroke then stroke.Color = Color3.fromRGB(45, 45, 65) end
		end
	end
end

for i, name in ipairs(TabNames) do
	local tBtn = Instance.new("TextButton")
	tBtn.Size = UDim2.new(0, 260 / #TabNames, 1, 0)
	tBtn.BackgroundTransparency = 1
	tBtn.Text = name
	tBtn.Font = Enum.Font.GothamBold
	tBtn.TextSize = 11
	tBtn.LayoutOrder = i
	tBtn.Parent = TabBar
	
	local tStroke = Instance.new("UIStroke")
	tStroke.Thickness = 1
	tStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tStroke.Parent = tBtn
	TabButtons[name] = tBtn
	
	local scrFrame = Instance.new("ScrollingFrame")
	scrFrame.Size = UDim2.new(1, 0, 1, 0)
	scrFrame.BackgroundTransparency = 1
	scrFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
	scrFrame.ScrollBarThickness = 2
	scrFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 100)
	scrFrame.Visible = false
	scrFrame.Parent = PagesContainer
	
	local scrLayout = Instance.new("UIListLayout")
	scrLayout.FillDirection = Enum.FillDirection.Vertical
	scrLayout.Padding = UDim.new(0, 6)
	scrLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrLayout.Parent = scrFrame
	Pages[name] = scrFrame
	
	tBtn.MouseButton1Click:Connect(function() SwitchToTab(name) end)
end
SwitchToTab("Движение")
_G.Notify("Основа GUI готова")
-- ЧАСТЬ 3 (ИНТЕРАКТИВНЫЕ ЭЛЕМЕНТЫ)
_G.ElementFactory = {}
local ElementFactory = _G.ElementFactory

function ElementFactory.CreateToggle(parent: Instance, text: string, stateKey: string, callback: (boolean) -> ())
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -4, 0, 32)
	f.BackgroundTransparency = 1
	f.Parent = parent
	
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 160, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f
	
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 45, 0, 22)
	btn.Position = UDim2.new(1, -50, 0.5, -11)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	btn.Text = ""
	btn.Parent = f
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn
	
	local targetTable = _G.CheatState
	local function updateVisual(s: boolean)
		game:GetService("TweenService"):Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundColor3 = s and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(45, 45, 65) }):Play()
	end
	
	btn.MouseButton1Click:Connect(function()
		targetTable[stateKey] = not targetTable[stateKey]
		updateVisual(targetTable[stateKey])
		callback(targetTable[stateKey])
	end)
	
	f:SetAttribute("RefreshToggle", true)
	f.AttributeChanged:Connect(function() updateVisual(targetTable[stateKey]) end)
end

function ElementFactory.CreateSlider(parent: Instance, text: string, min: number, max: number, default: number, stateKey: string, callback: (number) -> ())
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -4, 0, 45)
	f.BackgroundTransparency = 1
	f.Parent = parent
	
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Text = text .. ": " .. tostring(default)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f
	
	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -10, 0, 6)
	sliderBg.Position = UDim2.new(0, 0, 0, 24)
	sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = f
	
	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	sliderFill.BackgroundColor3 = Color3.fromRGB(70, 130, 230)
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg
	
	local targetTable = _G.CheatState
	local snap = false
	
	local function updateFromInput(input: InputObject)
		local absPos = sliderBg.AbsolutePosition
		local absSize = sliderBg.AbsoluteSize
		local percentage = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
		local val = math.round(min + (percentage * (max - min)))
		sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
		lbl.Text = text .. ": " .. tostring(val)
		targetTable[stateKey] = val
		callback(val)
	end
	
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then snap = true; updateFromInput(input) end
	end)
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if snap and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateFromInput(input) end
	end)
	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then snap = false end
	end)
end

function ElementFactory.CreateKeybind(parent: Instance, text: string, stateKey: string)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -4, 0, 32)
	f.BackgroundTransparency = 1
	f.Parent = parent
	
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 140, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f
	
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 70, 0, 22)
	btn.Position = UDim2.new(1, -75, 0.5, -11)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	
	local targetTable = _G.CheatState
	btn.Text = tostring(targetTable[stateKey].Name)
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = Color3.fromRGB(220, 220, 220)
	btn.TextSize = 10
	btn.Parent = f
	
	local listening = false
	btn.MouseButton1Click:Connect(function() listening = true; btn.Text = "..."; btn.BackgroundColor3 = Color3.fromRGB(90, 40, 40) end)
	game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			listening = false
			targetTable[stateKey] = input.KeyCode
			btn.Text = tostring(input.KeyCode.Name)
			btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
			_G.Notify("Хоткей изменен на " .. input.KeyCode.Name)
		end
	end)
end
_G.Notify("Элементы интерфейса созданы")
-- ЧАСТЬ 4 (ДВИЖЕНИЕ И ВИЗУАЛ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local State = _G.CheatState
local Connections = _G.CheatConnections
local ESPPool = _G.ESPPool

local FlyVelocity: BodyVelocity? = nil

local function Disconnect(name: string)
	if Connections[name] then Connections[name]:Disconnect(); Connections[name] = nil end
end

local function GetCharacterData()
	local char = LocalPlayer.Character
	if not char then return nil, nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return char, hum, hrp
end

function _G.ClearESP()
	for p, gui in pairs(ESPPool) do pcall(function() gui:Destroy() end) end
	table.clear(ESPPool)
end

local function ManageESP()
	if not State.ESP then _G.ClearESP(); return end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and not ESPPool[p] then
			local head = p.Character:FindFirstChild("Head")
			if head then
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.new(0, 150, 0, 40)
				bb.AlwaysOnTop = true
				bb.ExtentsOffset = Vector3.new(0, 2.5, 0)
				local txt = Instance.new("TextLabel")
				txt.Size = UDim2.new(1, 0, 1, 0)
				txt.BackgroundTransparency = 1
				txt.Font = Enum.Font.GothamBold
				txt.TextSize = 10
				txt.TextColor3 = Color3.fromRGB(255, 60, 60)
				txt.TextStrokeTransparency = 0
				txt.Parent = bb
				bb.Adornee = head; bb.Parent = head; ESPPool[p] = bb
			end
		end
	end
end

function _G.ResetXRay()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("OldTrans") then
			obj.Transparency = obj:GetAttribute("OldTrans")
			obj:SetAttribute("OldTrans", nil)
		end
	end
end

function _G.ApplyXRay()
	if not State.XRay then _G.ResetXRay(); return end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not (LocalPlayer.Character and obj:IsDescendantOf(LocalPlayer.Character)) then
			if not obj:GetAttribute("OldTrans") then obj:SetAttribute("OldTrans", obj.Transparency) end
			obj.Transparency = 0.7
		end
	end
end

function _G.ResetCharacterPhysics()
	local _, hum, _ = GetCharacterData()
	if hum then hum.PlatformStand = false; hum.WalkSpeed = 16; hum.JumpPower = 50 end
	if FlyVelocity then FlyVelocity:Destroy(); FlyVelocity = nil end
end

function _G.RebindCharacterConnections()
	Disconnect("Heartbeat"); Disconnect("Stepped"); Disconnect("RenderStepped"); Disconnect("JumpRequest")
	_G.ResetCharacterPhysics()
	
	Connections["Heartbeat"] = RunService.Heartbeat:Connect(function(dt: number)
		local char, hum, hrp = GetCharacterData()
		if not char or not hum or not hrp then return end
		if State.SpeedHack then hum.WalkSpeed = State.WalkSpeed end
		if State.JumpHack then hum.JumpPower = State.JumpPower end
		if State.NoRecoil then hum.CameraOffset = Vector3.new(0, 0, 0) end
		
		if State.Fly then
			hum.PlatformStand = true
			if not FlyVelocity or FlyVelocity.Parent ~= hrp then
				if FlyVelocity then FlyVelocity:Destroy() end
				FlyVelocity = Instance.new("BodyVelocity")
				FlyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				FlyVelocity.Velocity = Vector3.new(0, 0, 0)
				FlyVelocity.Parent = hrp
			end
			local cam = Workspace.CurrentCamera
			if cam and FlyVelocity then
				local moveDir = Vector3.new(0,0,0)
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
				if UserInputService:IsKeyDown(State.FlyUpKey) then moveDir += Vector3.new(0, 1, 0) end
				if UserInputService:IsKeyDown(State.FlyDownKey) then moveDir -= Vector3.new(0, 1, 0) end
				local targetVel = moveDir.Magnitude > 0 and moveDir.Unit * State.FlySpeed or Vector3.new(0,0,0)
				FlyVelocity.Velocity = FlyVelocity.Velocity:Lerp(targetVel, math.clamp(dt * 10, 0, 1))
			end
		else
			if FlyVelocity then FlyVelocity:Destroy(); FlyVelocity = nil; hum.PlatformStand = false end
		end
		
		if State.RapidFire and char:FindFirstChildOfClass("Tool") then
			for _, obj in ipairs(char:FindFirstChildOfClass("Tool"):GetDescendants()) do
				if obj:IsA("NumberValue") or obj:IsA("IntValue") then
					local nameLower = string.lower(obj.Name)
					if string.find(nameLower, "cooldown") or string.find(nameLower, "delay") then obj.Value = 0.01
					elseif string.find(nameLower, "ammo") or string.find(nameLower, "clip") then if obj.Value < 30 then obj.Value = 999 end end
				end
			end
		end
	end)
	
	Connections["Stepped"] = RunService.Stepped:Connect(function()
		local char = LocalPlayer.Character
		if char and State.Noclip then
			for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
		end
	end)
	
	Connections["RenderStepped"] = RunService.RenderStepped:Connect(function()
		local char, hum, hrp = GetCharacterData()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		if State.CustomFOV then cam.FieldOfView = State.FOVValue end
		if State.ThirdPerson then LocalPlayer.CameraMaxZoomDistance = 10; LocalPlayer.CameraMode = Enum.CameraMode.Classic else LocalPlayer.CameraMaxZoomDistance = _G.OriginalCameraProperties.CameraMaxZoomDistance end
		
		if State.ESP then
			ManageESP()
			for p, gui in pairs(ESPPool) do
				if p.Character and p.Character:FindFirstChild("Humanoid") and p.Character:FindFirstChild("HumanoidRootPart") and hrp then
					local pHum = p.Character:FindFirstChild("Humanoid") :: Humanoid
					local dist = math.round((hrp.Position - (p.Character:FindFirstChild("HumanoidRootPart") :: BasePart).Position).Magnitude)
					local lbl = gui:FindFirstChildOfClass("TextLabel")
					if lbl then lbl.Text = string.format("%s\nHP: %d/%d\nДист: %dм", p.Name, math.max(0, pHum.Health), pHum.MaxHealth, dist) end
				else gui:Destroy(); ESPPool[p] = nil end
			end
		end
		
		if State.AimAssist and hrp and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			local targetHead: BasePart? = nil
			local closestDist = 100
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") and p.Character:FindFirstChild("HumanoidRootPart") then
					local pHead = p.Character:FindFirstChild("Head") :: BasePart
					local d = (hrp.Position - (p.Character:FindFirstChild("HumanoidRootPart") :: BasePart).Position).Magnitude
					if d < closestDist then
						local angle = math.acos(math.clamp(cam.CFrame.LookVector:Dot((pHead.Position - cam.CFrame.Position).Unit), -1, 1))
						if math.deg(angle) <= 30 then closestDist = d; targetHead = pHead end
					end
				end
			end
			if targetHead then cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetHead.Position), 0.15) end
		end
	end)
	
	Connections["JumpRequest"] = UserInputService.JumpRequest:Connect(function()
		local _, hum, _ = GetCharacterData()
		if hum and State.InfJump then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)
	
	if hum then
		Connections["HealthChanged"] = hum.HealthChanged:Connect(function(health)
			if State.NoFall and health < hum.MaxHealth and hum:GetState() == Enum.HumanoidStateType.Freefall then hum.Health = hum.MaxHealth; _G.Notify("Урон от падения заблокирован") end
		end)
	end
end

LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); _G.RebindCharacterConnections(); if State.XRay then _G.ApplyXRay() end end)
_G.RebindCharacterConnections()
_G.Notify("Механики движения настроены")
-- ЧАСТЬ 5 (ФИНАЛ: БОЙ, НАПОЛНЕНИЕ И ПАНИКА)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local State = _G.CheatState
local Pages = _G.CheatPages
local ElementFactory = _G.ElementFactory
local AFKTimer = tick()

-- Фоновые потоки выполнения тасков
task.spawn(function()
	while true do
		task.wait(0.1)
		if State.GodMode and game:GetService("Players").LocalPlayer.Character then
			local hum = game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = hum.MaxHealth end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(10)
		if State.AntiAFK and tick() - AFKTimer > 120 and game:GetService("Players").LocalPlayer.Character then
			local hrp = game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then hrp.CFrame = hrp.CFrame * CFrame.new(0, 0.1, 0); AFKTimer = tick() end
		end
	end
end)

-- Наполнение Вкладки: Движение
local pageMove = Pages["Движение"]
ElementFactory.CreateToggle(pageMove, "Полет (Fly)", "Fly", function(s) _G.Notify("Fly: " .. tostring(s)) end)
ElementFactory.CreateSlider(pageMove, "Скорость полета", 16, 250, 50, "FlySpeed", function(v) end)
ElementFactory.CreateToggle(pageMove, "Сквозь стены (Noclip)", "Noclip", function(s) _G.Notify("Noclip: " .. tostring(s)) end)
ElementFactory.CreateToggle(pageMove, "Спидхак (Speed)", "SpeedHack", function(s) _G.Notify("SpeedHack: " .. tostring(s)) end)
ElementFactory.CreateSlider(pageMove, "Значение скорости", 16, 500, 16, "WalkSpeed", function(v) end)
ElementFactory.CreateToggle(pageMove, "Высота прыжка", "JumpHack", function(s) _G.Notify("JumpHack: " .. tostring(s)) end)
ElementFactory.CreateSlider(pageMove, "Сила прыжка", 50, 300, 50, "JumpPower", function(v) end)
ElementFactory.CreateToggle(pageMove, "Бесконечный прыжок", "InfJump", function(s) _G.Notify("InfJump: " .. tostring(s)) end)
ElementFactory.CreateToggle(pageMove, "Анти-Урон от Падения", "NoFall", function(s) _G.Notify("NoFall: " .. tostring(s)) end)

-- Наполнение Вкладки: Визуал
local pageVisual = Pages["Визуал"]
ElementFactory.CreateToggle(pageVisual, "Кастомный FOV", "CustomFOV", function(s) if not s then Workspace.CurrentCamera.FieldOfView = _G.OriginalCameraProperties.FieldOfView end end)
ElementFactory.CreateSlider(pageVisual, "Угол обзора", 70, 120, 70, "FOVValue", function(v) end)
ElementFactory.CreateToggle(pageVisual, "Вид от 3-го лица", "ThirdPerson", function(s) if not s then game:GetService("Players").LocalPlayer.CameraMode = _G.OriginalCameraProperties.CameraMode; game:GetService("Players").LocalPlayer.CameraMaxZoomDistance = _G.OriginalCameraProperties.CameraMaxZoomDistance end end)
ElementFactory.CreateToggle(pageVisual, "Режим Fullbright", "Fullbright", function(s) if s then Lighting.Ambient = Color3.fromRGB(255, 255, 255); Lighting.GlobalShadows = false; Lighting.ClockTime = 14 else Lighting.Ambient = _G.OriginalLighting.Ambient; Lighting.GlobalShadows = _G.OriginalLighting.GlobalShadows; Lighting.ClockTime = _G.OriginalLighting.ClockTime end end)
ElementFactory.CreateToggle(pageVisual, "Убрать туман (NoFog)", "NoFog", function(s) Lighting.FogEnd = s and 100000 or _G.OriginalLighting.FogEnd end)
ElementFactory.CreateToggle(pageVisual, "Просвечивание стен (X-Ray)", "XRay", function(s) _G.ApplyXRay() end)
ElementFactory.CreateToggle(pageVisual, "Подсветка игроков (ESP)", "ESP", function(s) _G.ClearESP() end)

-- Наполнение Вкладки: Бой
local pageCombat = Pages["Бой"]
local CrosshairFrame1, CrosshairFrame2
ElementFactory.CreateToggle(pageCombat, "Статичный прицел", "Crosshair", function(s)
	if s then
		CrosshairFrame1 = Instance.new("Frame"); CrosshairFrame1.Size = UDim2.new(0, 20, 0, 2); CrosshairFrame1.Position = UDim2.new(0.5, -10, 0.5, -1); CrosshairFrame1.BackgroundColor3 = Color3.fromRGB(0, 255, 0); CrosshairFrame1.BorderSizePixel = 0; CrosshairFrame1.Parent = _G.MainScreenGui
		CrosshairFrame2 = Instance.new("Frame"); CrosshairFrame2.Size = UDim2.new(0, 2, 0, 20); CrosshairFrame2.Position = UDim2.new(0.5, -1, 0.5, -10); CrosshairFrame2.BackgroundColor3 = Color3.fromRGB(0, 255, 0); CrosshairFrame2.BorderSizePixel = 0; CrosshairFrame2.Parent = _G.MainScreenGui
	else if CrosshairFrame1 then CrosshairFrame1:Destroy() end; if CrosshairFrame2 then CrosshairFrame2:Destroy() end end
end)
ElementFactory.CreateToggle(pageCombat, "Анти-Отдача (No Recoil)", "NoRecoil", function(s) end)
ElementFactory.CreateToggle(pageCombat, "Быстрая стрельба / Авто", "RapidFire", function(s) end)
ElementFactory.CreateToggle(pageCombat, "Доводка камеры (Aim Assist)", "AimAssist", function(s) end)

-- Наполнение Вкладки: Опции
local pageOptions = Pages["Опции"]
ElementFactory.CreateKeybind(pageOptions, "Кнопка Полета Вверх", "FlyUpKey")
ElementFactory.CreateKeybind(pageOptions, "Кнопка Полета Вниз", "FlyDownKey")
ElementFactory.CreateKeybind(pageOptions, "Экстренная кнопка (Panic)", "PanicKey")
ElementFactory.CreateToggle(pageOptions, "Режим бога (God Mode)", "GodMode", function(s) end)
ElementFactory.CreateToggle(pageOptions, "Обход AFK (Anti-AFK)", "AntiAFK", function(s) end)

-- Функция полной выгрузки (Panic Mode)
local function TriggerPanicMode()
	State.Fly = false; State.Noclip = false; State.SpeedHack = false; State.JumpHack = false; State.InfJump = false; State.NoFall = false; State.CustomFOV = false; State.ThirdPerson = false
	State.Fullbright = false; State.NoFog = false; State.XRay = false; State.ESP = false; State.Crosshair = false; State.NoRecoil = false; State.RapidFire = false; State.AimAssist = false
	State.GodMode = false; State.AntiAFK = false
	_G.ClearESP(); _G.ResetXRay(); _G.ResetCharacterPhysics()
	for name, con in pairs(_G.CheatConnections) do con:Disconnect(); _G.CheatConnections[name] = nil end
	Lighting.Ambient = _G.OriginalLighting.Ambient; Lighting.GlobalShadows = _G.OriginalLighting.GlobalShadows; Lighting.ClockTime = _G.OriginalLighting.ClockTime; Lighting.FogEnd = _G.OriginalLighting.FogEnd
	if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = _G.OriginalCameraProperties.FieldOfView end
	game:GetService("Players").LocalPlayer.CameraMode = _G.OriginalCameraProperties.CameraMode; game:GetService("Players").LocalPlayer.CameraMaxZoomDistance = _G.OriginalCameraProperties.CameraMaxZoomDistance
	if CrosshairFrame1 then CrosshairFrame1:Destroy() end; if CrosshairFrame2 then CrosshairFrame2:Destroy() end
	if _G.MainScreenGui then _G.MainScreenGui:Destroy() end
	if _G.FastOpenBtn then _G.FastOpenBtn:Destroy() end
	warn("[ПАНИКА]: Скрипт экстренно завершил работу. Следы зачищены.")
end

UserInputService.InputBegan:Connect(function(input) if input.KeyCode == State.PanicKey then TriggerPanicMode() end end)
_G.Notify("Все системы запущены!")
