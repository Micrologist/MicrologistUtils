local MU = MicrologistUtils

local module = {}
MU:RegisterModule("AutoRoleCheck", module, {
    displayName = "Accept Role Checks |cff808080/mu arc|r",
    description = "Automatically accept role checks when prompted (Set roles in Dungeon Finder)",
})

function module:Init()
    local pendingAccept  = nil
    local watchdog       = nil
    local combatDeferred = false

    local function Cleanup()
        if pendingAccept then pendingAccept:Cancel(); pendingAccept = nil end
        if watchdog      then watchdog:Cancel();      watchdog      = nil end
        combatDeferred = false
    end

    local function DoAccept()
        if not (LFDRoleCheckPopup and LFDRoleCheckPopup:IsVisible()) then return end
        LFDRoleCheckPopup:EnableMouse(true)
        LFDRoleCheckPopup:Raise()
        if LFDRoleCheckPopupAcceptButton and LFDRoleCheckPopupAcceptButton:IsVisible() then
            LFDRoleCheckPopupAcceptButton:Click()
        end
    end

    -- Attempt accept; if combat lock is active defer until PLAYER_REGEN_ENABLED
    local function ScheduleAccept()
        if not (MU.db and MU.db.AutoRoleCheck) then return end
        Cleanup()
        if InCombatLockdown() then
            combatDeferred = true
        else
            pendingAccept = C_Timer.NewTimer(0, function()
                pendingAccept = nil
                DoAccept()
            end)
        end

        watchdog = C_Timer.NewTimer(3, function()
            watchdog = nil
            if not (LFDRoleCheckPopup and LFDRoleCheckPopup:IsVisible()) then return end
            local function TryAccept(remaining)
                if remaining <= 0 then return end
                if not (LFDRoleCheckPopup and LFDRoleCheckPopup:IsVisible()) then return end
                DoAccept()
                C_Timer.After(0.5, function() TryAccept(remaining - 1) end)
            end
            TryAccept(20)
        end)
    end

    -- Hook the popup's own OnShow so we fire after it has fully initialised,
    -- rather than racing against LFG_ROLE_CHECK_SHOW
    if LFDRoleCheckPopup then
        LFDRoleCheckPopup:HookScript("OnShow", ScheduleAccept)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("LFG_ROLE_CHECK_HIDE")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "LFG_ROLE_CHECK_HIDE" then
            Cleanup()
        elseif event == "PLAYER_REGEN_ENABLED" and combatDeferred then
            combatDeferred = false
            DoAccept()
        end
    end)
end
