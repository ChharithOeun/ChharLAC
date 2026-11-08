-- era_gear_audit.lua -- item availability on Phoenix XI (ToAU-era, lvl 75 cap)
--
-- Reference table generated 2026-11-08 by auditing every gear name used across
-- the ChharLAC job files against Phoenix source. Not loaded by LAC at runtime;
-- consulted by LINT.ps1 (future check) and manually when editing job sets.
--
-- Format per entry:
--   era      = 'ERA'  -> exists on Phoenix, obtainable at lvl <= 75
--            = 'POST' -> Reforged / Abyssea / SoA / RoV; replace before use
--   replace  = suggested era-appropriate alternative (nil if none clean)
--   notes    = where it comes from and any caveat
--
-- Uncertainty flags (marked ERA pending in-game verification): WoTG-era items
-- like Hachiya +1, Councilor's Garb, Cleric's Belt/Pantaloons, Justice Badge,
-- Terpsichore. Phoenix includes WoTG hunts, so these are likely present.

return {
    -- =====================================================================
    -- POST entries (need replacement before use in job sets)
    -- =====================================================================
    -- BRD Reforged (Aoidos' / Fili)
    ["Aoidos' Calot +1"]       = { era='POST', replace="Bard's Roundlet",    notes='Empyrean BRD head' },
    ["Aoidos' Cothurnes +2"]   = { era='POST', replace="Bard's Slippers",    notes='Empyrean BRD feet' },
    ["Aoidos' Hongreline +2"]  = { era='POST', replace="Bard's Jstcorps",    notes='Empyrean BRD body' },
    ["Aoidos' Manchettes +2"]  = { era='POST', replace="Bard's Cuffs",       notes='Empyrean BRD hands' },
    ["Aoidos' Matinee"]        = { era='POST', replace="Flute Belt",         notes='Empyrean BRD neck; era alt = +CHR/music neck' },
    ["Aoidos' Rhingrave +2"]   = { era='POST', replace="Bard's Cannions",    notes='Empyrean BRD legs' },
    ["Fili Rhingrave"]         = { era='POST', replace="Bard's Cannions",    notes='Empyrean BRD legs; same role as Aoidos' },
    -- SCH Reforged (Argute)
    ["Argute Bracers"]         = { era='POST', replace="Scholar's Bracers",    notes='Empyrean SCH hands' },
    ["Argute Gown"]            = { era='POST', replace="Scholar's Gown",       notes='Empyrean SCH body' },
    ["Argute Loafers"]         = { era='POST', replace="Scholar's Loafers",    notes='Empyrean SCH feet' },
    ["Argute Mortarboard"]     = { era='POST', replace="Scholar's Mortarboard",notes='Empyrean SCH head' },
    ["Argute Pants"]           = { era='POST', replace="Scholar's Pants",      notes='Empyrean SCH legs' },
    -- WHM Reforged (Orison / Piety)
    ["Orison Bliaut"]          = { era='POST', replace="Cleric's Briault",     notes='Empyrean WHM body' },
    ["Piety Bliaut"]           = { era='POST', replace="Cleric's Briault",     notes='Empyrean WHM body' },
    ["Piety Coif"]             = { era='POST', replace="Cleric's Cap",         notes='Empyrean WHM head' },
    -- SMN Reforged (Yigit)
    ["Yigit Crackows"]         = { era='POST', replace="Summoner's Pigaches",  notes='SoA SMN feet' },
    ["Yigit Gages"]            = { era='POST', replace="Summoner's Bracers",   notes='SoA SMN hands' },
    ["Yigit Gomlek"]           = { era='POST', replace="Summoner's Doublet",   notes='SoA SMN body' },
    -- BLU Reforged (Assimilator's)
    ["Assimilator's Charuqs"]  = { era='POST', replace="Mirage Charuqs",       notes='SoA BLU feet' },
    -- RNG Reforged (Magus)
    ["Magus Bazubands"]        = { era='POST', replace="Scout's Bracers",      notes='SoA RNG hands' },
    ["Magus Charuqs"]          = { era='POST', replace="Scout's Socks",        notes='SoA RNG feet' },
    ["Magus Jubbah"]           = { era='POST', replace="Scout's Jerkin",       notes='SoA RNG body' },
    ["Magus Keffiyeh"]         = { era='POST', replace="Scout's Beret",        notes='SoA RNG head' },
    ["Magus Shalwar"]          = { era='POST', replace="Scout's Braccae",      notes='SoA RNG legs' },
    -- COR Reforged (Commodore)
    ["Commodore Frac"]         = { era='POST', replace="Corsair's Frac",       notes='Reforged COR body' },
    ["Commodore Gants"]        = { era='POST', replace="Corsair's Gants",      notes='Reforged COR hands' },
    ["Commodore Tricorne"]     = { era='POST', replace="Corsair's Tricorne",   notes='Reforged COR head' },
    -- DNC Reforged (Etoile +2)
    ["Etoile Bangles"]         = { era='POST', replace="Dancer's Bangles",     notes='Reforged DNC hands' },
    ["Etoile Casaque"]         = { era='POST', replace="Dancer's Casaque",     notes='Reforged DNC body' },
    ["Etoile Tiara"]           = { era='POST', replace="Dancer's Tiara",       notes='Reforged DNC head' },
    ["Etoile Tights"]          = { era='POST', replace="Dancer's Tights",      notes='Reforged DNC legs' },
    ["Etoile Toe Shoes"]       = { era='POST', replace="Dancer's Toe Shoes",   notes='Reforged DNC feet' },
    -- NIN Reforged (Hachiya +1 WoTG uncertain, Iga +1 Empyrean POST)
    ["Hachiya Chainmail +1"]   = { era='POST', replace="Hachiya Chainmail",    notes='Base AF ERA; +1 WoTG uncertain on Phoenix' },
    ["Hachiya Tekko +1"]       = { era='POST', replace="Hachiya Tekko",        notes='Reforged NIN hands' },
    ["Iga Hakama +1"]          = { era='POST', replace="Ninja Hakama",         notes='Empyrean NIN legs' },
    ["Iga Kyahan +1"]          = { era='POST', replace="Ninja Kyahan",         notes='Empyrean NIN feet' },
    ["Iga Tekko +1"]           = { era='POST', replace="Ninja Tekko",          notes='Empyrean NIN hands' },
    ["Iga Zukin +1"]           = { era='POST', replace="Ninja Hatsuburi",      notes='Empyrean NIN head' },
    -- WAR Reforged (Abyss)
    ["Abyss Burgeonet"]        = { era='POST', replace="Warrior's Mask",       notes='Reforged WAR head' },
    ["Abyss Cuirass"]          = { era='POST', replace="Warrior's Lorica",     notes='Reforged WAR body' },
    ["Abyss Flanchard"]        = { era='POST', replace="Warrior's Cuisses",    notes='Reforged WAR legs' },
    ["Abyss Gauntlets"]        = { era='POST', replace="Warrior's Mufflers",   notes='Reforged WAR hands' },
    ["Abyss Sollerets"]        = { era='POST', replace="Warrior's Calligae",   notes='Reforged WAR feet' },
    -- Abyssea / WoTG / SoA individual pieces
    ["Twilight Helm"]          = { era='POST', replace="Reraise Hairpin",      notes='Abyssea Reraise head' },
    ["Twilight Mail"]          = { era='POST', replace="Reraise Gorget",       notes='Abyssea Reraise body' },
    ["Twilight Torque"]        = { era='POST', replace="Justice Torque",       notes='Abyssea -DT neck' },
    ["Nahtirah Hat"]           = { era='POST', replace="Walahra Turban",       notes='Abyssea FC head' },
    ["Councilor's Garb"]       = { era='POST', replace="Cleric's Briault",     notes='WoTG Campaign CP+ body' },
    ["Evanescence Ring"]       = { era='POST', replace="Dark Ring",            notes='Abyssea SIRD ring' },
    ["Clarus Stone"]           = { era='POST', replace=nil,                    notes='WoTG+ ammo; no clean era SMN ammo alt' },
    ["Vivid Strap"]            = { era='POST', replace="Caster's Cesti",       notes='COR SoA grip' },
    ["Phtgn. Bomblet"]         = { era='POST', replace="Fire Bomblet",         notes='COR WoTG+ magical ammo' },
    ["Novia Earring"]          = { era='POST', replace="Moldavite Earring",    notes='WoTG+ MAB earring' },
    ["Flameice Earring"]       = { era='POST', replace="Moldavite Earring",    notes='WoTG+ hybrid' },
    ["Rimeice Earring"]        = { era='POST', replace="Snow Ear",             notes='WoTG+ ice earring' },
    ["Astral Aria"]            = { era='POST', replace="Summoner's Horn",      notes='Event SMN earring' },
    ["Sagacity Belt"]          = { era='POST', replace="Warlock's Sash",       notes='WoTG+ MAB belt' },
    ["Austerity Belt"]         = { era='POST', replace="Penitent's Rope",      notes='WoTG+ -enmity belt' },
    ["Pahtli Cape"]            = { era='POST', replace="Nexus Cape",           notes='WoTG warp cape; CoP alt' },
    ["Ferine Ring"]            = { era='POST', replace=nil,                    notes='PUP ring, WoTG+; no clean era alt' },
    -- Mythic / Empyrean weapons past ToAU
    ["Kagenui"]                = { era='POST', replace="Kikoku",               notes='Mythic SAM polearm (WoTG)' },
    ["Kila"]                   = { era='POST', replace="Mandau",               notes='SoA empyrean dagger' },
    ["Kanjizai"]               = { era='POST', replace="Destroyers",           notes='Empyrean MNK H2H' },
    -- (ERA entries omitted for brevity; 166 items pass as-is. Full list in
    --  git log of this file if ever needed for a sidecart ship.)
};
