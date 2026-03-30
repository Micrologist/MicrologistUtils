MicrologistUtils = {}
local MU = MicrologistUtils

local _v   = C_AddOns.GetAddOnMetadata("MicrologistUtils", "Version")
MU.version = (_v and _v:sub(1, 1) ~= "@") and _v or "dev"
MU.modules     = {}
MU.moduleOrder = {}  -- preserves registration order for the UI
MU.moduleMeta  = {}  -- displayName, description per module key

--- Prints a debug message to chat. No-op on non-dev builds.
---@param ... any  Values passed to tostring() and joined with spaces.
function MU.Debug(...)
    if MU.version ~= "dev" then return end
    local parts = { ... }
    for i, v in ipairs(parts) do parts[i] = tostring(v) end
    print("|cff888888[MU:dev]|r " .. table.concat(parts, "  "))
end

MU.defaults = {
    AutoRoleCheck             = false,
    AutoExpansionFilter       = true,
    KeystoneRerollReminder    = true,
    ElvuiStripedShieldTexture = true,
    UIScale                   = 1,
}

---@param key     string  SavedVariable key, must match a MU.defaults entry
---@param module  table   Module table, optionally containing :Init()
---@param meta    table?  { displayName="...", description="..." }
function MU:RegisterModule(key, module, meta)
    self.modules[key]    = module
    self.moduleMeta[key] = meta or {}
    table.insert(self.moduleOrder, key)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "MicrologistUtils" then return end

    if not MicrologistUtilsDB then
        MicrologistUtilsDB = CopyTable(MU.defaults)
        MU.Debug("DB created fresh with defaults")
    end
    MU.db = MicrologistUtilsDB

    -- Backfill defaults added by newer module versions
    for k, v in pairs(MU.defaults) do
        if MU.db[k] == nil then
            MU.db[k] = v
            MU.Debug("DB backfilled:", k, "=", tostring(v))
        end
    end

    -- Init in registration order
    for _, key in ipairs(MU.moduleOrder) do
        local m = MU.modules[key]
        if m and m.Init then
            MU.Debug("Init module:", key)
            m:Init()
        end
    end

    print("|cff5599cc[MicrologistUtils v" .. MU.version .. "]|r Type |cff5599cc/mu|r to open the config window")

    self:UnregisterEvent("ADDON_LOADED")
end)
