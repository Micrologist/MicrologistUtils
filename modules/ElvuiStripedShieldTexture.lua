local MU = MicrologistUtils

local module = {}
MU:RegisterModule("ElvuiStripedShieldTexture", module, {
    displayName = "ElvUI: Striped Shield Texture",
    description = "Replace ElvUI's solid (over-)shield texture with a striped one (requires reload)",
    available   = function() return ElvUI ~= nil end,
})

function module:Init()
    local ABSORB_TEX = "Interface\\AddOns\\MicrologistUtils\\media\\shield"

    local function ApplyToFrame(frame)
        local pred = frame.HealthPrediction
        if not pred then return end
        pred.damageAbsorb:SetStatusBarTexture(ABSORB_TEX)
        pred.healAbsorb:SetStatusBarTexture(ABSORB_TEX)
    end

    local function ApplyToAll(UF)
        for _, frame in pairs(UF.units or {}) do
            ApplyToFrame(frame)
        end

        for _, header in pairs(UF.headers or {}) do
            for _, group in pairs(header.groups or {}) do
                for _, frame in pairs(group) do
                    ApplyToFrame(frame)
                end
            end
        end
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if not (MU.db and MU.db.ElvuiStripedShieldTexture) then return end
        if not ElvUI then return end

        local E = unpack(ElvUI)
        local UF = E:GetModule("UnitFrames")

        hooksecurefunc(UF, "SetTexture_HealComm", function(self, obj)
            if not (MU.db and MU.db.ElvuiStripedShieldTexture) then return end
            obj.damageAbsorb:SetStatusBarTexture(ABSORB_TEX)
            obj.healAbsorb:SetStatusBarTexture(ABSORB_TEX)
        end)

        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function()
            f:UnregisterEvent("PLAYER_ENTERING_WORLD")
            C_Timer.After(0.5, function()
                if not (MU.db and MU.db.ElvuiStripedShieldTexture) then return end
                ApplyToAll(UF)
            end)
        end)
    end)
end
