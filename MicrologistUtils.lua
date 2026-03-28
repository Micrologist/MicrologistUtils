MicrologistUtils = {}
local MU = MicrologistUtils

MU.modules     = {}
MU.moduleOrder = {}  -- preserves registration order for the UI
MU.moduleMeta  = {}  -- displayName, description per module key

MU.defaults = {
    AutoRoleCheck = true,
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
    end
    MU.db = MicrologistUtilsDB

    -- Backfill defaults added by newer module versions
    for k, v in pairs(MU.defaults) do
        if MU.db[k] == nil then
            MU.db[k] = v
        end
    end

    -- Init in registration order
    for _, key in ipairs(MU.moduleOrder) do
        local m = MU.modules[key]
        if m and m.Init then
            m:Init()
        end
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
