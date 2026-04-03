local MU = MicrologistUtils

local THRESHOLD_OPTIONS = {}
for i = 2, 12 do THRESHOLD_OPTIONS[#THRESHOLD_OPTIONS + 1] = i end

local module = {}
MU:RegisterModule("KeystoneDowngradeReminder", module, {
    displayName     = "Keystone Downgrade Reminder",
    description     = "Show a reminder to downgrade keystone when held level greater than selected",
    dropdownKey     = "KeystoneDowngradeReminderThreshold",
    dropdownOptions = THRESHOLD_OPTIONS,
})

function module:Init()
    local reminder = nil
    local active   = false

    -- ── Dismiss ────────────────────────────────────────────────────────────────

    local function HideReminder(reason)
        MU.Debug("KeystoneDowngradeReminder: hide —", reason or "unknown")
        if reminder then reminder:Hide() end
        active = false
    end

    -- ── Show ───────────────────────────────────────────────────────────────────

    local function ShowReminder(keystoneMapID, keystoneLevel, threshold)
        if not (MU.db and MU.db.KeystoneDowngradeReminder) then
            MU.Debug("KeystoneDowngradeReminder: ShowReminder suppressed (module disabled)")
            return
        end
        if not reminder then
            reminder = MU.Keystone.BuildReminderFrame(
                "MUKeystoneDowngradeFrame",
                "Downgrade Keystone?",
                function() HideReminder("right-clicked") end
            )
        end

        local dungeonName = (keystoneMapID and C_ChallengeMode.GetMapUIInfo(keystoneMapID)) or "?"
        reminder.subtitle:SetText(dungeonName .. " +" .. keystoneLevel .. " -> +" .. threshold)
        MU.Keystone.AutoSizeFrame(reminder)

        reminder:Show()
        active = true
        MU.Debug("KeystoneDowngradeReminder: showing — +" .. keystoneLevel .. " > +" .. threshold)
    end

    -- ── Check conditions ───────────────────────────────────────────────────────

    local function CheckAndUpdate()
        if not (MU.db and MU.db.KeystoneDowngradeReminder) then
            if active then HideReminder("module disabled") end
            return
        end

        local threshold                  = MU.db.KeystoneDowngradeReminderThreshold or 10
        local keystoneMapID, keystoneLevel = MU.Keystone.GetOwnedKeystoneState()

        MU.Debug(
            "KeystoneDowngradeReminder: check —",
            "resting="   .. tostring(IsResting()),
            "keystone="  .. tostring(keystoneLevel),
            "threshold=" .. tostring(threshold)
        )

        if IsResting()
            and keystoneLevel and keystoneLevel > 0
            and keystoneLevel > threshold
        then
            ShowReminder(keystoneMapID, keystoneLevel, threshold)
        else
            if active then HideReminder("conditions not met") end
        end
    end

    -- ── Settings callbacks ─────────────────────────────────────────────────────
    -- Invoked by UI.lua immediately after the toggle or dropdown changes so the
    -- reminder reacts without waiting for the next game event.

    local meta = MU.moduleMeta["KeystoneDowngradeReminder"]

    meta.onToggleChanged = function(enabled)
        if enabled then
            CheckAndUpdate()
        else
            if active then HideReminder("module disabled via toggle") end
        end
    end

    meta.onDropdownChanged = function()
        if MU.db and MU.db.KeystoneDowngradeReminder then
            CheckAndUpdate()
        end
    end

    -- ── Event wiring ──────────────────────────────────────────────────────────

    local ef = CreateFrame("Frame")
    ef:RegisterEvent("PLAYER_UPDATE_RESTING")
    ef:RegisterEvent("PLAYER_ENTERING_WORLD")
    ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ef:RegisterEvent("ITEM_CHANGED")

    ef:SetScript("OnEvent", function(_)
        C_Timer.After(0.5, CheckAndUpdate)
    end)

    -- ── Debug subcommand  /mu debugdowngrade  ─────────────────────────────────

    if MU.subcommands then
        MU.subcommands["debugdowngrade"] = function()
            local threshold        = (MU.db and MU.db.KeystoneDowngradeReminderThreshold) or 10
            local mapID, level     = MU.Keystone.GetOwnedKeystoneState()
            ShowReminder(mapID, level and level > 0 and level or (threshold + 3), threshold)
        end
    end
end
