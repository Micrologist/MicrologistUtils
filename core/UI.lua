local MU = MicrologistUtils

-- ── Layout constants ──────────────────────────────────────────────────────────
local FRAME_W   = 280
local TITLE_H   = 24
local ROW_H     = 48
local PAD       = 10
local TOGGLE_W  = 34
local TOGGLE_H  = 14
local KNOB_SIZE = TOGGLE_H - 4

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

-- ── Backdrop (WHITE8X8 gives a solid fill + hard 1px edge) ───────────────────
local BD = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function ApplyBD(f, bg, border)
    f:SetBackdrop(BD)
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(border))
end

-- ── Toggle widget ─────────────────────────────────────────────────────────────
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
            knob:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
        else
            ApplyBD(btn, C.toggleOff, C.toggleOffBorder)
            knob:SetPoint("LEFT", btn, "LEFT", 3, 0)
        end
    end

    btn:SetScript("OnClick", function()
        if MU.db then
            MU.db[key] = not MU.db[key]
        end
        Refresh()
    end)

    btn.Refresh = Refresh
    Refresh()
    return btn
end

-- ── Main frame ────────────────────────────────────────────────────────────────
local settingsFrame

local function BuildFrame()
    local n      = #MU.moduleOrder
    local totalH = TITLE_H + PAD + (n * ROW_H) + PAD

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

    -- Allow ESC to close
    tinsert(UISpecialFrames, "MicrologistUtilsFrame")

    -- ── Title bar ────────────────────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(TITLE_H - 2)
    ApplyBD(titleBar, C.titleBg, C.titleBorder)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", PAD, 0)
    titleText:SetText("MicrologistUtils")
    titleText:SetTextColor(unpack(C.textPrim))

    -- Close button (×)
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(TITLE_H - 2, TITLE_H - 2)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeLabel:SetAllPoints()
    closeLabel:SetText("×")
    closeLabel:SetTextColor(unpack(C.closeNorm))
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(C.closeHover)) end)
    closeBtn:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(C.closeNorm)) end)

    -- ── Module rows ───────────────────────────────────────────────────────────
    f.toggles = {}

    for i, key in ipairs(MU.moduleOrder) do
        local meta = MU.moduleMeta[key] or {}

        local row = CreateFrame("Frame", nil, f)
        row:SetSize(FRAME_W - 2, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(TITLE_H + PAD + (i - 1) * ROW_H))

        -- Separator above every row except the first
        if i > 1 then
            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetColorTexture(unpack(C.separator))
            sep:SetSize(FRAME_W - 2 - PAD * 2, 1)
            sep:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, 0)
        end

        -- Module name
        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, -10)
        nameFS:SetText(meta.displayName or key)
        nameFS:SetTextColor(unpack(C.textPrim))

        -- Description (optional)
        local desc = meta.description or ""
        if desc ~= "" then
            local descFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            descFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -3)
            descFS:SetText(desc)
            descFS:SetTextColor(unpack(C.textSec))
        end

        -- Toggle (vertically centered in row)
        local toggle = CreateToggle(row, key)
        toggle:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)

        f.toggles[key] = toggle
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
        -- Sync toggle visuals with current db state before showing
        for key, toggle in pairs(settingsFrame.toggles) do
            toggle.Refresh()
        end
        settingsFrame:Show()
    end
end
