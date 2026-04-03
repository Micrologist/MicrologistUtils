local MU = MicrologistUtils

MU.Keystone = {}

local FONT             = "Interface\\AddOns\\MicrologistUtils\\media\\EXPRESSWAYRG.TTF"
local KEYSTONE_ITEM_ID = 180653

-- ── Bag / API helpers ─────────────────────────────────────────────────────────

--- Returns the mapID and level of the player's owned keystone, or nil, nil.
function MU.Keystone.GetOwnedKeystoneState()
    return C_MythicPlus.GetOwnedKeystoneChallengeMapID(), C_MythicPlus.GetOwnedKeystoneLevel()
end

--- Scans all regular bags for a Mythic Keystone.
--- Returns bag, slot or nil, nil if none is found.
function MU.Keystone.FindKeystoneInBags()
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

-- ── Shared reminder frame builder ─────────────────────────────────────────────

--- Builds a pixel-perfect keystone reminder popup.
---
--- @param frameName  string    Unique global WoW frame name.
--- @param labelText  string    Static gold header line ("Reroll Keystone?", etc.)
--- @param onDismiss  function  Called when the player right-clicks to dismiss.
--- @return Frame  The hidden frame, with .label and .subtitle FontStrings attached.
function MU.Keystone.BuildReminderFrame(frameName, labelText, onDismiss)
    -- Derive pixel size the same way UI.lua does so the notification is the
    -- same physical size on every resolution / UIScale combination.
    local physH = select(2, GetPhysicalScreenSize())
    local px    = UIParent:GetHeight() / physH

    local W      = math.floor(380 * px + 0.5)
    local H      = math.floor(86  * px + 0.5)
    local iconSz = math.floor(56  * px + 0.5)
    local pad    = math.floor(10  * px + 0.5)
    local fontSz = 22 * px

    local f = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, math.floor(325 * px + 0.5))
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and onDismiss then onDismiss() end
    end)

    -- Stash sizing values for use in AutoSizeFrame
    f._px       = px
    f._pad      = pad
    f._iconSz   = iconSz
    f._initialW = W

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = px,
        insets   = { left = px, right = px, top = px, bottom = px },
    })
    f:SetBackdropColor(0.09, 0.09, 0.09, 0.97)
    f:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)

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
    iconBorder:SetBackdropBorderColor(163/255, 53/255, 238/255, 1)

    -- Invisible frame over the icon to intercept mouse for the tooltip.
    -- Textures have no mouse handling, so we overlay a transparent Frame.
    local iconHit = CreateFrame("Frame", nil, f)
    iconHit:SetSize(iconSz, iconSz)
    iconHit:SetPoint("LEFT", f, "LEFT", pad, 0)
    iconHit:EnableMouse(true)
    iconHit:SetScript("OnEnter", function(self)
        local bag, slot = MU.Keystone.FindKeystoneInBags()
        if bag then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(bag, slot)
            GameTooltip:Show()
        end
    end)
    iconHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Static gold header
    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, fontSz, "OUTLINE")
    label:SetTextColor(1, 0.82, 0.1, 1)
    label:SetText(labelText)
    label:SetPoint("BOTTOMLEFT", icon, "RIGHT", pad, math.floor(3 * px + 0.5))
    label:SetJustifyH("LEFT")
    f.label = label

    -- Dynamic subtitle (set by each module before showing)
    local sub = f:CreateFontString(nil, "OVERLAY")
    sub:SetFont(FONT, fontSz, "OUTLINE")
    sub:SetTextColor(0.48, 0.48, 0.48, 1)
    sub:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -math.floor(4 * px + 0.5))
    sub:SetJustifyH("LEFT")
    f.subtitle = sub

    f:Hide()
    return f
end

-- ── Auto-width helper ─────────────────────────────────────────────────────────

--- Resizes a reminder frame's width to snugly fit its current text content.
--- Call this after updating f.subtitle's text, before calling f:Show().
function MU.Keystone.AutoSizeFrame(f)
    local pad    = f._pad
    local iconSz = f._iconSz
    local labelW = f.label:GetStringWidth()
    local subW   = f.subtitle:GetStringWidth()
    -- Never shrink below the frame's original built width so the layout
    -- stays consistent even when subtitle text is short.
    f:SetWidth(math.max(f._initialW, pad + iconSz + pad + math.max(labelW, subW) + pad * 2))
end
