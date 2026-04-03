local MU = MicrologistUtils

local module = {}
MU:RegisterModule("KeystoneRerollReminder", module, {
    displayName = "Keystone Reroll Reminder",
    description = "Show a reminder whenever a keystone reroll is available after a mythic+ run",
})

function module:Init()
    local reminder    = nil  -- "Reroll Keystone?" popup, built lazily
    local resultFrame = nil  -- reroll / completion result popup, built lazily
    local active      = false

    -- Continuously-tracked keystone state so we always have a valid "before"
    -- snapshot ready when ITEM_CHANGED fires
    local trackedMapID, trackedLevel = nil, nil

    -- Cancellable auto-dismiss timer for the result popup
    local resultDismissTimer = nil

    -- ── Helpers ────────────────────────────────────────────────────────────────

    local function DungeonLabel(mapID, level)
        local name = (mapID and C_ChallengeMode.GetMapUIInfo(mapID)) or "?"
        return name .. " +" .. (level or "?")
    end

    -- ── Dismiss ────────────────────────────────────────────────────────────────

    local function HideReminder(reason)
        MU.Debug("KeystoneRerollReminder: hide —", reason or "unknown reason")
        if reminder then reminder:Hide() end
        active = false
    end

    local function HideResult(reason)
        MU.Debug("KeystoneRerollReminder: hide result —", reason or "unknown reason")
        if resultFrame then resultFrame:Hide() end
        if resultDismissTimer then
            resultDismissTimer:Cancel()
            resultDismissTimer = nil
        end
    end

    -- ── Show "Reroll Keystone?" ────────────────────────────────────────────────

    local function ShowReminder(ownedMapID, ownedLevel)
        if not (MU.db and MU.db.KeystoneRerollReminder) then
            MU.Debug("KeystoneRerollReminder: ShowReminder suppressed (module disabled)")
            return
        end
        if not reminder then
            reminder = MU.Keystone.BuildReminderFrame(
                "MUKeystoneReminderFrame",
                "Reroll Keystone?",
                function() HideReminder("right-clicked") end
            )
        end

        local dungeonName = (ownedMapID and C_ChallengeMode.GetMapUIInfo(ownedMapID)) or ""
        local levelStr    = ownedLevel and ("+" .. ownedLevel) or ""
        local sep         = (dungeonName ~= "" and levelStr ~= "") and " " or ""
        reminder.subtitle:SetText(dungeonName .. sep .. levelStr)

        MU.Keystone.AutoSizeFrame(reminder)
        MU.Debug("KeystoneRerollReminder: showing —", "dungeon=" .. dungeonName)

        reminder:Show()
        active = true
    end

    -- ── Show keystone change result ────────────────────────────────────────────

    local function ShowKeystoneChange(header, newMapID, newLevel)
        if not (MU.db and MU.db.KeystoneRerollReminder) then return end
        if not resultFrame then
            resultFrame = MU.Keystone.BuildReminderFrame(
                "MUKeystoneChangeResultFrame",
                header,
                function() HideResult("right-clicked") end
            )
        end

        resultFrame.label:SetText(header)
        resultFrame.subtitle:SetText(DungeonLabel(newMapID, newLevel))
        MU.Keystone.AutoSizeFrame(resultFrame)

        MU.Debug("KeystoneRerollReminder:", header, DungeonLabel(newMapID, newLevel))

        resultFrame:Show()

        if resultDismissTimer then resultDismissTimer:Cancel() end
        resultDismissTimer = C_Timer.NewTimer(10, function() HideResult("auto-dismissed") end)
    end

    -- ── Event wiring ──────────────────────────────────────────────────────────

    local ef = CreateFrame("Frame")
    ef:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    ef:RegisterEvent("ITEM_CHANGED")
    ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ef:RegisterEvent("PLAYER_ENTERING_WORLD")

    ef:SetScript("OnEvent", function(_, event, ...)
        if event == "CHALLENGE_MODE_COMPLETED" then
            -- Capture completion info and the pre-change key state now, before
            -- the game updates the keystone.  After 1 s: if the key changed,
            -- show the upgrade popup; if not, fall through to the reroll check.
            local info     = C_ChallengeMode.GetChallengeCompletionInfo()
            local preMapID = trackedMapID
            local preLevel = trackedLevel

            MU.Debug(
                "KeystoneRerollReminder: CHALLENGE_MODE_COMPLETED —",
                "level="    .. tostring(info and info.level),
                "onTime="   .. tostring(info and info.onTime),
                "practice=" .. tostring(info and info.practiceRun)
            )

            C_Timer.After(1, function()
                if not (MU.db and MU.db.KeystoneRerollReminder) then return end

                local newMapID, newLevel = MU.Keystone.GetOwnedKeystoneState()

                if newMapID and newLevel
                    and (newMapID ~= preMapID or newLevel ~= preLevel)
                then
                    -- Key updated automatically after the run
                    MU.Debug("KeystoneRerollReminder: key upgraded —", DungeonLabel(newMapID, newLevel))
                    ShowKeystoneChange("Keystone Upgraded!", newMapID, newLevel)
                    trackedMapID, trackedLevel = newMapID, newLevel

                elseif info and not info.practiceRun and info.onTime then
                    -- Key unchanged; check whether a reroll is worthwhile
                    MU.Debug(
                        "KeystoneRerollReminder: key unchanged, checking reroll —",
                        "ownedLevel="     .. tostring(newLevel),
                        "completedLevel=" .. tostring(info.level)
                    )
                    if newLevel and newLevel > 0
                        and newMapID and newMapID ~= 0
                        and newLevel <= info.level
                    then
                        ShowReminder(newMapID, newLevel)
                    end
                end
            end)

        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, function()
                trackedMapID, trackedLevel = MU.Keystone.GetOwnedKeystoneState()
                MU.Debug("KeystoneRerollReminder: initial state —",
                    "mapID=" .. tostring(trackedMapID),
                    "level=" .. tostring(trackedLevel))
            end)

        elseif event == "ITEM_CHANGED" then
            -- Completion key changes do NOT fire this; any keystone ITEM_CHANGED
            -- is a deliberate reroll. The C_MythicPlus APIs lag behind the bag
            -- update, so poll every 0.2 s until the state differs from the
            -- pre-reroll snapshot (up to 5 attempts / 1 s total).
            local _, newHyperlink = ...
            MU.Debug("KeystoneRerollReminder: ITEM_CHANGED —", "new=" .. tostring(newHyperlink))

            if C_Item.IsItemKeystoneByID(newHyperlink) then
                local oldMapID, oldLevel = trackedMapID, trackedLevel
                if active then HideReminder("keystone changed") end

                local function TryShowReroll(attempt)
                    local newMapID, newLevel = MU.Keystone.GetOwnedKeystoneState()
                    if newMapID ~= nil and newLevel ~= nil
                        and (newMapID ~= oldMapID or newLevel ~= oldLevel)
                        and (newLevel >= oldLevel)
                    then
                        ShowKeystoneChange("Keystone Rerolled!", newMapID, newLevel)
                        trackedMapID, trackedLevel = newMapID, newLevel
                    elseif attempt < 5 then
                        C_Timer.After(0.2, function() TryShowReroll(attempt + 1) end)
                    else
                        -- API never updated within the poll window; re-sync tracked
                        -- state to whatever it reports now to avoid stale snapshots
                        if newMapID ~= nil and newLevel ~= nil then
                            trackedMapID, trackedLevel = newMapID, newLevel
                        end
                    end
                end
                TryShowReroll(0)
            end

        elseif event == "ZONE_CHANGED_NEW_AREA" then
            if active then HideReminder("changed zone") end
        end
    end)

    -- ── Debug subcommands ─────────────────────────────────────────────────────

    if MU.subcommands then
        MU.subcommands["debugkeystone"] = function()
            local ownedMapID, ownedLevel = MU.Keystone.GetOwnedKeystoneState()
            ShowReminder(ownedMapID, ownedLevel)
        end

        MU.subcommands["debugreroll"] = function()
            local newMapID, newLevel = MU.Keystone.GetOwnedKeystoneState()
            ShowKeystoneChange("Keystone Rerolled!", newMapID, newLevel or 8)
        end

        MU.subcommands["debugcompletion"] = function()
            local newMapID, newLevel = MU.Keystone.GetOwnedKeystoneState()
            ShowKeystoneChange("Keystone Upgraded!", newMapID, newLevel or 8)
        end
    end
end
