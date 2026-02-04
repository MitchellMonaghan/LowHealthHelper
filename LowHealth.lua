local LHH = _G.LHH
local LSM = LibStub("LibSharedMedia-3.0")

local function GetPotionData(spellID)
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local _, sID = C_Item.GetItemSpell(itemID)
                if sID == spellID then
                    local count = C_Item.GetItemCount(itemID)
                    local _, duration = C_Item.GetItemCooldown(itemID)
                    return count, (duration or 0) == 0, C_Item.GetItemIconByID(itemID)
                end
            end
        end
    end
    return 0, false, nil
end

function LHH:CreateMainFrame()
    local f = CreateFrame("Frame", "LHH_MainFrame", UIParent)
    f:SetSize(80, 80)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    
    local p = self.db.profile.pos
    f:ClearAllPoints()
    f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    f:SetScale(self.db.profile.scale)
    
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if IsControlKeyDown() and IsShiftKeyDown() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        LHH.db.profile.pos = { point = point, x = x, y = y }
    end)
    self.frame = f

    -- Hook the alert specifically in the health specialist module
    if LowHealthFrame then
        LowHealthFrame:HookScript("OnShow", function()
            self:RefreshIcon()
            self.frame:Show()
            local path = LSM:Fetch("sound", self.db.profile.soundName)
            if path then PlaySoundFile(path, "Master") end
        end)
        LowHealthFrame:HookScript("OnHide", function() 
            if not self.configMode then self.frame:Hide() end 
        end)
    end
end

function LHH:RefreshIcon()
    if not self.frame then return end
    if self.configMode then 
        self.frame.tex:SetTexture(C_Item.GetItemIconByID(5512))
        self.frame:SetAlpha(1) 
        return 
    end
    
    local healthstoneIDs = {224464, 5512} 
    local bestHS = nil
    local hsReady = false

    -- 1. Find the best stone and check if it's OFF cooldown
    for _, id in ipairs(healthstoneIDs) do
        if C_Item.GetItemCount(id, false, true) > 0 then
            bestHS = id
            local startTime, duration = C_Item.GetItemCooldown(id)
            -- If duration is 0, the item is ready to use
            if (duration or 0) == 0 then
                hsReady = true
                break 
            end
        end
    end

    -- 2. Get Potion Data
    local potCount, isPotReady, potIcon = GetPotionData(self.db.profile.potionSpellID)
    
    -- 3. Logic: Show HS if ready, otherwise show Pot if ready
    if bestHS and hsReady then
        self.frame.tex:SetTexture(C_Item.GetItemIconByID(bestHS))
        self.frame:SetAlpha(1)
    elseif isPotReady then
        self.frame.tex:SetTexture(potIcon)
        self.frame:SetAlpha(1)
    else 
        -- If neither is ready, hide the frame so it doesn't bait you into clicking
        self.frame:SetAlpha(0) 
    end
end