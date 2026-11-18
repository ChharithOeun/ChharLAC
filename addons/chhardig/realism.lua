--[[
    Metacast - realism.lua

    Human-like timing models, tuned against a real 60-minute HorizonXI
    capture (West Ronfaure, Moat Carp, 85 cycles, 2026-09-23).

    What the capture showed (fixed by the server - nobody controls these):
        bite wait / no-bite ........ 14.2s  (cv 0.02)
        caught animation (58->0) ... 5.7s
        lost/none anim (62->0) ..... 3.7s
        cast command -> Fishing .... 0.7s
        Moat Carp time limit ....... 41s; the client's "don't know how much longer"
                                     warning comes ~9.4s before the limit (31.6s).
                                     Metacast passes this module an EFFECTIVE limit
                                     (warning + 6s), so "tl - 8" = 2s before it.

    What Metacast controls, and how it now behaves:
      recast gap   Before: uniform 1.6-2.7s (cv 0.15) -> read as automated.
                   Now: log-normal around 3.0s (wide) with a long tail, 9% short
                   distractions (6-25s), 1.5% longer lapses (40-150s), slow
                   fatigue drift (+8%/hour, reset by breaks).
      fight end    Before: +0-90% on the table time, capped at limit-3s ->
                   28 of 49 catches landed AFTER the 6-second warning.
                   Now: log-normal around the (rod-adjusted) table time,
                   window 1.3x flawless .. limit-8s with soft edges, ~2%
                   close calls into the final seconds.
      release      log-normal around 1.7s (0.9-4.5s) instead of a flat 1-1.5s.
      resume       after a proximity pause: 6-18s once the range is clear,
                   not a fixed 3s.
      breaks       "Periodic pause" lengths jittered +/-20% (after) and
                   +/-30% (duration) so they don't repeat on the minute.
]]

local M = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Standard normal via Box-Muller.
local function gauss()
    local u1 = math.max(1e-9, math.random())
    local u2 = math.random()
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- Log-normal with the given median and sigma (log-space spread).
function M.lognormal(median, sigma)
    return median * math.exp(sigma * gauss())
end

-- Human recast gap (seconds), from returning to Idle to the next cast.
-- hours = time fished since the last break (fatigue drift).
function M.recast_gap(hours)
    local fatigue = 1 + 0.08 * clamp(hours or 0, 0, 4)
    local g = clamp(M.lognormal(3.0, 0.55), 1.4, 14.0)
    local r = math.random()
    if r < 0.015 then
        g = g + 40 + math.random() * 110           -- looked away / chat / tabbed out
    elseif r < 0.105 then
        g = g + 6 + math.random() * 19             -- short distraction
    end
    return g * fatigue
end

-- Planned fight length.
--   d    : table time + Extended timing (the user's realistic target)
--   tl   : the fish's time limit from 0x115 (+0x10), 0 if unknown
--   human: Human fight spread enabled
--   rate : slow-mode factor (1 or 4/3)
--   hm   : fastest humanly possible catch for THIS fish (hits x 1.2s, from
--          0x115 stamina / hit damage), 0 if unknown
-- Returns seconds, and a short label for the capture log.
--
-- Second capture (4.7): fights landed 26-37s with spread 0.08; over 2h
-- simulated they tightened to 0.05 - the table (24.1-30.1s + extend) already
-- touches the limit-8s cap, so everything was squeezed into 28-32s. A person's
-- fights vary far more (misses, stamina regen, attention). Now: log-normal
-- around the table time (sigma 0.14), 12% "sloppy" fish +3-8s, allowed down to
-- 80% of the table time but never under 1.6x the flawless-human minimum
-- (~20s for Moat Carp), and never past limit-8s. The server itself accepts
-- far faster catches (bots on Horizon land Moat Carp in 2-6s), so the floor
-- is about looking human, not about the server.
function M.fight(d, tl, human, rate, hm)
    rate, hm = rate or 1, tonumber(hm) or 0
    local has_limit = (tl or 0) > 8
    local safe = has_limit and (tl - 8) or math.huge        -- well before the 6s warning
    local out, why = d, 'table'
    if human then
        if has_limit and math.random() < 0.02 and d < tl - 6 then
            return tl - 6 + math.random() * 2.5, 'close call'   -- rare, like a person
        end
        -- Window: a skilled person (1.3x flawless) .. limit-8s. When a short
        -- limit leaves little room (Ebisu 30s on Moat Carp: 17-22s) the floor
        -- gives way first, keeping at least ~4s of room.
        local hi = has_limit and safe or (d * 1.35)
        local lo = math.max(d * 0.80, hm * 1.3)
        if lo > hi - 4 then lo = math.max(hm * 1.12, hi - 4) end
        if lo >= hi then lo = hi - 1 end
        local center = clamp(d, lo, hi)
        out = M.lognormal(center, 0.14)
        why = 'human'
        if math.random() < 0.12 then out = out + 3 + math.random() * 5; why = 'human, sloppy' end
        -- Soft edges: past either edge lands somewhere just inside it, never on
        -- one exact value (a pile-up at one number is a pattern).
        if out > hi then out = math.max(lo, hi - math.random() * math.min(2.5, hi - lo)) end
        if out < lo then out = math.min(hi, lo + math.random() * math.min(2.5, hi - lo)) end
    end
    out = out * rate
    if has_limit and out > safe then
        out = math.max(human and 0 or d, safe)
        why = why .. ', capped'
    end
    if has_limit and out > tl - 3 then out = tl - 3 end      -- hard ceiling
    return out, why
end

-- Delay before releasing an unwanted bite (before Extended release / rate).
function M.release_delay()
    return clamp(M.lognormal(1.7, 0.35), 0.9, 4.5)
end

-- Clear-range wait before auto-resuming from a proximity pause.
function M.resume_delay()
    return 7.0      -- requested: resume 7s after the range clears
end

-- Jitter a duration by +/- pct (0.2 = +/-20%).
function M.jitter(secs, pct)
    return secs * (1 + (math.random() * 2 - 1) * pct)
end

return M
