-- CienUtility single-file bundle (generated). Paste into a LocalScript or run as one file.
local _require=require
local cache,defs={},{}
local fakeParent=setmetatable({},{__index=function(_,k) return {__mod=k} end})
local function require(x) if type(x)=='table' and x.__mod then if cache[x.__mod]==nil then cache[x.__mod]=defs[x.__mod]() end return cache[x.__mod] end return _require(x) end
defs.Core=function()
local script={Parent=fakeParent}
-- Core: config, state (single source of truth), theme palette, tween helper, persistence
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local Core = {}

Core.Config = {
	Name = "CIEN UTILITY",
	Version = "v4.0",
	ToggleKey = Enum.KeyCode.M,
	BaseWide = Vector2.new(780, 480),
	BasePortrait = Vector2.new(380, 640),
	-- Fill in your own SoundIds (rbxassetid://...). Empty = silent.
	Sounds = { Click = "", Ambience = "", ClickVolume = 0.5, AmbienceVolume = 0.15 },
	-- Optional icon image ids per page (rbxassetid://...). Empty = letter fallback.
	Icons = { Overview = "", Player = "", Waypoints = "", ["World Tools"] = "", ["Visual Profiles"] = "", Settings = "" },
}

Core.Presets = {
	CLASSIC = { accent = Color3.fromRGB(64, 150, 255), accent2 = Color3.fromRGB(140, 215, 255), glow = 0.55, desc = "Clean & cool" },
	PRIME   = { accent = Color3.fromRGB(140, 72, 255), accent2 = Color3.fromRGB(205, 120, 255), glow = 0.35, desc = "Signature purple" },
	ULTRA   = { accent = Color3.fromRGB(255, 56, 200), accent2 = Color3.fromRGB(170, 70, 255), glow = 0.1,  desc = "Aggressive neon" },
}
Core.PresetOrder = { "CLASSIC", "PRIME", "ULTRA" }

local DEFAULTS = {
	theme = "Dark", preset = "PRIME", scale = 1,
	animBg = true, edge = true, notify = true, reduced = false, compact = false, sounds = true,
	bubbleX = 0.06, bubbleY = 0.5,
	-- runtime only (never saved)
	page = "Overview", ready = false, shown = false, perf = false, shadows = true, worldNonce = 0,
}
local NOSAVE = { page = true, ready = true, shown = true, perf = true, shadows = true, worldNonce = true }
Core.Defaults, Core.NoSave = DEFAULTS, NOSAVE

local State, listeners = {}, {}
for k, v in pairs(DEFAULTS) do State[k] = v end
Core.State = State
Core.Mode = "wide"
Core.Layouts = {}

function Core.On(key, fn)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
end

function Core.OnLayout(fn) table.insert(Core.Layouts, fn); fn() end
function Core.RunLayouts() for _, f in ipairs(Core.Layouts) do f() end end

-- Persistence (client-only; silently no-op where file APIs don't exist)
local FILE = "CienUtility_v4.json"
local saving = false
function Core.QueueSave()
	if saving then return end
	saving = true
	task.delay(1, function()
		saving = false
		local d = {}
		for k, v in pairs(State) do if not NOSAVE[k] then d[k] = v end end
		pcall(function() writefile(FILE, HttpService:JSONEncode(d)) end)
	end)
end
function Core.Load()
	local ok, d = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
	if ok and type(d) == "table" then
		for k, v in pairs(d) do
			if DEFAULTS[k] ~= nil and not NOSAVE[k] and type(v) == type(DEFAULTS[k]) then State[k] = v end
		end
		if not Core.Presets[State.preset] then State.preset = "PRIME" end
		State.scale = math.clamp(State.scale, 0.8, 1.2)
	end
end

function Core.Set(key, val)
	if State[key] == val then return end
	State[key] = val
	for _, f in ipairs(listeners[key] or {}) do
		local ok, e = pcall(f, val)
		if not ok then warn("[CienUtility] listener error: " .. tostring(e)) end
	end
	if not NOSAVE[key] then Core.QueueSave() end
end

-- Palette from theme + preset
function Core.Pal()
	local dark = State.theme == "Dark"
	local pr = Core.Presets[State.preset]
	local P
	if dark then
		P = { bg = Color3.fromRGB(11, 8, 22), surface = Color3.fromRGB(22, 15, 42), surface2 = Color3.fromRGB(34, 24, 64),
			text = Color3.new(1, 1, 1), sub = Color3.fromRGB(176, 165, 208), line = Color3.fromRGB(72, 52, 124) }
	else
		P = { bg = Color3.fromRGB(240, 234, 252), surface = Color3.fromRGB(252, 249, 255), surface2 = Color3.fromRGB(231, 222, 248),
			text = Color3.fromRGB(32, 22, 54), sub = Color3.fromRGB(104, 92, 138), line = Color3.fromRGB(196, 178, 235) }
	end
	P.bg = P.bg:Lerp(pr.accent, 0.04)
	P.surface = P.surface:Lerp(pr.accent, 0.05)
	P.surface2 = P.surface2:Lerp(pr.accent, 0.08)
	P.line = P.line:Lerp(pr.accent, 0.2)
	P.accent, P.accent2, P.glow, P.dark = pr.accent, pr.accent2, pr.glow, dark
	P.ok = Color3.fromRGB(60, 220, 120)
	return P
end

-- Tween helper (respects Reduced Motion)
function Core.Tween(inst, t, props, style, dir)
	if State.reduced then t = 0.01 end
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Themed registry: map = { Property = function(palette) -> value }
local themed = {}
function Core.Themed(inst, map)
	local e = themed[inst]
	if not e then
		e = {}
		themed[inst] = e
		inst.Destroying:Connect(function() themed[inst] = nil end)
	end
	local P = Core.Pal()
	for k, f in pairs(map) do e[k] = f; inst[k] = f(P) end
end
function Core.Refresh()
	local P = Core.Pal()
	for inst, e in pairs(themed) do
		for k, f in pairs(e) do
			local v = f(P)
			local t = typeof(v)
			if t == "Color3" or t == "number" then Core.Tween(inst, 0.25, { [k] = v }) else inst[k] = v end
		end
	end
end
Core.On("theme", Core.Refresh)
Core.On("preset", Core.Refresh)
Core.On("edge", Core.Refresh)

-- Looping UIGradient rotation, tied to a state key and Reduced Motion
function Core.Loop(gradient, seconds, key)
	local tw
	local function refresh()
		if tw then tw:Cancel(); tw = nil end
		if (key == nil or State[key]) and not State.reduced and gradient.Parent then
			gradient.Rotation = 0
			tw = TweenService:Create(gradient, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
			tw:Play()
		end
	end
	if key then Core.On(key, refresh) end
	Core.On("reduced", refresh)
	refresh()
end

-- Run fn every `interval` only while `page` is visible (cheap polling)
function Core.WhileShown(page, interval, fn)
	local token = 0
	local function check()
		token += 1
		if State.shown and State.page == page then
			local my = token
			task.spawn(function()
				while my == token do
					pcall(fn)
					task.wait(interval)
				end
			end)
		end
	end
	Core.On("shown", check)
	Core.On("page", check)
end

-- Sound
local clickSound
function Core.Click()
	if not State.sounds or Core.Config.Sounds.Click == "" then return end
	if not clickSound then
		clickSound = Instance.new("Sound")
		clickSound.SoundId = Core.Config.Sounds.Click
		clickSound.Volume = Core.Config.Sounds.ClickVolume
		clickSound.Parent = SoundService
	end
	clickSound:Play()
end

Core.Notify = function() end -- replaced by Main
Core.Goto = function() end   -- replaced by Main

return Core

end
defs.Components=function()
local script={Parent=fakeParent}
-- Reusable themed components
local UIS = game:GetService("UserInputService")
local Core = require(script.Parent.Core)
local State = Core.State

local C = {}
local order = 0
local function nxt() order += 1; return order end
local function mk(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do i[k] = v end
	i.Parent = parent
	return i
end
C.mk, C.nxt = mk, nxt

local LAYOUT = Enum.SortOrder.LayoutOrder
local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end

-- Drag helper: onMove(pos, startPos), connections live only during a drag
function C.BindDrag(target, onMove, onStart, onEnd)
	target.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		local start = Vector2.new(input.Position.X, input.Position.Y)
		if onStart then onStart(start) end
		local c1, c2
		c1 = UIS.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i == input then
				onMove(Vector2.new(i.Position.X, i.Position.Y), start)
			end
		end)
		c2 = UIS.InputEnded:Connect(function(i)
			if i == input then
				c1:Disconnect(); c2:Disconnect()
				if onEnd then onEnd(Vector2.new(i.Position.X, i.Position.Y), start) end
			end
		end)
	end)
end

function C.Corner(p, r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, p) end
function C.Stroke(p, accent, th)
	local s = mk("UIStroke", { Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	Core.Themed(s, { Color = function(P) return accent and P.accent or P.line end })
	return s
end

function C.Label(parent, text, size, kind, o)
	o = o or {}
	local l = mk("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, Font = o.Font or Enum.Font.Gotham,
		TextXAlignment = o.align or Enum.TextXAlignment.Left, TextWrapped = true,
		Size = o.Size or UDim2.new(1, 0, 0, size + 4), Position = o.Position or UDim2.new(),
		LayoutOrder = nxt(), RichText = o.rich or false, TextScaled = o.scaled or false,
	}, parent)
	if o.scaled then mk("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 8 }, l) end
	Core.Themed(l, { TextColor3 = function(P)
		if kind == "sub" then return P.sub end
		if kind == "accent" then return P.dark and P.accent2 or P.accent end
		return P.text
	end })
	return l
end

-- hover (mouse only) + press feedback + click sound
function C.Interact(btn, stroke)
	local sc = mk("UIScale", {}, btn)
	btn.MouseButton1Down:Connect(function() Core.Tween(sc, 0.08, { Scale = 0.97 }) end)
	btn.MouseButton1Up:Connect(function() Core.Tween(sc, 0.12, { Scale = 1 }) end)
	btn.MouseEnter:Connect(function()
		if UIS.MouseEnabled and stroke then Core.Tween(stroke, 0.15, { Color = Core.Pal().accent2 }) end
	end)
	btn.MouseLeave:Connect(function()
		Core.Tween(sc, 0.1, { Scale = 1 })
		if stroke then Core.Tween(stroke, 0.2, { Color = Core.Pal().line }) end
	end)
	btn.Activated:Connect(Core.Click)
end

function C.Card(parent, o)
	o = o or {}
	local f = mk(o.class or "Frame", {
		BorderSizePixel = 0, LayoutOrder = nxt(), Size = o.Size or UDim2.new(1, 0, 0, 60),
		AutomaticSize = o.auto or Enum.AutomaticSize.None,
	}, parent)
	if o.class == "TextButton" then f.Text = ""; f.AutoButtonColor = false end
	C.Corner(f, o.radius or 10)
	f.Name = o.Name or "Card"
	local s = C.Stroke(f)
	Core.Themed(f, { BackgroundColor3 = function(P) return o.alt and P.surface2 or P.surface end })
	if o.class == "TextButton" then C.Interact(f, s) end
	return f, s
end

function C.Section(parent, title, sub)
	local c = C.Card(parent, { Size = UDim2.new(1, 0, 0, 0), auto = Enum.AutomaticSize.Y })
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = LAYOUT }, c)
	mk("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, c)
	C.Label(c, title, 16, "text", { Font = Enum.Font.GothamBold })
	if sub then C.Label(c, sub, 11, "sub") end
	return c
end

function C.Button(parent, text, primary, cb, o)
	o = o or {}
	local b = mk("TextButton", {
		Text = text, TextSize = o.size or 13, Font = Enum.Font.GothamBold, AutoButtonColor = false,
		Size = o.Size or UDim2.new(1, 0, 0, 34), LayoutOrder = nxt(), BorderSizePixel = 0,
	}, parent)
	C.Corner(b, 8)
	local s = C.Stroke(b)
	Core.Themed(b, {
		BackgroundColor3 = function(P) return primary and P.accent or P.surface2 end,
		TextColor3 = function(P) return primary and Color3.new(1, 1, 1) or P.text end,
	})
	C.Interact(b, s)
	if cb then b.Activated:Connect(cb) end
	return b
end

-- Toggle row bound to State[key]; optional get/set overrides (e.g. theme)
function C.Toggle(parent, title, desc, key, get, set)
	get = get or function() return State[key] end
	set = set or function(v) Core.Set(key, v) end
	local row = C.Card(parent, { Size = UDim2.new(1, 0, 0, desc and 50 or 40), alt = true, class = "TextButton" })
	local t = C.Label(row, title, 13, "text", { Font = Enum.Font.GothamMedium, Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(12, desc and 7 or 11) })
	if desc then C.Label(row, desc, 10, "sub", { Size = UDim2.new(1, -70, 0, 14), Position = UDim2.fromOffset(12, 26) }) end
	local track = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 22), BorderSizePixel = 0 }, row)
	C.Corner(track, 11)
	local knob = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
	C.Corner(knob, 8)
	Core.Themed(track, { BackgroundColor3 = function(P) return get() and P.accent or P.line end })
	local function render()
		local on = get()
		Core.Tween(knob, 0.18, { Position = UDim2.new(0, on and 22 or 4, 0.5, 0) })
		Core.Tween(track, 0.18, { BackgroundColor3 = on and Core.Pal().accent or Core.Pal().line })
	end
	knob.Position = UDim2.new(0, get() and 22 or 4, 0.5, 0)
	row.Activated:Connect(function() set(not get()); render() end)
	if key then Core.On(key, render) end
	return row
end

-- Slider. get()/set(v); onKey re-renders when that state key changes
function C.Slider(parent, title, min, max, get, set, fmt, onKey, step)
	fmt = fmt or function(v) return string.format("%.2f", v) end
	step = step or 0
	local row = C.Card(parent, { Size = UDim2.new(1, 0, 0, 58), alt = true })
	C.Label(row, title, 13, "text", { Font = Enum.Font.GothamMedium, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(12, 7) })
	local val = C.Label(row, "", 12, "accent", { Font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, -12, 0, 18), Position = UDim2.new(0.6, 0, 0, 7) })
	local hit = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 28), Size = UDim2.new(1, -24, 0, 26) }, row)
	local bar = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BorderSizePixel = 0 }, hit)
	C.Corner(bar, 3)
	Core.Themed(bar, { BackgroundColor3 = function(P) return P.line end })
	local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, bar)
	C.Corner(fill, 3)
	Core.Themed(fill, { BackgroundColor3 = function(P) return P.accent end })
	local thumb = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, bar)
	C.Corner(thumb, 8)
	local ts = mk("UIStroke", { Thickness = 2 }, thumb)
	Core.Themed(ts, { Color = function(P) return P.accent2 end })
	local function render()
		local a = math.clamp((get() - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		thumb.Position = UDim2.fromScale(a, 0.5)
		val.Text = fmt(get())
	end
	local sf
	local function fromX(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local v = min + (max - min) * a
		if step > 0 then v = math.floor(v / step + 0.5) * step end
		set(v); render()
	end
	C.BindDrag(hit, function(p) fromX(p.X) end, function(p)
		sf = hit:FindFirstAncestorOfClass("ScrollingFrame")
		if sf then sf.ScrollingEnabled = false end
		fromX(p.X)
	end, function() if sf then sf.ScrollingEnabled = true end end)
	if onKey then Core.On(onKey, render) end
	render()
	return row
end

-- Chip row (single select)
function C.Chips(parent, title, options, onPick, default)
	local sec = C.Section(parent, title)
	local holder = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = nxt() }, sec)
	mk("UIGridLayout", { CellSize = UDim2.new(1 / #options, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 6), SortOrder = LAYOUT }, holder)
	local active, chips = default or options[1], {}
	local function paint(animate)
		local P = Core.Pal()
		for name, b in pairs(chips) do
			local c = name == active and P.accent or P.surface2
			if animate then Core.Tween(b, 0.15, { BackgroundColor3 = c }) else b.BackgroundColor3 = c end
		end
	end
	for _, name in ipairs(options) do
		local b = C.Button(holder, name, false, function() active = name; paint(true); onPick(name) end, { size = 11, Size = UDim2.new() })
		Core.Themed(b, { BackgroundColor3 = function(P) return name == active and P.accent or P.surface2 end,
			TextColor3 = function(P) return name == active and Color3.new(1, 1, 1) or P.text end })
		chips[name] = b
	end
	Core.On("worldNonce", function() active = default or options[1]; paint(true) end)
	return sec
end

-- Recreated crystalline "C" logo (UI primitives) + orbit trail
function C.Logo(parent, size, o)
	o = o or {}
	local f = mk("Frame", { BackgroundTransparency = 1, Size = size, LayoutOrder = nxt() }, parent)
	mk("UIAspectRatioConstraint", { AspectRatio = 1 }, f)
	if o.pos then f.Position = o.pos; f.AnchorPoint = o.anchor or Vector2.new() end
	local orbit = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.15, 0.7), BackgroundTransparency = 1, Rotation = -28, ZIndex = 1 }, f)
	C.Corner(orbit, 999)
	local os = mk("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, orbit)
	local og = mk("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0) }) }, os)
	Core.Themed(og, { Color = function(P) return ColorSequence.new(P.accent2, P.accent) end })
	Core.Loop(og, 5, nil)

	local function facet(x, y, w, h, rot, z)
		local b = mk("Frame", { Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rot or 0, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z or 2 }, f)
		local g = mk("UIGradient", { Rotation = 45 }, b)
		Core.Themed(g, { Color = function(P) return ColorSequence.new({ ColorSequenceKeypoint.new(0, P.accent2), ColorSequenceKeypoint.new(0.55, P.accent), ColorSequenceKeypoint.new(1, P.accent:Lerp(Color3.new(0, 0, 0), 0.65)) }) end })
		Core.Loop(g, 8, nil)
		return b
	end
	facet(0.16, 0.18, 0.68, 0.19)               -- top bar
	facet(0.16, 0.63, 0.68, 0.19)               -- bottom bar
	facet(0.16, 0.18, 0.22, 0.64)               -- spine
	facet(0.72, 0.13, 0.16, 0.16, 38, 3)        -- top terminal
	facet(0.72, 0.71, 0.16, 0.16, -38, 3)       -- bottom terminal
	local dark = mk("Frame", { Position = UDim2.fromScale(0.27, 0.37), Size = UDim2.fromScale(0.11, 0.26), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 4 }, f)
	local hl = mk("Frame", { Position = UDim2.fromScale(0.2, 0.19), Size = UDim2.fromScale(0.58, 0.02), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 4 }, f)
	return f
end

return C

end
defs.Features=function()
local script={Parent=fakeParent}
-- Client-side features: waypoint markers and cosmetic/performance world tools
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local F = {}

---------------------------------------------------------------- Waypoints
local WP = { list = {}, listeners = {}, MAX = 10 }
F.Waypoints = WP
local folder

local function fire() for _, f in ipairs(WP.listeners) do pcall(f) end end
function WP.OnChange(f) table.insert(WP.listeners, f) end

function WP.Place(color)
	if #WP.list >= WP.MAX then return nil, "Marker limit reached (" .. WP.MAX .. ")" end
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root then return nil, "Character not ready" end
	if not folder or not folder.Parent then
		folder = Instance.new("Folder"); folder.Name = "CienUtilityMarkers"; folder.Parent = workspace
	end
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + (hum and hum.HipHeight or 2), 0)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, 3, 3)
	part.Orientation = Vector3.new(0, 0, 90)
	part.Position = feet
	part.Material, part.Color, part.Transparency = Enum.Material.Neon, color or Color3.fromRGB(160, 90, 255), 0.3
	part.Parent = folder
	local id = #WP.list + 1
	local entry = { name = "Marker " .. id, pos = feet, part = part }
	local bb = Instance.new("BillboardGui")
	bb.Size, bb.StudsOffset, bb.AlwaysOnTop = UDim2.fromOffset(110, 24), Vector3.new(0, 3, 0), true
	bb.Parent = part
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Text = UDim2.fromScale(1, 1), 1, entry.name
	t.TextColor3, t.Font, t.TextSize = Color3.new(1, 1, 1), Enum.Font.GothamBold, 14
	t.TextStrokeTransparency = 0.5
	t.Parent = bb
	table.insert(WP.list, entry)
	fire()
	return entry
end

function WP.Remove(entry)
	local i = table.find(WP.list, entry)
	if i then table.remove(WP.list, i); entry.part:Destroy(); fire() end
end
function WP.Clear()
	for _, e in ipairs(WP.list) do e.part:Destroy() end
	table.clear(WP.list); fire()
end
function WP.Distance(entry)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - entry.pos).Magnitude or 0
end

---------------------------------------------------------------- World tools
local WT = { cur = {} }
F.World = WT
local orig
local function snap()
	if orig then return end
	orig = {
		Clock = Lighting.ClockTime, Brightness = Lighting.Brightness, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
		FogColor = Lighting.FogColor, Ambient = Lighting.Ambient, Outdoor = Lighting.OutdoorAmbient, Shadows = Lighting.GlobalShadows,
	}
	pcall(function() orig.Decoration = workspace.Terrain.Decoration end)
end

function WT.Clock(h) snap(); WT.cur.Clock = h; Lighting.ClockTime = h end
function WT.Brightness(v) snap(); WT.cur.Brightness = v; Lighting.Brightness = v end
function WT.FogDistance(d)
	snap(); WT.cur.Fog = d
	Lighting.FogStart = 0
	Lighting.FogEnd = d >= 5000 and (orig.FogEnd >= 5000 and orig.FogEnd or 100000) or d
end
local FOG = { Default = false, Mist = Color3.fromRGB(190, 195, 210), Violet = Color3.fromRGB(80, 40, 140), Night = Color3.fromRGB(10, 10, 24) }
WT.FogNames = { "Default", "Mist", "Violet", "Night" }
function WT.FogColor(n) snap(); Lighting.FogColor = FOG[n] or orig.FogColor end
local AMB = { Default = false, Cool = Color3.fromRGB(70, 90, 140), Warm = Color3.fromRGB(150, 110, 80), Neon = Color3.fromRGB(110, 60, 170) }
WT.AmbNames = { "Default", "Cool", "Warm", "Neon" }
function WT.Ambience(n)
	snap()
	local c = AMB[n]
	Lighting.Ambient = c or orig.Ambient
	Lighting.OutdoorAmbient = c or orig.Outdoor
end

local hiddenSkies = {}
function WT.Sky(mode)
	if mode == "Hidden" then
		for _, s in ipairs(Lighting:GetChildren()) do
			if s:IsA("Sky") then table.insert(hiddenSkies, s); s.Parent = nil end
		end
	else
		for _, s in ipairs(hiddenSkies) do s.Parent = Lighting end
		table.clear(hiddenSkies)
	end
end

local FX = { "BloomEffect", "BlurEffect", "SunRaysEffect", "DepthOfFieldEffect" }
local EMIT = { "ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles" }
local disabled, perfToken = {}, 0
local function isOneOf(inst, list) for _, c in ipairs(list) do if inst:IsA(c) then return true end end return false end

function WT.Perf(on)
	snap()
	perfToken += 1
	local my = perfToken
	if on then
		Lighting.GlobalShadows = false
		pcall(function() workspace.Terrain.Decoration = false end)
		for _, e in ipairs(Lighting:GetChildren()) do
			if isOneOf(e, FX) and e.Enabled then e.Enabled = false; table.insert(disabled, e) end
		end
		task.spawn(function()
			local n = 0
			for _, d in ipairs(workspace:GetDescendants()) do
				if my ~= perfToken then return end
				if isOneOf(d, EMIT) and d.Enabled then d.Enabled = false; table.insert(disabled, d) end
				n += 1
				if n % 600 == 0 then task.wait() end
			end
		end)
	else
		for _, d in ipairs(disabled) do if d.Parent then d.Enabled = true end end
		table.clear(disabled)
		Lighting.GlobalShadows = orig.Shadows
		if orig.Decoration ~= nil then pcall(function() workspace.Terrain.Decoration = orig.Decoration end) end
	end
end
function WT.Shadows(on) snap(); Lighting.GlobalShadows = on end

function WT.Reset()
	if not orig then return end
	WT.Perf(false)
	WT.Sky("Default")
	Lighting.ClockTime, Lighting.Brightness = orig.Clock, orig.Brightness
	Lighting.FogEnd, Lighting.FogStart, Lighting.FogColor = orig.FogEnd, orig.FogStart, orig.FogColor
	Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.GlobalShadows = orig.Ambient, orig.Outdoor, orig.Shadows
	table.clear(WT.cur)
end

function F.Cleanup()
	WT.Reset()
	WP.Clear()
	if folder then folder:Destroy() end
end

return F

end
defs.Pages=function()
local script={Parent=fakeParent}
-- All pages: Overview, Player, Waypoints, World Tools, Visual Profiles, Settings
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Core = require(script.Parent.Core)
local C = require(script.Parent.Components)
local F = require(script.Parent.Features)

local State, mk, nxt = Core.State, C.mk, C.nxt
local LAYOUT = Enum.SortOrder.LayoutOrder
local Pages = {}

Pages.Order = { "Overview", "Player", "Waypoints", "World Tools", "Visual Profiles", "Settings" }
Pages.Short = { Overview = "Home", Player = "Player", Waypoints = "Marks", ["World Tools"] = "World", ["Visual Profiles"] = "Visuals", Settings = "Settings" }

local function hex(c) return c:ToHex() end

function Pages.Build(content)
	local pages = {}

	local function newPage(name)
		local g = mk("CanvasGroup", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, content)
		local sc = mk("ScrollingFrame", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ScrollBarThickness = 3,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		}, g)
		Core.Themed(sc, { ScrollBarImageColor3 = function(P) return P.accent end })
		mk("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = LAYOUT }, sc)
		mk("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, sc)
		pages[name] = g
		return sc
	end

	local function grid(parent, cols, h)
		local holder = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nxt() }, parent)
		local g = mk("UIGridLayout", { CellPadding = UDim2.fromOffset(8, 8), SortOrder = LAYOUT }, holder)
		Core.OnLayout(function()
			local n = Core.Mode == "portrait" and 2 or cols
			g.CellSize = UDim2.new(1 / n, -(8 * (n - 1) / n), 0, h)
		end)
		return holder
	end

	---------------------------------------------------------------- Overview
	do
		local p = newPage("Overview")
		local hero = C.Card(p, { Size = UDim2.new(1, 0, 0, 170) })
		local hg = mk("UIGradient", { Rotation = 20 }, hero)
		Core.Themed(hero, { BackgroundColor3 = function() return Color3.new(1, 1, 1) end })
		Core.Themed(hg, { Color = function(P) return ColorSequence.new(P.surface2:Lerp(P.accent, 0.3), P.surface) end })
		Core.Loop(hg, 18, "animBg")

		local tx = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.62, 0, 1, 0) }, hero)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingTop = UDim.new(0, 14) }, tx)
		mk("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = LAYOUT }, tx)
		C.Label(tx, "WELCOME TO", 10, "sub", { Font = Enum.Font.GothamMedium })
		local title = C.Label(tx, "", 30, "text", { Font = Enum.Font.GothamBlack, rich = true, scaled = true, Size = UDim2.new(1, 0, 0, 34) })
		Core.Themed(title, { Text = function(P) return 'CIEN <font color="#' .. hex(P.accent2) .. '">UTILITY</font>' end })
		C.Label(tx, "OWN YOUR INTERFACE.", 13, "text", { Font = Enum.Font.GothamBold })
		C.Label(tx, "A smooth, responsive and powerful UI, built for your own experience.", 11, "sub", { Size = UDim2.new(1, 0, 0, 30) })
		local br = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = nxt() }, tx)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = LAYOUT }, br)
		C.Button(br, "Visual Profiles", true, function() Core.Goto("Visual Profiles") end, { Size = UDim2.fromOffset(110, 30), size = 12 })
		C.Button(br, "Settings", false, function() Core.Goto("Settings") end, { Size = UDim2.fromOffset(80, 30), size = 12 })
		C.Logo(hero, UDim2.fromScale(0.34, 0.92), { pos = UDim2.fromScale(0.97, 0.5), anchor = Vector2.new(1, 0.5) })

		-- status cards
		local sg = grid(p, 4, 52)
		local function stat(titleText, get, keys)
			local c = C.Card(sg, { alt = true })
			C.Label(c, titleText, 10, "sub", { Font = Enum.Font.GothamMedium, Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(10, 8) })
			local v = C.Label(c, "", 17, "accent", { Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(10, 24) })
			local function r() v.Text = get() end
			for _, k in ipairs(keys) do Core.On(k, r) end
			r()
			return v
		end
		local st = stat("UI STATUS", function() return State.ready and "READY" or "LOADING" end, { "ready" })
		Core.Themed(st, { TextColor3 = function(P) return P.ok end })
		stat("THEME", function() return State.theme:upper() end, { "theme" })
		stat("PRESET", function() return State.preset end, { "preset" })
		stat("SCALE", function() return string.format("%d%%", State.scale * 100 + 0.5) end, { "scale" })

		-- quick actions
		local qa = grid(p, 4, 54)
		local acts = { { "Player", "Profile & diagnostics" }, { "Waypoints", "Mark positions" }, { "World Tools", "Visual & FPS tweaks" }, { "Visual Profiles", "Customize look" } }
		for _, a in ipairs(acts) do
			local b = C.Card(qa, { class = "TextButton", alt = true })
			C.Label(b, a[1], 13, "text", { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(10, 9) })
			C.Label(b, a[2], 10, "sub", { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(10, 28) })
			b.Activated:Connect(function() Core.Goto(a[1]) end)
		end

		local qc = C.Section(p, "Quick Controls", "Essential toggles and interface settings.")
		C.Toggle(qc, "Animated Background", "Moving purple gradient", "animBg")
		C.Toggle(qc, "3D Edge Lighting", "Reactive outlines", "edge")
		C.Toggle(qc, "Notifications", "Action feedback", "notify")
		C.Toggle(qc, "Reduced Motion", "Smoother experience", "reduced")
		C.Slider(qc, "Interface Scale", 0.8, 1.2, function() return State.scale end, function(v) Core.Set("scale", v) end,
			function(v) return string.format("%.2fx", v) end, "scale", 0.05)
	end

	---------------------------------------------------------------- Player
	do
		local p = newPage("Player")
		local lp = Players.LocalPlayer
		local card = C.Card(p, { Size = UDim2.new(1, 0, 0, 90) })
		local av = mk("ImageLabel", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(13, 13), BackgroundTransparency = 0.5, BorderSizePixel = 0 }, card)
		C.Corner(av, 32)
		Core.Themed(av, { BackgroundColor3 = function(P) return P.surface2 end })
		task.spawn(function()
			local ok, img = pcall(function() return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
			if ok then av.Image = img end
		end)
		C.Label(card, lp.DisplayName, 17, "text", { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -96, 0, 22), Position = UDim2.fromOffset(88, 16) })
		C.Label(card, "@" .. lp.Name, 12, "sub", { Size = UDim2.new(1, -96, 0, 16), Position = UDim2.fromOffset(88, 40) })
		local on = C.Label(card, "Online (local)", 11, "text", { Size = UDim2.new(1, -96, 0, 14), Position = UDim2.fromOffset(88, 60) })
		Core.Themed(on, { TextColor3 = function(P) return P.ok end })

		local info = C.Section(p, "Account", "Read-only data from your local Roblox session.")
		C.Label(info, "User ID: " .. lp.UserId, 12, "text")
		C.Label(info, "Account age: " .. lp.AccountAge .. " days", 12, "text")

		local diag = C.Section(p, "Diagnostics", "Live while this page is open.")
		local fps = C.Label(diag, "FPS: ...", 12, "text")
		local ping = C.Label(diag, "Ping: ...", 12, "text")
		Core.WhileShown("Player", 0.5, function()
			local t = 0
			for _ = 1, 10 do t += RunService.RenderStepped:Wait() end
			fps.Text = string.format("FPS: %d", 10 / t + 0.5)
			ping.Text = string.format("Ping: %d ms", lp:GetNetworkPing() * 2000)
		end)
	end

	---------------------------------------------------------------- Waypoints
	do
		local p = newPage("Waypoints")
		local top = C.Section(p, "Waypoints", "Marks where you are standing. Markers are visible only to you.")
		C.Button(top, "Place marker here", true, function()
			local e, err = F.Waypoints.Place(Core.Pal().accent2)
			if e then Core.Notify("Placed " .. e.name) else Core.Notify(err, true) end
		end)
		C.Button(top, "Clear all markers", false, function() F.Waypoints.Clear(); Core.Notify("Markers cleared") end)
		local list = C.Section(p, "Markers")
		local rows, empty = {}, nil
		local function rebuild()
			for _, r in ipairs(rows) do r.row:Destroy() end
			table.clear(rows)
			if empty then empty:Destroy(); empty = nil end
			if #F.Waypoints.list == 0 then empty = C.Label(list, "No markers yet.", 12, "sub") end
			for _, e in ipairs(F.Waypoints.list) do
				local row = C.Card(list, { Size = UDim2.new(1, 0, 0, 40), alt = true })
				C.Label(row, e.name, 13, "text", { Font = Enum.Font.GothamMedium, Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(12, 11) })
				local d = C.Label(row, "", 12, "accent", { align = Enum.TextXAlignment.Right, Size = UDim2.new(0.3, 0, 0, 18), Position = UDim2.new(0.4, 0, 0, 11) })
				local x = C.Button(row, "X", false, function() F.Waypoints.Remove(e) end, { Size = UDim2.fromOffset(26, 26), size = 11 })
				x.AnchorPoint, x.Position = Vector2.new(1, 0.5), UDim2.new(1, -8, 0.5, 0)
				table.insert(rows, { row = row, d = d, e = e })
			end
		end
		F.Waypoints.OnChange(rebuild)
		rebuild()
		Core.WhileShown("Waypoints", 1, function()
			for _, r in ipairs(rows) do r.d.Text = string.format("%d studs", F.Waypoints.Distance(r.e)) end
		end)
	end

	---------------------------------------------------------------- World Tools
	do
		local p = newPage("World Tools")
		local W = F.World
		local at = C.Section(p, "Atmosphere", "Client-side visuals only.")
		C.Slider(at, "Time of day", 0, 24, function() return W.cur.Clock or Lighting.ClockTime end, W.Clock, function(v) return string.format("%02d:%02d", v, (v % 1) * 60) end, "worldNonce", 0.25)
		C.Slider(at, "Brightness", 0, 5, function() return W.cur.Brightness or Lighting.Brightness end, W.Brightness, nil, "worldNonce", 0.1)
		C.Slider(at, "Fog distance", 100, 5000, function() return W.cur.Fog or math.min(Lighting.FogEnd, 5000) end, W.FogDistance,
			function(v) return v >= 5000 and "Off" or string.format("%d", v) end, "worldNonce", 50)
		C.Chips(p, "Fog color", W.FogNames, W.FogColor)
		C.Chips(p, "Ambience", W.AmbNames, W.Ambience)
		C.Chips(p, "Sky", { "Default", "Hidden" }, W.Sky)
		local pf = C.Section(p, "Performance", "Reduces effects to help frame rate.")
		C.Toggle(pf, "Performance mode", "Disables shadows, particles, post effects", "perf")
		C.Toggle(pf, "Shadows", "Global shadows", "shadows")
		C.Button(p, "Reset world to original", false, function()
			W.Reset(); Core.Set("perf", false); Core.Set("shadows", true)
			Core.Set("worldNonce", State.worldNonce + 1)
			Core.Notify("World restored")
		end)
		Core.On("perf", W.Perf)
		Core.On("shadows", W.Shadows)
	end

	---------------------------------------------------------------- Visual Profiles
	do
		local p = newPage("Visual Profiles")
		local sec = C.Section(p, "Visual Profiles", "Each profile changes accent colors, glow strength and tint.")
		local holder = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 140), LayoutOrder = nxt() }, sec)
		mk("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 8), SortOrder = LAYOUT }, holder)
		local pending, cards = State.preset, {}
		local function paint()
			for name, c in pairs(cards) do
				local sel = name == pending
				Core.Tween(c.stroke, 0.2, { Thickness = sel and 3 or 1 })
				c.tag.Text = name == State.preset and "ACTIVE" or (sel and "SELECTED" or "")
			end
		end
		for _, name in ipairs(Core.PresetOrder) do
			local pr = Core.Presets[name]
			local b, s = C.Card(holder, { class = "TextButton", alt = true })
			local sw = mk("Frame", { Size = UDim2.new(1, -16, 0, 56), Position = UDim2.fromOffset(8, 8), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, b)
			C.Corner(sw, 8)
			mk("UIGradient", { Color = ColorSequence.new(pr.accent2, pr.accent), Rotation = 35 }, sw)
			C.Label(b, name, 14, "text", { Font = Enum.Font.GothamBlack, align = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 72) })
			C.Label(b, pr.desc, 10, "sub", { align = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 92) })
			local tag = C.Label(b, "", 9, "accent", { Font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 114) })
			cards[name] = { stroke = s, tag = tag }
			b.Activated:Connect(function() pending = name; paint() end)
		end
		paint()
		C.Button(sec, "APPLY VISUAL PROFILE", true, function()
			if pending == State.preset then Core.Notify("Already using " .. pending) return end
			Core.Set("preset", pending); paint(); Core.Notify("Applied profile: " .. pending)
		end)
		Core.On("preset", function(v) pending = v; paint() end)
	end

	---------------------------------------------------------------- Settings
	do
		local p = newPage("Settings")
		local ap = C.Section(p, "Appearance", "Theme and layout.")
		C.Toggle(ap, "Light theme", "Clean and vibrant look", "theme", function() return State.theme == "Light" end, function(v) Core.Set("theme", v and "Light" or "Dark") end)
		C.Slider(ap, "Interface Scale", 0.8, 1.2, function() return State.scale end, function(v) Core.Set("scale", v) end,
			function(v) return string.format("%d%%", v * 100 + 0.5) end, "scale", 0.05)
		C.Toggle(ap, "Compact sidebar", "Icons only", "compact")
		local fx = C.Section(p, "Effects & Feedback")
		C.Toggle(fx, "Animated Background", nil, "animBg")
		C.Toggle(fx, "3D Edge Lighting", nil, "edge")
		C.Toggle(fx, "Reduced Motion", "Disables looping effects", "reduced")
		C.Toggle(fx, "Notifications", nil, "notify")
		C.Toggle(fx, "Sounds", "Needs SoundIds in Config", "sounds")
		C.Button(p, "Restore defaults", false, function()
			for k, v in pairs(Core.Defaults) do
				if not Core.NoSave[k] then Core.Set(k, v) end
			end
			Core.Notify("Defaults restored")
		end)
	end

	return pages
end

return Pages

end
defs.Main=function()
local script={Parent=fakeParent}
-- Main: window shell, navigation, bubble, notifications, responsive layout
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local Core = require(script.Parent.Core)
local C = require(script.Parent.Components)
local F = require(script.Parent.Features)
local Pages = require(script.Parent.Pages)

local State, mk, nxt = Core.State, C.mk, C.nxt
local LAYOUT = Enum.SortOrder.LayoutOrder
local lp = Players.LocalPlayer
local PG = lp:WaitForChild("PlayerGui")

local old = PG:FindFirstChild("CienUtility")
if old then old:Destroy() end
Core.Load()

local gui = mk("ScreenGui", { Name = "CienUtility", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, PG)

---------------------------------------------------------------- Window
local win = mk("CanvasGroup", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(780, 480), BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 1, Visible = false }, gui)
C.Corner(win, 16)
local uiscale = mk("UIScale", {}, win)

-- animated backdrop lives in a child frame (a gradient on the CanvasGroup itself would tint every child)
local bgf = mk("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, win)
local bgg = mk("UIGradient", { Rotation = 30 }, bgf)
Core.Themed(bgg, { Color = function(P)
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, P.bg), ColorSequenceKeypoint.new(0.5, P.bg:Lerp(P.accent, 0.22)), ColorSequenceKeypoint.new(1, P.bg) })
end })
Core.Loop(bgg, 24, "animBg")

local edge = mk("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, win)
local eg = mk("UIGradient", {}, edge)
Core.Themed(eg, { Color = function(P) return ColorSequence.new({ ColorSequenceKeypoint.new(0, P.accent), ColorSequenceKeypoint.new(0.5, P.accent2), ColorSequenceKeypoint.new(1, P.accent) }) end })
Core.Themed(edge, { Transparency = function(P) return State.edge and P.glow * 0.6 or 0.8 end })
Core.Loop(eg, 6, "edge")

---------------------------------------------------------------- Header
local header = mk("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56) }, win)
C.Logo(header, UDim2.fromOffset(40, 40), { pos = UDim2.fromOffset(14, 8) })
local title = C.Label(header, "", 20, "text", { Font = Enum.Font.GothamBlack, rich = true, scaled = true, Position = UDim2.fromOffset(62, 8), Size = UDim2.fromOffset(200, 24) })
Core.Themed(title, { Text = function(P) return 'CIEN <font color="#' .. P.accent2:ToHex() .. '">UTILITY</font>' end })
local subtitle = C.Label(header, "", 9, "sub", { Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(62, 33), Size = UDim2.fromOffset(260, 12) })

local function hbtn(text, x, w)
	local b = C.Button(header, text, false, nil, { Size = UDim2.fromOffset(w or 30, 30), size = 12 })
	b.AnchorPoint, b.Position = Vector2.new(1, 0.5), UDim2.new(1, x, 0.5, 0)
	return b
end
local closeB, minB = hbtn("X", -14), hbtn("-", -50)
local themeB = hbtn("THEME", -86, 56)

local search = mk("TextBox", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(190, 30),
	PlaceholderText = "Search anything...", Text = "", ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0,
}, header)
C.Corner(search, 8); C.Stroke(search)
mk("UIPadding", { PaddingLeft = UDim.new(0, 10) }, search)
Core.Themed(search, {
	BackgroundColor3 = function(P) return P.surface end,
	TextColor3 = function(P) return P.text end,
	PlaceholderColor3 = function(P) return P.sub end,
})

---------------------------------------------------------------- Sidebar + content
local side = C.Card(win, { Name = "Sidebar" })
local profile = C.Card(side, { Size = UDim2.new(1, -16, 0, 52), alt = true })
profile.Position = UDim2.fromOffset(8, 8)
local av = mk("ImageLabel", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(8, 8), BorderSizePixel = 0, BackgroundTransparency = 0.5 }, profile)
C.Corner(av, 18)
Core.Themed(av, { BackgroundColor3 = function(P) return P.surface end })
task.spawn(function()
	local ok, img = pcall(function() return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	if ok then av.Image = img end
end)
C.Label(profile, lp.DisplayName, 13, "text", { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -58, 0, 16) })
local onl = C.Label(profile, "Online", 10, "text", { Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -58, 0, 12) })
Core.Themed(onl, { TextColor3 = function(P) return P.ok end })

local navHolder = mk("Frame", { BackgroundTransparency = 1, Name = "Nav" }, side)
local navList = mk("UIListLayout", { SortOrder = LAYOUT, Padding = UDim.new(0, 4) }, navHolder)

local footer = C.Card(side, { Size = UDim2.new(1, -16, 0, 44), alt = true })
footer.Position = UDim2.new(0, 8, 1, -52)
local dot = mk("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(12, 18), BorderSizePixel = 0 }, footer)
C.Corner(dot, 4)
Core.Themed(dot, { BackgroundColor3 = function(P) return P.ok end })
C.Label(footer, "Interface Online", 11, "text", { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(28, 7), Size = UDim2.new(1, -34, 0, 14) })
C.Label(footer, Core.Config.Version, 10, "sub", { Position = UDim2.fromOffset(28, 22), Size = UDim2.new(1, -34, 0, 12) })

local content = mk("Frame", { Name = "Content", BackgroundTransparency = 1 }, win)

local items, current = {}, nil
for _, name in ipairs(Pages.Order) do
	local b = mk("TextButton", { Name = name, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 1, LayoutOrder = nxt() }, navHolder)
	C.Corner(b, 10)
	Core.Themed(b, { BackgroundColor3 = function(P) return P.accent end })
	local icon = mk("Frame", { Size = UDim2.fromOffset(28, 28), BorderSizePixel = 0 }, b)
	C.Corner(icon, 8)
	Core.Themed(icon, { BackgroundColor3 = function(P) return P.surface2 end })
	local id = Core.Config.Icons[name]
	if id and id ~= "" then
		mk("ImageLabel", { BackgroundTransparency = 1, Image = id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62) }, icon)
	else
		C.Label(icon, name:sub(1, 1), 14, "accent", { Font = Enum.Font.GothamBlack, align = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	end
	local label = C.Label(b, name, 13, "text", { Font = Enum.Font.GothamMedium })
	C.Interact(b, nil)
	b.MouseEnter:Connect(function() if UIS.MouseEnabled and current ~= name then Core.Tween(b, 0.15, { BackgroundTransparency = 0.85 }) end end)
	b.MouseLeave:Connect(function() if current ~= name then Core.Tween(b, 0.15, { BackgroundTransparency = 1 }) end end)
	b.Activated:Connect(function() Core.Goto(name) end)
	items[name] = { btn = b, icon = icon, label = label }
end

local function highlight()
	local P = Core.Pal()
	for name, it in pairs(items) do
		local a = name == current
		Core.Tween(it.btn, 0.2, { BackgroundTransparency = a and 0 or 1 })
		Core.Tween(it.label, 0.2, { TextColor3 = a and Color3.new(1, 1, 1) or P.text })
	end
end

---------------------------------------------------------------- Layout (responsive)
local pos, target, mode = Vector2.zero, 1, "closed"
local base = Core.Config.BaseWide
local lastMode

local function clampPos()
	local vp = gui.AbsoluteSize
	local hw, hh = base.X * target / 2, base.Y * target / 2
	pos = Vector2.new(
		math.clamp(pos.X, math.min(hw, vp.X / 2), math.max(vp.X - hw, vp.X / 2)),
		math.clamp(pos.Y, math.min(hh, vp.Y / 2), math.max(vp.Y - hh, vp.Y / 2)))
	win.Position = UDim2.fromOffset(pos.X, pos.Y)
end

local function Layout()
	local vp = gui.AbsoluteSize
	if vp.X <= 0 or vp.Y <= 0 then return end
	local portrait = vp.X < 560 and vp.Y > vp.X
	local newMode = portrait and "portrait" or "wide"
	base = portrait and Core.Config.BasePortrait or Core.Config.BaseWide
	local modeChanged = newMode ~= lastMode
	lastMode = newMode
	Core.Mode = newMode

	win.Size = UDim2.fromOffset(base.X, base.Y)
	local maxFit = math.min((vp.X - 16) / base.X, (vp.Y - 16) / base.Y)
	target = math.min(math.min(1, maxFit * 0.92) * State.scale, maxFit)
	if win.Visible then Core.Tween(uiscale, 0.1, { Scale = target }) end
	if modeChanged or pos == Vector2.zero then pos = vp / 2 end
	clampPos()

	local full = not portrait and not State.compact
	local sideW = portrait and 0 or (full and 196 or 56)
	if portrait then
		side.Position, side.Size = UDim2.new(0, 8, 1, -64), UDim2.new(1, -16, 0, 56)
		content.Position, content.Size = UDim2.fromOffset(8, 64), UDim2.new(1, -16, 1, -136)
		navHolder.Position, navHolder.Size = UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0)
		navList.FillDirection, navList.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 4)
	else
		side.Position, side.Size = UDim2.fromOffset(12, 64), UDim2.new(0, sideW, 1, -76)
		content.Position, content.Size = UDim2.fromOffset(12 + sideW + 12, 64), UDim2.new(1, -(sideW + 36), 1, -76)
		navHolder.Position = full and UDim2.fromOffset(0, 68) or UDim2.fromOffset(0, 8)
		navHolder.Size = UDim2.new(1, 0, 0, 6 * 40 + 5 * 4)
		navList.FillDirection, navList.Padding = Enum.FillDirection.Vertical, UDim.new(0, 4)
	end
	profile.Visible, footer.Visible, search.Visible = full, full, not portrait
	subtitle.Text = portrait and Core.Config.Version or ("MOTION CONTROL / UI SHELL / " .. Core.Config.Version)
	title.Size = portrait and UDim2.fromOffset(150, 24) or UDim2.fromOffset(200, 24)

	for name, it in pairs(items) do
		local b, icon, label = it.btn, it.icon, it.label
		if portrait then
			b.Size = UDim2.new(1 / 6, -4, 1, 0)
			icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 5), UDim2.fromOffset(26, 26)
			label.Visible, label.TextXAlignment, label.TextSize = true, Enum.TextXAlignment.Center, 10
			label.Position, label.Size, label.Text = UDim2.new(0, 0, 1, -18), UDim2.new(1, 0, 0, 14), Pages.Short[name]
		elseif full then
			b.Size = UDim2.new(1, 0, 0, 40)
			icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(0, 0.5), UDim2.new(0, 8, 0.5, 0), UDim2.fromOffset(28, 28)
			label.Visible, label.TextXAlignment, label.TextSize = true, Enum.TextXAlignment.Left, 13
			label.Position, label.Size, label.Text = UDim2.fromOffset(46, 0), UDim2.new(1, -52, 1, 0), name
		else
			b.Size = UDim2.new(1, 0, 0, 40)
			icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(28, 28)
			label.Visible = false
		end
	end
	if modeChanged then Core.RunLayouts() end
end

---------------------------------------------------------------- Pages + navigation
local pages = Pages.Build(content)
local function ShowPage(name)
	if current == name or not pages[name] then return end
	local oldName = current
	local old = oldName and pages[oldName]
	current = name
	Core.Set("page", name)
	highlight()
	for n, p in pairs(pages) do if n ~= name and p ~= old then p.Visible = false end end
	if old then
		Core.Tween(old, 0.1, { GroupTransparency = 1 })
		task.delay(0.11, function() if current ~= oldName then old.Visible = false end end)
	end
	local new = pages[name]
	new.Visible = true
	new.GroupTransparency = 1
	new.Position = UDim2.fromOffset(0, 8)
	Core.Tween(new, 0.22, { GroupTransparency = 0, Position = UDim2.new() })
end
Core.Goto = ShowPage

---------------------------------------------------------------- Notifications
local nf = mk("Frame", { Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(300, 200), ZIndex = 50 }, gui)
mk("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = LAYOUT }, nf)
Core.Notify = function(text, force)
	if not State.notify and not force then return end
	local dup = nf:FindFirstChild(text)
	if dup then dup:Destroy() end
	local kids = {}
	for _, k in ipairs(nf:GetChildren()) do if k:IsA("GuiObject") then table.insert(kids, k) end end
	if #kids >= 3 then table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end); kids[1]:Destroy() end
	local card = C.Card(nf, { class = "CanvasGroup", Size = UDim2.fromOffset(260, 34), Name = text })
	C.Stroke(card, true)
	C.Label(card, text, 12, "text", { Font = Enum.Font.GothamMedium, align = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0) })
	card.GroupTransparency = 1
	Core.Tween(card, 0.2, { GroupTransparency = 0 })
	task.delay(2.5, function()
		if card.Parent then
			Core.Tween(card, 0.25, { GroupTransparency = 1 })
			task.delay(0.3, function() if card.Parent then card:Destroy() end end)
		end
	end)
end

---------------------------------------------------------------- Bubble
local bubble = mk("Frame", { Name = "Bubble", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BorderSizePixel = 0, Visible = false }, gui)
bubble.Position = UDim2.fromScale(State.bubbleX, State.bubbleY)
C.Corner(bubble, 32)
Core.Themed(bubble, { BackgroundColor3 = function(P) return P.surface end })
C.Stroke(bubble, true, 2)
C.Logo(bubble, UDim2.fromScale(0.78, 0.78), { pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5) })
local bsc = mk("UIScale", {}, bubble)
local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20 }, bubble)

local Open, Hide
local startCenter, moved = Vector2.zero, false
C.BindDrag(hit, function(p, start)
	local d = p - start
	if d.Magnitude > 6 then moved = true end
	if moved then
		local vp = gui.AbsoluteSize
		local c = startCenter + d
		bubble.Position = UDim2.fromOffset(math.clamp(c.X, 36, vp.X - 36), math.clamp(c.Y, 36, vp.Y - 36))
	end
end, function()
	local vp = gui.AbsoluteSize
	startCenter, moved = Vector2.new(State.bubbleX * vp.X, State.bubbleY * vp.Y), false
	Core.Tween(bsc, 0.1, { Scale = 0.94 })
end, function()
	Core.Tween(bsc, 0.15, { Scale = 1 })
	if moved then
		local vp = gui.AbsoluteSize
		local p = bubble.Position
		local x, y = math.clamp(p.X.Offset / vp.X, 0.03, 0.97), math.clamp(p.Y.Offset / vp.Y, 0.03, 0.97)
		Core.Set("bubbleX", x); Core.Set("bubbleY", y)
		bubble.Position = UDim2.fromScale(x, y)
	else
		Core.Click()
		Open()
	end
end)

---------------------------------------------------------------- Open / hide
function Open()
	mode = "open"
	bubble.Visible = false
	win.Visible = true
	Layout()
	uiscale.Scale = target * 0.94
	win.GroupTransparency = 1
	Core.Tween(win, 0.22, { GroupTransparency = 0 })
	Core.Tween(uiscale, 0.28, { Scale = target })
	Core.Set("shown", true)
end

function Hide(toBubble)
	if mode ~= "open" then return end
	mode = toBubble and "min" or "closed"
	Core.Set("shown", false)
	Core.Tween(win, 0.15, { GroupTransparency = 1 })
	Core.Tween(uiscale, 0.15, { Scale = target * 0.96 })
	task.delay(0.16, function() if mode ~= "open" then win.Visible = false end end)
	if toBubble then
		bubble.Visible = true
		bsc.Scale = 0.6
		Core.Tween(bsc, 0.25, { Scale = 1 })
	else
		bubble.Visible = false
	end
end

closeB.Activated:Connect(function() Hide(false) end)
minB.Activated:Connect(function() Hide(true) end)
themeB.Activated:Connect(function() Core.Set("theme", State.theme == "Dark" and "Light" or "Dark") end)

search.FocusLost:Connect(function(enter)
	local q = search.Text:lower()
	if not enter or q == "" then return end
	for _, name in ipairs(Pages.Order) do
		if name:lower():find(q, 1, true) then Core.Goto(name); search.Text = ""; return end
	end
	Core.Notify("No match for \"" .. search.Text .. "\"", true)
end)

-- drag window by header
local startPos = Vector2.zero
C.BindDrag(header, function(p, start)
	pos = startPos + (p - start)
	clampPos()
end, function() startPos = pos end)

local keyConn = UIS.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Core.Config.ToggleKey then return end
	if mode == "open" then Hide(false) else Open() end
end)

---------------------------------------------------------------- Ambience
local amb
local function updateAmb()
	if Core.Config.Sounds.Ambience == "" then return end
	if not amb then
		amb = Instance.new("Sound")
		amb.SoundId, amb.Looped, amb.Volume = Core.Config.Sounds.Ambience, true, Core.Config.Sounds.AmbienceVolume
		amb.Parent = gui
	end
	if State.sounds and State.shown then if not amb.IsPlaying then amb:Play() end else amb:Pause() end
end
Core.On("sounds", updateAmb)
Core.On("shown", updateAmb)

---------------------------------------------------------------- Boot
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Layout)
Core.On("scale", Layout)
Core.On("compact", Layout)
gui.Destroying:Connect(function()
	keyConn:Disconnect()
	F.Cleanup()
end)

Layout()
ShowPage("Overview")
Open()
Core.Set("ready", true)
Core.Notify("Cien Utility " .. Core.Config.Version .. " ready. Press M to toggle.")

end
defs.Main()