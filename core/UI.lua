local MU = MicrologistUtils

-- ── Physical pixel counts (integers, UI-scale-independent) ───────────────────
local PX = {
    FRAME_W     = 280,
    TITLE_H     = 24,
    ROW_H       = 56,
    PAD         = 10,
    TOGGLE_W    = 34,
    TOGGLE_H    = 14,
    KNOB_OFF    = 3,   -- knob inset from toggle edge
    FONT_NORMAL = 12,
    FONT_SMALL  = 10,
    FONT_CLOSE  = 14,
}
PX.KNOB   = PX.TOGGLE_H - 4
PX.TEXT_W = PX.FRAME_W - 2 - PX.PAD - PX.TOGGLE_W - PX.PAD - 8

-- ── Virtual-unit equivalents (set by InitSizes before any frame is built) ─────
local pixel                                -- 1 physical px in virtual units
local FRAME_W, TITLE_H, ROW_H, PAD
local TOGGLE_W, TOGGLE_H, KNOB_SIZE, KNOB_OFF, TEXT_W
local FONT_NORMAL_SZ, FONT_SMALL_SZ, FONT_CLOSE_SZ
local FONT_FACE, FONT_FLAGS

-- Shared backdrop table; edgeSize and insets are patched in InitSizes
local BD = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function InitSizes()
    pixel          = 1 / UIParent:GetEffectiveScale()
    FRAME_W        = PX.FRAME_W  * pixel
    TITLE_H        = PX.TITLE_H  * pixel
    ROW_H          = PX.ROW_H    * pixel
    PAD            = PX.PAD      * pixel
    TOGGLE_W       = PX.TOGGLE_W * pixel
    TOGGLE_H       = PX.TOGGLE_H * pixel
    KNOB_SIZE      = PX.KNOB     * pixel
    KNOB_OFF       = PX.KNOB_OFF * pixel
    TEXT_W         = PX.TEXT_W   * pixel
    -- Font sizes: desired physical px * pixel converts to virtual units that
    -- render at exactly that many screen pixels regardless of UI scale
    FONT_NORMAL_SZ = PX.FONT_NORMAL * pixel
    FONT_SMALL_SZ  = PX.FONT_SMALL  * pixel
    FONT_CLOSE_SZ  = PX.FONT_CLOSE  * pixel
    -- Borrow the font face and flags from Blizzard; only override the size
    FONT_FACE, _, FONT_FLAGS = GameFontNormal:GetFont()
    -- 1px border and insets
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
    separator       = { 0.19, 0.19, 0.19, 1    },
    textPrim        = { 0.92, 0.92, 0.92, 1    },
    textSec         = { 0.48, 0.48, 0.48, 1    },
    toggleOn        = { 0.18, 0.55, 0.18, 1    },
    toggleOnBorder  = { 0.28, 0.72, 0.28, 1    },
    toggleOff       = { 0.14, 0.14, 0.14, 1    },
    toggleOffBorder = { 0.26, 0.26, 0.26, 1    },
    knob            = { 0.88, 0.88, 0.88, 1    },
    closeNorm       = { 0.60, 0.60, 0.60, 1    },
    closeHover      = { 1.00, 0.28, 0.28, 1    },
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

local function BuildFrame()
    InitSizes()

    local n      = #MU.moduleOrder
    local totalH = TITLE_H + PAD / 2 + n * ROW_H + PAD

    local f = CreateFrame("Frame", "MicrologistUtilsFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, totalH)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    ApplyBD(f, C.bg, C.border)
    f:Hide()

    tinsert(UISpecialFrames, "MicrologistUtilsFrame")

    -- ── Title bar ────────────────────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",   pixel, -pixel)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT",  -pixel, -pixel)
    titleBar:SetHeight(TITLE_H - 2 * pixel)
    ApplyBD(titleBar, C.titleBg, C.titleBorder)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT_FACE, FONT_NORMAL_SZ, FONT_FLAGS)
    titleText:SetPoint("LEFT", titleBar, "LEFT", PAD, 0)
    titleText:SetText("MicrologistUtils")
    titleText:SetTextColor(unpack(C.textPrim))

    local versionText = titleBar:CreateFontString(nil, "OVERLAY")
    versionText:SetFont(FONT_FACE, FONT_SMALL_SZ, FONT_FLAGS)
    versionText:SetPoint("LEFT", titleText, "RIGHT", 6 * pixel, 0)
    versionText:SetText("v" .. (MU.version or "?"))
    versionText:SetTextColor(0.45, 0.45, 0.45, 1)

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

    -- ── Module rows ───────────────────────────────────────────────────────────
    f.toggles = {}
    local yOffset = -(TITLE_H + PAD / 2)

    for i, key in ipairs(MU.moduleOrder) do
        local meta = MU.moduleMeta[key] or {}

        local row = CreateFrame("Frame", nil, f)
        row:SetSize(FRAME_W - 2 * pixel, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", pixel, yOffset)

        if i > 1 then
            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetColorTexture(unpack(C.separator))
            sep:SetSize(FRAME_W - 2 * pixel - PAD * 2, pixel)
            sep:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, 0)
        end

        local nameFS = row:CreateFontString(nil, "OVERLAY")
        nameFS:SetFont(FONT_FACE, FONT_NORMAL_SZ, FONT_FLAGS)
        nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, -10 * pixel)
        nameFS:SetWidth(TEXT_W)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetText(meta.displayName or key)
        nameFS:SetTextColor(unpack(C.textPrim))

        local desc = meta.description or ""
        if desc ~= "" then
            local descFS = row:CreateFontString(nil, "OVERLAY")
            descFS:SetFont(FONT_FACE, FONT_SMALL_SZ, FONT_FLAGS)
            descFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -3 * pixel)
            descFS:SetWidth(TEXT_W)
            descFS:SetJustifyH("LEFT")
            descFS:SetText(desc)
            descFS:SetTextColor(unpack(C.textSec))
        end

        local toggle = CreateToggle(row, key)
        toggle:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
        f.toggles[key] = toggle

        yOffset = yOffset - ROW_H
    end

    return f
end

-- ── Slash command  /mu  ───────────────────────────────────────────────────────
SLASH_MU1 = "/mu"
SlashCmdList["MU"] = function()
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
