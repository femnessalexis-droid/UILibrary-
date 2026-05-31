--[[

    Mercury UILibrary — macOS Edition
    edited: 17/26
    developers: Ness

    Upgrades vs. original:
      • Full macOS-style redesign (sidebar layout, traffic lights, refined typography)
      • Browser-style title bar (Fluorine-Hub inspired): sidebar toggle,
        back / forward navigation arrows, stacked Title + Subtitle, and a
        live search box that filters the sidebar tabs as you type
      • Traffic lights now reveal ✕ / – / + glyphs on hover (Sonoma style)
      • Collapsible sidebar — the panel button slides it away to reclaim space
      • New "Subtitle"/"Author" window options (e.g. Author = "ALLNIGHT"
        renders "Made by ALLNIGHT" under the title)
      • New default "MacOS" theme (dark, indigo accent) — legacy themes preserved
      • Drag-to-resize handle in the bottom-right corner
      • Minimize via the yellow traffic light, full-screen toggle via the green one
      • Full mobile support: unified touch+mouse drag, larger touch targets,
        numeric TextBox for sliders so they work without a mouse,
        responsive title bar (search hides on narrow windows)
      • Tab categories (e.g. "Main", "Settings") in the sidebar
      • Same public API as the original — drop-in replacement.

]]

local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local HTTPService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
-- Robust mobile detection.
-- Single-property checks fail on real devices:
--   • Some Android executors report MouseEnabled = true even with no mouse
--   • iOS reports KeyboardEnabled = true while iOS keyboards are docked
--   • Studio's Device Emulator inherits the developer's mouse/keyboard
-- We bias toward "if touch is available, treat it as mobile" so the
-- floating toggle button is shown whenever the user *can* reach it.
-- A genuine desktop with no touch will still register correctly.
-- ─────────────────────────────────────────────────────────────
local function detectMobile()
    if not UserInputService.TouchEnabled then
        return false                 -- no touch hardware → definitely desktop
    end
    -- Touch is present. If gamepad is also active and there's no mouse,
    -- this might be a console — but we still want the button visible there.
    if not UserInputService.MouseEnabled then
        return true                  -- touch + no mouse = clearly mobile
    end
    -- Touch + Mouse both true. Could be a phone with a Bluetooth mouse,
    -- a 2-in-1 laptop, or Studio's emulator. Use viewport ratio as tiebreak:
    -- portrait or near-square viewports are mobile / tablet.
    local cam = workspace.CurrentCamera
    if cam then
        local v = cam.ViewportSize
        if v.Y > 0 and (v.X / v.Y) < 1.45 then
            return true              -- portrait / tablet aspect ratio
        end
    end
    -- Touch with mouse and a wide viewport → treat as desktop hybrid;
    -- the user can pass AlwaysShowToggleButton = true to force the button.
    return false
end

local IsMobile = detectMobile()

local Library = {
    Themes = {
        -- ──────────────────────────────────────────────────────────
        -- Dark  — the flagship.
        -- Deep neutral background, near-black sidebar, indigo accent.
        -- Inspired by Linear, Vercel, Arc Browser, and macOS Sonoma's
        -- dark appearance.  This is the one to beat.
        -- ──────────────────────────────────────────────────────────
        Dark = {
            Main      = Color3.fromRGB(14, 15, 19),
            Secondary = Color3.fromRGB(24, 26, 32),
            Tertiary  = Color3.fromRGB(120, 119, 255),

            StrongText = Color3.fromRGB(245, 246, 250),
            WeakText   = Color3.fromRGB(132, 138, 156)
        },

        -- macOS Sonoma-style. Slightly bluer than Dark, softer.
        MacOS = {
            Main      = Color3.fromRGB(22, 24, 30),
            Secondary = Color3.fromRGB(32, 34, 42),
            Tertiary  = Color3.fromRGB(108, 112, 240),

            StrongText = Color3.fromRGB(240, 242, 248),
            WeakText   = Color3.fromRGB(140, 146, 160)
        },

        -- Pure black OLED — for AMOLED phones / battery saving.
        Midnight = {
            Main      = Color3.fromRGB(6, 6, 9),
            Secondary = Color3.fromRGB(16, 16, 22),
            Tertiary  = Color3.fromRGB(140, 130, 255),

            StrongText = Color3.fromRGB(248, 249, 252),
            WeakText   = Color3.fromRGB(118, 122, 140)
        },

        -- Soft warm dark + emerald — easy on the eyes for long sessions.
        Forest = {
            Main      = Color3.fromRGB(18, 22, 22),
            Secondary = Color3.fromRGB(28, 34, 34),
            Tertiary  = Color3.fromRGB(76, 200, 142),

            StrongText = Color3.fromRGB(238, 245, 240),
            WeakText   = Color3.fromRGB(132, 152, 144)
        },

        -- Catppuccin Mocha — warm dark + lavender. Beloved in dev circles.
        Mocha = {
            Main      = Color3.fromRGB(30, 30, 46),
            Secondary = Color3.fromRGB(40, 40, 60),
            Tertiary  = Color3.fromRGB(203, 166, 247),

            StrongText = Color3.fromRGB(245, 245, 250),
            WeakText   = Color3.fromRGB(150, 152, 175)
        },

        -- Tokyo Night — popular code-editor palette. Cool deep blue + cyan.
        TokyoNight = {
            Main      = Color3.fromRGB(26, 27, 38),
            Secondary = Color3.fromRGB(36, 40, 59),
            Tertiary  = Color3.fromRGB(125, 207, 255),

            StrongText = Color3.fromRGB(232, 237, 245),
            WeakText   = Color3.fromRGB(138, 148, 178)
        },

        -- Sunset — warm dark with rose/coral accent.
        Sunset = {
            Main      = Color3.fromRGB(28, 22, 26),
            Secondary = Color3.fromRGB(40, 30, 38),
            Tertiary  = Color3.fromRGB(255, 130, 132),

            StrongText = Color3.fromRGB(248, 240, 244),
            WeakText   = Color3.fromRGB(168, 142, 152)
        },

        -- Aqua — cool dark + teal accent.
        Aqua = {
            Main      = Color3.fromRGB(15, 22, 26),
            Secondary = Color3.fromRGB(24, 36, 42),
            Tertiary  = Color3.fromRGB(64, 200, 196),

            StrongText = Color3.fromRGB(232, 244, 248),
            WeakText   = Color3.fromRGB(124, 152, 162)
        },

        -- Rose Pine Moon — muted dusky pink/lavender. Distinctive.
        RosePine = {
            Main      = Color3.fromRGB(35, 33, 54),
            Secondary = Color3.fromRGB(47, 44, 71),
            Tertiary  = Color3.fromRGB(235, 188, 186),

            StrongText = Color3.fromRGB(231, 224, 236),
            WeakText   = Color3.fromRGB(156, 148, 178)
        },

        -- Citrus — dark + bright yellow accent. Bold contrast.
        Citrus = {
            Main      = Color3.fromRGB(22, 22, 18),
            Secondary = Color3.fromRGB(34, 34, 28),
            Tertiary  = Color3.fromRGB(252, 211, 77),

            StrongText = Color3.fromRGB(245, 245, 240),
            WeakText   = Color3.fromRGB(150, 148, 130)
        },

        -- Crimson — black + red accent. Aggressive, gamer-ish.
        Crimson = {
            Main      = Color3.fromRGB(18, 16, 18),
            Secondary = Color3.fromRGB(30, 26, 28),
            Tertiary  = Color3.fromRGB(239, 68, 68),

            StrongText = Color3.fromRGB(248, 240, 240),
            WeakText   = Color3.fromRGB(150, 132, 132)
        },

        -- ──────────────────────────────────────────────────────────
        -- Light themes  (only one, kept minimal)
        -- ──────────────────────────────────────────────────────────
        Light = {
            Main      = Color3.fromRGB(248, 249, 252),
            Secondary = Color3.fromRGB(232, 234, 240),
            Tertiary  = Color3.fromRGB(99, 102, 241),

            StrongText = Color3.fromRGB(20, 22, 30),
            WeakText   = Color3.fromRGB(90, 96, 112)
        },

        -- ──────────────────────────────────────────────────────────
        -- Legacy themes (kept for backwards compatibility)
        -- ──────────────────────────────────────────────────────────
        Legacy = {
            Main      = Color3.fromHSV(262/360, 60/255, 34/255),
            Secondary = Color3.fromHSV(240/360, 40/255, 63/255),
            Tertiary  = Color3.fromHSV(260/360, 60/255, 148/255),

            StrongText = Color3.fromHSV(0, 0, 1),
            WeakText   = Color3.fromHSV(0, 0, 172/255)
        },
        Serika = {
            Main      = Color3.fromRGB(50, 52, 55),
            Secondary = Color3.fromRGB(80, 82, 85),
            Tertiary  = Color3.fromRGB(226, 183, 20),

            StrongText = Color3.fromHSV(0, 0, 1),
            WeakText   = Color3.fromHSV(0, 0, 172/255)
        },
        Rust = {
            Main      = Color3.fromRGB(37, 35, 33),
            Secondary = Color3.fromRGB(65, 63, 63),
            Tertiary  = Color3.fromRGB(237, 94, 38),

            StrongText = Color3.fromHSV(0, 0, 1),
            WeakText   = Color3.fromHSV(0, 0, 172/255)
        }
    },

    ColorPickerStyles = { Legacy = 0, Modern = 1 },

    Toggled = true,
    ThemeObjects = {
        Main = {}, Secondary = {}, Tertiary = {},
        StrongText = {}, WeakText = {}
    },

    -- Callbacks invoked whenever change_theme runs. Components whose colour
    -- depends on a runtime state (e.g. toggle on/off, tab selected/idle)
    -- register here so they can pick the right colour from the new theme.
    _themeUpdaters = {},

    WelcomeText   = nil,
    DisplayName   = nil,
    DragSpeed     = 0.06,
    LockDragging  = false,
    ToggleKey     = Enum.KeyCode.RightControl,
    UrlLabel      = nil,
    Url           = nil,

    IsMobile = IsMobile
}
Library.__index = Library

local selectedTab
Library._promptExists      = false
Library._colorPickerExists = false
Library._navigating        = false   -- true while back/forward arrows retrace history

local GlobalTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- =====================================================================
--                              UTILITIES
-- =====================================================================

function Library:set_defaults(defaults, options)
    defaults = defaults or {}
    options  = options  or {}
    for option, value in next, options do
        defaults[option] = value
    end
    return defaults
end

function Library:darken(color, f)
    local h, s, v = Color3.toHSV(color)
    f = 1 - ((f or 15) / 80)
    return Color3.fromHSV(h, math.clamp(s/f, 0, 1), math.clamp(v*f, 0, 1))
end

function Library:lighten(color, f)
    local h, s, v = Color3.toHSV(color)
    f = 1 - ((f or 15) / 80)
    return Color3.fromHSV(h, math.clamp(s*f, 0, 1), math.clamp(v/f, 0, 1))
end

function Library:change_theme(toTheme)
    Library.CurrentTheme = toTheme
    if Library.DisplayName then
        local c = self:lighten(toTheme.Tertiary, 20)
        Library.DisplayName.Text = "Welcome, <font color='rgb("
            .. math.floor(c.R*255) .. "," .. math.floor(c.G*255) .. "," .. math.floor(c.B*255)
            .. ")'> <b>" .. LocalPlayer.DisplayName .. "</b> </font>"
    end
    for color, objects in next, Library.ThemeObjects do
        for _, obj in next, objects do
            local element, property, theme, colorAlter = obj[1], obj[2], obj[3], obj[4] or 0
            local themeColor = Library.CurrentTheme[theme]
            local modifiedColor = themeColor
            if colorAlter < 0 then
                modifiedColor = Library:darken(themeColor, -1 * colorAlter)
            elseif colorAlter > 0 then
                modifiedColor = Library:lighten(themeColor, colorAlter)
            end
            element:tween{[property] = modifiedColor}
        end
    end

    -- State-dependent components (toggle on/off, tab selected, slider fill, …)
    -- can't be registered against a single property, so they hook into
    -- _themeUpdaters and refresh themselves here.
    for _, updater in ipairs(Library._themeUpdaters) do
        pcall(updater, toTheme)
    end
end

-- =====================================================================
--                       OBJECT FACTORY (preserved)
-- =====================================================================

function Library:object(class, properties)
    local localObject = Instance.new(class)

    local forcedProps = {
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        Text = ""
    }
    for property, value in next, forcedProps do
        pcall(function() localObject[property] = value end)
    end

    local methods = {}
    methods.AbsoluteObject = localObject

    function methods:tween(options, callback)
        options = Library:set_defaults({
            Length    = 0.2,
            Style     = Enum.EasingStyle.Quad,
            Direction = Enum.EasingDirection.Out
        }, options)
        callback = callback or function() end

        local ti = TweenInfo.new(options.Length, options.Style, options.Direction)
        options.Length, options.Style, options.Direction = nil, nil, nil

        local tween = TweenService:Create(localObject, ti, options)
        tween:Play()
        tween.Completed:Connect(callback)
        return tween
    end

    function methods:round(radius)
        radius = radius or 6
        Library:object("UICorner", {
            Parent = localObject,
            CornerRadius = UDim.new(0, radius)
        })
        return methods
    end

    function methods:object(class, properties)
        properties = properties or {}
        properties.Parent = localObject
        return Library:object(class, properties)
    end

    function methods:crossfade(p2, length)
        length = length or 0.2
        self:tween({ImageTransparency = 1, Length = length})
        p2:tween({ImageTransparency = 0, Length = length})
    end

    function methods:fade(state, colorOverride, length, instant)
        length = length or 0.2
        if not rawget(self, "fadeFrame") then
            local frame = self:object("Frame", {
                BackgroundColor3 = colorOverride or self.BackgroundColor3,
                BackgroundTransparency = (state and 1) or 0,
                Size = UDim2.fromScale(1, 1),
                Centered = true,
                ZIndex = 999
            }):round(self.AbsoluteObject:FindFirstChildOfClass("UICorner")
                and self.AbsoluteObject:FindFirstChildOfClass("UICorner").CornerRadius.Offset
                or 0)
            rawset(self, "fadeFrame", frame)
        else
            self.fadeFrame.BackgroundColor3 = colorOverride or self.BackgroundColor3
        end

        if instant then
            self.fadeFrame.BackgroundTransparency = state and 0 or 1
            self.fadeFrame.Visible = state
        else
            if state then
                self.fadeFrame.BackgroundTransparency = 1
                self.fadeFrame.Visible = true
                self.fadeFrame:tween{BackgroundTransparency = 0, Length = length}
            else
                self.fadeFrame.BackgroundTransparency = 0
                self.fadeFrame:tween({BackgroundTransparency = 1, Length = length}, function()
                    self.fadeFrame.Visible = false
                end)
            end
        end
    end

    function methods:stroke(color, thickness, strokeMode)
        thickness = thickness or 1
        strokeMode = strokeMode or Enum.ApplyStrokeMode.Border
        local stroke = self:object("UIStroke", {
            ApplyStrokeMode = strokeMode,
            Thickness = thickness
        })

        if type(color) == "table" then
            local theme, colorAlter = color[1], color[2] or 0
            local themeColor = Library.CurrentTheme[theme]
            local modifiedColor = themeColor
            if colorAlter < 0 then
                modifiedColor = Library:darken(themeColor, -1 * colorAlter)
            elseif colorAlter > 0 then
                modifiedColor = Library:lighten(themeColor, colorAlter)
            end
            stroke.Color = modifiedColor
            table.insert(Library.ThemeObjects[theme], {stroke, "Color", theme, colorAlter})
        elseif type(color) == "string" then
            stroke.Color = Library.CurrentTheme[color]
            table.insert(Library.ThemeObjects[color], {stroke, "Color", color, 0})
        else
            stroke.Color = color
        end

        return methods
    end

    function methods:tooltip(text)
        local tooltipContainer = methods:object("TextLabel", {
            Theme = {
                BackgroundColor3 = {"Main", 10},
                TextColor3 = {"WeakText"}
            },
            TextSize = 14,
            Font = Enum.Font.Gotham,
            Text = text,
            Position = UDim2.new(0.5, 0, 0, -8),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            AnchorPoint = Vector2.new(0.5, 1),
            BackgroundTransparency = 1,
            TextTransparency = 1,
            ZIndex = 50
        }):round(5)
        tooltipContainer.Size = UDim2.fromOffset(tooltipContainer.TextBounds.X + 14, tooltipContainer.TextBounds.Y + 6)

        local hovered = false
        methods.MouseEnter:Connect(function()
            hovered = true
            task.wait(0.25)
            if hovered then
                tooltipContainer:tween{BackgroundTransparency = 0.15, TextTransparency = 0.05}
            end
        end)
        methods.MouseLeave:Connect(function()
            hovered = false
            tooltipContainer:tween{BackgroundTransparency = 1, TextTransparency = 1}
        end)

        return methods
    end

    local customHandlers = {
        Centered = function(value)
            if value then
                localObject.AnchorPoint = Vector2.new(0.5, 0.5)
                localObject.Position    = UDim2.fromScale(0.5, 0.5)
            end
        end,
        Theme = function(value)
            for property, obj in next, value do
                if type(obj) == "table" then
                    local theme, colorAlter = obj[1], obj[2] or 0
                    local themeColor = Library.CurrentTheme[theme]
                    local modifiedColor = themeColor
                    if colorAlter < 0 then
                        modifiedColor = Library:darken(themeColor, -1 * colorAlter)
                    elseif colorAlter > 0 then
                        modifiedColor = Library:lighten(themeColor, colorAlter)
                    end
                    localObject[property] = modifiedColor
                    table.insert(Library.ThemeObjects[theme], {methods, property, theme, colorAlter})
                else
                    localObject[property] = Library.CurrentTheme[obj]
                    table.insert(Library.ThemeObjects[obj], {methods, property, obj, 0})
                end
            end
        end
    }

    for property, value in next, properties do
        if customHandlers[property] then
            customHandlers[property](value)
        else
            localObject[property] = value
        end
    end

    return setmetatable(methods, {
        __index    = function(_, p)    return localObject[p]    end,
        __newindex = function(_, p, v) localObject[p] = v       end
    })
end

-- =====================================================================
--                       UNIVERSAL DRAG HANDLER
--   Works with both Mouse and Touch — used for window drag and resize.
-- =====================================================================

-- ─────────────────────────────────────────────────────────────
-- Camera-suppression while dragging.
-- On mobile, Roblox routes a touch over a non-Button GuiObject to
-- the camera controller, which rotates the in-game camera *while*
-- the user is dragging the UI. We sink the camera/movement actions
-- through ContextActionService for the duration of any active drag
-- so the world camera stays still.
-- ─────────────────────────────────────────────────────────────
local ContextActionService = game:GetService("ContextActionService")
local CAMERA_SINK_ID       = "MercuryDragCameraSink"
local activeDragCount      = 0

local function sinkCameraInput()
    activeDragCount = activeDragCount + 1
    if activeDragCount == 1 then
        ContextActionService:BindAction(
            CAMERA_SINK_ID,
            function() return Enum.ContextActionResult.Sink end,
            false,
            Enum.PlayerActions.CameraLook,
            Enum.PlayerActions.CharacterForward,
            Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,
            Enum.PlayerActions.CharacterRight,
            Enum.PlayerActions.CharacterJump
        )
    end
end

local function releaseCameraInput()
    activeDragCount = math.max(0, activeDragCount - 1)
    if activeDragCount == 0 then
        pcall(function() ContextActionService:UnbindAction(CAMERA_SINK_ID) end)
    end
end

local function bindDrag(handle, onMove, onBegin, onEnd)
    local dragging = false
    local dragInput, startInputPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startInputPos = input.Position
            sinkCameraInput()                         -- stop camera rotation
            if onBegin then onBegin(startInputPos) end

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if dragging then                  -- guard against double-fire
                        dragging = false
                        releaseCameraInput()
                        if onEnd then onEnd() end
                    end
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - startInputPos
            onMove(delta, input.Position)
        end
    end)
end

-- =====================================================================
--                          SHOW / STATUS
-- =====================================================================

function Library:show(state)
    self.Toggled = state
    self.mainFrame.ClipsDescendants = true
    local shadow = rawget(self.mainFrame, "_shadowRef")
    if state then
        -- Re-show shadow as window grows back
        if shadow then
            shadow.ImageTransparency = 1
            shadow.Visible = true
            shadow:tween{ImageTransparency = 0.78, Length = 0.25}
        end
        self.mainFrame:tween({Size = self.mainFrame.oldSize, Length = 0.25}, function()
            self.mainFrame.ClipsDescendants = false
        end)
        task.wait(0.05)
        self.mainFrame:fade(false, self.mainFrame.BackgroundColor3, 0.15)
    else
        -- Fade the shadow alongside the window so no dark square is left
        if shadow then
            shadow:tween{ImageTransparency = 1, Length = 0.2}
        end
        self.mainFrame:fade(true, self.mainFrame.BackgroundColor3, 0.15)
        task.wait(0.05)
        self.mainFrame:tween{Size = UDim2.new(), Length = 0.25}
    end
end

local updateSettings = function() end

function Library:set_status(txt)
    if self.statusText then
        self.statusText.Text = txt
    end
end

-- =====================================================================
--                          MAIN WINDOW
-- =====================================================================

function Library:create(options)

    local settings = { Theme = "Dark" }
    if readfile and writefile and isfile then
        if not isfile("MercurySettings.json") then
            writefile("MercurySettings.json", HTTPService:JSONEncode(settings))
        end
        local ok, decoded = pcall(function()
            return HTTPService:JSONDecode(readfile("MercurySettings.json"))
        end)
        if ok and decoded and Library.Themes[decoded.Theme] then
            settings = decoded
        end
        Library.CurrentTheme = Library.Themes[settings.Theme]
        updateSettings = function(property, value)
            settings[property] = value
            pcall(writefile, "MercurySettings.json", HTTPService:JSONEncode(settings))
        end
    else
        Library.CurrentTheme = Library.Themes[settings.Theme]
    end

    -- Compute a default size that fits the screen on mobile.
    local viewSize = workspace.CurrentCamera.ViewportSize
    local defaultWidth  = IsMobile and math.min(640, viewSize.X - 30) or 720
    local defaultHeight = IsMobile and math.min(420, viewSize.Y - 60) or 470

    options = self:set_defaults({
        Name              = "Mercury",
        Size              = UDim2.fromOffset(defaultWidth, defaultHeight),
        Theme             = self.Themes[settings.Theme] or self.Themes.Dark,
        Link              = "https://github.com/deeeity/mercury-lib",
        ToggleButtonText  = nil,   -- string shown inside the floating button
        ToggleButtonIcon  = nil,   -- rbxassetid; takes precedence over text
        AlwaysShowToggleButton = false, -- force visible on desktop too
        Subtitle          = nil,   -- second line under the title (e.g. "Made by …")
        Author            = nil,   -- shorthand: becomes "Made by <Author>" if Subtitle unset
    }, options)

    if getgenv and getgenv().MercuryUI then
        pcall(getgenv().MercuryUI)
        getgenv().MercuryUI = nil
    end

    if options.Link:sub(-1, -1) == "/" then
        options.Link = options.Link:sub(1, -2)
    end

    self.CurrentTheme = options.Theme

    -- Mount under CoreGui if executor allows it; fall back to PlayerGui.
    local parent = (RunService:IsStudio() and LocalPlayer:WaitForChild("PlayerGui"))
        or (gethui and gethui())
        or (syn and syn.protect_gui and (function() syn.protect_gui(Instance.new("ScreenGui")) return CoreGui end)())
        or CoreGui

    local gui = self:object("ScreenGui", {
        Parent = parent,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        ResetOnSpawn = false
    })

    -- ----- Notifications holder ----------------------------------------
    local notificationHolder = gui:object("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.new(0, 320, 1, -60),
        ZIndex = 100
    })
    notificationHolder:object("UIListLayout", {
        Padding = UDim.new(0, 12),
        VerticalAlignment = Enum.VerticalAlignment.Bottom
    })

    -- ----- Main window --------------------------------------------------
    local core = gui:object("Frame", {
        Size = UDim2.new(),
        Theme = { BackgroundColor3 = "Main" },
        Centered = true,
        ClipsDescendants = true,
        Active = true,            -- absorb touch so the camera can't pan when
                                  -- the user interacts anywhere inside the window
        ZIndex = 2
    }):round(10):stroke({"Secondary", 10}, 1)

    core:fade(true, nil, 0.2, true)
    core:fade(false, nil, 0.35)
    core:tween({Size = options.Size, Length = 0.35, Style = Enum.EasingStyle.Quint}, function()
        core.ClipsDescendants = false
    end)

    rawset(core, "oldSize", options.Size)
    self.mainFrame = core

    -- ----- Drop shadow --------------------------------------------------
    -- Lives at GUI level (NOT inside core) so it never gets clipped when
    -- core has ClipsDescendants = true. It mirrors core's position/size
    -- and is always rendered just under it.
    local shadow = gui:object("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = core.AnchorPoint,
        Position = core.Position,
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 1,
        Image = "rbxassetid://6015897843",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.78,
        SliceCenter = Rect.new(47, 47, 450, 450),
        ScaleType = Enum.ScaleType.Slice
    })

    -- Keep the shadow glued to the window
    local function syncShadow()
        local cs = core.AbsoluteSize
        -- When core is collapsed (Library:show(false) tweens size to 0),
        -- hide the shadow entirely so we don't leave a dark square on
        -- screen. Threshold of 4px catches any tiny tween residue.
        if cs.X < 4 or cs.Y < 4 then
            shadow.Visible = false
        else
            shadow.Visible = true
            shadow.Size     = UDim2.fromOffset(cs.X + 60, cs.Y + 60)
            shadow.Position = core.Position
        end
    end
    syncShadow()
    core.AbsoluteObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncShadow)
    core.AbsoluteObject:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncShadow)

    -- Store shadow so Library:show() can pre-fade it on hide.
    rawset(core, "_shadowRef", shadow)

    -- =================================================================
    --                          TITLE BAR
    --   Browser-style toolbar:  ●●●   ▣  ‹ ›   Title / Subtitle   🔍 Search
    --   (traffic lights · sidebar toggle · nav arrows · titles · search)
    -- =================================================================

    local TITLE_BAR_HEIGHT = 52

    -- Resolve the subtitle once. Either an explicit string, or built from
    -- a short Author name → "Made by <Author>".
    local subtitleStr = options.Subtitle
    if (not subtitleStr or subtitleStr == "") and options.Author then
        subtitleStr = "Made by " .. tostring(options.Author)
    end
    local hasSubtitle = subtitleStr ~= nil and subtitleStr ~= ""

    -- titleBar must be a Button (not a plain Frame) so that on mobile
    -- it absorbs touch events before they reach Roblox's camera
    -- controller. Otherwise dragging the window also pans the world
    -- camera, regardless of any ContextActionService sinking.
    local titleBar = core:object("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT),
        Text = "",
        AutoButtonColor = false,
        Active = true,
        ZIndex = 3
    })

    -- subtle separator below the title bar
    local titleSep = core:object("Frame", {
        Theme = { BackgroundColor3 = {"Secondary", 6} },
        BackgroundTransparency = 0.45,
        Position = UDim2.new(0, 0, 0, TITLE_BAR_HEIGHT),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3
    })

    -- ----- Traffic lights ----------------------------------------------
    local lightHolder = titleBar:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(0, 66, 1, 0),
        ZIndex = 4
    })
    lightHolder:object("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    -- macOS-style: each light reveals a faint glyph (✕ – +) on hover.
    local function makeLight(color, hover, layoutOrder, glyph)
        local btn = lightHolder:object("ImageButton", {
            BackgroundColor3 = color,
            Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(0, 0.5),
            LayoutOrder = layoutOrder,
            AutoButtonColor = false,
            ZIndex = 5
        }):round(100)

        local sym = btn:object("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = glyph,
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            TextColor3 = Color3.fromRGB(35, 25, 0),
            TextTransparency = 1,
            ZIndex = 6
        })

        btn.MouseEnter:Connect(function()
            btn:tween{BackgroundColor3 = hover, Length = 0.1}
            sym:tween{TextTransparency = 0.25, Length = 0.1}
        end)
        btn.MouseLeave:Connect(function()
            btn:tween{BackgroundColor3 = color, Length = 0.1}
            sym:tween{TextTransparency = 1, Length = 0.1}
        end)
        return btn
    end

    local redLight    = makeLight(Color3.fromRGB(255, 95, 86),  Color3.fromRGB(255, 99, 92),  1, "✕")
    local yellowLight = makeLight(Color3.fromRGB(255, 189, 46), Color3.fromRGB(255, 191, 49), 2, "–")
    local greenLight  = makeLight(Color3.fromRGB(39, 201, 63),  Color3.fromRGB(40, 200, 64),  3, "+")

    -- ----- Toolbar group: sidebar toggle + nav arrows ------------------
    local toolbar = titleBar:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(88, 0),
        Size = UDim2.new(0, 96, 1, 0),
        ZIndex = 4
    })
    toolbar:object("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    -- A reusable "ghost" toolbar button: invisible until hovered.
    local function makeToolButton(layoutOrder)
        local b = toolbar:object("TextButton", {
            BackgroundTransparency = 1,
            Theme = { BackgroundColor3 = {"Secondary", 14} },
            Size = UDim2.fromOffset(28, 28),
            AnchorPoint = Vector2.new(0, 0.5),
            LayoutOrder = layoutOrder,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 5
        }):round(7)
        b.MouseEnter:Connect(function() b:tween{BackgroundTransparency = 0.5, Length = 0.1} end)
        b.MouseLeave:Connect(function() b:tween{BackgroundTransparency = 1,   Length = 0.1} end)
        return b
    end

    -- Sidebar toggle — a small panel glyph drawn from frames so it tints
    -- cleanly with the theme (no font-glyph guessing).
    local sidebarToggleBtn = makeToolButton(1)
    do
        local box = sidebarToggleBtn:object("Frame", {
            Centered = true,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(15, 13),
            ZIndex = 6
        }):round(3):stroke({"WeakText", 4}, 1.5)
        box:object("Frame", {
            Position = UDim2.fromOffset(5, 0),
            Size = UDim2.new(0, 1, 1, 0),
            Theme = { BackgroundColor3 = {"WeakText", 4} },
            ZIndex = 6
        })
    end

    -- Back / forward navigation arrows
    local backBtn = makeToolButton(2)
    local backIcon = backBtn:object("TextLabel", {
        BackgroundTransparency = 1,
        Centered = true,
        Size = UDim2.fromScale(1, 1),
        Text = "❮",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Theme = { TextColor3 = {"WeakText", 4} },
        TextTransparency = 0.7,
        ZIndex = 6
    })

    local fwdBtn = makeToolButton(3)
    local fwdIcon = fwdBtn:object("TextLabel", {
        BackgroundTransparency = 1,
        Centered = true,
        Size = UDim2.fromScale(1, 1),
        Text = "❯",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Theme = { TextColor3 = {"WeakText", 4} },
        TextTransparency = 0.7,
        ZIndex = 6
    })

    -- ----- App title + subtitle (left-aligned, stacked) ----------------
    local TITLE_LEFT  = 194
    local SEARCH_W    = IsMobile and 148 or 192
    local titleBlock = titleBar:object("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, TITLE_LEFT, 0.5, 0),
        Size = UDim2.new(1, -(TITLE_LEFT + SEARCH_W + 28), 1, 0),
        ClipsDescendants = true,
        ZIndex = 4
    })

    local titleText = titleBlock:object("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, hasSubtitle and -9 or 0),
        Size = UDim2.new(1, 0, 0, 18),
        Text = options.Name,
        Theme = { TextColor3 = "StrongText" },
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4
    })

    local subtitleText
    if hasSubtitle then
        subtitleText = titleBlock:object("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 9),
            Size = UDim2.new(1, 0, 0, 14),
            Text = subtitleStr,
            Theme = { TextColor3 = {"WeakText", 2} },
            TextSize = 11,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 4
        })
    end

    -- ----- Search box (right) ------------------------------------------
    --   Filters the sidebar tabs live as you type.
    local searchHolder = titleBar:object("Frame", {
        Theme = { BackgroundColor3 = {"Secondary", 8} },
        BackgroundTransparency = 0.35,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(SEARCH_W, 30),
        ZIndex = 4
    }):round(8):stroke({"Secondary", 20}, 1)

    -- Magnifier icon: a ring + a short diagonal handle (theme-tinted).
    local mag = searchHolder:object("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 11, 0.5, -1),
        Size = UDim2.fromOffset(10, 10),
        ZIndex = 5
    }):round(100):stroke({"WeakText", 2}, 1.5)
    mag:object("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 1, 1, 1),
        Size = UDim2.fromOffset(5, 1.5),
        Rotation = 45,
        Theme = { BackgroundColor3 = {"WeakText", 2} },
        ZIndex = 5
    }):round(100)

    local searchBox = searchHolder:object("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Text = "",
        PlaceholderText = "Search",
        Theme = { TextColor3 = "StrongText", PlaceholderColor3 = {"WeakText", 2} },
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
        ZIndex = 5
    })

    searchBox.AbsoluteObject.Focused:Connect(function()
        searchHolder:tween{BackgroundTransparency = 0.12, Length = 0.12}
    end)
    searchBox.AbsoluteObject.FocusLost:Connect(function()
        searchHolder:tween{BackgroundTransparency = 0.35, Length = 0.12}
    end)

    -- =================================================================
    --                          SIDEBAR
    -- =================================================================

    local SIDEBAR_WIDTH = IsMobile and 150 or 168

    local sidebar = core:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, TITLE_BAR_HEIGHT + 1),
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -(TITLE_BAR_HEIGHT + 1)),
        ClipsDescendants = true,
        ZIndex = 3
    })

    -- subtle vertical separator between sidebar and content
    local sidebarSep = sidebar:object("Frame", {
        Theme = { BackgroundColor3 = {"Secondary", 5} },
        BackgroundTransparency = 0.4,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        ZIndex = 3
    })

    local sidebarScroll = sidebar:object("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -30),
        Position = UDim2.fromOffset(0, 4),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3
    })

    local sidebarList = sidebarScroll:object("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })

    sidebarScroll:object("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop  = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6)
    })

    -- =================================================================
    --                       CONTENT AREA
    -- =================================================================

    local content = core:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, SIDEBAR_WIDTH, 0, TITLE_BAR_HEIGHT + 1),
        Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -(TITLE_BAR_HEIGHT + 1)),
        ZIndex = 3,
        ClipsDescendants = true
    })

    -- Section title (current tab name + url-style breadcrumb)
    local headerHolder = content:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 14),
        Size = UDim2.new(1, -40, 0, 26)
    })

    local headerTitle = headerHolder:object("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = options.Name,
        Theme = { TextColor3 = "StrongText" },
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    })

    -- ScrollingFrame that actually holds the per-tab content
    local contentArea = content:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 46),
        Size = UDim2.new(1, 0, 1, -60)
    })

    -- Status text (bottom-left, very subtle)
    local status = core:object("TextLabel", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, SIDEBAR_WIDTH + 16, 1, -6),
        Size = UDim2.new(0.5, 0, 0, 14),
        Text = "Idle",
        Theme = { TextColor3 = {"WeakText", -15} },
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3
    })

    -- URL label (hidden — kept to satisfy original API)
    local link = core:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, -16),
        Size = UDim2.new(0, 0, 0, 0),
        Text = options.Link .. "/home",
        TextTransparency = 1,
        Visible = false
    })
    Library.UrlLabel = link
    Library.Url      = options.Link

    -- =================================================================
    --                        RESIZE HANDLE
    -- =================================================================

    local resizeHandle = core:object("ImageButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -4, 1, -4),
        Size = UDim2.fromOffset(IsMobile and 26 or 18, IsMobile and 26 or 18),
        ZIndex = 5,
        AutoButtonColor = false
    })

    -- Diagonal-dot resize grip (six dots in a triangle)
    local resizeDots = {}
    do
        local gridFrame = resizeHandle:object("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1)
        })
        local positions = {
            Vector2.new(1.00, 0.34), Vector2.new(0.67, 0.67),
            Vector2.new(1.00, 0.67), Vector2.new(0.34, 1.00),
            Vector2.new(0.67, 1.00), Vector2.new(1.00, 1.00),
        }
        for _, p in ipairs(positions) do
            local dot = gridFrame:object("Frame", {
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.fromScale(p.X, p.Y),
                Size = UDim2.fromOffset(3, 3),
                Theme = { BackgroundColor3 = {"WeakText", -10} },
                BackgroundTransparency = 0.4
            }):round(100)
            table.insert(resizeDots, dot)
        end
    end

    -- Single source of truth for the grip's visual state. We tween only
    -- the cached dot references — never via GetDescendants (which can
    -- pick up unrelated frames) — and call setGlow(false) from drag-end
    -- so the highlight can never get stuck after a touch release.
    local function setResizeGlow(state)
        local target = state and 0 or 0.4
        for _, dot in ipairs(resizeDots) do
            dot:tween{BackgroundTransparency = target, Length = 0.12}
        end
    end

    -- Hover effects only make sense on desktop
    if not IsMobile then
        resizeHandle.MouseEnter:Connect(function() setResizeGlow(true)  end)
        resizeHandle.MouseLeave:Connect(function() setResizeGlow(false) end)
    end

    do
        local startSize, startPos
        local minW, minH = 480, 320
        bindDrag(resizeHandle,
            function(delta)
                local newW = math.max(minW, startSize.X + delta.X)
                local newH = math.max(minH, startSize.Y + delta.Y)
                local maxW = gui.AbsoluteSize.X - 10
                local maxH = gui.AbsoluteSize.Y - 10
                newW = math.min(newW, maxW)
                newH = math.min(newH, maxH)
                core.Size = UDim2.fromOffset(newW, newH)
                rawset(core, "oldSize", core.Size)
            end,
            function()
                startSize = Vector2.new(core.AbsoluteSize.X, core.AbsoluteSize.Y)
                startPos  = core.AbsolutePosition
                setResizeGlow(true)
            end,
            function()
                setResizeGlow(false)
            end
        )
    end

    -- =================================================================
    --                       WINDOW DRAGGING
    -- =================================================================

    do
        local startPos
        bindDrag(titleBar,
            function(delta)
                local newX = startPos.X.Offset + delta.X
                local newY = startPos.Y.Offset + delta.Y
                if Library.LockDragging then
                    local halfW = core.AbsoluteSize.X * core.AnchorPoint.X
                    local halfH = core.AbsoluteSize.Y * core.AnchorPoint.Y
                    newX = math.clamp(newX, halfW, gui.AbsoluteSize.X - core.AbsoluteSize.X + halfW)
                    newY = math.clamp(newY, halfH, gui.AbsoluteSize.Y - core.AbsoluteSize.Y + halfH)
                end
                core:tween{
                    Position = UDim2.fromOffset(newX, newY),
                    Length = Library.DragSpeed
                }
            end,
            function()
                startPos = core.Position
            end
        )
    end

    -- =================================================================
    --                  TRAFFIC LIGHT BEHAVIOURS
    -- =================================================================

    local function closeUI()
        core.ClipsDescendants = true
        core:fade(true, nil, 0.15)
        task.wait(0.1)
        core:tween({Size = UDim2.new(), Length = 0.2}, function()
            gui.AbsoluteObject:Destroy()
        end)
    end

    if getgenv then
        getgenv().MercuryUI = closeUI
    end

    redLight.MouseButton1Click:Connect(closeUI)

    -- Yellow = minimize (hides via Library:show(false))
    yellowLight.MouseButton1Click:Connect(function()
        Library:show(false)
        Library.Toggled = false
    end)

    -- Green = toggle maximized
    local isMaximized = false
    local savedSize, savedPos
    greenLight.MouseButton1Click:Connect(function()
        if not isMaximized then
            savedSize = core.Size
            savedPos  = core.Position
            local targetSize = UDim2.fromOffset(
                gui.AbsoluteSize.X - 30,
                gui.AbsoluteSize.Y - 30
            )
            core:tween{Size = targetSize, Position = UDim2.fromScale(0.5, 0.5), Length = 0.25}
            rawset(core, "oldSize", targetSize)
            isMaximized = true
        else
            core:tween{Size = savedSize, Position = savedPos, Length = 0.25}
            rawset(core, "oldSize", savedSize)
            isMaximized = false
        end
    end)

    -- Global toggle key
    UserInputService.InputBegan:Connect(function(key, gp)
        if gp then return end
        if key.KeyCode == Library.ToggleKey then
            Library.Toggled = not Library.Toggled
            Library:show(Library.Toggled)
        end
    end)

    -- =================================================================
    --                  MOBILE FLOATING TOGGLE BUTTON
    --   A square, macOS-Dock-style icon that hovers over the screen.
    --   Tap to show / hide the UI.  Drag to reposition.
    --   Mobile-only by default — Library.AlwaysShowToggleButton = true
    --   on the returned window forces it on for desktop too.
    -- =================================================================

    do
        local TOGGLE_BTN_SIZE = 46

        -- Re-evaluate at button-creation time. Input devices may not be
        -- fully registered when the module was first required (executor
        -- loads on a separate thread on some platforms).
        local isMobileNow = detectMobile()
        local shouldShow  = isMobileNow or options.AlwaysShowToggleButton

        -- Position: top-left of the screen, tucked just below the Roblox
        -- top-bar controls (chat/menu icons sit around y = 0–60). The
        -- button is draggable so users can move it later if they need to.
        local defaultX = 20
        local defaultY = 130

        -- Make sure the ScreenGui is rendered above whatever else exists.
        gui.DisplayOrder = math.max(gui.DisplayOrder or 0, 10)

        local toggleBtn = gui:object("ImageButton", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(defaultX, defaultY),
            Size = UDim2.fromOffset(TOGGLE_BTN_SIZE, TOGGLE_BTN_SIZE),
            Visible = shouldShow,
            ZIndex = 50,
            AutoButtonColor = false,
            Active = true
        })

        -- Watch for first touch input — if it ever fires, we know the user
        -- is on a touch device and the button should be visible. This is a
        -- last-resort safety net for devices Roblox can't classify upfront.
        if not shouldShow then
            local touchConn
            touchConn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.Touch then
                    toggleBtn.Visible = true
                    if touchConn then touchConn:Disconnect() end
                end
            end)
        end

        -- Soft drop shadow
        local btnShadow = toggleBtn:object("ImageLabel", {
            Centered = true,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 24, 1, 24),
            ZIndex = 49,
            Image = "rbxassetid://6015897843",
            ImageColor3 = Color3.new(0, 0, 0),
            ImageTransparency = 0.45,
            SliceCenter = Rect.new(47, 47, 450, 450),
            ScaleType = Enum.ScaleType.Slice,
            SliceScale = 1
        })

        -- Background card — looks like a macOS Dock icon
        local btnBg = toggleBtn:object("Frame", {
            Size = UDim2.fromScale(1, 1),
            Theme = { BackgroundColor3 = "Main" },
            ZIndex = 50
        }):round(11):stroke({"Secondary", 25}, 1)

        -- Subtle inner highlight (macOS top-gloss feel)
        local glossLayer = btnBg:object("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.92,
            Size = UDim2.new(1, -4, 0.45, 0),
            Position = UDim2.fromOffset(2, 2),
            ZIndex = 51
        }):round(9)

        -- Accent-coloured badge inside; holds either a TextLabel or ImageLabel
        local iconBadge = btnBg:object("Frame", {
            Centered = true,
            Size = UDim2.fromOffset(28, 28),
            Theme = { BackgroundColor3 = "Tertiary" },
            ZIndex = 52
        }):round(8)

        -- Default text = first character of window name (or option override)
        local defaultText = options.ToggleButtonText
            or (options.Name and options.Name:sub(1, 1):upper())
            or "M"

        local iconText = iconBadge:object("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = defaultText,
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 53,
            Visible = options.ToggleButtonIcon == nil
        })

        local iconImage = iconBadge:object("ImageLabel", {
            BackgroundTransparency = 1,
            Centered = true,
            Size = UDim2.fromOffset(20, 20),
            Image = options.ToggleButtonIcon or "",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 53,
            Visible = options.ToggleButtonIcon ~= nil
        })

        -- Scale for press feedback
        local btnScale = toggleBtn:object("UIScale", { Scale = 1 })

        -- ----- Tap-vs-drag detection ----------------------------------------
        local TAP_THRESHOLD = 6  -- pixels
        local pressed   = false
        local moved     = false
        local startPos          -- screen-space input position when press began
        local startBtnPos       -- button's UDim2 position when press began

        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                pressed     = true
                moved       = false
                startPos    = input.Position
                startBtnPos = toggleBtn.Position
                sinkCameraInput()   -- prevent camera rotation while pressed
                btnScale:tween{Scale = 0.9, Length = 0.1}
                btnBg:tween{
                    BackgroundColor3 = Library:lighten(Library.CurrentTheme.Main, 15),
                    Length = 0.1
                }
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not pressed then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end

            local delta = input.Position - startPos
            if not moved and (math.abs(delta.X) > TAP_THRESHOLD or math.abs(delta.Y) > TAP_THRESHOLD) then
                moved = true
                -- Once we know it's a drag, restore scale so the icon doesn't look squashed
                btnScale:tween{Scale = 1, Length = 0.1}
            end
            if moved then
                local newX = math.clamp(startBtnPos.X.Offset + delta.X, 0, gui.AbsoluteSize.X - TOGGLE_BTN_SIZE)
                local newY = math.clamp(startBtnPos.Y.Offset + delta.Y, 0, gui.AbsoluteSize.Y - TOGGLE_BTN_SIZE)
                toggleBtn.Position = UDim2.fromOffset(newX, newY)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if not pressed then return end
            pressed = false
            releaseCameraInput()    -- allow camera again
            btnScale:tween{Scale = 1, Length = 0.12, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out}
            btnBg:tween{BackgroundColor3 = Library.CurrentTheme.Main, Length = 0.15}
            if not moved then
                -- A real tap → toggle the UI
                Library.Toggled = not Library.Toggled
                Library:show(Library.Toggled)
                -- Tiny pulse on the inner badge for tactile feedback
                iconBadge:tween{Size = UDim2.fromOffset(24, 24), Length = 0.08}
                task.delay(0.08, function()
                    iconBadge:tween{
                        Size = UDim2.fromOffset(28, 28),
                        Length = 0.18,
                        Style = Enum.EasingStyle.Back,
                        Direction = Enum.EasingDirection.Out
                    }
                end)
            end
        end)

        -- Expose for the returned window object so callers can re-style
        -- the floating button at any time.
        Library._toggleButton      = toggleBtn
        Library._toggleIconText    = iconText
        Library._toggleIconImage   = iconImage
        Library._toggleIconBadge   = iconBadge
    end

    -- =================================================================
    --                     TAB / CATEGORY MANAGEMENT
    -- =================================================================

    local tabs = {}
    local categories = {}      -- [name] = { header, baseOrder, count }
    local categoryCounter = 0  -- monotonic

    local function getOrCreateCategory(name)
        if categories[name] then return categories[name] end
        categoryCounter += 100

        local header = sidebarScroll:object("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            Text = string.upper(name),
            Theme = { TextColor3 = {"WeakText", -20} },
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = categoryCounter
        })
        header:object("UIPadding", {
            PaddingLeft = UDim.new(0, 4),
            PaddingTop  = UDim.new(0, 6)
        })

        categories[name] = {
            header    = header,
            baseOrder = categoryCounter,
            count     = 0
        }
        return categories[name]
    end

    -- =================================================================
    -- Build the metatable that we'll return to the caller.  Every tab /
    -- section / element function attaches itself via this object.
    -- =================================================================

    local mt = setmetatable({
        core                 = core,
        gui                  = gui,
        notifs               = notificationHolder,
        statusText           = status,
        headerTitle          = headerTitle,
        container            = contentArea,     -- default container (replaced per-tab)
        navigation           = sidebarScroll,
        sidebar              = sidebarScroll,
        Theme                = options.Theme,
        Tabs                 = tabs,
        Categories           = categories,
        getOrCreateCategory  = getOrCreateCategory,
        contentArea          = contentArea,
        toggleButton         = Library._toggleButton,
        nilFolder            = core:object("Folder"),
        _firstTab            = nil,
        _navHistory          = {},   -- stack of tab-select functions (browser-style)
        _navIndex            = 0
    }, Library)

    -- Public helper: force-show or hide the floating toggle button
    function mt:SetToggleButtonVisible(state)
        if self.toggleButton then
            self.toggleButton.Visible = state and true or false
        end
    end

    -- Change the character (or short string) shown inside the toggle button.
    -- Passing nil restores the default — first character of the window name.
    function mt:SetToggleButtonText(text)
        local t = Library._toggleIconText
        local img = Library._toggleIconImage
        if not t then return end
        t.Text    = text or (options.Name and options.Name:sub(1, 1):upper()) or "M"
        t.Visible = true
        if img then img.Visible = false end
    end

    -- Swap the toggle button to image mode using an rbxassetid (or any
    -- Image url). Passing nil/false reverts to text mode.
    function mt:SetToggleButtonIcon(assetId)
        local t = Library._toggleIconText
        local img = Library._toggleIconImage
        if not img then return end
        if assetId then
            img.Image   = assetId
            img.Visible = true
            if t then t.Visible = false end
        else
            img.Visible = false
            if t then t.Visible = true end
        end
    end

    -- =================================================================
    -- Auto-create the Settings tab (theme selector + drag/resize prefs)
    -- =================================================================

    task.defer(function()
        local settingsTab = Library.tab(mt, {
            Name     = "Settings",
            Icon     = "⚙",
            Category = "Settings"
        })

        settingsTab:_theme_selector()

        settingsTab:keybind{
            Name        = "Toggle Key",
            Description = "Key to show/hide the UI.",
            Keybind     = Enum.KeyCode.RightControl,
            Callback    = function()
                Library.Toggled = not Library.Toggled
                Library:show(Library.Toggled)
            end
        }

        settingsTab:toggle{
            Name         = "Lock Dragging",
            Description  = "Keep the UI inside the screen bounds.",
            StartingState = true,
            Callback     = function(state) Library.LockDragging = state end
        }

        settingsTab:slider{
            Name        = "UI Drag Speed",
            Description = "How smooth the dragging looks.",
            Max         = 20,
            Default     = 14,
            Callback    = function(value) Library.DragSpeed = (20 - value)/100 end
        }

        -- Auto-select the first tab created by the user (or settings if none)
        if mt._firstTab then
            mt._firstTab:_select()
        else
            settingsTab:_select()
        end
    end)

    -- =================================================================
    --                 TITLE-BAR TOOLBAR BEHAVIOURS
    --   Wired here (after sidebar / content / tabs exist) so the
    --   closures can see everything they touch.
    -- =================================================================

    -- ----- Sidebar collapse / expand -----------------------------------
    do
        local collapsed = false
        sidebarToggleBtn.MouseButton1Click:Connect(function()
            collapsed = not collapsed
            local quint = Enum.EasingStyle.Quint
            if collapsed then
                sidebar:tween{Size = UDim2.new(0, 0, 1, -(TITLE_BAR_HEIGHT + 1)), Length = 0.28, Style = quint}
                sidebarSep:tween{BackgroundTransparency = 1, Length = 0.18}
                content:tween{
                    Position = UDim2.new(0, 0, 0, TITLE_BAR_HEIGHT + 1),
                    Size     = UDim2.new(1, 0, 1, -(TITLE_BAR_HEIGHT + 1)),
                    Length = 0.28, Style = quint
                }
                status:tween{Position = UDim2.new(0, 18, 1, -6), Length = 0.28, Style = quint}
            else
                sidebar:tween{Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -(TITLE_BAR_HEIGHT + 1)), Length = 0.28, Style = quint}
                sidebarSep:tween{BackgroundTransparency = 0.45, Length = 0.22}
                content:tween{
                    Position = UDim2.new(0, SIDEBAR_WIDTH, 0, TITLE_BAR_HEIGHT + 1),
                    Size     = UDim2.new(1, -SIDEBAR_WIDTH, 1, -(TITLE_BAR_HEIGHT + 1)),
                    Length = 0.28, Style = quint
                }
                status:tween{Position = UDim2.new(0, SIDEBAR_WIDTH + 16, 1, -6), Length = 0.28, Style = quint}
            end
        end)
        sidebarToggleBtn:tooltip("Toggle sidebar")
    end

    -- ----- Navigation history (back / forward) -------------------------
    local function refreshNavArrows()
        local canBack = mt._navIndex > 1
        local canFwd  = mt._navIndex < #mt._navHistory
        backIcon:tween{TextTransparency = canBack and 0 or 0.72, Length = 0.12}
        fwdIcon:tween{TextTransparency = canFwd  and 0 or 0.72, Length = 0.12}
    end
    mt._refreshNavArrows = refreshNavArrows

    -- Called by each tab's selectThisTab (unless we're mid-navigation).
    function mt:_recordNav(selectFn)
        if Library._navigating then return end
        for i = #self._navHistory, self._navIndex + 1, -1 do
            self._navHistory[i] = nil           -- drop the old forward branch
        end
        if self._navHistory[self._navIndex] ~= selectFn then
            table.insert(self._navHistory, selectFn)
            self._navIndex = #self._navHistory
        end
        refreshNavArrows()
    end

    local function navigate(step)
        local target = mt._navIndex + step
        if target < 1 or target > #mt._navHistory then return end
        mt._navIndex = target
        Library._navigating = true
        pcall(mt._navHistory[target])
        Library._navigating = false
        refreshNavArrows()
    end

    backBtn.MouseButton1Click:Connect(function() navigate(-1) end)
    fwdBtn.MouseButton1Click:Connect(function() navigate(1)  end)
    refreshNavArrows()

    -- ----- Search: live-filter the sidebar tabs ------------------------
    local function applySearch(query)
        query = tostring(query or ""):lower():match("^%s*(.-)%s*$")
        local searching = query ~= ""
        for _, info in ipairs(tabs) do
            local name = tostring(info[3]):lower()
            info[2].Visible = (not searching) or (name:find(query, 1, true) ~= nil)
        end
        -- During a search we collapse the category headers so the list
        -- reads as a flat set of matches; restore them when cleared.
        for _, cat in pairs(categories) do
            if cat.header then cat.header.Visible = not searching end
        end
    end
    searchBox.AbsoluteObject:GetPropertyChangedSignal("Text"):Connect(function()
        applySearch(searchBox.Text)
    end)

    -- ----- Responsive title bar ----------------------------------------
    --   On narrow windows the search box is the first thing to go, so the
    --   title never gets squeezed into nothing.
    local function reflow()
        local w = core.AbsoluteSize.X
        local compact = w < 560
        searchHolder.Visible = not compact
        local rightReserve = compact and 16 or (SEARCH_W + 28)
        titleBlock.Size = UDim2.new(1, -(TITLE_LEFT + rightReserve), 1, 0)
    end
    core.AbsoluteObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow)
    reflow()

    return mt
end

-- =====================================================================
--                              TAB
-- =====================================================================

function Library:tab(options)
    options = self:set_defaults({
        Name     = "New Tab",
        Icon     = "rbxassetid://8569322835",
        Category = "Main"
    }, options)

    local TAB_HEIGHT = IsMobile and 38 or 34

    -- Ensure the category exists and grab its LayoutOrder data
    local cat = self.getOrCreateCategory(options.Category)
    cat.count += 1
    local tabLayoutOrder = cat.baseOrder + cat.count

    -- ----- Sidebar button --------------------------------------------------
    local tabButton = self.sidebar:object("TextButton", {
        BackgroundTransparency = 1,
        Theme = { BackgroundColor3 = {"Tertiary", -10} },
        Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
        LayoutOrder = tabLayoutOrder,
        AutoButtonColor = false,
        ZIndex = 4
    }):round(8)

    -- Tab icon: detect the icon type so we can handle tinting correctly.
    -- Roblox renders Unicode emojis (🥚, 💰, 🌙 — anything from the
    -- Supplementary Multilingual Plane) as *colour glyphs* — system
    -- bitmap fonts that ignore TextColor3. Monochrome BMP symbols
    -- like ★ ⚡ ⚙ ◆ ● respect TextColor3 normally.
    --
    -- We auto-classify so:
    --   • Image icon  → ImageLabel  (tints via ImageColor3)
    --   • Mono symbol → TextLabel   (tints via TextColor3)
    --   • Color emoji → TextLabel + a small accent dot under it
    --                   that DOES tint, giving the user a visible
    --                   "active" indicator even though the emoji
    --                   itself stays its native colour.
    local iconStr = tostring(options.Icon or "")
    local isImageIcon = iconStr:sub(1, 13) == "rbxassetid://"
        or iconStr:sub(1, 4)  == "http"
        or iconStr:match("^%d+$")

    -- Quick check for color emoji: any codepoint >= U+1F000 is
    -- almost certainly a color emoji on every Roblox-supported
    -- platform. Iterate bytes and test for 4-byte UTF-8 sequences
    -- (which encode codepoints in the 0x10000+ range).
    local function isColorEmoji(s)
        for _, code in utf8.codes(s) do
            if code >= 0x1F000 then return true end
            -- Also catch some BMP emoji like ⭐ ✨ ❤
            if code == 0x2B50 or code == 0x2728 or code == 0x2764
                or code == 0x2705 or code == 0x274C then
                return true
            end
        end
        return false
    end
    local isMonoSymbol = (not isImageIcon) and (not isColorEmoji(iconStr))

    local tabIcon
    local tabIconDot   -- the tinting indicator under color emojis

    if isImageIcon then
        tabIcon = tabButton:object("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Image = iconStr,
            Theme = { ImageColor3 = {"WeakText", 0} },
            ZIndex = 5
        })
    else
        -- TextLabel works for both mono symbols and color emojis.
        -- Color emojis get pushed slightly right to leave room for the
        -- accent indicator dot. Mono symbols sit in the regular spot.
        tabIcon = tabButton:object("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(0, isMonoSymbol and 10 or 14, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            Text = iconStr ~= "" and iconStr or "•",
            Font = Enum.Font.GothamBold,
            TextSize = isMonoSymbol and 16 or 14,
            Theme = { TextColor3 = {"WeakText", 0} },
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 5
        })

        -- For color emojis, add a tiny tintable dot on the left
        -- so there's still a clear visual "active" cue when the
        -- tab is selected. Mono symbols tint themselves and don't
        -- need this extra dot.
        if not isMonoSymbol then
            tabIconDot = tabButton:object("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0.5, 0),
                Size = UDim2.fromOffset(3, 14),
                Theme = { BackgroundColor3 = {"WeakText", 0} },
                ZIndex = 5
            }):round(100)
        end
    end

    local tabLabel = tabButton:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(34, 0),
        Size = UDim2.new(1, -42, 1, 0),
        Text = options.Name,
        Theme = { TextColor3 = {"WeakText", 10} },
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5
    })

    -- ----- Content page ---------------------------------------------------
    local tabPage = self.contentArea:object("ScrollingFrame", {
        BackgroundTransparency = 1,
        Visible = false,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = IsMobile and 0 or 3,
        ScrollBarImageColor3 = Color3.fromRGB(120, 120, 130),
        ScrollBarImageTransparency = 0.5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3
    })

    tabPage:object("UIPadding", {
        PaddingLeft   = UDim.new(0, 20),
        PaddingRight  = UDim.new(0, 16),
        PaddingTop    = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 24)
    })

    local layout = tabPage:object("UIListLayout", {
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    table.insert(self.Tabs, {tabPage, tabButton, options.Name})

    -- Decide which element + property to tween for the colored "active"
    -- indicator:
    --   • Image icon → tween ImageColor3 on the icon itself
    --   • Mono symbol → tween TextColor3 on the icon text
    --   • Color emoji → tween BackgroundColor3 on the side dot
    --                   (emoji itself keeps its native colours)
    local tintTarget, tintProp
    if isImageIcon then
        tintTarget, tintProp = tabIcon, "ImageColor3"
    elseif isMonoSymbol then
        tintTarget, tintProp = tabIcon, "TextColor3"
    else
        tintTarget, tintProp = tabIconDot, "BackgroundColor3"
    end

    -- ----- Selection visuals ----------------------------------------------
    local function setSelected(isSel)
        if isSel then
            tabButton:tween{BackgroundTransparency = 0.82, Length = 0.15}
            tintTarget:tween{[tintProp] = Library.CurrentTheme.Tertiary, Length = 0.15}
            tabLabel:tween{TextColor3 = Library.CurrentTheme.StrongText, Length = 0.15}
        else
            tabButton:tween{BackgroundTransparency = 1, Length = 0.15}
            tintTarget:tween{[tintProp] = Library.CurrentTheme.WeakText, Length = 0.15}
            tabLabel:tween{TextColor3 = Library:lighten(Library.CurrentTheme.WeakText, 10), Length = 0.15}
        end
    end
    setSelected(false)

    -- Re-apply colours when the theme changes (we already track `selectedTab`)
    table.insert(Library._themeUpdaters, function(theme)
        local isSel = (selectedTab == tabButton)
        if isSel then
            tintTarget:tween{[tintProp] = theme.Tertiary, Length = 0.15}
            tabLabel:tween{TextColor3 = theme.StrongText, Length = 0.15}
        else
            tintTarget:tween{[tintProp] = theme.WeakText, Length = 0.15}
            tabLabel:tween{TextColor3 = Library:lighten(theme.WeakText, 10), Length = 0.15}
        end
    end)

    local function selectThisTab()
        -- Deselect whatever tab was previously active
        if selectedTab and selectedTab ~= tabButton then
            local prev = selectedTab
            if rawget(prev, "_setSelected") then
                rawget(prev, "_setSelected")(false)
            end
        end
        -- Hide all tab pages
        for _, tabInfo in next, self.Tabs do
            tabInfo[1].Visible = false
        end
        selectedTab = tabButton
        tabPage.Visible = true
        setSelected(true)
        if self.headerTitle then
            self.headerTitle.Text = options.Name
        end
        if Library.UrlLabel then
            Library.UrlLabel.Text = Library.Url .. "/" .. options.Name:lower()
        end
        -- Record into the window's navigation history so the title-bar
        -- back / forward arrows can retrace the user's path.
        if self._recordNav then
            self:_recordNav(selectThisTab)
        end
    end

    -- expose for cross-tab deselection
    rawset(tabButton, "_setSelected", setSelected)

    do
        local hovered = false
        tabButton.MouseEnter:Connect(function()
            hovered = true
            if selectedTab ~= tabButton then
                tabButton:tween{BackgroundTransparency = 0.92, Length = 0.1}
                tabLabel:tween{TextColor3 = Library.CurrentTheme.StrongText, Length = 0.1}
            end
        end)
        tabButton.MouseLeave:Connect(function()
            hovered = false
            if selectedTab ~= tabButton then
                tabButton:tween{BackgroundTransparency = 1, Length = 0.1}
                tabLabel:tween{TextColor3 = Library:lighten(Library.CurrentTheme.WeakText, 10), Length = 0.1}
            end
        end)
        tabButton.MouseButton1Click:Connect(selectThisTab)
    end

    local tabObj = setmetatable({
        statusText  = self.statusText,
        container   = tabPage,
        Theme       = self.Theme,
        core        = self.core,
        layout      = layout,
        headerTitle = self.headerTitle,
        _tabButton  = tabButton,
        _setSelected = setSelected,
        _select     = selectThisTab
    }, Library)

    -- Remember the first user-defined tab so we can auto-open it
    if options.Category ~= "Settings" and not self._firstTab then
        self._firstTab = tabObj
    end

    return tabObj
end

-- =====================================================================
--                            _resize_tab
-- =====================================================================

function Library:_resize_tab()
    -- Sections nest a parent container; this keeps section heights in sync.
    if self.sectionContainer then
        self.sectionContainer.Size = UDim2.new(1, 0, 0, self.layout.AbsoluteContentSize.Y + 28)
    end
end

-- =====================================================================
--                            SECTION
-- =====================================================================

function Library:section(options)
    options = self:set_defaults({ Name = "Section" }, options)

    local sectionFrame = self.container:object("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
        AutomaticSize = Enum.AutomaticSize.None
    })

    -- Section header (large, no container border — clean macOS look)
    local header = sectionFrame:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.new(1, -4, 0, 22),
        Text = options.Name,
        Theme = { TextColor3 = "StrongText" },
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    -- Inner frame that actually holds the items
    local body = sectionFrame:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 28),
        Size = UDim2.new(1, 0, 1, -28)
    })

    local layout = body:object("UIListLayout", {
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    -- Auto-grow when content changes
    layout.AbsoluteObject:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sectionFrame.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 32)
    end)

    return setmetatable({
        statusText        = self.statusText,
        container         = body,
        sectionContainer  = sectionFrame,
        parentContainer   = self.container,
        Theme             = self.Theme,
        core              = self.core,
        layout            = layout
    }, Library)
end

-- =====================================================================
--                       SHARED ROW HELPERS
-- =====================================================================

-- Standard row sizing — title + description + right-side control
local ROW_HEIGHT      = IsMobile and 62 or 58
local ROW_HEIGHT_SLIM = IsMobile and 52 or 48

local function buildRow(parent, options, height)
    local row = parent:object("TextButton", {
        Theme = { BackgroundColor3 = "Secondary" },
        BackgroundTransparency = 0.4,
        Size = UDim2.new(1, 0, 0, height or ROW_HEIGHT),
        AutoButtonColor = false,
        Text = "",                  -- so the inherited Text field doesn't render
        ClipsDescendants = true     -- crop overflow cleanly instead of bleeding out
    }):round(8)

    -- Reserve a right-side region of the row for the control (toggle
    -- pill, slider value box, dropdown chevron, textbox, etc). Using a
    -- fixed offset instead of a percentage means the text area shrinks
    -- but the *title* never gets clipped to invisibility when the
    -- window is resized narrow. 120 fits every standard control —
    -- textboxes are capped at MAX_W=180 below so they never overlap.
    local TITLE_RIGHT_PAD = 140
    local DESC_RIGHT_PAD  = 140

    local title = row:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, options.Description and 10 or 0),
        Size = options.Description
            and UDim2.new(1, -(14 + TITLE_RIGHT_PAD), 0, 18)
            or UDim2.new(1, -(14 + TITLE_RIGHT_PAD), 1, 0),
        Text = options.Name or "Item",
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
        Theme = { TextColor3 = "StrongText" },
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd     -- "…" when too long
    })

    local description
    if options.Description then
        description = row:object("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 30),
            Size = UDim2.new(1, -(14 + DESC_RIGHT_PAD), 0, 16),
            Text = options.Description,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            Theme = { TextColor3 = {"WeakText", 5} },
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
    end

    -- Hover behaviour (no hover on mobile)
    if not IsMobile then
        row.MouseEnter:Connect(function()
            row:tween{BackgroundTransparency = 0.2, Length = 0.12}
        end)
        row.MouseLeave:Connect(function()
            row:tween{BackgroundTransparency = 0.4, Length = 0.12}
        end)
    end

    return row, title, description
end

-- =====================================================================
--                              TOGGLE
-- =====================================================================

function Library:toggle(options)
    options = self:set_defaults({
        Name          = "Toggle",
        StartingState = false,
        Description   = nil,
        Callback      = function() end
    }, options)

    local row = buildRow(self.container, options)

    local toggled = options.StartingState

    -- Pill background
    local pill = row:object("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(40, 22),
        BackgroundColor3 = toggled
            and Library.CurrentTheme.Tertiary
            or Library:lighten(Library.CurrentTheme.Secondary, 25)
    }):round(100)

    -- Sliding circle
    local circle = pill:object("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = toggled
            and UDim2.new(1, -20, 0.5, 0)
            or UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    }):round(100)

    local function setState(state, fireCallback)
        toggled = state
        pill:tween{
            BackgroundColor3 = state
                and Library.CurrentTheme.Tertiary
                or Library:lighten(Library.CurrentTheme.Secondary, 25),
            Length = 0.18
        }
        circle:tween{
            Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
            Length = 0.18,
            Style = Enum.EasingStyle.Back,
            Direction = Enum.EasingDirection.Out
        }
        if fireCallback ~= false then
            task.spawn(options.Callback, toggled)
        end
    end

    -- Refresh colours on theme swap (state must be re-evaluated each time)
    table.insert(Library._themeUpdaters, function(theme)
        pill:tween{
            BackgroundColor3 = toggled
                and theme.Tertiary
                or Library:lighten(theme.Secondary, 25),
            Length = 0.18
        }
    end)

    row.MouseButton1Click:Connect(function()
        setState(not toggled)
    end)

    local methods = {}
    function methods:Toggle()        setState(not toggled)       end
    function methods:SetState(state) setState(state)              end
    function methods:Get()           return toggled               end

    if options.StartingState then setState(true) end

    return methods
end

-- =====================================================================
--                              SLIDER
--   Uses a numeric TextBox on the right so it works equally well with
--   mouse, touch, or keyboard input.
-- =====================================================================

function Library:slider(options)
    options = self:set_defaults({
        Name        = "Slider",
        Default     = 50,
        Min         = 0,
        Max         = 100,
        Suffix      = "",
        Description = nil,
        Callback    = function() end
    }, options)

    local rowHeight = options.Description and 76 or 60
    local row, title, description = buildRow(self.container, options, rowHeight)

    -- Numeric textbox (right side, top half)
    local valueBox = row:object("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10),
        Size = UDim2.fromOffset(IsMobile and 56 or 46, 22),
        Theme = {
            BackgroundColor3 = {"Secondary", 15},
            TextColor3 = "StrongText"
        },
        Text = tostring(options.Default),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Center
    }):round(6)

    -- Slider track at the bottom of the row
    local track = row:object("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -14),
        Size = UDim2.new(1, -28, 0, 4),
        Theme = { BackgroundColor3 = {"Secondary", 25} },
        BackgroundTransparency = 0.2
    }):round(100)

    local pct = (options.Default - options.Min) / math.max(1, (options.Max - options.Min))

    local fill = track:object("Frame", {
        Size = UDim2.fromScale(pct, 1),
        Theme = { BackgroundColor3 = "Tertiary" }
    }):round(100)

    local thumb = fill:object("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(IsMobile and 16 or 12, IsMobile and 16 or 12),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    }):round(100):stroke({"Tertiary", 10}, 1)

    local currentValue = options.Default

    local function applyValue(value, fireCallback)
        value = math.clamp(math.floor(value + 0.5), options.Min, options.Max)
        currentValue = value
        local p = (value - options.Min) / math.max(1, (options.Max - options.Min))
        fill:tween{Size = UDim2.fromScale(p, 1), Length = 0.08}
        valueBox.Text = tostring(value)
        if fireCallback ~= false then
            task.spawn(options.Callback, value)
        end
    end

    -- Invisible hit area that overlays the lower half of the row, so the
    -- slider remains easy to grab on touch.
    local hitArea = row:object("TextButton", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, -28, 0, IsMobile and 28 or 22),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = ""
    })

    -- Drag the track via the larger hit area
    do
        local dragging = false
        local function updateFromInput(input)
            local rel = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
            rel = math.clamp(rel, 0, 1)
            local value = options.Min + rel * (options.Max - options.Min)
            applyValue(value)
        end

        hitArea.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                sinkCameraInput()
                updateFromInput(input)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and
              (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    releaseCameraInput()
                end
            end
        end)
    end

    -- Type a value into the box
    valueBox.AbsoluteObject.FocusLost:Connect(function()
        local num = tonumber(valueBox.Text)
        if num then
            applyValue(num)
        else
            valueBox.Text = tostring(currentValue)
        end
    end)

    local methods = {}
    function methods:Set(value) applyValue(value) end
    function methods:Get()      return currentValue end

    return methods
end

-- =====================================================================
--                              BUTTON
-- =====================================================================

function Library:button(options)
    options = self:set_defaults({
        Name        = "Button",
        Description = nil,
        Callback    = function() end
    }, options)

    local row = buildRow(self.container, options)

    -- Trailing chevron icon
    local icon = row:object("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        Image = "rbxassetid://8498776661",
        Theme = { ImageColor3 = {"WeakText", 10} }
    })

    row.MouseEnter:Connect(function()
        icon:tween{ImageColor3 = Library.CurrentTheme.Tertiary, Length = 0.12}
    end)
    row.MouseLeave:Connect(function()
        icon:tween{ImageColor3 = Library.CurrentTheme.WeakText, Length = 0.12}
    end)

    row.MouseButton1Click:Connect(function()
        -- Quick "press" visual feedback
        row:tween{BackgroundTransparency = 0.05, Length = 0.06}
        task.delay(0.1, function()
            row:tween{BackgroundTransparency = IsMobile and 0.4 or 0.2, Length = 0.12}
        end)
        task.spawn(options.Callback)
    end)

    local methods = {}
    function methods:Fire()       task.spawn(options.Callback) end
    function methods:SetText(txt) row.AbsoluteObject:FindFirstChildWhichIsA("TextLabel").Text = txt end

    return methods
end

-- =====================================================================
--                            DROPDOWN
-- =====================================================================

function Library:dropdown(options)
    options = self:set_defaults({
        Name         = "Dropdown",
        StartingText = "Select...",
        Description  = nil,
        Items        = {},
        Callback     = function() end
    }, options)

    local row = buildRow(self.container, options)

    -- Value badge on the right
    local selectedBadge = row:object("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -36, 0.5, 0),
        Size = UDim2.fromOffset(120, 24),
        Theme = {
            BackgroundColor3 = {"Secondary", 20},
            TextColor3 = "StrongText"
        },
        Text = options.StartingText,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd
    }):round(6)
    selectedBadge.Size = UDim2.fromOffset(math.clamp(selectedBadge.TextBounds.X + 18, 60, 160), 24)

    local chevron = row:object("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        Image = "rbxassetid://8498840035",
        Theme = { ImageColor3 = "Tertiary" }
    })

    -- Expandable item area
    local itemArea = row:object("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, ROW_HEIGHT),
        Size = UDim2.new(1, -28, 0, 0),
        ClipsDescendants = true
    })

    local itemLayout = itemArea:object("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    local items = {}
    local open = false

    local function setOpen(state)
        open = state
        local itemH = (#items * 30) + (math.max(0, #items - 1) * 4)
        local rowH  = ROW_HEIGHT + (state and (itemH + 12) or 0)
        row:tween{Size = UDim2.new(1, 0, 0, rowH), Length = 0.18}
        itemArea:tween{Size = UDim2.new(1, -28, 0, state and itemH or 0), Length = 0.18}
        chevron:tween{Rotation = state and 180 or 0, Length = 0.18}
    end

    local function buildItem(label, value, idx)
        local btn = itemArea:object("TextButton", {
            BackgroundTransparency = 0.3,
            Theme = { BackgroundColor3 = {"Secondary", 15} },
            Size = UDim2.new(1, 0, 0, 26),
            LayoutOrder = idx,
            AutoButtonColor = false,
            ZIndex = 3
        }):round(6)

        btn:object("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -16, 1, 0),
            Text = tostring(label),
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            Theme = { TextColor3 = "StrongText" },
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4
        })

        btn.MouseEnter:Connect(function()
            btn:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary, BackgroundTransparency = 0.1, Length = 0.1}
        end)
        btn.MouseLeave:Connect(function()
            btn:tween{
                BackgroundColor3 = Library:lighten(Library.CurrentTheme.Secondary, 15),
                BackgroundTransparency = 0.3,
                Length = 0.1
            }
        end)
        btn.MouseButton1Click:Connect(function()
            selectedBadge.Text = tostring(label)
            selectedBadge.Size = UDim2.fromOffset(math.clamp(selectedBadge.TextBounds.X + 18, 60, 160), 24)
            task.spawn(options.Callback, value)
            setOpen(false)
        end)

        return btn
    end

    -- Populate initial items
    for i, v in next, options.Items do
        local label, value
        if typeof(v) == "table" then label, value = v[1], v[2] else label, value = tostring(v), v end
        items[#items + 1] = {label = label, value = value, btn = buildItem(label, value, #items + 1)}
    end

    -- Row click toggles
    row.MouseButton1Click:Connect(function() setOpen(not open) end)

    local methods = {}
    function methods:Set(text)
        selectedBadge.Text = tostring(text)
        selectedBadge.Size = UDim2.fromOffset(math.clamp(selectedBadge.TextBounds.X + 18, 60, 160), 24)
    end
    function methods:AddItems(newItems)
        for _, v in next, newItems do
            local label, value
            if typeof(v) == "table" then label, value = v[1], v[2] else label, value = tostring(v), v end
            items[#items + 1] = {label = label, value = value, btn = buildItem(label, value, #items + 1)}
        end
        if open then setOpen(true) end
    end
    function methods:RemoveItems(removeList)
        for _, v in next, removeList do
            for idx, it in next, items do
                if tostring(it.label):lower() == tostring(v):lower() then
                    it.btn.AbsoluteObject:Destroy()
                    table.remove(items, idx)
                    break
                end
            end
        end
        if open then setOpen(true) end
    end
    function methods:Clear()
        for _, it in next, items do it.btn.AbsoluteObject:Destroy() end
        items = {}
        setOpen(false)
    end

    return methods
end

-- =====================================================================
--                            KEYBIND
-- =====================================================================

function Library:keybind(options)
    options = self:set_defaults({
        Name        = "Keybind",
        Keybind     = nil,
        Description = nil,
        Callback    = function() end
    }, options)

    local row = buildRow(self.container, options)

    local keyBadge = row:object("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(54, 24),
        Theme = {
            BackgroundColor3 = {"Secondary", 20},
            TextColor3 = "StrongText"
        },
        Text = options.Keybind and tostring(options.Keybind.Name):upper() or "?",
        Font = Enum.Font.GothamMedium,
        TextSize = 11
    }):round(6)
    keyBadge.Size = UDim2.fromOffset(math.clamp(keyBadge.TextBounds.X + 18, 36, 100), 24)

    local listening = false

    row.MouseButton1Click:Connect(function()
        if not listening then
            listening = true
            keyBadge.Text = "..."
            keyBadge.Size = UDim2.fromOffset(36, 24)
            keyBadge:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary, Length = 0.15}
        end
    end)

    UserInputService.InputBegan:Connect(function(key, gp)
        if listening and not UserInputService:GetFocusedTextBox() then
            if key.UserInputType == Enum.UserInputType.Keyboard then
                if key.KeyCode ~= Enum.KeyCode.Escape then
                    options.Keybind = key.KeyCode
                end
                keyBadge.Text = options.Keybind and tostring(options.Keybind.Name):upper() or "?"
                keyBadge.Size = UDim2.fromOffset(math.clamp(keyBadge.TextBounds.X + 18, 36, 100), 24)
                keyBadge:tween{BackgroundColor3 = Library:lighten(Library.CurrentTheme.Secondary, 20), Length = 0.15}
                listening = false
            end
        elseif not gp and not UserInputService:GetFocusedTextBox() then
            if key.KeyCode == options.Keybind then
                task.spawn(options.Callback)
            end
        end
    end)

    local methods = {}
    function methods:Set(keycode)
        options.Keybind = keycode
        keyBadge.Text = keycode and tostring(keycode.Name):upper() or "?"
        keyBadge.Size = UDim2.fromOffset(math.clamp(keyBadge.TextBounds.X + 18, 36, 100), 24)
    end

    return methods
end

-- =====================================================================
--                            TEXTBOX
-- =====================================================================

function Library:textbox(options)
    options = self:set_defaults({
        Name        = "Text Box",
        Placeholder = "Type something..",
        Description = nil,
        Callback    = function() end
    }, options)

    local row = buildRow(self.container, options)

    -- Compute a width that fits the placeholder comfortably so the
    -- hint "https://www.roblox.com" (and similar) is fully visible
    -- when the box is empty. We pick the larger of:
    --   • a minimum (110 desktop / 130 mobile so the box doesn't
    --     shrink to nothing on empty Placeholder)
    --   • the actual rendered width of the placeholder + padding
    --   • a maximum cap so it doesn't push the row text off-screen
    local TS = game:GetService("TextService")
    local MIN_W   = IsMobile and 130 or 110
    local MAX_W   = 200
    local SIDE_PAD = 18    -- 8 left + 8 right padding + small breathing room

    local computedW = MIN_W
    pcall(function()
        local size = TS:GetTextSize(
            options.Placeholder or "",
            12,
            Enum.Font.GothamMedium,
            Vector2.new(10000, 100)
        )
        computedW = math.max(MIN_W, math.min(MAX_W, math.ceil(size.X) + SIDE_PAD))
    end)

    local input = row:object("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(computedW, 26),
        Theme = {
            BackgroundColor3 = {"Secondary", 15},
            TextColor3 = "StrongText"
        },
        PlaceholderText = options.Placeholder,
        PlaceholderColor3 = Library:lighten(Library.CurrentTheme.WeakText, 5),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true
    }):round(6):stroke({"Secondary", 25}, 1)

    input:object("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8)
    })

    input.AbsoluteObject.Focused:Connect(function()
        input.AbsoluteObject:FindFirstChildWhichIsA("UIStroke").Color = Library.CurrentTheme.Tertiary
    end)
    input.AbsoluteObject.FocusLost:Connect(function()
        input.AbsoluteObject:FindFirstChildWhichIsA("UIStroke").Color = Library:lighten(Library.CurrentTheme.Secondary, 25)
        task.spawn(options.Callback, input.Text)
    end)

    local methods = {}
    function methods:Set(t) input.Text = t end
    function methods:Get()  return input.Text end

    return methods
end

-- =====================================================================
--                            LABEL
-- =====================================================================

function Library:label(options)
    options = self:set_defaults({
        Text        = "Label title",
        Description = "Label text"
    }, options)

    local row = self.container:object("Frame", {
        Theme = { BackgroundColor3 = "Secondary" },
        BackgroundTransparency = 0.4,
        Size = UDim2.new(1, 0, 0, options.Description and 56 or 38)
    }):round(8)

    local title = row:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, options.Description and 8 or 0),
        Size = options.Description
            and UDim2.new(1, -28, 0, 18)
            or UDim2.new(1, -28, 1, 0),
        Text = options.Text,
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
        Theme = { TextColor3 = "StrongText" },
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    })

    local description
    if options.Description then
        description = row:object("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 28),
            Size = UDim2.new(1, -28, 0, 18),
            Text = options.Description,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            Theme = { TextColor3 = "WeakText" },
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true
        })
    end

    local methods = {}
    function methods:SetText(t)        title.Text = t        end
    function methods:SetDescription(t) if description then description.Text = t end end

    return methods
end

-- =====================================================================
--                          NOTIFICATION
-- =====================================================================

function Library:notification(options)
    options = self:set_defaults({
        Title    = "Notification",
        Text     = "Your character has been reset.",
        Duration = 4,
        Callback = function() end
    }, options)

    -- ───── Layout constants ─────
    local NOTI_W       = 320
    local PAD_X        = 14
    local PAD_TOP      = 12
    local PAD_BOTTOM   = 14    -- gap above the progress bar
    local PROGRESS_H   = 3     -- height of the bar at the very bottom
    local TITLE_H      = 20
    local TITLE_GAP    = 6
    local ICON_SIZE    = 18

    -- Pre-compute the wrapped text height with TextService so the
    -- notification's outer Size is known *before* the tween starts.
    -- (Reading TextBounds while Size = (1,0,0,0) gives 0 — that was the
    -- root cause of the progress bar overlapping the body text.)
    local TextService  = game:GetService("TextService")
    local textWidth    = NOTI_W - (PAD_X * 2)
    local ok, computed = pcall(function()
        return TextService:GetTextSize(
            options.Text,
            13,                                 -- TextSize
            Enum.Font.Gotham,
            Vector2.new(textWidth, 10000)       -- wrap inside this width
        )
    end)
    local textHeight   = (ok and computed and computed.Y) or 16
    -- Guard against unrealistic values (some fonts return weird metrics)
    textHeight = math.clamp(math.ceil(textHeight) + 2, 14, 400)

    local TOTAL_H = PAD_TOP + TITLE_H + TITLE_GAP + textHeight + PAD_BOTTOM + PROGRESS_H

    -- ───── Outer frame ─────
    local noti = self.notifs:object("Frame", {
        BackgroundTransparency = 1,
        Theme = { BackgroundColor3 = "Secondary" },
        Size = UDim2.new(0, NOTI_W, 0, 0),
        ZIndex = 101,
        ClipsDescendants = true
    }):round(10):stroke({"Secondary", 20}, 1)

    local _shadow = noti:object("ImageLabel", {
        Centered = true,
        Size = UDim2.new(1, 70, 1, 70),
        BackgroundTransparency = 1,
        ZIndex = 100,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450)
    })

    -- ───── Icon ─────
    local icon = noti:object("ImageLabel", {
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        Position = UDim2.fromOffset(PAD_X, PAD_TOP + 1),
        Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
        Image = "rbxassetid://8628681683",
        Theme = { ImageColor3 = "Tertiary" },
        ZIndex = 102
    })

    -- ───── Title ─────
    local title = noti:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(PAD_X + ICON_SIZE + 8, PAD_TOP),
        Size = UDim2.new(1, -(PAD_X * 2 + ICON_SIZE + 8 + 20), 0, TITLE_H),
        Font = Enum.Font.GothamBold,
        Text = options.Title,
        Theme = { TextColor3 = "StrongText" },
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = 1,
        ZIndex = 102
    })

    -- ───── Close button ─────
    local exit = noti:object("ImageButton", {
        Image = "http://www.roblox.com/asset/?id=8497487650",
        AnchorPoint = Vector2.new(1, 0),
        Theme = { ImageColor3 = {"WeakText", 10} },
        Position = UDim2.new(1, -PAD_X, 0, PAD_TOP + 4),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        ImageTransparency = 1,
        ZIndex = 102
    })

    -- ───── Body text ─────
    local text = noti:object("TextLabel", {
        BackgroundTransparency = 1,
        Text = options.Text,
        Position = UDim2.fromOffset(PAD_X, PAD_TOP + TITLE_H + TITLE_GAP),
        Size = UDim2.new(1, -(PAD_X * 2), 0, textHeight),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextTransparency = 1,
        TextWrapped = true,
        Theme = { TextColor3 = {"WeakText", 15} },
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 102
    })

    -- ───── Progress bar (anchored to the absolute bottom) ─────
    local durHolder = noti:object("Frame", {
        BackgroundTransparency = 1,
        Theme = { BackgroundColor3 = {"Secondary", 25} },
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, PROGRESS_H),
        ZIndex = 102
    }):round(100)

    local lengthBar = durHolder:object("Frame", {
        BackgroundTransparency = 1,
        Theme = { BackgroundColor3 = "Tertiary" },
        Size = UDim2.fromScale(1, 1)
    }):round(100)

    -- ───── Animations ─────
    local fadeOut
    fadeOut = function()
        task.delay(0.3, function()
            if noti.AbsoluteObject then noti.AbsoluteObject:Destroy() end
            task.spawn(options.Callback)
        end)
        icon:tween{ImageTransparency = 1, Length = 0.2}
        exit:tween{ImageTransparency = 1, Length = 0.2}
        durHolder:tween{BackgroundTransparency = 1, Length = 0.2}
        lengthBar:tween{BackgroundTransparency = 1, Length = 0.2}
        text:tween{TextTransparency = 1, Length = 0.2}
        title:tween{TextTransparency = 1, Length = 0.2, Style = Enum.EasingStyle.Quad}
        _shadow:tween{ImageTransparency = 1, Length = 0.2}
        noti:tween{BackgroundTransparency = 1, Length = 0.2, Size = UDim2.fromOffset(NOTI_W, 0)}
    end

    exit.MouseButton1Click:Connect(fadeOut)

    _shadow:tween{ImageTransparency = 0.55, Length = 0.25}
    noti:tween({BackgroundTransparency = 0.05, Size = UDim2.fromOffset(NOTI_W, TOTAL_H), Length = 0.25}, function()
        icon:tween{ImageTransparency = 0, Length = 0.2}
        exit:tween{ImageTransparency = 0.4, Length = 0.2}
        durHolder:tween{BackgroundTransparency = 0.4, Length = 0.2}
        lengthBar:tween{BackgroundTransparency = 0, Length = 0.2}
        text:tween{TextTransparency = 0, Length = 0.2}
        title:tween{TextTransparency = 0, Length = 0.2}
    end)

    lengthBar:tween({Size = UDim2.fromScale(0, 1), Length = options.Duration, Style = Enum.EasingStyle.Linear}, fadeOut)
end

-- =====================================================================
--                              PROMPT
-- =====================================================================

function Library:prompt(options)
    options = self:set_defaults({
        Followup = false,
        Title    = "Prompt",
        Text     = "Are you sure?",
        Buttons  = { OK = function() return true end }
    }, options)

    if Library._promptExists and not options.Followup then return end
    Library._promptExists = true

    local count = 0
    for _ in next, options.Buttons do count += 1 end

    local darkener = self.core:object("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Active = true,
        ZIndex = 40
    }):round(10)

    local box = darkener:object("Frame", {
        Theme = { BackgroundColor3 = "Secondary" },
        BackgroundTransparency = 1,
        Centered = true,
        Size = UDim2.fromOffset(280, 140),
        ZIndex = 41
    }):round(10):stroke({"Secondary", 25}, 1)

    box:object("UIPadding", {
        PaddingTop = UDim.new(0, 18),
        PaddingLeft = UDim.new(0, 18),
        PaddingRight = UDim.new(0, 18),
        PaddingBottom = UDim.new(0, 14)
    })

    local titleLabel = box:object("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Center,
        Font = Enum.Font.GothamBold,
        Text = options.Title,
        Theme = { TextColor3 = "StrongText" },
        TextSize = 15,
        TextTransparency = 1,
        ZIndex = 42
    })

    local msg = box:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 1, -64),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        Theme = { TextColor3 = {"WeakText", 15} },
        Text = options.Text,
        TextTransparency = 1,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 42
    })

    local buttonHolder = box:object("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 28),
        ZIndex = 42
    })

    buttonHolder:object("UIGridLayout", {
        CellPadding = UDim2.new(0, 10, 0, 0),
        CellSize = UDim2.new(1/count, -10 + 10/count, 1, 0),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    darkener:tween{BackgroundTransparency = 0.5, Length = 0.15}
    box:tween{BackgroundTransparency = 0, Length = 0.15}
    titleLabel:tween{TextTransparency = 0, Length = 0.15}
    msg:tween{TextTransparency = 0, Length = 0.15}

    local btnRefs = {}
    local order = 1
    for txt, callback in next, options.Buttons do
        local isPrimary = (order == count)
        local btn = buttonHolder:object("TextButton", {
            BackgroundColor3 = isPrimary
                and Library.CurrentTheme.Tertiary
                or Library:lighten(Library.CurrentTheme.Secondary, 20),
            Text = tostring(txt),
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            Theme = { TextColor3 = "StrongText" },
            BackgroundTransparency = 1,
            TextTransparency = 1,
            LayoutOrder = order,
            ZIndex = 43
        }):round(6)
        btnRefs[#btnRefs + 1] = btn
        btn:tween{BackgroundTransparency = 0, TextTransparency = 0, Length = 0.15}

        btn.MouseEnter:Connect(function()
            btn:tween{BackgroundColor3 = isPrimary
                and Library:lighten(Library.CurrentTheme.Tertiary, 10)
                or Library:lighten(Library.CurrentTheme.Secondary, 30), Length = 0.1}
        end)
        btn.MouseLeave:Connect(function()
            btn:tween{BackgroundColor3 = isPrimary
                and Library.CurrentTheme.Tertiary
                or Library:lighten(Library.CurrentTheme.Secondary, 20), Length = 0.1}
        end)
        btn.MouseButton1Click:Connect(function()
            box:tween{BackgroundTransparency = 1, Length = 0.12}
            titleLabel:tween{TextTransparency = 1, Length = 0.12}
            msg:tween{TextTransparency = 1, Length = 0.12}
            for _, b in next, btnRefs do
                b:tween{BackgroundTransparency = 1, TextTransparency = 1, Length = 0.12}
            end
            darkener:tween({BackgroundTransparency = 1, Length = 0.12}, function()
                darkener.AbsoluteObject:Destroy()
                task.delay(0.2, function() Library._promptExists = false end)
                task.spawn(callback)
            end)
        end)
        order += 1
    end
end

-- =====================================================================
--                              CREDIT
-- =====================================================================

function Library:credit(options)
    options = self:set_defaults({
        Name = "Creditor",
        Description = nil
    }, options)
    options.V3rmillion = options.V3rmillion or options.V3rm

    local row, _, _ = buildRow(self.container, {
        Name = options.Name,
        Description = options.Description
    })

    local function smallButton(idx, color, tooltipTxt, callback, imageId)
        local btn = row:object("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, -14 - (idx - 1) * 32, 0.5, 0),
            BackgroundColor3 = color
        }):round(6):tooltip(tooltipTxt)

        btn:object("ImageLabel", {
            Image = imageId,
            Size = UDim2.new(1, -8, 1, -8),
            Centered = true,
            BackgroundTransparency = 1
        })

        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    if setclipboard then
        local idx = 1
        if options.Github then
            smallButton(idx, Library:lighten(Library.CurrentTheme.Secondary, 15), "copy github",
                function() setclipboard(options.Github) end,
                "http://www.roblox.com/asset/?id=11965755499")
            idx += 1
        end
        if options.Discord then
            smallButton(idx, Color3.fromRGB(88, 101, 242), "copy discord",
                function() setclipboard(options.Discord) end,
                "http://www.roblox.com/asset/?id=8594150191")
            idx += 1
        end
        if options.V3rmillion then
            smallButton(idx, Library:lighten(Library.CurrentTheme.Secondary, 15), "copy v3rm",
                function() setclipboard(options.V3rmillion) end,
                "http://www.roblox.com/asset/?id=8594086769")
            idx += 1
        end
    end
end

-- =====================================================================
--                         THEME SELECTOR
-- =====================================================================

function Library:_theme_selector()
    -- Curated display order — Dark is the flagship (first), then other
    -- premium dark themes, then accent variants, then Light, then legacy.
    local THEME_ORDER = {
        "Dark", "MacOS", "Midnight", "Forest", "Mocha", "TokyoNight",
        "Sunset", "Aqua", "RosePine", "Citrus", "Crimson",
        "Light",
        "Legacy", "Serika", "Rust",
    }

    local row = self.container:object("Frame", {
        Theme = { BackgroundColor3 = "Secondary" },
        BackgroundTransparency = 0.4,
        Size = UDim2.new(1, 0, 0, 164)
    }):round(8)

    row:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 0, 18),
        Text = "Theme",
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
        Theme = { TextColor3 = "StrongText" },
        TextXAlignment = Enum.TextXAlignment.Left
    })

    row:object("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 30),
        Size = UDim2.new(1, -28, 0, 14),
        Text = "Swipe to browse — tap a card to apply",
        TextSize = 12,
        Font = Enum.Font.Gotham,
        Theme = { TextColor3 = "WeakText" },
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local grid = row:object("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 54),
        Size = UDim2.new(1, -28, 0, 98),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ClipsDescendants = true        -- keep cards inside the Theme box
    })

    -- Inner padding gives the outer selection ring room to draw without
    -- bumping against the scroll frame's clip edge.
    grid:object("UIPadding", {
        PaddingLeft  = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop   = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4)
    })

    grid:object("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center
    })

    -- Track all cards so we can update the selected ring when the user picks one.
    local cards = {}

    -- Find the currently active theme by reference
    local function currentName()
        for name, t in next, Library.Themes do
            if t == Library.CurrentTheme then return name end
        end
        return "Dark"
    end
    local activeName = currentName()

    -- Build a card for one theme
    local function buildCard(themeName, layoutOrder)
        local themeColors = Library.Themes[themeName]
        if not (themeColors and themeColors.Main and themeColors.Tertiary) then return end

        -- Card has extra padding to leave room for the outer selection ring,
        -- so it never collides with the preview thumbnail itself.
        local card = grid:object("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(86, 96),
            LayoutOrder = layoutOrder,
            AutoButtonColor = false
        })

        -- ── Outer selection ring ────────────────────────────────────
        -- A dedicated frame whose stroke sits *outside* the preview, so
        -- it stays visible against dark themes (Citrus, Crimson, Midnight).
        -- We tween its size — when selected, it grows beyond the preview
        -- by 4px on each side, giving a glow halo effect.
        local ringFrame = card:object("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.fromOffset(78, 60),
            ZIndex = 1
        }):round(10)
        local ring = ringFrame:object("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 0,
            Color = Library.CurrentTheme.Tertiary,
            Transparency = 0
        })

        local preview = card:object("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 4),
            Size = UDim2.fromOffset(74, 56),
            BackgroundColor3 = themeColors.Main,
            ZIndex = 2
        }):round(8)

        -- Subtle constant border so unselected cards still have definition
        local border = preview:object("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 1,
            Color = Library:lighten(themeColors.Secondary, 20),
            Transparency = 0.5
        })

        local inner = preview:object("Frame", {
            Centered = true,
            Size = UDim2.new(1, -14, 1, -14),
            BackgroundColor3 = themeColors.Secondary,
            ZIndex = 3
        }):round(6)

        inner:object("UIListLayout", {
            Padding = UDim.new(0, 4),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            HorizontalAlignment = Enum.HorizontalAlignment.Center
        })
        inner:object("Frame", {
            Size = UDim2.new(0.7, 0, 0, 4),
            BackgroundColor3 = themeColors.Tertiary
        }):round(100)
        inner:object("Frame", {
            Size = UDim2.new(0.55, 0, 0, 4),
            BackgroundColor3 = themeColors.StrongText
        }):round(100)
        inner:object("Frame", {
            Size = UDim2.new(0.4, 0, 0, 4),
            BackgroundColor3 = themeColors.WeakText
        }):round(100)

        -- ── Checkmark badge in the top-right corner when selected ──
        -- This is the most reliable indicator on a dark card: a small
        -- coloured pill with a white tick. Sits on top of everything.
        local badge = card:object("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -2, 0, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = Library.CurrentTheme.Tertiary,
            BackgroundTransparency = 1,
            ZIndex = 5
        }):round(100)
        local badgeStroke = badge:object("UIStroke", {
            Thickness = 2,
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 1
        })
        local badgeText = badge:object("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "✓",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextTransparency = 1,
            ZIndex = 6
        })

        local label = card:object("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 66),
            Size = UDim2.new(1, 0, 0, 18),
            Text = themeName,
            TextSize = 11,
            Font = Enum.Font.GothamMedium,
            Theme = { TextColor3 = "StrongText" }
        })

        local function applySelected(isSel)
            if isSel then
                ring:tween{Thickness = 2, Length = 0.18}
                badge:tween{BackgroundTransparency = 0, Length = 0.15}
                badgeStroke:tween{Transparency = 0, Length = 0.15}
                badgeText:tween{TextTransparency = 0, Length = 0.15}
                label:tween{TextColor3 = Library.CurrentTheme.Tertiary, Length = 0.18}
            else
                ring:tween{Thickness = 0, Length = 0.18}
                badge:tween{BackgroundTransparency = 1, Length = 0.15}
                badgeStroke:tween{Transparency = 1, Length = 0.15}
                badgeText:tween{TextTransparency = 1, Length = 0.15}
                label:tween{TextColor3 = Library.CurrentTheme.StrongText, Length = 0.18}
            end
        end

        cards[themeName] = {
            card = card, ring = ring, label = label,
            preview = preview, badge = badge,
            applySelected = applySelected
        }

        -- Hover lift (desktop only)
        if not IsMobile then
            card.MouseEnter:Connect(function()
                if activeName ~= themeName then
                    border:tween{Transparency = 0.2, Length = 0.12}
                end
            end)
            card.MouseLeave:Connect(function()
                if activeName ~= themeName then
                    border:tween{Transparency = 0.5, Length = 0.12}
                end
            end)
        end

        card.MouseButton1Click:Connect(function()
            Library:change_theme(Library.Themes[themeName])
            updateSettings("Theme", themeName)
            activeName = themeName
            -- Re-tint and re-apply visuals to every card so old selection
            -- clears and new one lights up.
            for n, refs in next, cards do
                refs.ring.Color  = Library.CurrentTheme.Tertiary
                refs.badge.BackgroundColor3 = Library.CurrentTheme.Tertiary
                refs.applySelected(n == themeName)
            end
        end)
    end

    -- Build in curated order; pick up anything else at the end.
    local seen = {}
    for i, name in ipairs(THEME_ORDER) do
        buildCard(name, i)
        seen[name] = true
    end
    local extraOrder = 100
    for name in next, Library.Themes do
        if not seen[name] then
            buildCard(name, extraOrder)
            extraOrder += 1
        end
    end

    -- Apply initial selection visuals
    if cards[activeName] and cards[activeName].applySelected then
        cards[activeName].applySelected(true)
    end

    -- Re-tint rings/badges when the theme changes from elsewhere
    table.insert(Library._themeUpdaters, function(theme)
        for n, refs in next, cards do
            refs.ring.Color = theme.Tertiary
            refs.badge.BackgroundColor3 = theme.Tertiary
            if n == activeName then
                refs.label:tween{TextColor3 = theme.Tertiary, Length = 0.15}
            else
                refs.label:tween{TextColor3 = theme.StrongText, Length = 0.15}
            end
        end
    end)
end

-- =====================================================================
--                          COLOR PICKER
--   Single, modern macOS-style picker (legacy/modern variants
--   collapsed into one clean implementation — Style option preserved
--   for API compatibility).
-- =====================================================================

function Library:color_picker(options)
    options = self:set_defaults({
        Name        = "Color Picker",
        Description = nil,
        Style       = Library.ColorPickerStyles.Modern,
        Default     = Color3.fromRGB(255, 80, 100),
        Followup    = false,
        Callback    = function() end
    }, options)

    local row = buildRow(self.container, options)

    -- Color swatch on the right
    local swatch = row:object("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(28, 24),
        BackgroundColor3 = options.Default
    }):round(6):stroke({"Secondary", 25}, 1)

    local selectedColor = options.Default

    row.MouseButton1Click:Connect(function()
        if Library._colorPickerExists then return end
        Library._colorPickerExists = true

        local hue, sat, val = Color3.toHSV(selectedColor)

        local darkener = self.core:object("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Active = true,
            ZIndex = 30
        }):round(10)

        local pickerW = IsMobile and 280 or 260
        local pickerH = IsMobile and 220 or 200

        local holder = darkener:object("Frame", {
            Centered = true,
            Theme = { BackgroundColor3 = "Secondary" },
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(pickerW, pickerH),
            ZIndex = 31
        }):round(10):stroke({"Secondary", 25}, 1)

        holder:object("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12)
        })

        local titleLbl = holder:object("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = options.Name,
            Theme = { TextColor3 = "StrongText" },
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 1,
            ZIndex = 32
        })

        -- SV picker area
        local svArea = holder:object("TextButton", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 26),
            Size = UDim2.new(1, -28, 1, -76),
            BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
            ZIndex = 32,
            ClipsDescendants = true
        }):round(6):stroke({"Secondary", 25}, 1)

        svArea:object("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
            },
            Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0)
            },
            Rotation = 180
        })

        local svBlack = svArea:object("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex = 33
        })
        svBlack:object("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
            },
            Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0)
            },
            Rotation = 90
        })

        local svCursor = svArea:object("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(sat, 1 - val),
            Size = UDim2.fromOffset(10, 10),
            BackgroundTransparency = 1,
            ZIndex = 34
        }):round(100)
        local svCursorStroke = svCursor:object("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Thickness = 2,
            Transparency = 1
        })

        -- Hue bar
        local hueBar = holder:object("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 26),
            Size = UDim2.new(0, 18, 1, -76),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            ZIndex = 32,
            ClipsDescendants = true
        }):round(6):stroke({"Secondary", 25}, 1)

        hueBar:object("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
            },
            Rotation = 90
        })

        local hueCursor = hueBar:object("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, hue, 0),
            Size = UDim2.new(1, 4, 0, 4),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            ZIndex = 34
        }):round(100)

        -- Confirm row
        local previewBox = holder:object("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.fromOffset(80, 30),
            BackgroundColor3 = selectedColor,
            BackgroundTransparency = 1,
            ZIndex = 32
        }):round(6):stroke({"Secondary", 25}, 1)

        local confirmBtn = holder:object("TextButton", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, 0, 1, 0),
            Size = UDim2.fromOffset(80, 30),
            Theme = { BackgroundColor3 = "Tertiary", TextColor3 = "StrongText" },
            Text = "Confirm",
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            BackgroundTransparency = 1,
            TextTransparency = 1,
            ZIndex = 32
        }):round(6)

        local function updateColor()
            selectedColor = Color3.fromHSV(hue, sat, val)
            svArea:tween{BackgroundColor3 = Color3.fromHSV(hue, 1, 1), Length = 0.05}
            svCursor:tween{Position = UDim2.fromScale(sat, 1 - val), Length = 0.05}
            hueCursor:tween{Position = UDim2.new(0.5, 0, hue, 0), Length = 0.05}
            previewBox:tween{BackgroundColor3 = selectedColor, Length = 0.05}
        end

        -- Drag SV
        do
            local dragging = false
            local function update(input)
                local rx = math.clamp((input.Position.X - svArea.AbsolutePosition.X) / svArea.AbsoluteSize.X, 0, 1)
                local ry = math.clamp((input.Position.Y - svArea.AbsolutePosition.Y) / svArea.AbsoluteSize.Y, 0, 1)
                sat = rx; val = 1 - ry
                updateColor()
            end
            svArea.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    sinkCameraInput()
                    update(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    if dragging then
                        dragging = false
                        releaseCameraInput()
                    end
                end
            end)
        end

        -- Drag Hue
        do
            local dragging = false
            local function update(input)
                local r = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                hue = r
                updateColor()
            end
            hueBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    sinkCameraInput()
                    update(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    if dragging then
                        dragging = false
                        releaseCameraInput()
                    end
                end
            end)
        end

        -- Fade in
        darkener:tween{BackgroundTransparency = 0.5, Length = 0.15}
        holder:tween{BackgroundTransparency = 0, Length = 0.15}
        titleLbl:tween{TextTransparency = 0, Length = 0.15}
        svArea:tween{BackgroundTransparency = 0, Length = 0.15}
        svBlack:tween{BackgroundTransparency = 0, Length = 0.15}
        svCursorStroke:tween{Transparency = 0, Length = 0.15}
        hueBar:tween{BackgroundTransparency = 0, Length = 0.15}
        hueCursor:tween{BackgroundTransparency = 0, Length = 0.15}
        previewBox:tween{BackgroundTransparency = 0, Length = 0.15}
        confirmBtn:tween{BackgroundTransparency = 0, TextTransparency = 0, Length = 0.15}

        confirmBtn.MouseEnter:Connect(function()
            confirmBtn:tween{BackgroundColor3 = Library:lighten(Library.CurrentTheme.Tertiary, 10), Length = 0.1}
        end)
        confirmBtn.MouseLeave:Connect(function()
            confirmBtn:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary, Length = 0.1}
        end)
        confirmBtn.MouseButton1Click:Connect(function()
            swatch:tween{BackgroundColor3 = selectedColor, Length = 0.12}
            task.spawn(options.Callback, selectedColor)
            darkener:tween({BackgroundTransparency = 1, Length = 0.12}, function()
                darkener.AbsoluteObject:Destroy()
                task.delay(0.2, function() Library._colorPickerExists = false end)
            end)
        end)
    end)

    local methods = {}
    function methods:Set(color)
        selectedColor = color
        swatch:tween{BackgroundColor3 = color, Length = 0.1}
    end
    function methods:Get() return selectedColor end

    return methods
end

function Library:cp(options)          return Library.color_picker(self, options) end
function Library:colorpicker(options) return Library.color_picker(self, options) end

-- =====================================================================
--                        FINAL METATABLE
--   Allow case-insensitive method lookup (preserved from original).
-- =====================================================================

return setmetatable(Library, {
    __index = function(_, i)
        return rawget(Library, i:lower())
    end
})
