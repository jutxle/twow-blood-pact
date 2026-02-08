-- Blood Pact - Rate Limiter
-- Simple interval-based rate limiting for addon message sends

BloodPact_RateLimiter = {
    lastSendTime = 0
}

-- Check if enough time has passed since last send
-- Returns true if allowed to send, false if throttled
function BloodPact_RateLimiter:CanSend()
    local now = GetTime()
    if now - self.lastSendTime >= BLOODPACT_RATE_LIMIT_INTERVAL then
        return true
    end
    return false
end

-- Record that a message was sent (call after successful send)
function BloodPact_RateLimiter:RecordSend()
    self.lastSendTime = GetTime()
end

-- Returns seconds until next send is allowed (0 if ready now)
function BloodPact_RateLimiter:TimeUntilReady()
    local elapsed = GetTime() - self.lastSendTime
    local remaining = BLOODPACT_RATE_LIMIT_INTERVAL - elapsed
    if remaining < 0 then return 0 end
    return remaining
end
