local MU = MicrologistUtils
local module = {}

MU:RegisterModule("AutoExpansionFilter", module, {
    displayName = "Current Expansion Filters",
    description = "Automatically set the current expansion filter when browsing auctions or work orders",
})

function module:Init()
    -- ── Auction House
    local ahFrame = CreateFrame("Frame")
    ahFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    ahFrame:SetScript("OnEvent", function()
        if not MU.db or not MU.db.AutoExpansionFilter then return end
        C_Timer.After(0, function()
            if AuctionHouseFrame and AuctionHouseFrame.SearchBar then
                local filterBtn = AuctionHouseFrame.SearchBar.FilterButton
                if filterBtn and filterBtn.filters then
                    filterBtn.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
                    AuctionHouseFrame.SearchBar:UpdateClearFiltersButton()
                end
            end
        end)
    end)

    -- ── Work Orders
    local woFrame = CreateFrame("Frame")
    woFrame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
    woFrame:SetScript("OnEvent", function()
        if not MU.db or not MU.db.AutoExpansionFilter then return end
        C_Timer.After(0, function()
            if ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar then
                local filterBtn = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar.FilterDropdown
                if filterBtn and filterBtn.filters then
                    filterBtn.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
                    local sb = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar
                    if sb.UpdateClearFiltersButton then sb:UpdateClearFiltersButton() end
                end
            end
        end)
    end)
end
