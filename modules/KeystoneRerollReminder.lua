local MU = MicrologistUtils

local module = {}
MU:RegisterModule("KeystoneRerollReminder", module, {
    displayName = "Keystone Reroll Reminder",
    description = "Show a reminder whenever a keystone reroll is available after a mythic+ run",
})

function module:Init()
    local FONT = "Interface\\AddOns\\MicrologistUtils\\media\\EXPRESSWAYRG.TTF"
    local KEYSTONE_ITEM_ID = 180653

    local reminder = nil -- built lazily on first show
    local active = false

    -- ── Helpers ────────────────────────────────────────────────────────────────
    
    local function GetOwnedKeystoneState()
        return C_MythicPlus.GetOwnedKeystoneChallengeMapID(), C_MythicPlus.GetOwnedKeystoneLevel()
    end

    -- Scans all regular bag slots for the Mythic Keystone (item 180653).
    -- Returns bag, slot  or  nil, nil if not found.
    local function FindKeystoneInBags()
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and C_Item.IsItemKeystoneByID(info.itemID) then
                    return bag, slot
                end
            end
        end
        return nil, nil
    end

    -- ── Dismiss ────────────────────────────────────────────────────────────────
    local function HideReminder(reason)
        MU.Debug("KeystoneRerollReminder: hide —", reason or "unknown reason")
        if reminder then reminder:Hide() end
        active = false
    end

    -- ── Build frame ────────────────────────────────────────────────────────────
    local function BuildReminder()
        -- Derive pixel size the same way UI.lua does so the notification is the
        -- same physical pixel count on every resolution / UIScale combination.
        local physH = select(2, GetPhysicalScreenSize())
        local px = UIParent:GetHeight() / physH

        local W        = math.floor(380 * px + 0.5)
        local H        = math.floor(86  * px + 0.5)
        local iconSz   = math.floor(56  * px + 0.5)
        local pad      = math.floor(10  * px + 0.5)
        local fontSz   = 22 * px
        local fontSzSub = 22 * px

        local f = CreateFrame("Frame", "MUKeystoneReminderFrame", UIParent, "BackdropTemplate")
        f:SetSize(W, H)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, math.floor(325 * px + 0.5))
        f:SetFrameStrata("HIGH")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop",  f.StopMovingOrSizing)
        f:SetScript("OnMouseDown", function(_, button)
            if button == "RightButton" then HideReminder("right-clicked") end
        end)

        -- Stash sizing for use in ShowReminder's auto-width calculation
        f._px     = px
        f._pad    = pad
        f._iconSz = iconSz

        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = px,
            insets = { left = px, right = px, top = px, bottom = px },
        })
        f:SetBackdropColor(0.09, 0.09, 0.09, 0.97)
        f:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)  -- C.border

        -- Keystone icon (Texture — cannot receive mouse events directly)
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSz, iconSz)
        icon:SetPoint("LEFT", f, "LEFT", pad, 0)

        local atlasOK = C_Texture and C_Texture.GetAtlasInfo
            and C_Texture.GetAtlasInfo("ChallengesMode-Keystone")
        if atlasOK then
            icon:SetAtlas("ChallengesMode-Keystone")
        else
            local itemTex = select(10, GetItemInfo(KEYSTONE_ITEM_ID))
            icon:SetTexture(itemTex or "Interface\\Icons\\Inv_Misc_Key_15")
        end

        -- 1px epic-quality border around the icon
        local iconBorder = CreateFrame("Frame", nil, f, "BackdropTemplate")
        iconBorder:SetSize(iconSz + 2 * px, iconSz + 2 * px)
        iconBorder:SetPoint("LEFT", f, "LEFT", pad - px, 0)
        iconBorder:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = px,
            insets   = { left = px, right = px, top = px, bottom = px },
        })
        iconBorder:SetBackdropBorderColor(163/255, 53/255, 238/255, 1)  -- epic purple

        -- Invisible frame over the icon to intercept mouse for the tooltip.
        -- Textures have no mouse handling, so we overlay a transparent Frame.
        local iconHit = CreateFrame("Frame", nil, f)
        iconHit:SetSize(iconSz, iconSz)
        iconHit:SetPoint("LEFT", f, "LEFT", pad, 0)
        iconHit:EnableMouse(true)
        iconHit:SetScript("OnEnter", function(self)
            local bag, slot = FindKeystoneInBags()
            if bag then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(bag, slot)
                GameTooltip:Show()
            end
        end)
        iconHit:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- "Reroll Keystone?"
        local label = f:CreateFontString(nil, "OVERLAY")
        label:SetFont(FONT, fontSz, "OUTLINE")
        label:SetTextColor(1, 0.82, 0.1, 1)  -- gold
        label:SetText("Reroll Keystone?")
        label:SetPoint("BOTTOMLEFT", icon, "RIGHT", pad, math.floor(3 * px + 0.5))
        label:SetJustifyH("LEFT")
        f.label = label

        -- Dungeon name + level
        local sub = f:CreateFontString(nil, "OVERLAY")
        sub:SetFont(FONT, fontSzSub, "OUTLINE")
        sub:SetTextColor(0.48, 0.48, 0.48, 1)
        sub:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -math.floor(4 * px + 0.5))
        sub:SetJustifyH("LEFT")
        f.subtitle = sub

        f:Hide()
        return f
    end

    -- ── Show ───────────────────────────────────────────────────────────────────
    local function ShowReminder(ownedMapID, ownedLevel)
        if not (MU.db and MU.db.KeystoneRerollReminder) then
            MU.Debug("KeystoneRerollReminder: ShowReminder suppressed (module disabled)")
            return
        end
        if not reminder then
            reminder = BuildReminder()
        end

        -- Resolve dungeon name from the challenge map ID.
        -- GetMapUIInfo returns: name, id, timeLimit, texture, backgroundTexture
        local dungeonName = (ownedMapID and C_ChallengeMode.GetMapUIInfo(ownedMapID)) or ""
        local levelStr    = ownedLevel and ("+" .. ownedLevel) or ""
        local sep         = (dungeonName ~= "" and levelStr ~= "") and " " or ""
        reminder.subtitle:SetText(dungeonName .. sep .. levelStr)

        -- Auto-size frame width to fit whichever text line is widest.
        -- text area starts at: pad + iconSz + pad from the frame's left edge.
        do
            local px     = reminder._px
            local pad    = reminder._pad
            local iconSz = reminder._iconSz
            local textLeft = pad + iconSz + pad
            local labelW   = reminder.label:GetStringWidth()
            local subW     = reminder.subtitle:GetStringWidth()
            local newW     = textLeft + math.max(labelW, subW) + pad * 2
            reminder:SetWidth(newW)
        end

        MU.Debug("KeystoneRerollReminder: showing —", "dungeon=" .. dungeonName)

        reminder:Show()
        active = true
    end

    -- ── Completion check ───────────────────────────────────────────────────────
    local function CheckCompletion()
        if not (MU.db and MU.db.KeystoneRerollReminder) then
            return
        end

        local info = C_ChallengeMode.GetChallengeCompletionInfo()

        MU.Debug(
            "KeystoneRerollReminder: CheckCompletion —",
            "level=" .. tostring(info and info.level),
            "onTime=" .. tostring(info and info.onTime),
            "practice=" .. tostring(info and info.practiceRun)
        )

        if not info or info.practiceRun then
            MU.Debug("KeystoneRerollReminder: no info or practice run — skip")
            return
        end

        local completedLevel = info.level

        if not info.onTime then
            MU.Debug("KeystoneRerollReminder: not timed — skip")
            return
        end

        local ownedMapID, ownedLevel = GetOwnedKeystoneState()

        MU.Debug(
            "KeystoneRerollReminder:",
            "ownedLevel=" .. tostring(ownedLevel),
            "ownedMapID=" .. tostring(ownedMapID),
            "canReroll=" .. tostring(
                ownedLevel ~= nil and ownedLevel > 0 and ownedLevel <= completedLevel
            )
        )

        if ownedLevel and ownedLevel > 0
            and ownedMapID and ownedMapID ~= 0
            and ownedLevel <= completedLevel
        then
            ShowReminder(ownedMapID, ownedLevel)
        end
    end

    -- ── Event wiring ──────────────────────────────────────────────────────────
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    ef:RegisterEvent("ITEM_CHANGED")
    ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    -- ── Debug subcommand  /mu debugkeystone  ──────────────────────────────────
    if MU.subcommands then
        MU.subcommands["debugkeystone"] = function()
            local ownedMapID, ownedLevel = GetOwnedKeystoneState()
            ShowReminder(ownedMapID, ownedLevel)
        end
    end

    ef:SetScript("OnEvent", function(_, event, ...)
        if event == "CHALLENGE_MODE_COMPLETED" then
            C_Timer.After(1, CheckCompletion)

        elseif event == "ITEM_CHANGED" then
            if active then
                local _, newHyperlink = ...
                MU.Debug("KeystoneRerollReminder: ITEM_CHANGED —", "new=" .. tostring(newHyperlink))
                if C_Item.IsItemKeystoneByID(newHyperlink) then
                    HideReminder("keystone changed")
                end
            end

        elseif event == "ZONE_CHANGED_NEW_AREA" then
            if active then
                HideReminder("changed zone")
            end
        end
    end)
end