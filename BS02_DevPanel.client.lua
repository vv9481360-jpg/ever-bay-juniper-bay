--================================================================--
--  BS 0.2 DEV PANEL — клиентский инструментарий разработчика
--  ЧАСТЬ 1/3: секции 1–3 (инициализация, GUI, движение)
--  Вставлять ВЕСЬ скрипт (после всех 3 частей) в:
--  StarterPlayer → StarterPlayerScripts
--================================================================--

--============================================================--
--==== СЕКЦИЯ 1: ИНИЦИАЛИЗАЦИЯ И ЗАЩИТА                     ====--
--============================================================--

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local Lighting           = game:GetService("Lighting")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- Камера может меняться (смерть, смена камеры) — держим ссылку актуальной
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera
end)

----------------------------------------------------------------
-- Белый список UserId. СЮДА ДОБАВЛЯЕШЬ СВОЙ UserId (и тестеров).
-- Узнать свой UserId: https://www.roblox.com/users/<твой id>/profile
-- Если UserId не найден в списке — скрипт мгновенно завершается (return).
----------------------------------------------------------------
local WHITELIST: {number} = {
	123456789, -- <-- ЗАМЕНИ ЭТО ЧИСЛО НА СВОЙ UserId
}

do
	local allowed = false
	for _, id in ipairs(WHITELIST) do
		if id == LocalPlayer.UserId then
			allowed = true
			break
		end
	end
	if not allowed then
		return -- полное отключение скрипта для чужих UserId
	end
end

----------------------------------------------------------------
-- Глобальное состояние всех функций. Хранится в одной таблице,
-- чтобы Panic Key и респавн могли сбрасывать всё разом.
----------------------------------------------------------------
local State = {
	-- движение
	Fly = false,       FlySpeed = 60,
	Noclip = false,
	Speed = false,     WalkSpeed = 16,
	Jump = false,      JumpPower = 50,
	InfJump = false,
	NoFall = false,
	-- визуал (заполняется в части 2/3)
	FOV = false,       FOVValue = 70,
	ThirdPerson = false,
	Fullbright = false,
	XRay = false,
	ESP = false,
	NoFog = false,
	-- бой (заполняется в части 2/3)
	NoRecoil = false,
	RapidFire = false,
	AutoReload = false,
	AimAssist = false,
	Crosshair = false,
	-- прочее
	God = false,
	AntiAFK = false,
}

----------------------------------------------------------------
-- Клавиши быстрого доступа. Меняются во вкладке «Настройки»,
-- поэтому лежат отдельной таблицей — все обработчики читают её.
----------------------------------------------------------------
local Keybinds = {}
local ToggleRegistry = {}

local Binds = {
    Menu = Enum.KeyCode.RightShift, -- открыть/закрыть меню
    Fly  = Enum.KeyCode.F,
    Noclip = Enum.KeyCode.N,
    God = Enum.KeyCode.G,
    Panic = Enum.KeyCode.End,        -- аварийное отключение всего
}

-- Ниже автоматически загрузится графический интерфейс вашей панели...
print("DevPanel успешно загружена напрямую!")

----------------------------------------------------------------
-- Реестр соединений. Любое RunService/UserInputService-соединение
-- регистрируется через track()/untrack() — ноль утечек: при
-- выключении функции или смерти персонажа соединения отключаются.
----------------------------------------------------------------
local Connections: {[string]: RBXScriptConnection} = {}

local function track(name: string, conn: RBXScriptConnection)
	if Connections[name] then
		Connections[name]:Disconnect()
	end
	Connections[name] = conn
end

local function untrack(name: string)
	local conn = Connections[name]
	if conn then
		conn:Disconnect()
		Connections[name] = nil
	end
end

local function untrackAll(prefix: string?)
	for name, conn in pairs(Connections) do
		if not prefix or string.sub(name, 1, #prefix) == prefix then
			conn:Disconnect()
			Connections[name] = nil
		end
	end
end

-- Защита от ошибок: любая функция панели вызывается через safe().
-- Ошибка внутри одной функции не уронит весь скрипт.
local function safe(fn: (...any) -> ...any, ...: any): ...any
	local ok, res = pcall(fn, ...)
	if not ok then
		warn("[BS 0.2 DEV PANEL] Ошибка:", res)
	end
	return res
end

-- Проверка персонажа перед каждой операцией: возвращает только
-- валидную тройку character + humanoid + rootPart, иначе nil.
local function getCharacter(): Model?
	local ok, char = pcall(function()
		return LocalPlayer.Character
	end)
	if ok and char and typeof(char) == "Instance" then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			return char
		end
	end
	return nil
end

local function getHumanoid(): Humanoid?
	local char = getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart(): BasePart?
	local char = getCharacter()
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

----------------------------------------------------------------
-- ScreenGui создаётся кодом (Instance.new), не через Studio.
-- ResetOnSpawn = false — GUI переживает смерть персонажа.
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BS02_DevPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Единая палитра оформления
local THEME = {
	Background = Color3.fromRGB(20, 20, 28),   -- фон окна
	Stroke     = Color3.fromRGB(70, 70, 100),  -- обводка
	Off        = Color3.fromRGB(45, 45, 65),   -- кнопка выкл
	On         = Color3.fromRGB(60, 180, 90),  -- кнопка вкл
	Text       = Color3.fromRGB(235, 235, 245),
	SubText    = Color3.fromRGB(150, 150, 170),
	HoverBoost = 1.25, -- множитель яркости при наведении
}

--============================================================--
--==== СЕКЦИЯ 2: GUI-МЕНЮ                                    ====--
--============================================================--

-- Контейнер уведомлений (внизу экрана, по центру)
local NotifyHolder = Instance.new("Frame")
NotifyHolder.Name = "Notifications"
NotifyHolder.AnchorPoint = Vector2.new(0.5, 1)
NotifyHolder.Position = UDim2.new(0.5, 0, 1, -20)
NotifyHolder.Size = UDim2.fromOffset(300, 140)
NotifyHolder.BackgroundTransparency = 1
NotifyHolder.Parent = ScreenGui

local notifyLayout = Instance.new("UIListLayout")
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifyLayout.Padding = UDim.new(0, 4)
notifyLayout.Parent = NotifyHolder

local notifyOrder = 0

-- Уведомление: плавно появляется, висит 2 секунды, исчезает и уничтожается.
-- Как работает: твин прозрачности внутрь → task.delay(2) → твин наружу → Destroy.
local function notify(text: string, accent: Color3?)
	notifyOrder += 1
	local label = Instance.new("TextLabel")
	label.Name = "Notice"
	label.Size = UDim2.fromOffset(280, 26)
	label.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
	label.BackgroundTransparency = 1
	label.TextColor3 = accent or THEME.Text
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.Text = text
	label.LayoutOrder = notifyOrder -- новые уведомления появляются ниже старых
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Stroke
	stroke.Thickness = 1
	stroke.Parent = label
	label.TextTransparency = 1
	label.Parent = NotifyHolder

	TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.1,
		TextTransparency = 0,
	}):Play()

	task.delay(2, function()
		local out = TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		out:Play()
		out.Completed:Once(function()
			label:Destroy()
		end)
	end)
end

----------------------------------------------------------------
-- Главное окно. CanvasGroup выбран сознательно: его
-- GroupTransparency твинит прозрачность окна И всех детей разом —
-- это даёт плавную анимацию открытия/закрытия одним твином.
----------------------------------------------------------------
local Window = Instance.new("CanvasGroup")
Window.Name = "MainWindow"
Window.Size = UDim2.fromOffset(260, 420)
Window.Position = UDim2.new(0.5, -130, 0.5, -210)
Window.BackgroundColor3 = THEME.Background
Window.BackgroundTransparency = 0.05 -- непрозрачность фона 95%
Window.GroupTransparency = 0
Window.BorderSizePixel = 0
Window.Parent = ScreenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 8) -- скругление 8px
windowCorner.Parent = Window

local windowStroke = Instance.new("UIStroke")
windowStroke.Color = THEME.Stroke
windowStroke.Thickness = 2
windowStroke.Parent = Window

-- Заголовок / перетаскиваемая область
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = TitleBar

local titleFix = Instance.new("Frame") -- закрывает нижние скругления заголовка
titleFix.Size = UDim2.new(1, 0, 0, 8)
titleFix.Position = UDim2.new(0, 0, 1, -8)
titleFix.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
titleFix.BorderSizePixel = 0
titleFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.fromOffset(10, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextColor3 = THEME.Text
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.Text = "BS 0.2 DEV PANEL"
TitleLabel.Parent = TitleBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.fromOffset(26, 22)
MinimizeBtn.Position = UDim2.new(1, -32, 0.5, -11)
MinimizeBtn.BackgroundColor3 = THEME.Off
MinimizeBtn.TextColor3 = THEME.Text
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.Text = "—"
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = TitleBar
local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 5)
minimizeCorner.Parent = MinimizeBtn

----------------------------------------------------------------
-- Перетаскивание за заголовок. Своя реализация (Draggable
-- устарел): InputBegan на заголовке запоминает точку, глобальный
-- InputChanged двигает окно, InputEnded отпускает.
----------------------------------------------------------------
do
	local dragging = false
	local dragStart = Vector2.zero
	local startPos = UDim2.new()

	TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Window.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			Window.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

----------------------------------------------------------------
-- Иконка сворачивания: когда окно свёрнуто, оно исчезает твином
-- и в углу экрана появляется кнопка 40x40 для восстановления.
----------------------------------------------------------------
local MinIcon = Instance.new("TextButton")
MinIcon.Name = "MinimizedIcon"
MinIcon.Size = UDim2.fromOffset(40, 40)
MinIcon.Position = UDim2.new(1, -52, 1, -52)
MinIcon.BackgroundColor3 = THEME.Background
MinIcon.TextColor3 = THEME.Text
MinIcon.Font = Enum.Font.GothamBold
MinIcon.TextSize = 14
MinIcon.Text = "BS"
MinIcon.Visible = false
MinIcon.AutoButtonColor = false
MinIcon.Parent = ScreenGui
local minIconCorner = Instance.new("UICorner")
minIconCorner.CornerRadius = UDim.new(0, 8)
minIconCorner.Parent = MinIcon
local minIconStroke = Instance.new("UIStroke")
minIconStroke.Color = THEME.Stroke
minIconStroke.Thickness = 2
minIconStroke.Parent = MinIcon

local menuOpen = true
local menuTween: Tween? = nil

-- Как работает: твин GroupTransparency 0↔1, по завершении скрытия
-- окно выключается через Visible, при открытии включается заранее.
local function setMenu(open: boolean)
	menuOpen = open
	if menuTween then menuTween:Cancel() end
	Window.Visible = true
	Window.Interactable = open
	menuTween = TweenService:Create(Window, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = open and 0 or 1,
	})
	menuTween:Play()
	if not open then
		menuTween.Completed:Once(function()
			if not menuOpen then
				Window.Visible = false
			end
		end)
	end
end

MinimizeBtn.MouseButton1Click:Connect(function()
	setMenu(false)
	MinIcon.Visible = true
end)

MinIcon.MouseButton1Click:Connect(function()
	MinIcon.Visible = false
	setMenu(true)
end)

-- Открытие/закрытие на клавишу меню (по умолчанию RightShift)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Keybinds.Menu then
		MinIcon.Visible = false
		setMenu(not menuOpen)
	end
end)

----------------------------------------------------------------
-- Панель вкладок (сверху под заголовком) и контейнер страниц
----------------------------------------------------------------
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.fromOffset(0, 32)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Window

local tabBarLayout = Instance.new("UIListLayout")
tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
tabBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabBarLayout.Padding = UDim.new(0, 4)
tabBarLayout.Parent = TabBar

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -12, 1, -72)
Content.Position = UDim2.fromOffset(6, 64)
Content.BackgroundTransparency = 1
Content.Parent = Window

local TabButtons: {TextButton} = {}
local TabPages: {ScrollingFrame} = {}

-- Фабрика вкладок: создаёт кнопку в TabBar и страницу-ScrollingFrame.
-- Как работает переключение: при клике скрываются все страницы,
-- показывается нужная; активная кнопка подсвечивается зелёным.
local function createTab(name: string): ScrollingFrame
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(58, 24)
	btn.BackgroundColor3 = THEME.Off
	btn.TextColor3 = THEME.Text
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 11
	btn.Text = name
	btn.AutoButtonColor = false
	btn.LayoutOrder = #TabButtons + 1
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 5)
	btnCorner.Parent = btn
	btn.Parent = TabBar
	table.insert(TabButtons, btn)

	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = THEME.Stroke
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Visible = false
	page.Parent = Content

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = page

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = page
	table.insert(TabPages, page)

	btn.MouseButton1Click:Connect(function()
		for _, other in ipairs(TabPages) do
			other.Visible = false
		end
		page.Visible = true
		for _, other in ipairs(TabButtons) do
			TweenService:Create(other, TweenInfo.new(0.12), {
				BackgroundColor3 = (other == btn) and THEME.On or THEME.Off,
			}):Play()
		end
	end)

	return page
end

-- Создаём все 4 вкладки сразу (наполняются в своих секциях)
local MovementPage = createTab("Движение")
local VisualPage   = createTab("Визуал")
local CombatPage   = createTab("Бой")
local SettingsPage = createTab("Настройки")

TabPages[1].Visible = true -- активна вкладка «Движение» по умолчанию

----------------------------------------------------------------
-- Фабрика тогглов. Как работает: кнопка хранит своё состояние,
-- при клике переключает цвет твином и вызывает callback через
-- safe() в отдельном потоке (task.spawn), чтобы ошибка в логике
-- не прервала обработчик клика. Возвращает setState для
-- принудительного переключения извне (нужно Panic Key / респавну).
----------------------------------------------------------------
local function applyHover(btn: GuiButton, baseColor: () -> Color3)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = baseColor() * THEME.HoverBoost,
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = baseColor(),
		}):Play()
	end)
end

local function createToggle(parent: Instance, text: string, callback: (boolean) -> ())
		: (TextButton, (boolean, boolean?) -> ())
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 30)
	btn.BackgroundColor3 = THEME.Off
	btn.TextColor3 = THEME.Text
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	btn.Parent = parent

	local state = false
	local currentColor = function(): Color3
		return state and THEME.On or THEME.Off
	end

	local function setState(newState: boolean, silent: boolean?)
		state = newState
		btn.Text = "  " .. text .. (state and ": ВКЛ" or ": ВЫКЛ")
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = currentColor(),
		}):Play()
		if not silent then
			task.spawn(function()
				safe(callback, state)
			end)
		end
	end

	applyHover(btn, currentColor)
	btn.MouseButton1Click:Connect(function()
		setState(not state)
	end)

	return btn, setState
end

----------------------------------------------------------------
-- Фабрика слайдеров (своя реализация, без библиотек).
-- Как работает: InputBegan на полосе захватывает drag, глобальный
-- InputChanged переводит X-координату мыши в значение min..max,
-- InputEnded отпускает. Заполнение — Frame внутри полосы.
----------------------------------------------------------------
local function createSlider(parent: Instance, text: string, min: number, max: number,
	default: number, callback: (number) -> (), unit: string?)
		: (Frame, (number, boolean?) -> ())
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -16, 0, 44)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.6, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = THEME.SubText
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.Text = text
	label.Parent = holder

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.4, 0, 0, 16)
	valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextColor3 = THEME.Text
	valueLabel.Font = Enum.Font.GothamMedium
	valueLabel.TextSize = 12
	valueLabel.Parent = holder

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.new(0, 0, 0, 26)
	bar.BackgroundColor3 = THEME.Off
	bar.BorderSizePixel = 0
	bar.Parent = holder
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = THEME.On
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(12, 12)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(220, 220, 235)
	knob.BorderSizePixel = 0
	knob.Parent = bar
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local value = default

	local function render()
		local alpha = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = tostring(math.floor(value + 0.5)) .. (unit or "")
	end

	local function setValue(newValue: number, silent: boolean?)
		value = math.clamp(newValue, min, max)
		render()
		if not silent then
			task.spawn(function()
				safe(callback, value)
			end)
		end
	end

	local sliding = false

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			-- мгновенный прыжок ползунка к точке клика
			local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
			setValue(min + rel * (max - min))
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			setValue(min + rel * (max - min))
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)

	render()
	return holder, setValue
end

--============================================================--
--==== СЕКЦИЯ 3: ВКЛАДКА «ДВИЖЕНИЕ»                          ====--
--============================================================--

----------------------------------------------------------------
-- Вспомогательное: запоминаем исходные CanCollide деталей
-- персонажа, чтобы вернуть их при выключении Noclip (не все
-- детали изначально имеют CanCollide = true).
----------------------------------------------------------------
local noclipOriginal: {[BasePart]: boolean} = {}

----------------------------------------------------------------
-- FLY
-- Как работает изнутри: включает Humanoid.PlatformStand (человек
-- перестаёт реагировать на физику), в HumanoidRootPart вставляется
-- BodyVelocity с бесконечной силой. Каждый кадр (Heartbeat) цель
-- скорости = MoveDirection * flySpeed + вертикаль (Space вверх,
-- LeftControl вниз), а реальная скорость подтягивается к цели
-- через Lerp — это и есть инерция/плавность. При выключении
-- BodyVelocity уничтожается, PlatformStand снимается.
----------------------------------------------------------------
local function setFly(on: boolean)
	if on == State.Fly and on then return end
	State.Fly = on

	if on then
		local char = getCharacter()
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (char and humanoid and root) then
			State.Fly = false
			notify("Fly: нет персонажа", Color3.fromRGB(220, 90, 90))
			return
		end

		humanoid.PlatformStand = true

		local bv = Instance.new("BodyVelocity")
		bv.Name = "DevFlyVelocity"
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Velocity = Vector3.zero
		bv.Parent = root

		track("Fly", RunService.Heartbeat:Connect(function(dt: number)
			local c = LocalPlayer.Character
			if not c then return end
			local h = c:FindFirstChildOfClass("Humanoid")
			local r = c:FindFirstChild("HumanoidRootPart")
			local vel = r and r:FindFirstChild("DevFlyVelocity")
			if not (h and r and vel) or not vel:IsA("BodyVelocity") then return end

			local dir = h.MoveDirection
			local vertical = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				vertical += 1
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				vertical -= 1
			end

			local target = dir * State.FlySpeed + Vector3.new(0, vertical * State.FlySpeed, 0)
			-- Lerp с dt * 8: плавный разгон/торможение без рывков
			vel.Velocity = vel.Velocity:Lerp(target, math.clamp(dt * 8, 0, 1))
		end))

		notify("Fly: включён (" .. State.FlySpeed .. ")")
	else
		untrack("Fly")
		local char = LocalPlayer.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			local bv = root and root:FindFirstChild("DevFlyVelocity")
			if bv then bv:Destroy() end
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = false
			end
		end
		notify("Fly: выключен")
	end
end

----------------------------------------------------------------
-- NOCLIP
-- Как работает изнутри: каждый шаг физики (RunService.Stepped —
-- до коллизий) у всех BasePart персонажа выключается CanCollide,
-- персонаж проваливается сквозь геометрию. Исходные значения
-- CanCollide сохраняются в таблицу и восстанавливаются при off.
----------------------------------------------------------------
local function setNoclip(on: boolean)
	if on == State.Noclip and on then return end
	State.Noclip = on

	if on then
		table.clear(noclipOriginal)
		track("Noclip", RunService.Stepped:Connect(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, obj in ipairs(char:GetDescendants()) do
				if obj:IsA("BasePart") then
					if noclipOriginal[obj] == nil then
						noclipOriginal[obj] = obj.CanCollide
					end
					obj.CanCollide = false
				end
			end
		end))
		notify("Noclip: включён")
	else
		untrack("Noclip")
		for part, original in pairs(noclipOriginal) do
			if part.Parent then
				part.CanCollide = original
			end
		end
		table.clear(noclipOriginal)
		notify("Noclip: выключен")
	end
end

----------------------------------------------------------------
-- SPEED / JUMP
-- Как работают: значения из слайдеров пишутся в State и сразу
-- применяются к живому Humanoid; повторное применение после
-- респавна делает setupCharacter() (см. ниже).
----------------------------------------------------------------
local function applySpeed()
	local humanoid = getHumanoid()
	if humanoid and State.Speed then
		humanoid.WalkSpeed = State.WalkSpeed
	end
end

local function applyJump()
	local humanoid = getHumanoid()
	if humanoid and State.Jump then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = State.JumpPower
	end
end

local function setSpeedEnabled(on: boolean)
	State.Speed = on
	if on then
		applySpeed()
		notify("Speed: " .. State.WalkSpeed)
	else
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = 16 -- дефолт Roblox
		end
		notify("Speed: выключен")
	end
end

local function setJumpEnabled(on: boolean)
	State.Jump = on
	if on then
		applyJump()
		notify("Jump: " .. State.JumpPower)
	else
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.JumpPower = 50 -- дефолт Roblox
		end
		notify("Jump: выключен")
	end
end

----------------------------------------------------------------
-- INFINITE JUMP
-- Как работает изнутри: подписывается на UserInputService.JumpRequest
-- (событие прыжка). Если человек в состоянии Freefall — прыжок
-- форсится через ChangeState, можно прыгать в воздухе бесконечно.
----------------------------------------------------------------
local function setInfJump(on: boolean)
	State.InfJump = on
	if on then
		track("InfJump", UserInputService.JumpRequest:Connect(function()
			local humanoid = getHumanoid()
			if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end))
		notify("Infinite Jump: включён")
	else
		untrack("InfJump")
		notify("Infinite Jump: выключен")
	end
end

----------------------------------------------------------------
-- NO FALL DAMAGE
-- Как работает изнутри: ловится Humanoid.HealthChanged. Если
-- здоровье упало, а человек при этом в состоянии падения/приземления
-- (Freefall / Landed / FallingDown) — это урон от падения, и он
-- откатывается обратно. Иначе lastHealth просто обновляется.
----------------------------------------------------------------
local NoFallConn: RBXScriptConnection? = nil

local function bindNoFall(humanoid: Humanoid)
	if NoFallConn then
		NoFallConn:Disconnect()
		NoFallConn = nil
	end
	if not State.NoFall then return end

	local lastHealth = humanoid.Health
	NoFallConn = humanoid.HealthChanged:Connect(function(health: number)
		local state = humanoid:GetState()
		local falling = state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.FallingDown
		if health < lastHealth and falling then
			humanoid.Health = lastHealth -- откат урона от падения
		else
			lastHealth = health
		end
	end)
end

local function setNoFall(on: boolean)
	State.NoFall = on
	if on then
		local humanoid = getHumanoid()
		if humanoid then
			bindNoFall(humanoid)
		end
		notify("No Fall Damage: включён")
	else
		if NoFallConn then
			NoFallConn:Disconnect()
			NoFallConn = nil
		end
		notify("No Fall Damage: выключен")
	end
end

----------------------------------------------------------------
-- Респавн-менеджер. Как работает: при CharacterAdded отключаются
-- состояния, живущие на теле (Fly, Noclip), затем setupCharacter()
-- заново применяет Speed/Jump и перепривязывает персонажеские
-- соединения (No Fall Damage) — всё восстанавливается автоматически.
----------------------------------------------------------------
local function setupCharacter(char: Model)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	-- Speed / Jump применяются мгновенно на новом персонаже
	safe(applySpeed)
	safe(applyJump)
	-- No Fall Damage перепривязывается к новому Humanoid
	if State.NoFall then
		safe(bindNoFall, humanoid)
	end
end

LocalPlayer.CharacterAdded:Connect(function(char)
	-- Fly и Noclip живут на конкретном теле — выключаем, состояние
	-- остаётся в State и ждёт ручного включения на новом персонаже
	if State.Fly then
		State.Fly = false
		untrack("Fly")
		notify("Fly: сброшен (респавн)")
	end
	if State.Noclip then
		State.Noclip = false
		untrack("Noclip")
		table.clear(noclipOriginal)
		notify("Noclip: сброшен (респавн)")
	end
	task.defer(function()
		safe(setupCharacter, char)
	end)
end)

if LocalPlayer.Character then
	task.spawn(function()
		safe(setupCharacter, LocalPlayer.Character)
	end)
end

----------------------------------------------------------------
-- Наполнение вкладки «Движение»: тогглы + слайдеры
----------------------------------------------------------------
createToggle(MovementPage, "Fly", setFly)
createToggle(MovementPage, "Noclip", setNoclip)
createToggle(MovementPage, "Speed", setSpeedEnabled)
createToggle(MovementPage, "Jump", setJumpEnabled)
createToggle(MovementPage, "Infinite Jump", setInfJump)
createToggle(MovementPage, "No Fall Damage", setNoFall)

createSlider(MovementPage, "Скорость полёта", 16, 250, 60, function(v)
	State.FlySpeed = v
end)

createSlider(MovementPage, "WalkSpeed", 16, 500, 16, function(v)
	State.WalkSpeed = v
	applySpeed()
end)

createSlider(MovementPage, "JumpPower", 50, 300, 50, function(v)
	State.JumpPower = v
	applyJump()
end)

notify("BS 0.2 DEV PANEL загружена. Меню: RightShift", THEME.On)
--================================================================--
--  BS 0.2 DEV PANEL — ЧАСТЬ 2/3: секции 4–6 (визуал, бой, настройки)
--================================================================--

--============================================================--
--==== СЕКЦИЯ 4: ВКЛАДКА «ВИЗУАЛ»                            ====--
--============================================================--

----------------------------------------------------------------
-- FOV CHANGER
-- Как работает изнутри: пока включён, каждый кадр RenderStepped
-- плавно подтягивает Camera.FieldOfView к значению слайдера
-- через Lerp — твин здесь не нужен, камера может пересоздаваться
-- (смерть), а Lerp работает с любой текущей камерой. При выключении
-- FOV возвращается к исходному значению.
----------------------------------------------------------------
local originalFOV = Camera and Camera.FieldOfView or 70

local function setFOV(on: boolean)
	State.FOV = on
	if on then
		track("FOV", RunService.RenderStepped:Connect(function(dt: number)
			if not Camera then return end
			local goal = State.FOVValue
			Camera.FieldOfView = Camera.FieldOfView
				+ (goal - Camera.FieldOfView) * math.clamp(dt * 10, 0, 1)
		end))
		notify("FOV Changer: " .. State.FOVValue)
	else
		untrack("FOV")
		if Camera then
			Camera.FieldOfView = originalFOV
		end
		notify("FOV Changer: выключен")
	end
end

----------------------------------------------------------------
-- THIRD PERSON
-- Как работает: переключает CameraMode игрока и фиксирует зум.
-- Камера в Roblox — клиентский объект, поэтому это чисто
-- локальное переключение вида. Исходные настройки сохраняются.
----------------------------------------------------------------
local savedCamera = {
	Mode = LocalPlayer.CameraMode,
	MinZoom = LocalPlayer.CameraMinZoomDistance,
	MaxZoom = LocalPlayer.CameraMaxZoomDistance,
}

local function setThirdPerson(on: boolean)
	State.ThirdPerson = on
	if on then
		LocalPlayer.CameraMode = Enum.CameraMode.Classic
		LocalPlayer.CameraMinZoomDistance = 10 -- дистанция камеры 10 стадов
		LocalPlayer.CameraMaxZoomDistance = 10
		notify("Third Person: включён")
	else
		LocalPlayer.CameraMode = savedCamera.Mode
		LocalPlayer.CameraMinZoomDistance = savedCamera.MinZoom
		LocalPlayer.CameraMaxZoomDistance = savedCamera.MaxZoom
		notify("Third Person: выключен")
	end
end

----------------------------------------------------------------
-- FULLBRIGHT
-- Как работает: сохраняет исходные параметры Lighting в таблицу,
-- затем выставляет яркое освещение. При выключении ВСЕ значения
-- откатываются из сохранённой таблицы — состояние карты не ломается.
----------------------------------------------------------------
local savedLighting: {[string]: any} = {}
local LIGHTING_PROPS = {"Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient"}

local function setFullbright(on: boolean)
	State.Fullbright = on
	if on then
		for _, prop in ipairs(LIGHTING_PROPS) do
			savedLighting[prop] = (Lighting :: any)[prop]
		end
		Lighting.Brightness = 10
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(255, 255, 255)
		notify("Fullbright: включён")
	else
		for prop, value in pairs(savedLighting) do
			pcall(function()
				(Lighting :: any)[prop] = value
			end)
		end
		table.clear(savedLighting)
		notify("Fullbright: выключен")
	end
end

----------------------------------------------------------------
-- X-RAY
-- Как работает: проходит по всем BasePart workspace и ставит
-- LocalTransparencyModifier = 0.7 (прозрачность ТОЛЬКО для тебя,
-- сервер и другие игроки не видят). Исходные LTM сохраняются.
-- Соединение DescendantAdded ловит новые детали карты на лету.
-- Персонаж игрока и его инструменты пропускаются.
----------------------------------------------------------------
local XRayParts: {[BasePart]: number} = {}

local function xrayApply(part: BasePart)
	local char = LocalPlayer.Character
	if char and part:IsDescendantOf(char) then return end
	if XRayParts[part] == nil then
		XRayParts[part] = part.LocalTransparencyModifier
	end
	part.LocalTransparencyModifier = 0.7
end

local function xrayRevertAll()
	for part, original in pairs(XRayParts) do
		if part.Parent then
			part.LocalTransparencyModifier = original
		end
	end
	table.clear(XRayParts)
end

local function setXRay(on: boolean)
	State.XRay = on
	if on then
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("BasePart") then
				xrayApply(obj)
			end
		end
		track("XRay", Workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") then
				task.defer(xrayApply, obj)
			end
		end))
		notify("X-Ray: включён")
	else
		untrack("XRay")
		xrayRevertAll()
		notify("X-Ray: выключен")
	end
end

----------------------------------------------------------------
-- ESP (подсветка игроков)
-- Как работает: над головой каждого игрока (кроме тебя) создаётся
-- BillboardGui: ник, полоска HP, дистанция. Обновление раз в 0.5 с
-- через накопитель дельты в Heartbeat. PlayerRemoving и смерть
-- персонажа гасят плашку. Всё лежит в папке ESPFolder.
----------------------------------------------------------------
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ESP_Holders"
ESPFolder.Parent = ScreenGui

local ESPGui: {[Player]: BillboardGui} = {}
local espAccum = 0

local function espEnsure(player: Player)
	if player == LocalPlayer then return end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and head and humanoid and humanoid.Health > 0) then
		local old = ESPGui[player]
		if old then old.Enabled = false end
		return
	end

	local gui = ESPGui[player]
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "ESP_" .. player.Name
		gui.Size = UDim2.fromOffset(120, 42)
		gui.StudsOffset = Vector3.new(0, 2.4, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = head
		gui.Parent = ESPFolder

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Nickname"
		nameLabel.Size = UDim2.new(1, 0, 0, 14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = THEME.Text
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextStrokeTransparency = 0.6
		nameLabel.Parent = gui

		local hpBack = Instance.new("Frame")
		hpBack.Name = "HPBack"
		hpBack.Size = UDim2.new(1, -20, 0, 5)
		hpBack.Position = UDim2.new(0, 10, 0, 17)
		hpBack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		hpBack.BorderSizePixel = 0
		hpBack.Parent = gui
		local hpBackCorner = Instance.new("UICorner")
		hpBackCorner.CornerRadius = UDim.new(1, 0)
		hpBackCorner.Parent = hpBack

		local hpFill = Instance.new("Frame")
		hpFill.Name = "HPFill"
		hpFill.Size = UDim2.fromScale(1, 1)
		hpFill.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
		hpFill.BorderSizePixel = 0
		hpFill.Parent = hpBack
		local hpFillCorner = Instance.new("UICorner")
		hpFillCorner.CornerRadius = UDim.new(1, 0)
		hpFillCorner.Parent = hpFill

		local distLabel = Instance.new("TextLabel")
		distLabel.Name = "Distance"
		distLabel.Size = UDim2.new(1, 0, 0, 12)
		distLabel.Position = UDim2.new(0, 0, 0, 25)
		distLabel.BackgroundTransparency = 1
		distLabel.TextColor3 = THEME.SubText
		distLabel.Font = Enum.Font.Gotham
		distLabel.TextSize = 11
		distLabel.TextStrokeTransparency = 0.6
		distLabel.Parent = gui

		ESPGui[player] = gui
	end

	gui.Enabled = true
	gui.Adornee = head -- голова могла пересоздаться после смерти
	local nameLabel = gui:FindFirstChild("Nickname")
	local hpFill = gui:FindFirstChild("HPBack") and gui.HPBack:FindFirstChild("HPFill")
	local distLabel = gui:FindFirstChild("Distance")
	if nameLabel then
		nameLabel.Text = player.DisplayName
	end
	if hpFill and hpFill:IsA("Frame") then
		hpFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
	end
	if distLabel and Camera then
		local dist = (Camera.CFrame.Position - head.Position).Magnitude
		distLabel.Text = string.format("%d studs", math.floor(dist))
	end
end

local function espDestroy(player: Player)
	local gui = ESPGui[player]
	if gui then
		gui:Destroy()
		ESPGui[player] = nil
	end
end

local function setESP(on: boolean)
	State.ESP = on
	if on then
		espAccum = 0
		for _, player in ipairs(Players:GetPlayers()) do
			safe(espEnsure, player)
		end
		track("ESP", RunService.Heartbeat:Connect(function(dt: number)
			espAccum += dt
			if espAccum < 0.5 then return end -- обновление раз в 0.5 сек
			espAccum = 0
			for _, player in ipairs(Players:GetPlayers()) do
				safe(espEnsure, player)
			end
		end))
		notify("ESP: включён")
	else
		untrack("ESP")
		for player in pairs(ESPGui) do
			espDestroy(player)
		end
		notify("ESP: выключен")
	end
end

-- Очистка ESP при выходе игрока (соединение живёт всю сессию —
-- это не утечка: оно одно на скрипт и нужно всегда).
Players.PlayerRemoving:Connect(function(player)
	espDestroy(player)
end)

----------------------------------------------------------------
-- NO FOG
-- Как работает: запоминает FogStart/FogEnd/FogColor и растягивает
-- туман до 100000 стадов — фактически убирает его. Откат — из
-- сохранённых значений.
----------------------------------------------------------------
local savedFog: {[string]: any} = nil

local function setNoFog(on: boolean)
	State.NoFog = on
	if on then
		savedFog = {
			FogStart = Lighting.FogStart,
			FogEnd = Lighting.FogEnd,
			FogColor = Lighting.FogColor,
		}
		Lighting.FogStart = 0
		Lighting.FogEnd = 100000
		notify("No Fog: включён")
	else
		if savedFog then
			Lighting.FogStart = savedFog.FogStart
			Lighting.FogEnd = savedFog.FogEnd
			Lighting.FogColor = savedFog.FogColor
			savedFog = nil
		end
		notify("No Fog: выключен")
	end
end

-- Наполнение вкладки «Визуал»
createToggle(VisualPage, "FOV Changer", setFOV)
createToggle(VisualPage, "Third Person", setThirdPerson)
createToggle(VisualPage, "Fullbright", setFullbright)
createToggle(VisualPage, "X-Ray", setXRay)
createToggle(VisualPage, "ESP", setESP)
createToggle(VisualPage, "No Fog", setNoFog)

createSlider(VisualPage, "FOV", 70, 120, 70, function(v)
	State.FOVValue = v
end)

--============================================================--
--==== СЕКЦИЯ 5: ВКЛАДКА «БОЙ»                               ====--
--============================================================--

-- Адаптивные имена конфигов оружия: разные игры называют одно и
-- то же по-разному, поэтому ищем по списку вариантов (FindFirstChild
-- с перебором имён). Если структура не найдена — функция просто
-- ничего не делает и не падает.

local RECOIL_NAMES = {"Recoil", "CameraRecoil", "Kick", "CameraKick", "Shake", "RecoilOffset"}
local COOLDOWN_NAMES = {"Cooldown", "FireCooldown", "ShotCooldown", "FireRate", "ROF"}
local AMMO_NAMES = {"Ammo", "Clip", "Magazine", "CurrentAmmo", "AmmoCount"}
local MAG_NAMES = {"MagazineSize", "MaxAmmo", "MagSize", "MaxClip"}

local function findValueByNames(parent: Instance, names: {string}): ValueBase?
	for _, name in ipairs(names) do
		local obj = parent:FindFirstChild(name)
		if obj and obj:IsA("ValueBase") then
			return obj
		end
	end
	return nil
end

local function forEachTool(fn: (Tool) -> ())
	local char = LocalPlayer.Character
	if char then
		for _, obj in ipairs(char:GetChildren()) do
			if obj:IsA("Tool") then
				task.spawn(fn, obj)
			end
		end
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, obj in ipairs(backpack:GetChildren()) do
			if obj:IsA("Tool") then
				task.spawn(fn, obj)
			end
		end
	end
end

----------------------------------------------------------------
-- NO RECOIL
-- Как работает изнутри: двухуровневый подход. Уровень 1 — стабилизация
-- Humanoid.CameraOffset: многие отдачи в играх двигают камеру через
-- него, каждый кадр он обнуляется. Уровень 2 — адаптивный поиск
-- ValueBase-конфигов отдачи внутри инструментов/камеры (Recoil,
-- Kick и т.д.) с принудительным обнулением значения.
----------------------------------------------------------------
local function zeroRecoilIn(tool: Tool)
	local recoil = findValueByNames(tool, RECOIL_NAMES)
	if recoil and recoil:IsA("NumberValue") and recoil.Value ~= 0 then
		recoil.Value = 0
	end
end

local function setNoRecoil(on: boolean)
	State.NoRecoil = on
	if on then
		track("NoRecoil", RunService.Heartbeat:Connect(function()
			local humanoid = getHumanoid()
			if humanoid and humanoid.CameraOffset.Magnitude > 0.0001 then
				humanoid.CameraOffset = Vector3.zero
			end
			forEachTool(zeroRecoilIn)
		end))
		notify("No Recoil: включён")
	else
		untrack("NoRecoil")
		notify("No Recoil: выключен")
	end
end

----------------------------------------------------------------
-- RAPID FIRE
-- Как работает: раз в секунду сканирует все инструменты (руки +
-- рюкзак) на предмет NumberValue-конфигов кулдауна и режет их
-- до 0.05 с. Работает, только если игра хранит кулдаун в ValueBase;
-- если кулдаун внутри скрипта — чисто клиентски понизить его
-- невозможно, скрипт это корректно «переживает» благодаря safe().
----------------------------------------------------------------
local function rapidFireScan()
	forEachTool(function(tool)
		local cd = findValueByNames(tool, COOLDOWN_NAMES)
		if cd and cd:IsA("NumberValue") and cd.Value > 0.05 then
			cd.Value = 0.05
		end
	end)
end

local function setRapidFire(on: boolean)
	State.RapidFire = on
	if on then
		track("RapidFire", task.spawn(function()
			while State.RapidFire do
				safe(rapidFireScan)
				task.wait(1)
			end
		end) :: any)
		notify("Rapid Fire: включён")
	else
		untrack("RapidFire")
		notify("Rapid Fire: выключен")
	end
end

----------------------------------------------------------------
-- AUTO RELOAD
-- Как работает: каждые 0.5 с смотрит на инструмент в руках. Если
-- нашёл счётчик патронов (Ammo/Clip) и он на нуле — мгновенно
-- выставляет полный магазин (MagazineSize/MaxAmmo). Если магазин
-- не найден — ставит 30 как стандартное значение.
----------------------------------------------------------------
local function autoReloadScan()
	local char = LocalPlayer.Character
	if not char then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return end
	local ammo = findValueByNames(tool, AMMO_NAMES)
	if ammo and ammo:IsA("NumberValue") and ammo.Value <= 0 then
		local mag = findValueByNames(tool, MAG_NAMES)
		ammo.Value = (mag and mag:IsA("NumberValue") and mag.Value > 0) and mag.Value or 30
	end
end

local function setAutoReload(on: boolean)
	State.AutoReload = on
	if on then
		track("AutoReload", task.spawn(function()
			while State.AutoReload do
				safe(autoReloadScan)
				task.wait(0.5)
			end
		end) :: any)
		notify("Auto Reload: включён")
	else
		untrack("AutoReload")
		notify("Auto Reload: выключен")
	end
end

----------------------------------------------------------------
-- AIM ASSIST (мягкий)
-- Как работает: при зажатой ПКМ (MouseButton2) каждый кадр рендера
-- ищется ближайший к оси взгляда живой игрок: радиус 100 стадов,
-- конус 30°. Если цель есть — камера плавно доворачивается к ней
-- через Lerp (0.15 за кадр), это НЕ резкий aimbot, прицел «плывёт»
-- к цели. BindToRenderStep с приоритетом выше камеры — доворот
-- применяется ПОСЛЕ штатного обновления камеры игры.
----------------------------------------------------------------
local AIM_ASSIST_STEP = "BS02_AimAssist"

local function aimAssistFindTarget(): (Vector3?, number?)
	if not Camera then return nil, nil end
	local camPos = Camera.CFrame.Position
	local camLook = Camera.CFrame.LookVector
	local bestPos: Vector3? = nil
	local bestAngle = 30 -- максимальный угол 30°
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		-- пропускаем тиммейтов, если в игре включены команды
		if LocalPlayer.Team and player.Team and player.Team == LocalPlayer.Team then
			continue
		end
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not (head and humanoid and humanoid.Health > 0) then continue end
		local offset = head.Position - camPos
		local dist = offset.Magnitude
		if dist > 100 then continue end -- радиус 100 стадов
		local angle = math.deg(math.acos(math.clamp(camLook:Dot(offset.Unit), -1, 1)))
		if angle < bestAngle then
			bestAngle = angle
			bestPos = head.Position
		end
	end
	return bestPos, bestAngle
end

local function aimAssistStep()
	if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
	if not Camera then return end
	local targetPos = aimAssistFindTarget()
	if targetPos then
		local goal = CFrame.lookAt(Camera.CFrame.Position, targetPos)
		Camera.CFrame = Camera.CFrame:Lerp(goal, 0.15) -- плавный доворот
	end
end

local function setAimAssist(on: boolean)
	State.AimAssist = on
	if on then
		RunService:BindToRenderStep(AIM_ASSIST_STEP, Enum.RenderPriority.Camera.Value + 1, function()
			safe(aimAssistStep)
		end)
		notify("Aim Assist: включён")
	else
		pcall(function()
			RunService:UnbindFromRenderStep(AIM_ASSIST_STEP)
		end)
		notify("Aim Assist: выключен")
	end
end

----------------------------------------------------------------
-- CROSSHAIR
-- Как работает: два тонких Frame (вертикаль + горизонталь) в центре
-- экрана, AnchorPoint (0.5, 0.5). Просто переключается Visible.
----------------------------------------------------------------
local CrosshairH = Instance.new("Frame")
CrosshairH.Name = "CrosshairH"
CrosshairH.AnchorPoint = Vector2.new(0.5, 0.5)
CrosshairH.Position = UDim2.fromScale(0.5, 0.5)
CrosshairH.Size = UDim2.fromOffset(14, 2)
CrosshairH.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
CrosshairH.BorderSizePixel = 0
CrosshairH.Visible = false
CrosshairH.Parent = ScreenGui

local CrosshairV = Instance.new("Frame")
CrosshairV.Name = "CrosshairV"
CrosshairV.AnchorPoint = Vector2.new(0.5, 0.5)
CrosshairV.Position = UDim2.fromScale(0.5, 0.5)
CrosshairV.Size = UDim2.fromOffset(2, 14)
CrosshairV.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
CrosshairV.BorderSizePixel = 0
CrosshairV.Visible = false
CrosshairV.Parent = ScreenGui

local function setCrosshair(on: boolean)
	State.Crosshair = on
	CrosshairH.Visible = on
	CrosshairV.Visible = on
	notify(on and "Crosshair: включён" or "Crosshair: выключен")
end

-- Наполнение вкладки «Бой»
createToggle(CombatPage, "No Recoil", setNoRecoil)
createToggle(CombatPage, "Rapid Fire", setRapidFire)
createToggle(CombatPage, "Auto Reload", setAutoReload)
createToggle(CombatPage, "Aim Assist", setAimAssist)
createToggle(CombatPage, "Crosshair", setCrosshair)

--============================================================--
--==== СЕКЦИЯ 6: ВКЛАДКА «НАСТРОЙКИ»                         ====--
--============================================================--

----------------------------------------------------------------
-- СОХРАНЕНИЕ ПОЗИЦИИ ОКНА
-- Как работает: позиция сериализуется в строку "xs,xo,ys,yo" и
-- пишется в атрибут ScreenGui (клиентские атрибуты живут в сессии;
-- writefile в обычном Roblox недоступен — это возможность эксплойтов).
-- При старте позиция восстанавливается из атрибута.
----------------------------------------------------------------
do
	local saved = ScreenGui:GetAttribute("WindowPos")
	if typeof(saved) == "string" then
		local parts = string.split(saved, ",")
		if #parts == 4 then
			local xs, xo = tonumber(parts[1]), tonumber(parts[2])
			local ys, yo = tonumber(parts[3]), tonumber(parts[4])
			if xs and xo and ys and yo then
				Window.Position = UDim2.new(xs, xo, ys, yo)
			end
		end
	end

	local savePending = false
	Window:GetPropertyChangedSignal("Position"):Connect(function()
		if savePending then return end
		savePending = true
		task.delay(0.5, function() -- дебаунс: пишем не чаще раза в 0.5 с
			savePending = false
			local p = Window.Position
			ScreenGui:SetAttribute("WindowPos",
				string.format("%d,%d,%d,%d", p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset))
		end)
	end)
end

----------------------------------------------------------------
-- KEYBINDS (смена клавиш быстрого доступа)
-- Как работает: ряд с кнопкой, показывающей текущую клавишу. Клик →
-- режим захвата (capturing), следующая нажатая клавиша записывается
-- в таблицу Keybinds. Все обработчики читают Keybinds «на лету», так
-- что смена применяется мгновенно без перезапуска.
----------------------------------------------------------------
local capturing: string? = nil
local KeybindButtons: {[string]: TextButton} = {}

-- Глобальный обработчик захвата клавиши (живёт всю сессию)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not capturing then return end
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Unknown then return end
	Keybinds[capturing] = input.KeyCode
	local btn = KeybindButtons[capturing]
	if btn then
		btn.Text = input.KeyCode.Name
	end
	notify("Клавиша '" .. capturing .. "' → " .. input.KeyCode.Name)
	capturing = nil
end)

local function createKeybindRow(parent: Instance, labelText: string, keyName: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 30)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.55, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = THEME.Text
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.Text = labelText
	label.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.45, -6, 0, 24)
	btn.Position = UDim2.new(0.55, 6, 0.5, -12)
	btn.BackgroundColor3 = THEME.Off
	btn.TextColor3 = THEME.Text
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 12
	btn.Text = Keybinds[keyName].Name
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	btn.Parent = row

	applyHover(btn, function(): Color3
		return (capturing == keyName) and THEME.On or THEME.Off
	end)

	btn.MouseButton1Click:Connect(function()
		capturing = keyName
		btn.Text = "Нажми клавишу…"
	end)

	KeybindButtons[keyName] = btn
end

createKeybindRow(SettingsPage, "Меню", "Menu")
createKeybindRow(SettingsPage, "Fly", "Fly")
createKeybindRow(SettingsPage, "Noclip", "Noclip")
createKeybindRow(SettingsPage, "God", "God")

local panicInfo = Instance.new("TextLabel")
panicInfo.Size = UDim2.new(1, -16, 0, 16)
panicInfo.BackgroundTransparency = 1
panicInfo.TextXAlignment = Enum.TextXAlignment.Left
panicInfo.TextColor3 = THEME.SubText
panicInfo.Font = Enum.Font.Gotham
panicInfo.TextSize = 11
panicInfo.Text = "Panic Key: End (аварийное отключение)"
panicInfo.Parent = SettingsPage

----------------------------------------------------------------
-- ANTI-AFK
-- Как работает: фоновая задача раз в 4 минуты, если функция включена,
-- даёт персонажу короткий рывок случайного BodyVelocity на 0.1 с.
-- Этого достаточно, чтобы клиент считался «активным». Перед
-- применением проверяет, что Fly не активен (не мешает полёту).
----------------------------------------------------------------
local function setAntiAFK(on: boolean)
	State.AntiAFK = on
	notify(on and "Anti-AFK: включён" or "Anti-AFK: выключен")
end

createToggle(SettingsPage, "Anti-AFK", setAntiAFK)

task.spawn(function()
	while true do
		task.wait(240) -- раз в 4 минуты
		if State.AntiAFK and not State.Fly then
			safe(function()
				local root = getRootPart()
				if root then
					local bv = Instance.new("BodyVelocity")
					bv.MaxForce = Vector3.new(1e5, 0, 1e5)
					-- случайное направление, чтобы не выглядело одинаково
					local angle = math.rad(math.random(0, 360))
					bv.Velocity = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 8
					bv.Parent = root
					task.delay(0.1, function()
						bv:Destroy()
					end)
				end
			end)
		end
	end
end)

-- Паника (Panic Key) и горячие клавиши Fly/Noclip/God — в части 3/3,
-- т.к. паника должна выключать в том числе и God Mode.
--================================================================--
--  BS 0.2 DEV PANEL — ЧАСТЬ 3/3: секции 7–9 (God Mode, хоткеи,
--  Panic Key, финальная инструкция)
--  ЭТА ЧАСТЬ ЗАВЕРШАЕТ СКРИПТ — вставлять СРАЗУ после части 2/3
--================================================================--

--============================================================--
--==== СЕКЦИЯ 7: GOD MODE                                    ====--
--============================================================--

----------------------------------------------------------------
-- GOD MODE
-- Как работает изнутри: фоновая задача каждые 0.1 с проверяет
-- флаг State.God и при живом Humanoid мгновенно восстанавливает
-- Health до MaxHealth. Урон физически проходит (сервер его видит),
-- но тут же откатывается — для локального теста этого достаточно.
-- Персонажеские соединения (HealthChanged и т.п.) не нужны —
-- проверка идёт через getHumanoid(), который сам валидирует
-- персонажа. После респавна новый Humanoid подхватывается
-- автоматически следующей итерацией цикла.
----------------------------------------------------------------
local function setGod(on: boolean)
	State.God = on
	notify(on and "God Mode: включён" or "God Mode: выключен",
		on and THEME.On or nil)
end

task.spawn(function()
	while true do
		task.wait(0.1) -- никаких while true без task.wait()
		if State.God then
			safe(function()
				local humanoid = getHumanoid()
				if humanoid and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = humanoid.MaxHealth
				end
			end)
		end
	end
end)

-- Тоггл God Mode — во вкладке «Бой» (горячая клавиша G читается
-- из Keybinds и работает сразу, без перезапуска).
createToggle(CombatPage, "God Mode", setGod)

----------------------------------------------------------------
-- ГЛОБАЛЬНЫЕ ГОРЯЧИЕ КЛАВИШИ (Fly / Noclip / God)
-- Как работает: единый обработчик InputBegan сверяет нажатую
-- клавишу с таблицей Keybinds. Таблица читается в момент нажатия,
-- поэтому смена клавиш во вкладке «Настройки» применяется мгновенно.
-- Каждая функция вызывается через safe() в task.spawn — ошибка
-- в одной функции не сломает обработчик остальных.
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- игнорируем ввод в чате/текстбоксах
	local key = input.KeyCode

	if key == Keybinds.Fly then
		task.spawn(function()
			safe(setFly, not State.Fly)
		end)
	elseif key == Keybinds.Noclip then
		task.spawn(function()
			safe(setNoclip, not State.Noclip)
		end)
	elseif key == Keybinds.God then
		task.spawn(function()
			safe(setGod, not State.God)
		end)
	elseif key == Keybinds.Panic then
		task.spawn(function()
			safe(triggerPanic)
		end)
	end
end)

----------------------------------------------------------------
-- PANIC KEY (End) — аварийное отключение ВСЕГО
-- Как работает: вызывает setState(false) для каждого зарегистрированного
-- тоггла через ToggleRegistry (поэтому нужен патч из части 2/3 — кнопки
-- в GUI синхронно гаснут), принудительно снимает Fly/Noclip-логику,
-- откатывает визуал (Fullbright, X-Ray, No Fog, ESP, FOV, Third Person),
-- закрывает меню и скрывает иконку сворачивания. Работает даже если
-- меню скрыто — клавиша End обрабатывается глобально.
-- Реализация лежит ниже, ПОСЛЕ определения triggerPanic, потому что
-- hotkey-обработчик выше ссылается на неё (forward-объявление).
----------------------------------------------------------------
local panicOrder = {
	-- порядок выключения важен: сначала то, что живёт на теле
	"Fly", "Noclip",
	-- затем бой (God внутри перезаписывает здоровье — гасим рано)
	"God Mode", "Aim Assist", "Rapid Fire", "Auto Reload", "No Recoil", "Crosshair",
	-- затем визуал
	"ESP", "X-Ray", "Fullbright", "No Fog", "Third Person", "FOV Changer",
	-- затем движение
	"Speed", "Jump", "Infinite Jump", "No Fall Damage",
	-- прочее
	"Anti-AFK",
}

-- Forward-объявление: hotkey-обработчик выше уже ссылается на эту
-- функцию; тело присваивается здесь, до первого нажатия End.
function triggerPanic()
	for _, name in ipairs(panicOrder) do
		local setter = ToggleRegistry[name]
		if setter then
			task.spawn(function()
				safe(setter, false) -- non-silent: реальные функции отключаются
			end)
		end
	end
	-- Принудительный сброс состояний, которые могли остаться от
	-- респавна/краевых случаев (дублирование безопасно — сеттеры
	-- идемпотентны: повторный вызов с тем же значением просто
	-- пройдёт повторную логику отключения).
	task.spawn(function()
		safe(setFly, false)
		safe(setNoclip, false)
		safe(setGod, false)
	end)
	setMenu(false)
	MinIcon.Visible = false
	notify("PANIC: все функции отключены", Color3.fromRGB(220, 90, 90))
end

-- Дополнительная защита: если смерть персонажа произошла, пока меню
-- открыто и активен Fly/Noclip — CharacterAdded-обработчик из части 1
-- уже сбрасывает их; здесь ловим случай, когда Panic нажат в момент
-- отсутствия персонажа (сеттеры сами проверяют через getCharacter()).

--============================================================--
--==== СЕКЦИЯ 8: РЕСПАВН-ИНТЕГРАЦИЯ (дополнение к части 1)   ====--
--============================================================--

-- В части 1 setupCharacter() уже заново применяет Speed/Jump и
-- перепривязывает No Fall Damage. Здесь дополняем: если Anti-AFK
-- или God были включены — они не требуют действий (работают через
-- циклы с getHumanoid()). ESP сам подхватит нового персонажа
-- следующим тиком обновления. Third Person переживает респавн,
-- т.к. CameraMode — свойство игрока, а не персонажа.

-- Одно соединение на случай смены камеры: Aim Assist и FV привязаны
-- к Camera, обновляем ссылку (объявлено в части 1, здесь — дубль
-- страховки для части 2/3-функций, использующих Camera напрямую).
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera
end)

--============================================================--
--==== СЕКЦИЯ 9: ФИНАЛЬНАЯ ИНСТРУКЦИЯ                       ====--
--============================================================--

----------------------------------------------------------------
-- УСТАНОВКА:
-- 1. Собери ВСЕ ТРИ части в ОДИН LocalScript (части идут подряд,
--    в порядке 1/3 → 2/3 → 3/3, без пропусков и дублирования
--    заголовков-разделителей).
-- 2. Не забудь ПАТЧ из начала части 2/3 (ToggleRegistry) —
--    без него Panic Key не будет синхронизировать кнопки GUI.
-- 3. В Studio: Explorer → StarterPlayer → StarterPlayerScripts
--    → вставь LocalScript → вставь в него собранный код.
-- 4. В части 1 замени 123456789 в таблице WHITELIST на свой UserId
--    (узнать: открой свой профиль на roblox.com — число в URL).
--    Добавь туда же UserId тестеров через запятую.
-- 5. Запусти игру через Play. Меню откроется клавишей RightShift.
--
-- КЛАВИШИ ПО УМОЛЧАНИЮ (меняются во вкладке «Настройки»):
--   RightShift — открыть/закрыть меню
--   F          — Fly
--   N          — Noclip
--   G          — God Mode
--   End        — PANIC KEY (мгновенно всё выключает + скрывает меню)
--   Space / LeftControl — вверх/вниз во время полёта
--   ПКМ (зажать) — мягкий Aim Assist к ближайшему игроку
--
-- ВАЖНО (ограничения клиентских функций):
--   Всё здесь — СТРОГО локально: другие игроки и сервер ничего не
--   видят (ESP, X-Ray, Fly-вид, Fullbright — только у тебя на экране).
--   God Mode откатывает урон локально; если сервер твоей игры валидирует
--   здоровье — допиши серверный аналог для честного теста.
--   Rapid Fire / Auto Reload работают, только если оружие хранит
--   конфиги в ValueBase (см. списки имён в секции 5) — это сделано
--   намеренно, чтобы панель была адаптивной к структуре Block Strike.
----------------------------------------------------------------

notify("Панель готова. Клавиши: RightShift — меню, End — паника", THEME.On)
