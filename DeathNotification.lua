local LHH = _G.LHH
local LSM = LibStub("LibSharedMedia-3.0")
local deadCache = {}
local nextDeathSoundAt = 0

local function IsGroupUnit(unit)
    if not unit then
        return false
    end

    local raidIndex = tonumber(string.match(unit, "^raid(%d+)$"))
    if raidIndex then
        return true
    end

    local partyIndex = tonumber(string.match(unit, "^party(%d+)$"))
    if partyIndex then
        return true
    end

    return false
end

function LHH:RefreshRoster()
    wipe(deadCache)
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local num = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, num do
            local unit = prefix .. i
            deadCache[unit] = UnitIsDeadOrGhost(unit)
        end
    end
end

function LHH:OnUnitUpdate(event, unit)
    if not self.db or not self.db.profile.deathEnabled then return end
    if not unit then return end
    
    if not IsGroupUnit(unit) then return end

    local isDead = UnitIsDeadOrGhost(unit)
    local wasDead = deadCache[unit]

    if wasDead == nil then
        deadCache[unit] = isDead
        return
    end

    if not wasDead and isDead then
        local name = UnitName(unit) or "Someone"
        local soundPath = LSM:Fetch("sound", self.db.profile.deathSound)
        
        if self.db.profile.deathEnabled and soundPath then
            local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
            local throttle = tonumber(self.db.profile.deathSoundThrottleSeconds) or 0.5
            if throttle < 0 then throttle = 0 end
            if now >= nextDeathSoundAt then
                PlaySoundFile(soundPath, "Master")
                nextDeathSoundAt = now + throttle
            end
        end
    end
    deadCache[unit] = isDead
end
