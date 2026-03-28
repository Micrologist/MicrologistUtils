MicrologistUtils = {}
local MU = MicrologistUtils

MU.modules = {}

MU.defaults = {
    AutoRoleCheck = true,
}

function MU:RegisterModule(name, module)
    self.modules[name] = module
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "MicrologistUtils" then return end
    if not MicrologistUtilsDB then
        MicrologistUtilsDB = CopyTable(MU.defaults)
    end
    MU.db = MicrologistUtilsDB
    for k, v in pairs(MU.defaults) do
        if MU.db[k] == nil then
            MU.db[k] = v
        end
    end
    for _, module in pairs(MU.modules) do
        if module.Init then
            module:Init()
        end
    end
    self:UnregisterEvent("ADDON_LOADED")
end)
