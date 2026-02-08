-- Blood Pact - Conflict Resolver
-- Resolves conflicts when merging death records from multiple sources

BloodPact_ConflictResolver = {}

-- Determine if two death records represent the same death event
-- Criteria: same character, timestamps within 10s, same level
function BloodPact_ConflictResolver:IsSameDeath(d1, d2)
    if not d1 or not d2 then return false end
    if d1.characterName ~= d2.characterName then return false end
    if math.abs((d1.timestamp or 0) - (d2.timestamp or 0)) > 10 then return false end
    if d1.level ~= d2.level then return false end
    return true
end

-- Resolve a conflict between two records for the same death.
-- Returns the preferred record (earlier timestamp wins; alphabetical tie-break).
function BloodPact_ConflictResolver:Resolve(local_rec, remote_rec)
    local lt = local_rec.timestamp or 0
    local rt = remote_rec.timestamp or 0

    if lt < rt then
        return local_rec
    elseif rt < lt then
        return remote_rec
    else
        -- Same timestamp: alphabetical character name as final tie-break
        if (local_rec.characterName or "") <= (remote_rec.characterName or "") then
            return local_rec
        else
            return remote_rec
        end
    end
end

-- Merge a single remote death into an existing list for a character.
-- Returns true if the death was added/updated, false if it was a duplicate.
function BloodPact_ConflictResolver:MergeIntoList(deathList, remoteDeath)
    for i, existing in ipairs(deathList) do
        if self:IsSameDeath(existing, remoteDeath) then
            -- Conflict: keep preferred record
            local resolved = self:Resolve(existing, remoteDeath)
            deathList[i] = resolved
            return false  -- not a new death, just updated
        end
    end
    -- New death
    table.insert(deathList, remoteDeath)
    return true
end

-- Sort a death list by timestamp descending and enforce max size limit
function BloodPact_ConflictResolver:PruneAndSort(deathList)
    table.sort(deathList, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
    while table.getn(deathList) > BLOODPACT_MAX_DEATHS_PER_CHAR do
        table.remove(deathList)  -- removes last (oldest)
    end
end
