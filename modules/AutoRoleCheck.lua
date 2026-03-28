local MU = MicrologistUtils

local module = {}
MU:RegisterModule("AutoRoleCheck", module, {
    displayName = "Auto Accept Role Check",
    description = "Automatically accepts role checks when queuing.",
})

function module:Init()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
    frame:SetScript("OnEvent", function()
        if not MU.db or not MU.db.AutoRoleCheck then return end
        C_Timer.After(0, function()
            if LFDRoleCheckPopupAcceptButton and LFDRoleCheckPopupAcceptButton:IsVisible() then
                LFDRoleCheckPopupAcceptButton:Click()
            end
        end)
    end)
end
