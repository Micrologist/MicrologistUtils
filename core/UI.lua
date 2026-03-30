local MU = MicrologistUtils

-- ── Physical pixel counts (integers) ──────────────────────────────────────────
local PX = {
    FRAME_W     = 486,
    TITLE_H     = 43,
    ROW_H       = 88,
    PAD         = 18,
    TOGGLE_W    = 53,
    TOGGLE_H    = 23,
    KNOB_OFF    = 2,
    FONT_NORMAL = 25,
    FONT_SMALL  = 23,
    FONT_TINY   = 18,
    FONT_CLOSE  = 25,
    SLIDER_W    = 50,
}
PX.KNOB   = PX.TOGGLE_H - 4
PX.TEXT_W = PX.FRAME_W - 2 - PX.PAD - PX.TOGGLE_W - PX.PAD - 8

-- ── Virtual-unit equivalents (recomputed by InitSizes on every build) ──────────
local pixel
local FRAME_W, TITLE_H, ROW_H, PAD
local TOGGLE_W, TOGGLE_H, KNOB_SIZE, KNOB_OFF, TEXT_W
local SLIDER_W
local FONT_NORMAL_SZ, FONT_SMALL_SZ, FONT_TINY_SZ, FONT_CLOSE_SZ
local FONT_FACE  = "Interface\\AddOns\\MicrologistUtils\\media\\EXPRESSWAYRG.TTF"
local FONT_FLAGS

-- Shared backdrop table; edgeSize and insets are patched in InitSizes
local BD = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function InitSizes()
    -- pixel = UIParent virtual units per physical screen pixel.
    --
    -- UIParent:GetHeight() already reflects both screen resolution AND the game's
    -- UIScale setting (it equals the WoW base height 768 divided by UIScale, scaled
    -- up/down for the physical resolution).  Dividing by GetPhysicalScreenSize()
    -- converts that virtual height into a per-pixel factor.  No further division by
    -- GetEffectiveScale() is needed — doing so would double-count UIScale and make
    -- the frame grow as UIScale decreases.
    local physH = select(2, GetPhysicalScreenSize())
    pixel = UIParent:GetHeight() / physH

    FRAME_W        = PX.FRAME_W     * pixel
    TITLE_H        = PX.TITLE_H     * pixel
    ROW_H          = PX.ROW_H       * pixel
    PAD            = PX.PAD         * pixel
    TOGGLE_W       = PX.TOGGLE_W    * pixel
    TOGGLE_H       = PX.TOGGLE_H    * pixel
    KNOB_SIZE      = PX.KNOB        * pixel
    KNOB_OFF       = PX.KNOB_OFF    * pixel
    TEXT_W         = PX.TEXT_W      * pixel
    SLIDER_W       = PX.SLIDER_W    * pixel
    FONT_NORMAL_SZ = PX.FONT_NORMAL * pixel
    FONT_SMALL_SZ  = PX.FONT_SMALL  * pixel
    FONT_TINY_SZ   = PX.FONT_TINY   * pixel
    FONT_CLOSE_SZ  = PX.FONT_CLOSE  * pixel
    _, FONT_FLAGS  = GameFontNormal:GetFont()
    BD.edgeSize      = pixel
    BD.insets.left   = pixel
    BD.insets.right  = pixel
    BD.insets.top    = pixel
    BD.insets.bottom = pixel
end

-- ── Color palette (ElvUI-ish dark) ────────────────────────────────────────────
local C = {
    bg              = { 0.09, 0.09, 0.09, 0.97 },
    border          = { 0.22, 0.22, 0.22, 1    },
    titleBg         = { 0.13, 0.13, 0.13, 1    },
    titleBorder     = { 0.28, 0.28, 0.28, 1    },
    accent          = { 85/255, 153/255, 204/255, 1 },
    separator       = { 0.19, 0.19, 0.19, 1    },
    textPrim        = { 0.92, 0.92, 0.92, 1    },
    textSec         = { 0.48, 0.48, 0.48, 1    },
    toggleOn        = { 0.18, 0.55, 0.18, 1    },
    toggleOnBorder  = { 0.28, 0.72, 0.28, 1    },
    toggleOff       = { 0.14, 0.14, 0.14, 1    },
    toggleOffBorder = { 0.26, 0.26, 0.26, 1    },
    knob            = { 0.66, 0.66, 0.66, 1    },
    closeNorm       = { 0.60, 0.60, 0.60, 1    },
    closeHover      = { 1.00, 0.28, 0.28, 1    },
    sliderTrack     = { 0.18, 0.18, 0.18, 1    },
    sliderBorder    = { 0.26, 0.26, 0.26, 1    },
}

local function ApplyBD(f, bg, border)
    f:SetBackdrop(BD)
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(border))
end

-- ── Sliding toggle ────────────────────────────────────────────────────────────
local function CreateToggle(parent, key)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(TOGGLE_W, TOGGLE_H)
    ApplyBD(btn, C.toggleOff, C.toggleOffBorder)

    local knob = btn:CreateTexture(nil, "OVERLAY")
    knob:SetColorTexture(unpack(C.knob))
    knob:SetSize(KNOB_SIZE, KNOB_SIZE)

    local function Refresh()
        local on = MU.db and MU.db[key]
        knob:ClearAllPoints()
        if on then
            ApplyBD(btn, C.toggleOn, C.toggleOnBorder)
            knob:SetPoint("RIGHT", btn, "RIGHT", -KNOB_OFF, 0)
        else
            ApplyBD(btn, C.toggleOff, C.toggleOffBorder)
            knob:SetPoint("LEFT", btn, "LEFT", KNOB_OFF, 0)
        end
    end

    btn:SetScript("OnClick", function()
        if MU.db then MU.db[key] = not MU.db[key] end
        Refresh()
    end)

    btn.Refresh = Refresh
    Refresh()
    return btn
end

-- ── Main frame ────────────────────────────────────────────────────────────────
local settingsFrame
-- Saved drag position (UIParent virtual coords); persisted across rebuilds
local savedAnchor
-- UISpecialFrames entry is registered once and stays valid because the frame
-- always uses the same global name "MicrologistUtilsFrame"
local specialFrameRegistered = false

local function BuildFrame()
    InitSizes()

    local n      = #MU.moduleOrder
    local totalH = TITLE_H + n * ROW_H + PAD

    local f = CreateFrame("Frame", "MicrologistUtilsFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, totalH)
    if savedAnchor then
        f:SetPoint(savedAnchor.point, UIParent, savedAnchor.relPoint,
                   savedAnchor.x, savedAnchor.y)
    else
        f:SetPoint("CENTER")
    end
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        savedAnchor = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    ApplyBD(f, C.bg, C.border)

    -- User-chosen visual scale multiplier (0.5 – 2.0, default 1)
    -- Applied on top of the pixel-perfect base; does not affect PX calculations.
    local userScale = (MU.db and MU.db.UIScale) or 1
    f:SetScale(userScale)

    f:Hide()

    if not specialFrameRegistered then
        tinsert(UISpecialFrames, "MicrologistUtilsFrame")
        specialFrameRegistered = true
    end

    -- ── Title bar ─────────────────────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  pixel, -pixel)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pixel, -pixel)
    titleBar:SetHeight(TITLE_H - 2 * pixel)
    ApplyBD(titleBar, C.titleBg, C.titleBorder)

    -- Close button (anchored first so slider can reference it)
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(TITLE_H - 2 * pixel, TITLE_H - 2 * pixel)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY")
    closeLabel:SetFont(FONT_FACE, FONT_CLOSE_SZ, FONT_FLAGS)
    closeLabel:SetAllPoints()
    closeLabel:SetText("×")
    closeLabel:SetTextColor(unpack(C.closeNorm))
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(C.closeHover)) end)
    closeBtn:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(C.closeNorm)) end)

    -- Scale slider
    local sliderFrame = CreateFrame("Slider", "MicrologistUtilsScaleSlider", titleBar)
    sliderFrame:SetOrientation("HORIZONTAL")
    sliderFrame:SetSize(SLIDER_W, TITLE_H - 2 * pixel)
    sliderFrame:SetPoint("RIGHT", closeBtn, "LEFT", 0, 0)
    sliderFrame:SetMinMaxValues(0.5, 2.0)
    sliderFrame:SetValueStep(0.05)
    if sliderFrame.SetObeyStepOnDrag then
        sliderFrame:SetObeyStepOnDrag(true)
    end

    -- Track
    local track = sliderFrame:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(unpack(C.sliderTrack))
    track:SetHeight(3 * pixel)
    track:SetPoint("LEFT",  sliderFrame, "LEFT",  0, 0)
    track:SetPoint("RIGHT", sliderFrame, "RIGHT", 0, 0)

    -- 1px border around the track
    local trackBorder = sliderFrame:CreateTexture(nil, "BACKGROUND")
    trackBorder:SetColorTexture(unpack(C.sliderBorder))
    trackBorder:SetHeight(6 * pixel)
    trackBorder:SetPoint("LEFT",  sliderFrame, "LEFT",  0, 0)
    trackBorder:SetPoint("RIGHT", sliderFrame, "RIGHT", 0, 0)
    trackBorder:SetDrawLayer("BACKGROUND", -1)

    -- Thumb
    local thumb = sliderFrame:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(unpack(C.knob))
    thumb:SetSize(2 * pixel, 7 * pixel)
    sliderFrame:SetThumbTexture(thumb)

    sliderFrame:SetValue(userScale)

    local function SliderTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(math.floor(self:GetValue() * 100 + 0.5) .. "%", 1, 1, 1)
        GameTooltip:Show()
    end
    sliderFrame:SetScript("OnValueChanged", function(self, value)
        if MU.db then MU.db.UIScale = value end
        if GameTooltip:GetOwner() == self then SliderTooltip(self) end
    end)
    sliderFrame:SetScript("OnMouseUp", function(self)
        f:SetScale(self:GetValue())
    end)
    sliderFrame:SetScript("OnEnter", SliderTooltip)
    sliderFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT_FACE, FONT_NORMAL_SZ, FONT_FLAGS)
    titleText:SetPoint("LEFT", titleBar, "LEFT", PAD, 0)
    titleText:SetText("MicrologistUtils")
    titleText:SetTextColor(unpack(C.accent))

    -- Version text — baseline-aligned with title text
    local versionText = titleBar:CreateFontString(nil, "OVERLAY")
    versionText:SetFont(FONT_FACE, FONT_SMALL_SZ, FONT_FLAGS)
    versionText:SetPoint("BOTTOMLEFT", titleText, "BOTTOMRIGHT", 4 * pixel, 0)
    versionText:SetText("v" .. (MU.version or "?"))
    versionText:SetTextColor(0.25, 0.25, 0.25, 1)

    -- ── Module rows ───────────────────────────────────────────────────────────
    f.toggles = {}
    local yOffset = -TITLE_H

    for i, key in ipairs(MU.moduleOrder) do
        local meta   = MU.moduleMeta[key] or {}
        local dimmed = meta.noToggle or (meta.available and not meta.available())

        local row = CreateFrame("Frame", nil, f)
        row:SetSize(FRAME_W - 2 * pixel, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", pixel, yOffset)

        if i > 1 then
            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetColorTexture(unpack(C.separator))
            sep:SetSize(FRAME_W - 2 * pixel - PAD * 2, pixel)
            sep:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, -4 * pixel)
        end

        local nameFS = row:CreateFontString(nil, "OVERLAY")
        nameFS:SetFont(FONT_FACE, FONT_SMALL_SZ, FONT_FLAGS)
        nameFS:SetPoint("LEFT", row, "LEFT", PAD, FONT_SMALL_SZ * 0.5)
        nameFS:SetWidth(TEXT_W)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetText(meta.displayName or key)
        if dimmed then
            nameFS:SetTextColor(unpack(C.textSec))
        else
            nameFS:SetTextColor(unpack(C.textPrim))
        end

        local desc = meta.description or ""
        if desc ~= "" then
            local descFS = row:CreateFontString(nil, "OVERLAY")
            descFS:SetFont(FONT_FACE, FONT_TINY_SZ, FONT_FLAGS)
            descFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -2 * pixel)
            descFS:SetWidth(TEXT_W)
            descFS:SetJustifyH("LEFT")
            descFS:SetText(desc)
            descFS:SetTextColor(unpack(C.textSec))
        end

        if not dimmed then
            local toggle = CreateToggle(row, key)
            toggle:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
            f.toggles[key] = toggle
        end

        yOffset = yOffset - ROW_H
    end

    return f
end

-- ── Adapt to resolution / UIScale changes ─────────────────────────────────────
-- When either changes, pixel changes — rebuild the frame so all sizes and font
-- heights are recalculated.  The saved anchor keeps it in the same screen region.
local function OnDisplayChanged()
    if not settingsFrame then return end

    -- Capture position before destroying
    local point, _, relPoint, x, y = settingsFrame:GetPoint(1)
    savedAnchor = { point = point, relPoint = relPoint, x = x, y = y }

    local wasShown = settingsFrame:IsShown()
    settingsFrame:Hide()
    settingsFrame = nil   -- release old frame to GC

    settingsFrame = BuildFrame()
    for _, toggle in pairs(settingsFrame.toggles) do
        toggle.Refresh()
    end
    if wasShown then settingsFrame:Show() end
end

local displayEventFrame = CreateFrame("Frame")
displayEventFrame:RegisterEvent("UI_SCALE_CHANGED")
displayEventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
displayEventFrame:SetScript("OnEvent", function() OnDisplayChanged() end)

-- ── Subcommands ───────────────────────────────────────────────────────────────
local subcommands = {}
MU.subcommands = subcommands   -- exposed so modules can self-register subcommands

subcommands["arc"] = function()
    if not MU.db then return end
    MU.db.AutoRoleCheck = not MU.db.AutoRoleCheck
    local state = MU.db.AutoRoleCheck and "Enabled" or "Disabled"
    print("|cff5599cc[MicrologistUtils]|r Automatic Role Checks " .. state)
    if settingsFrame and settingsFrame.toggles.AutoRoleCheck then
        settingsFrame.toggles.AutoRoleCheck.Refresh()
    end
end

-- ── Slash command  /mu  ───────────────────────────────────────────────────────
SLASH_MU1 = "/mu"
SlashCmdList["MU"] = function(msg)
    local cmd = msg and msg:match("^%s*(%S+)") and msg:match("^%s*(%S+)"):lower()
    if cmd and subcommands[cmd] then
        subcommands[cmd]()
        return
    end

    if not settingsFrame then
        settingsFrame = BuildFrame()
    end

    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        for _, toggle in pairs(settingsFrame.toggles) do
            toggle.Refresh()
        end
        settingsFrame:Show()
    end
end
