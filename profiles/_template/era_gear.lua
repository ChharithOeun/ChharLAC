-- era_gear.lua -- Phoenix XI ToAU-era gear reference (lvl 1-75 cap)
--
-- Compiled 2026-11-08 from:
--   * Phoenix beta source (phoenixffxi/Phoenix) -- NM drops, hunt rewards, ZNM,
--     Nyzul/Salvage/Besieged piece listings traced across zone mob scripts
--   * Standard ToAU-era FFXI gear knowledge (AF/AF+1 quests, BCNM/KSNM/HNM
--     drops, craft recipes, Campaign/CP rewards, event/seasonal items)
--
-- **NOT every entry is Phoenix-source-verified.** The subagent crawl confirmed
-- high-signal items (AF, Dynamis relic, Nyzul/Salvage, BCNM) but Phoenix's
-- base item SQL is too large to fully audit in-session. Use this as a
-- reference for "is this gear era-appropriate?" rather than "is this gear
-- obtainable on Phoenix right now?". Verify specific entries in-game before
-- relying on them in a job set.
--
-- Fields per entry:
--   lvl         -- level requirement
--   jobs        -- short string: "all", "melee", "mages", or JOB list
--   src         -- where it comes from (BCNM/HNM/ZNM/AF/craft/NPC/quest/event)
--   notes       -- stat focus / role
--   event=true  -- special-event reward (Mog Bonanza, Login Campaign, etc.)
--   wardrobe8=true -- Phoenix/Horizon convention: event gear stored in
--                     Wardrobe 8
--   uncertain=true -- WoTG-era item; Phoenix availability not fully verified.
--                     (Phoenix includes WoTG hunt NMs so these likely ARE
--                     obtainable; just flag so reviewer can double-check.)
--
-- Companion file: era_gear_audit.lua (per-item POST list for the gear names
-- that were actually in use across job files as of 2026-11-08).

return {

-- =============================================================================
-- HEAD (slot 5)
-- =============================================================================
Head = {
    -- Classic BCNM / NPC heads (all ERA, popular stat heads)
    ["Empress Hairpin"]      = { lvl=20, jobs="all",    src="BCNM30",                        notes="DEX+5 classic" },
    ["Walahra Turban"]       = { lvl=58, jobs="all",    src="ToAU NPC-sold (Aht Urhgan)",    notes="Haste+2% cheap haste head" },
    ["Optical Hat"]          = { lvl=60, jobs="all",    src="BCNM60: Shattering Stars",      notes="Acc+10 iconic WS head" },
    ["Opo-opo Crown"]        = { lvl=40, jobs="all",    src="NPC",                           notes="CHR+1" },
    -- AF (artifact) heads -- all ERA via AF quest
    ["Warrior's Mask"]       = { lvl=52, jobs="WAR",    src="WAR AF quest",                  notes="DA+ATT" },
    ["Beast Helm"]           = { lvl=52, jobs="BST",    src="BST AF quest",                  notes="+Charm skill" },
    ["Duelist's Chapeau"]    = { lvl=52, jobs="RDM",    src="RDM AF quest",                  notes="Fast Cast" },
    ["Temple Crown"]         = { lvl=52, jobs="MNK",    src="MNK AF quest",                  notes="Kick DMG" },
    ["Sorcerer's Petasos"]   = { lvl=52, jobs="BLM",    src="BLM AF quest",                  notes="Elemental skill" },
    ["Cleric's Cap"]         = { lvl=52, jobs="WHM",    src="WHM AF quest",                  notes="MP, Divine" },
    ["Chaos Burgeonet"]      = { lvl=52, jobs="DRK",    src="DRK AF quest",                  notes="Last Resort+" },
    ["Assassin's Bonnet"]    = { lvl=52, jobs="THF",    src="THF AF quest",                  notes="Triple Attack" },
    ["Temple Crown"]         = { lvl=52, jobs="PLD",    src="PLD AF quest",                  notes="MP, Divine" },
    ["Ninja Hatsuburi"]      = { lvl=52, jobs="NIN",    src="NIN AF quest",                  notes="HP+ Dual Wield" },
    ["Drachen Helm"]         = { lvl=52, jobs="DRG",    src="DRG AF quest",                  notes="Jump+" },
    ["Evoker's Horn"]        = { lvl=52, jobs="SMN",    src="SMN AF head",                   notes="Summoning skill" },
    ["Myochin Kabuto"]       = { lvl=52, jobs="SAM",    src="SAM AF quest",                  notes="Zanshin" },
    ["Scout's Beret"]        = { lvl=52, jobs="RNG",    src="RNG AF quest",                  notes="Snapshot" },
    ["Bard's Roundlet"]      = { lvl=52, jobs="BRD",    src="BRD AF quest",                  notes="Song HP" },
    ["Mirage Keffiyeh"]      = { lvl=52, jobs="BLU",    src="BLU AF quest (ToAU)",           notes="BLU +skill" },
    ["Corsair's Tricorne"]   = { lvl=52, jobs="COR",    src="COR AF quest (ToAU)",           notes="Snapshot" },
    ["Puppetry Taj"]         = { lvl=52, jobs="PUP",    src="PUP AF quest (ToAU)",           notes="Repair+" },
    ["Dancer's Tiara"]       = { lvl=52, jobs="DNC",    src="DNC AF quest (WoTG)",           uncertain=true, notes="WoTG; Phoenix likely" },
    ["Scholar's Mortarboard"]= { lvl=52, jobs="SCH",    src="SCH AF quest (WoTG)",           uncertain=true, notes="WoTG; Phoenix likely" },
    -- Relic / AF+1 (Dynamis / WoTG upgrades)
    ["Valor Coronet"]        = { lvl=71, jobs="WAR",    src="Dynamis",                       notes="Double Attack+" },
    ["Tantra Crown"]         = { lvl=71, jobs="MNK",    src="Dynamis",                       notes="Chakra+" },
    ["Cleric's Cap +1"]      = { lvl=71, jobs="WHM",    src="WHM AF+1 quest",                notes="MP/Cure" },
    ["Wizard's Petasos"]     = { lvl=71, jobs="BLM",    src="Dynamis",                       notes="Elemental seal+" },
    ["Warlock's Chapeau"]    = { lvl=71, jobs="RDM",    src="Dynamis",                       notes="Enhancing" },
    ["Assassin's Bonnet +1"] = { lvl=74, jobs="THF",    src="Attowha Chasm quest",           notes="TA+2 DEX+3" },
    ["Abyss Burgeonet"]      = { lvl=71, jobs="DRK",    src="Dynamis",                       notes="Last Resort+" },
    ["Monster Helm"]         = { lvl=71, jobs="BST",    src="Dynamis",                       notes="Call Beast+" },
    ["Choral Roundlet"]      = { lvl=71, jobs="BRD",    src="Dynamis",                       notes="Song recast-" },
    ["Scout's Beret +1"]     = { lvl=74, jobs="RNG",    src="Dynamis",                       notes="Barrage+" },
    ["Crimson Mask"]         = { lvl=71, jobs="SAM",    src="Dynamis",                       notes="Meditate+" },
    ["Koga Hatsuburi"]       = { lvl=71, jobs="NIN",    src="Dynamis",                       notes="TA" },
    ["Wyrm Armet"]           = { lvl=71, jobs="DRG",    src="DRG AF2 quest",                 notes="Jump+" },
    -- HNM / high-tier drops
    ["Genbu's Kabuto"]       = { lvl=70, jobs="WAR DRK PLD", src="HNM: Genbu",                notes="plate rare" },
    ["Byakko's Headdress"]   = { lvl=70, jobs="SAM MNK",    src="HNM: Byakko",                notes="rare drop" },
    ["Gnadbhod's Helm"]      = { lvl=73, jobs="WAR PLD",    src="ZNM: Gnadbhod (ToAU)",       notes="PDT-" },
    -- Nyzul Isle / Salvage / Assault heads (ERA)
    ["Askar Zucchetto"]      = { lvl=72, jobs="WAR MNK THF BST DRG RNG SAM NIN DNC", src="Nyzul Isle Investigation", notes="ACC/ATT" },
    ["Homam Zucchetto"]      = { lvl=73, jobs="mage+hybrid",src="Nyzul Isle",                 notes="Haste/Refresh" },
    ["Nashira Turban"]       = { lvl=73, jobs="BLU COR PUP",src="Nyzul Isle",                 notes="ToAU job set" },
    ["Denali Bonnet"]        = { lvl=72, jobs="mage",       src="Salvage Bhaflau",            notes="MDB/Enfeeb" },
    ["Morrigan's Coronal"]   = { lvl=72, jobs="mage",       src="Salvage Zhayolm",            notes="Fast Cast" },
    ["Marduk's Tiara"]       = { lvl=72, jobs="mage+support",src="Salvage Arrapago",          notes="haste-related" },
    ["Usukane Hachimaki"]    = { lvl=72, jobs="SAM MNK",    src="Salvage",                    notes="Store TP" },
    ["Ares's Mask"]          = { lvl=72, jobs="melee",      src="Salvage",                    notes="DA/ACC" },
    ["Skadi's Visor"]        = { lvl=72, jobs="THF RNG NIN BLU", src="Salvage",               notes="Acc/Eva" },
    -- Reraise / recovery
    ["Reraise Hairpin"]      = { lvl=70, jobs="all",        src="Craft (Goldsmithing)",       notes="auto-Reraise head era alt" },
    -- Event / wardrobe8
    ["Mandragora Mask"]      = { lvl=1,  jobs="all",        src="Mog Bonanza / event",        event=true, wardrobe8=true, notes="cosmetic event" },
    ["Pumpkin Head"]         = { lvl=1,  jobs="all",        src="Harvest Festival",           event=true, wardrobe8=true, notes="Oct event" },
    ["Red Cap"]              = { lvl=1,  jobs="all",        src="Starlight Celebration",      event=true, wardrobe8=true, notes="Dec event" },
    ["Golden Bomb Mask"]     = { lvl=1,  jobs="all",        src="Sunbreeze event",            event=true, wardrobe8=true, notes="Summer event" },
},

-- =============================================================================
-- BODY (slot 6)
-- =============================================================================
Body = {
    ["Haubergeon"]           = { lvl=59, jobs="WAR DRK BST DRG BLU", src="BCNM60 craft",      notes="ACC+10 classic" },
    ["Hauberk"]              = { lvl=59, jobs="WAR DRK BST DRG BLU", src="HQ craft",          notes="HQ Haubergeon" },
    ["Scorpion Harness"]     = { lvl=55, jobs="many DD",    src="craft (Leathercraft)",       notes="ACC+10 classic DD body" },
    ["Scorpion Harness +1"]  = { lvl=57, jobs="many DD",    src="HQ craft",                   notes="iconic" },
    ["Adaman Hauberk"]       = { lvl=70, jobs="WAR PLD DRK",src="craft Smithing",             notes="+20 PDT classic" },
    -- AF bodies
    ["Warrior's Lorica"]     = { lvl=52, jobs="WAR",        src="WAR AF quest",               notes="VIT/STR" },
    ["Beast Jackcoat"]       = { lvl=52, jobs="BST",        src="BST AF quest",               notes="pet HP" },
    ["Duelist's Tabard"]     = { lvl=52, jobs="RDM",        src="RDM AF quest",               notes="Fast Cast" },
    ["Melee Gi"]             = { lvl=52, jobs="MNK",        src="MNK AF quest",               notes="H2H" },
    ["Temple Cyclas"]        = { lvl=52, jobs="PLD",        src="PLD AF quest",               notes="DEF/Divine" },
    ["Sorcerer's Coat"]      = { lvl=52, jobs="BLM",        src="BLM AF quest",               notes="Elemental skill" },
    ["Cleric's Briault"]     = { lvl=52, jobs="WHM",        src="WHM AF quest",               notes="MP, Cure" },
    ["Chaos Cuirass"]        = { lvl=52, jobs="DRK",        src="DRK AF quest",               notes="DMG+ Weapon Bash" },
    ["Rogue's Vest"]         = { lvl=52, jobs="THF",        src="THF AF quest",               notes="pre-Assassin" },
    ["Assassin's Vest"]      = { lvl=52, jobs="THF",        src="THF AF+1 quest",             notes="DEX/AGI" },
    ["Ninja Chainmail"]      = { lvl=52, jobs="NIN",        src="NIN AF quest",               notes="DEX/HP" },
    ["Hachiya Chainmail"]    = { lvl=58, jobs="NIN",        src="NIN AF2 quest",              notes="DW" },
    ["Drachen Mail"]         = { lvl=52, jobs="DRG",        src="DRG AF quest",               notes="Jump+ DMG" },
    ["Summoner's Doublet"]   = { lvl=52, jobs="SMN",        src="SMN AF quest",               notes="Summoning skill" },
    ["Saotome Domaru"]       = { lvl=52, jobs="SAM",        src="SAM AF quest",               notes="pre-Haubergeon" },
    ["Scout's Jerkin"]       = { lvl=52, jobs="RNG",        src="RNG AF quest",               notes="Barrage+" },
    ["Bard's Jstcorps"]      = { lvl=52, jobs="BRD",        src="BRD AF quest",               notes="Song +1 effect" },
    ["Mirage Jubbah"]        = { lvl=52, jobs="BLU",        src="BLU AF quest (ToAU)",        notes="BLU skill+" },
    ["Corsair's Frac"]       = { lvl=52, jobs="COR",        src="COR AF quest (ToAU)",        notes="COR+" },
    ["Puppetry Tobe"]        = { lvl=52, jobs="PUP",        src="PUP AF quest (ToAU)",        notes="Automaton+" },
    ["Dancer's Casaque"]     = { lvl=52, jobs="DNC",        src="DNC AF quest (WoTG)",        uncertain=true },
    ["Scholar's Gown"]       = { lvl=52, jobs="SCH",        src="SCH AF quest (WoTG)",        uncertain=true },
    -- Relic / AF+1 bodies
    ["Dalmatica"]            = { lvl=74, jobs="mage+support", src="Dynamis-Tavnazia relic",   notes="DEF/Refresh/MDB iconic" },
    ["Valor Surcoat"]        = { lvl=71, jobs="WAR",        src="Dynamis",                    notes="Double Attack+" },
    ["Warlock's Tabard"]     = { lvl=71, jobs="RDM",        src="Dynamis / RDM AF+1",         notes="Enhancing Magic" },
    ["Assassin's Vest +1"]   = { lvl=74, jobs="THF",        src="Dynamis",                    notes="TA" },
    ["Hecatomb Harness"]     = { lvl=74, jobs="DRK DRG",    src="HNM: Vrtra",                 notes="rare" },
    ["Hecatomb Harness +1"]  = { lvl=74, jobs="DRK DRG",    src="HQ HNM",                     notes="HQ" },
    -- HNM / HQ bodies
    ["Kirin's Osode"]        = { lvl=73, jobs="DD",         src="HNM: Kirin",                 notes="STR/ACC/ATT" },
    ["Shura Togi"]           = { lvl=74, jobs="SAM",        src="HNM: Kirin",                 notes="Store TP SAM" },
    ["Mekira-oi"]            = { lvl=74, jobs="SAM",        src="KSNM / Byakko",              notes="SAM body" },
    ["Mekira-oi +1"]         = { lvl=74, jobs="SAM",        src="HQ",                         notes="SAM body HQ" },
    -- Nyzul / Salvage
    ["Askar Korazin"]        = { lvl=73, jobs="WAR MNK THF BST DRG RNG SAM NIN DNC", src="Nyzul Isle", notes="ACC Store TP" },
    ["Homam Corazza"]        = { lvl=73, jobs="mage+hybrid",src="Salvage",                    notes="Haste/Refresh" },
    ["Nashira Manteel"]      = { lvl=73, jobs="BLU COR PUP",src="Salvage",                    notes="ToAU set" },
    ["Denali Jacket"]        = { lvl=72, jobs="mage",       src="Salvage Bhaflau",            notes="MDB" },
    ["Morrigan's Robe"]      = { lvl=72, jobs="mage",       src="Salvage Zhayolm",            notes="Fast Cast" },
    ["Marduk's Jubbah"]      = { lvl=72, jobs="mage+hybrid",src="Salvage Arrapago",           notes="haste-related" },
    ["Usukane Haramaki"]     = { lvl=72, jobs="SAM MNK",    src="Salvage",                    notes="Store TP" },
    ["Ares's Cuirass"]       = { lvl=72, jobs="melee",      src="Salvage",                    notes="DA/ACC" },
    ["Skadi's Cuirie"]       = { lvl=72, jobs="THF RNG NIN BLU", src="Salvage",               notes="Acc/Eva" },
    ["Igqira Weskit"]        = { lvl=58, jobs="BLU",        src="BLU AF2",                    notes="BLU +skill" },
    -- Reraise / event
    ["Reraise Gorget"]       = { lvl=70, jobs="all",        src="Craft (Goldsmithing)",       notes="auto-Reraise body era alt" },
    ["Beast Jackcoat +1"]    = { lvl=58, jobs="BST",        src="BST AF+1 (WoTG quest)",      uncertain=true, notes="WoTG; Phoenix likely" },
    ["Councilor's Garb"]     = { lvl=71, jobs="all",        src="WoTG Campaign CP",           uncertain=true, event=true, wardrobe8=true, notes="WoTG Campaign" },
    ["Decennial Coat"]       = { lvl=1,  jobs="all",        src="FFXI anniversary event",     event=true, wardrobe8=true, notes="EXP+" },
    ["Moogle Suit"]          = { lvl=1,  jobs="all",        src="Mog Bonanza / event",        event=true, wardrobe8=true, notes="cosmetic" },
},

-- =============================================================================
-- HANDS (slot 7)
-- =============================================================================
Hands = {
    -- Classic BCNM / NPC / craft hands
    ["Dusk Gloves"]          = { lvl=72, jobs="DD",         src="Fenrir Prime drop",          notes="Haste+2%" },
    ["Dusk Gloves +1"]       = { lvl=72, jobs="DD",         src="Fenrir Prime (HQ)",          notes="Haste+3%" },
    ["Enkidu's Mittens"]     = { lvl=74, jobs="WAR MNK THF BST BLU", src="ZNM: Enkidu",       notes="STR+5 DA+2%" },
    ["Alkyoneus's Bracelets"]= { lvl=73, jobs="WAR MNK THF BST DRG", src="ZNM: Alkyoneus",    notes="STR+5 Haste+1%" },
    ["Blood Fng. Gauntlets"] = { lvl=70, jobs="DRK",        src="BCNM",                       notes="Attack+5 Drain+" },
    -- AF hands
    ["Warrior's Mufflers"]   = { lvl=52, jobs="WAR",        src="WAR AF",                     notes="Double Attack+" },
    ["Beast Gloves"]         = { lvl=52, jobs="BST",        src="BST AF",                     notes="Snarl" },
    ["Chaos Gauntlets"]      = { lvl=52, jobs="DRK",        src="DRK AF",                     notes="Souleater+" },
    ["Duelist's Gloves"]     = { lvl=52, jobs="RDM",        src="RDM AF",                     notes="En-spell+" },
    ["Temple Gloves"]        = { lvl=52, jobs="MNK",        src="MNK AF",                     notes="Kick Attacks" },
    ["Sorcerer's Gloves"]    = { lvl=52, jobs="BLM",        src="BLM AF",                     notes="Dark element+" },
    ["Rogue's Armlets"]      = { lvl=52, jobs="THF",        src="THF AF",                     notes="Steal+" },
    ["Assassin's Armlets"]   = { lvl=71, jobs="THF",        src="THF AF+1",                   notes="Triple Attack+1" },
    ["Assassin's Armlets +1"]= { lvl=71, jobs="THF",        src="Attowha Chasm quest",        notes="TA+2 DEX+3" },
    ["Ninja Tekko"]          = { lvl=24, jobs="NIN",        src="Craft/NPC",                  notes="Sub-AF NIN hands" },
    ["Hachiya Tekko"]        = { lvl=52, jobs="NIN",        src="NIN AF",                     notes="Dual Wield+" },
    ["Drachen Finger Gauntlets"] = { lvl=52, jobs="DRG",    src="DRG AF",                     notes="Jump+" },
    ["Summoner's Bracers"]   = { lvl=52, jobs="SMN",        src="SMN AF",                     notes="Perpetuation-" },
    ["Saotome Kote"]         = { lvl=71, jobs="SAM",        src="SAM AF2",                    notes="STR+3 STP" },
    ["Scout's Bracers"]      = { lvl=52, jobs="RNG",        src="RNG AF",                     notes="Scavenge+" },
    ["Bard's Cuffs"]         = { lvl=52, jobs="BRD",        src="BRD AF",                     notes="Song recast-" },
    ["Mirage Bazubands"]     = { lvl=52, jobs="BLU",        src="BLU AF",                     notes="Blue Magic+" },
    ["Corsair's Gants"]      = { lvl=50, jobs="COR",        src="COR AF",                     notes="Phantom Roll+" },
    ["Pantin Dastanas"]      = { lvl=52, jobs="PUP",        src="PUP AF",                     notes="Maneuver+" },
    ["Dancer's Bangles"]     = { lvl=52, jobs="DNC",        src="DNC AF (WoTG)",              uncertain=true },
    ["Scholar's Bracers"]    = { lvl=52, jobs="SCH",        src="SCH AF (WoTG)",              uncertain=true },
    -- Relic / HNM
    ["Hecatomb Mittens"]     = { lvl=74, jobs="WAR DRK",    src="Dynamis-Tavnazia",           notes="Acc+/Att+" },
    ["Homam Manopolas"]      = { lvl=74, jobs="DD+hybrid",  src="Salvage",                    notes="Haste+2% Acc+5" },
    ["Nashira Gages"]        = { lvl=73, jobs="BLU SMN",    src="Salvage",                    notes="BP delay- / BLU+" },
    ["Askar Manopolas"]      = { lvl=74, jobs="DD",         src="Nyzul Isle",                 notes="STR+6 STP" },
    ["Denali Gloves"]        = { lvl=71, jobs="RNG",        src="Nyzul Isle",                 notes="RACC+10" },
    ["Morrigan's Cuffs"]     = { lvl=72, jobs="BLM",        src="Salvage Zhayolm",            notes="MAB" },
    ["Marduk's Dastanas"]    = { lvl=72, jobs="mage+hybrid",src="Salvage Arrapago",           notes="haste-related" },
    ["Usukane Gote"]         = { lvl=74, jobs="WAR MNK PLD DRK SAM", src="Salvage",           notes="VIT+ HP+" },
    ["Ares's Gauntlets"]     = { lvl=72, jobs="melee",      src="Salvage",                    notes="DA/ACC" },
    ["Skadi's Bazubands"]    = { lvl=72, jobs="THF RNG NIN BLU", src="Salvage",               notes="Acc/Eva" },
},

-- =============================================================================
-- LEGS (slot 8)
-- =============================================================================
Legs = {
    -- HNM / iconic
    ["Byakko's Haidate"]     = { lvl=74, jobs="DD",         src="HNM: Byakko",                notes="Haste+5% Acc+10" },
    ["Hecatomb Subligar"]    = { lvl=73, jobs="DD",         src="Dynamis-Tavnazia",           notes="Acc+ Att+" },
    ["Enkidu's Subligar"]    = { lvl=72, jobs="WAR MNK THF BST", src="ZNM: Enkidu",           notes="STR+5 Acc+" },
    -- AF legs
    ["Warrior's Cuisses"]    = { lvl=58, jobs="WAR",        src="WAR AF",                     notes="Attack+" },
    ["Beast Trousers"]       = { lvl=60, jobs="BST",        src="BST AF",                     notes="Tame+/Pet enhance" },
    ["Chaos Flanchard"]      = { lvl=60, jobs="DRK",        src="DRK AF",                     notes="Acc+" },
    ["Duelist's Tights"]     = { lvl=58, jobs="RDM",        src="RDM AF",                     notes="MAB+" },
    ["Temple Hose"]          = { lvl=58, jobs="MNK",        src="MNK AF",                     notes="Kick Attacks+" },
    ["Sorcerer's Tonban"]    = { lvl=58, jobs="BLM",        src="BLM AF",                     notes="MND+ MAB+" },
    ["Cleric's Pantaloons"]  = { lvl=50, jobs="WHM",        src="WHM AF+1 quest",             notes="Cure+ MP+", uncertain=true },
    ["Chaos Cuisses"]        = { lvl=58, jobs="DRK",        src="DRK AF",                     notes="Acc+" },
    ["Assassin's Culottes"]  = { lvl=73, jobs="THF",        src="THF AF",                     notes="Movement +12%" },
    ["Ninja Hakama"]         = { lvl=24, jobs="NIN",        src="NPC/Craft",                  notes="Sub-AF NIN legs" },
    ["Hachiya Hakama"]       = { lvl=58, jobs="NIN",        src="NIN AF2",                    notes="Dual Wield+" },
    ["Drachen Brais"]        = { lvl=58, jobs="DRG",        src="DRG AF",                     notes="Jump+ attack" },
    ["Summoner's Spats"]     = { lvl=58, jobs="SMN",        src="SMN AF",                     notes="Perpetuation-" },
    ["Saotome Haidate"]      = { lvl=73, jobs="SAM",        src="SAM AF2",                    notes="STR+ Att+" },
    ["Scout's Braccae"]      = { lvl=58, jobs="RNG",        src="RNG AF",                     notes="STP+" },
    ["Bard's Cannions"]      = { lvl=58, jobs="BRD",        src="BRD AF",                     notes="Song recast-" },
    ["Mirage Shalwar"]       = { lvl=50, jobs="BLU",        src="BLU AF",                     notes="Enhance BLU" },
    ["Corsair's Trews"]      = { lvl=58, jobs="COR",        src="COR AF",                     notes="PH roll+" },
    ["Pantin Churidars"]     = { lvl=58, jobs="PUP",        src="PUP AF",                     notes="Pet: Att+ Acc+" },
    ["Dancer's Tights"]      = { lvl=58, jobs="DNC",        src="DNC AF (WoTG)",              uncertain=true },
    ["Scholar's Pants"]      = { lvl=58, jobs="SCH",        src="SCH AF (WoTG)",              uncertain=true },
    -- Nyzul / Salvage
    ["Askar Dirs"]           = { lvl=74, jobs="DD",         src="Nyzul Isle",                 notes="STR+ STP+" },
    ["Homam Cosciales"]      = { lvl=74, jobs="DD+hybrid",  src="Salvage",                    notes="Haste+2% Acc+" },
    ["Nashira Seraweels"]    = { lvl=73, jobs="BLU SMN",    src="Salvage",                    notes="BLU +skill / BP delay-" },
    ["Denali Kecks"]         = { lvl=71, jobs="RNG",        src="Nyzul Isle",                 notes="RACC+10" },
    ["Morrigan's Pantaloons"]= { lvl=72, jobs="BLM",        src="Salvage Zhayolm",            notes="Fast Cast" },
    ["Marduk's Shalwar"]     = { lvl=72, jobs="mage+hybrid",src="Salvage Arrapago",           notes="haste-related" },
    ["Usukane Hizayoroi"]    = { lvl=74, jobs="WAR MNK PLD DRK SAM", src="Salvage",           notes="VIT+ HP+" },
    ["Ares's Flanchard"]     = { lvl=72, jobs="melee",      src="Salvage",                    notes="DA/ACC" },
    ["Skadi's Chausses"]     = { lvl=72, jobs="THF RNG NIN BLU", src="Salvage",               notes="Acc/Eva" },
    -- Reraise / event
    ["Wyrm Brais"]           = { lvl=73, jobs="DRG",        src="DRG AF2",                    notes="Jump+" },
},

-- =============================================================================
-- FEET (slot 9)
-- =============================================================================
Feet = {
    -- Movement + iconic
    ["Rutter Sabatons"]      = { lvl=74, jobs="DD",         src="ZNM: Ulhuadshi",             notes="Movement +12% Acc+" },
    ["Herald's Gaiters"]     = { lvl=73, jobs="DD",         src="Mog Bonanza / event",        event=true, wardrobe8=true, notes="Movement +12% Haste+" },
    ["Leaping Boots"]        = { lvl=15, jobs="all",        src="NM: Leaping Lizzy drop",     notes="Acc+/Att+/Agi+" },
    ["Bounding Boots"]       = { lvl=25, jobs="all",        src="BCNM Carby Mitts",           notes="Movement +12%" },
    ["Dune Boots"]           = { lvl=30, jobs="all",        src="NPC",                        notes="Movement +12%" },
    -- AF feet
    ["Warrior's Calligae"]   = { lvl=66, jobs="WAR",        src="WAR AF",                     notes="Att+ Haste+" },
    ["Beast Gaiters"]        = { lvl=66, jobs="BST",        src="BST AF",                     notes="Tame+ Pet Acc+" },
    ["Chaos Sollerets"]      = { lvl=66, jobs="DRK",        src="DRK AF",                     notes="Att+ Acc+" },
    ["Duelist's Boots"]      = { lvl=66, jobs="RDM",        src="RDM AF",                     notes="En-spell+" },
    ["Temple Gaiters"]       = { lvl=66, jobs="MNK",        src="MNK AF",                     notes="Counter+ Kick+" },
    ["Sorcerer's Sabots"]    = { lvl=66, jobs="BLM",        src="BLM AF",                     notes="MAB+ element+" },
    ["Rogue's Poulaines"]    = { lvl=66, jobs="THF",        src="THF AF",                     notes="Flee+" },
    ["Ninja Kyahan"]         = { lvl=27, jobs="NIN",        src="NPC/Craft",                  notes="Sub-AF NIN feet" },
    ["Hachiya Kyahan"]       = { lvl=66, jobs="NIN",        src="NIN AF2",                    notes="DW+/Stealth" },
    ["Drachen Greaves"]      = { lvl=66, jobs="DRG",        src="DRG AF",                     notes="Jump+" },
    ["Summoner's Pigaches"]  = { lvl=66, jobs="SMN",        src="SMN AF",                     notes="Perp- Movement" },
    ["Saotome Sune-Ate"]     = { lvl=73, jobs="SAM",        src="SAM AF2",                    notes="STR+ Zan+" },
    ["Scout's Socks"]        = { lvl=66, jobs="RNG",        src="RNG AF",                     notes="STP+" },
    ["Bard's Slippers"]      = { lvl=66, jobs="BRD",        src="BRD AF",                     notes="Song+" },
    ["Mirage Charuqs"]       = { lvl=66, jobs="BLU",        src="BLU AF",                     notes="BLU skill+ Movement" },
    ["Corsair's Bottes"]     = { lvl=66, jobs="COR",        src="COR AF",                     notes="Roll+ Movement+" },
    ["Pantin Babouches"]     = { lvl=66, jobs="PUP",        src="PUP AF",                     notes="Pet feet / Automaton stat+" },
    ["Dancer's Toe Shoes"]   = { lvl=66, jobs="DNC",        src="DNC AF (WoTG)",              uncertain=true },
    ["Scholar's Loafers"]    = { lvl=66, jobs="SCH",        src="SCH AF (WoTG)",              uncertain=true },
    -- Relic AF+1 / HNM / Salvage
    ["Homam Gambieras"]      = { lvl=74, jobs="DD+hybrid",  src="Salvage",                    notes="Haste+2% STR+" },
    ["Askar Gambieras"]      = { lvl=74, jobs="DD",         src="Nyzul Isle",                 notes="STR+ STP+" },
    ["Denali Gamashes"]      = { lvl=71, jobs="RNG",        src="Nyzul Isle",                 notes="RACC+ RATT+" },
    ["Morrigan's Pigaches"]  = { lvl=72, jobs="BLM",        src="Salvage Zhayolm",            notes="MAB" },
    ["Marduk's Crackows"]    = { lvl=72, jobs="mage+hybrid",src="Salvage Arrapago",           notes="haste" },
    ["Usukane Sune-Ate"]     = { lvl=74, jobs="WAR MNK PLD DRK SAM", src="Salvage",           notes="VIT+ HP+" },
    ["Ares's Sollerets"]     = { lvl=72, jobs="melee",      src="Salvage",                    notes="DA/ACC" },
    ["Skadi's Jambeaux"]     = { lvl=72, jobs="THF RNG NIN BLU", src="Salvage",               notes="Acc/Eva" },
    ["Nashira Crackows"]     = { lvl=73, jobs="BLU SMN",    src="Salvage",                    notes="Perp- / BLU skill" },
    ["Raider's Poulaines"]   = { lvl=73, jobs="THF",        src="WoTG AF+1 (THF)",            uncertain=true, notes="TA+/DEX+" },
    ["Wyrm Greaves"]         = { lvl=72, jobs="DRG",        src="DRG AF2",                    notes="Jump+" },
},

-- =============================================================================
-- NECK (slot 10)
-- =============================================================================
Neck = {
    ["Peacock Amulet"]       = { lvl=56, jobs="all",     src="BCNM60: Royal Jelly",       notes="Acc+10 STR+5" },
    ["Peacock Charm"]        = { lvl=56, jobs="all",     src="BCNM60 HQ drop",            notes="Acc+10 Att+10" },
    ["Uggalepih Pendant"]    = { lvl=66, jobs="mages",   src="KSNM30: Dark Legacy",       notes="MAB+5 MP-25%" },
    ["Chivalrous Chain"]     = { lvl=70, jobs="PLD WAR DRK BRD BST", src="BCNM70: Shattering Stars", notes="Acc+5 Att+5" },
    ["Loricate Torque"]      = { lvl=71, jobs="all",     src="Treasure Casket",           notes="PDT-6% MDT-6%" },
    ["Beastmaster's Collar"] = { lvl=60, jobs="BST",     src="BST merit purchase",        notes="Pet Att+15" },
    ["Agitator's Collar"]    = { lvl=72, jobs="WAR MNK", src="CoP: Grimoire of Twilight", notes="Enmity+5" },
    ["Prelate's Collar"]     = { lvl=72, jobs="PLD",     src="CoP",                       notes="Enmity+7" },
    ["Royal Knight's Collar"]= { lvl=72, jobs="PLD",     src="San d'Oria mission",        notes="PDT-3% Enmity+3" },
    ["Opo-opo Necklace"]     = { lvl=51, jobs="all",     src="Yagudo PH drop",            notes="TP bonus" },
    ["Fylgja Torque +1"]     = { lvl=71, jobs="all",     src="CoP KSNM",                  notes="Cure Potency+3" },
    ["Ganesha's Mala"]       = { lvl=70, jobs="MNK PUP", src="HNM: Ouryu/Azdaja",         notes="Subtle Blow+5 Kick+8" },
    ["Phalaina Locket"]      = { lvl=72, jobs="all",     src="ZNM: Experimental Lacquer", notes="HP+ MP+" },
    ["Colossus's Torque"]    = { lvl=71, jobs="WAR MNK THF DRK SAM NIN", src="ZNM: Colossus", notes="Att+5" },
    ["Stoicheion Medal"]     = { lvl=74, jobs="mages",   src="ZNM: Experimental Lacquer", notes="MAB+3 MACC+3" },
    ["Magoraga Beads"]       = { lvl=72, jobs="all",     src="CoP: PM3 reward",           notes="Status ailment dur-25%" },
    ["Cassie Earring"]       = { lvl=60, jobs="all",     src="HNM: Cassie drop",          notes="HP+60" },
    ["Promise Badge"]        = { lvl=68, jobs="all",     src="CoP: Promyvion",            notes="MP+15 regen" },
    ["Enfeebling Torque"]    = { lvl=71, jobs="RDM BLM WHM SCH BRD", src="CoP KSNM",       notes="Enfeeble skill+5" },
    ["Healer's Torque"]      = { lvl=71, jobs="WHM SCH", src="CoP KSNM",                  notes="Healing skill+5" },
    -- Elemental WS gorgets
    ["Soil Gorget"]          = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Earth WS +10% dmg" },
    ["Light Gorget"]         = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Light WS +10% dmg" },
    ["Flame Gorget"]         = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Fire WS +10% dmg" },
    ["Snow Gorget"]          = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Ice WS +10% dmg" },
    ["Breeze Gorget"]        = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Wind WS +10% dmg" },
    ["Aqua Gorget"]          = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Water WS +10% dmg" },
    ["Thunder Gorget"]       = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Lightning WS +10% dmg" },
    ["Shadow Gorget"]        = { lvl=72, jobs="all",     src="BCNM: Elemental",           notes="Dark WS +10% dmg" },
    -- Virtue Stones (CP rewards)
    ["Justice Torque"]       = { lvl=72, jobs="all",     src="CP reward",                 notes="DT-3%", event=true, wardrobe8=true },
    ["Faith Torque"]         = { lvl=72, jobs="all",     src="CP reward",                 notes="MDT-3%", event=true, wardrobe8=true },
    ["Love Torque"]          = { lvl=72, jobs="all",     src="CP reward",                 notes="PDT-3%", event=true, wardrobe8=true },
    ["Hope Torque"]          = { lvl=72, jobs="all",     src="CP reward",                 notes="BDT-3%", event=true, wardrobe8=true },
    ["Prudence Torque"]      = { lvl=72, jobs="all",     src="CP reward",                 notes="Enmity-3", event=true, wardrobe8=true },
    ["Temperance Torque"]    = { lvl=72, jobs="all",     src="CP reward",                 notes="Enmity+3", event=true, wardrobe8=true },
},

-- =============================================================================
-- WAIST (slot 11)
-- =============================================================================
Waist = {
    ["Swift Belt"]           = { lvl=70, jobs="melee",   src="BCNM: Incursion",           notes="Haste+6% Acc+4 Att+4" },
    ["Warwolf Belt"]         = { lvl=71, jobs="all",     src="HNM: King Vinegarroon",     notes="STR+5 DEX+5 Att+5" },
    ["Speed Belt"]           = { lvl=68, jobs="all",     src="BCNM60",                    notes="Haste+2% Acc+4" },
    ["Life Belt"]            = { lvl=55, jobs="all",     src="BCNM60: Royal Jelly",       notes="Acc+10" },
    ["Life Belt +1"]         = { lvl=55, jobs="all",     src="BCNM60 HQ",                 notes="Acc+10 +HQ" },
    ["Tilt Belt"]            = { lvl=71, jobs="DD",      src="ZNM: Tinnin drop",          notes="Att+4 ACC+2" },
    ["Corsette +1"]          = { lvl=72, jobs="BRD",     src="BCNM70 HQ",                 notes="CHR+3 Music skill+6" },
    ["Chaac Belt"]           = { lvl=74, jobs="all",     src="ZNM: Chaac drop",           notes="Acc+5 Att+5 Eva-5" },
    ["Elanid Belt"]          = { lvl=74, jobs="mages",   src="ZNM: Experimental Lacquer", notes="MACC+5" },
    ["Sacro Cord"]           = { lvl=72, jobs="mages",   src="CoP: PM3 reward",           notes="MP+15" },
    ["Penitent's Rope"]      = { lvl=72, jobs="mages",   src="Dynamis-Buburimu",          notes="Enmity-3" },
    ["Warlock's Sash"]       = { lvl=72, jobs="mages",   src="Dynamis",                   notes="MAB+2" },
    ["Mohbwa Sash"]          = { lvl=71, jobs="all",     src="ZNM: Tiny Mandragora",      notes="Store TP+3" },
    ["Boxer's Mantle"]       = { lvl=70, jobs="MNK",     src="MNK AF3 quest",             notes="MNK +kick" },
    -- Elemental resistance
    ["Fire Belt"]            = { lvl=49, jobs="all",     src="Mysticmaker Profblix drop", notes="Fire res+15" },
    ["Ice Belt"]             = { lvl=49, jobs="all",     src="NM drop",                   notes="Ice res+15" },
    ["Wind Belt"]            = { lvl=49, jobs="all",     src="NM drop",                   notes="Wind res+15" },
    ["Earth Belt"]           = { lvl=49, jobs="all",     src="NM drop",                   notes="Earth res+15" },
    ["Thunder Belt"]         = { lvl=49, jobs="all",     src="NM drop",                   notes="Lightning res+15" },
    ["Water Belt"]           = { lvl=49, jobs="all",     src="NM drop",                   notes="Water res+15" },
    ["Light Belt"]           = { lvl=49, jobs="all",     src="NM drop",                   notes="Light res+15" },
    ["Dark Belt"]            = { lvl=49, jobs="all",     src="NM drop",                   notes="Dark res+15" },
    -- Elemental WS belts
    ["Soil Belt"]            = { lvl=72, jobs="all",     src="BCNM Elemental",            notes="Earth WS mod" },
    ["Flame Belt"]           = { lvl=72, jobs="all",     src="BCNM Elemental",            notes="Fire WS mod" },
    ["Snow Belt"]            = { lvl=72, jobs="all",     src="BCNM Elemental",            notes="Ice WS mod" },
    ["Breeze Belt"]          = { lvl=72, jobs="all",     src="BCNM Elemental",            notes="Wind WS mod" },
    ["Aqua Belt"]            = { lvl=72, jobs="all",     src="BCNM Elemental",            notes="Water WS mod" },
    ["Shadow Belt"]          = { lvl=72, jobs="all",     src="BCNM Elemental",            notes="Dark WS mod" },
    -- PLD/tank
    ["Royal Knight's Belt"]  = { lvl=70, jobs="PLD",     src="San d'Oria mission",        notes="Enmity+3" },
    ["Alkyoneus's Belt"]     = { lvl=72, jobs="DD",      src="ZNM: Alkyoneus",            notes="HP+20 STR+3" },
},

-- =============================================================================
-- EAR (slots 12 + 13; same table -- items can slot either)
-- =============================================================================
Ear = {
    ["Brutal Earring"]       = { lvl=75, jobs="melee",   src="ZNM: Brutal Earring quest", notes="Dbl Atk+5% STR+1" },
    ["Suppanomimi"]          = { lvl=75, jobs="NIN DW",  src="ZNM: Experimental Lacquer", notes="Dual Wield+5%" },
    ["Loquac. Earring"]      = { lvl=75, jobs="mages",   src="CoP KSNM: Divine Might",    notes="FastCast+2%" },
    ["Musical Earring"]      = { lvl=41, jobs="BRD",     src="BCNM30",                    notes="Music skill+3" },
    ["Moldavite Earring"]    = { lvl=46, jobs="mages",   src="BCNM40: Shell Shocker",     notes="MAB+4" },
    ["Snow Ear"]             = { lvl=50, jobs="BLM",     src="ENM/BCNM50",                notes="Ice MAB+3" },
    ["Static Earring"]       = { lvl=50, jobs="BLM",     src="BCNM50",                    notes="Thunder MAB+3" },
    ["Ethereal Earring"]     = { lvl=45, jobs="all",     src="ENM: Waking Dreams",        notes="TP save on dmg received" },
    ["Minuet Earring"]       = { lvl=71, jobs="BRD",     src="BRD AF+1 quest",            notes="Minuet effect+1" },
    ["Magnetic Earring"]     = { lvl=56, jobs="RNG SAM BRD", src="BCNM: Ark Angels",      notes="Store TP+3" },
    ["Merman's Earring"]     = { lvl=30, jobs="all",     src="NPC",                       notes="Dmg taken -2%" },
    ["Volley Earring"]       = { lvl=72, jobs="RNG",     src="BCNM70",                    notes="Ranged Acc+5" },
    ["Beastly Earring"]      = { lvl=68, jobs="BST",     src="BST AF quest",              notes="Charm success+4" },
    ["Assault Earring"]      = { lvl=67, jobs="melee",   src="Assault (Salvage)",         notes="Acc+3 Dex+1" },
    ["Hollow Earring"]       = { lvl=70, jobs="NIN THF", src="HNM drop",                  notes="HP+10 Haste" },
    ["Reraise Earring"]      = { lvl=10, jobs="all",     src="NPC/quest",                 notes="Reraise effect" },
    ["Reraise Earring II"]   = { lvl=20, jobs="all",     src="NPC/quest",                 notes="Reraise II" },
    ["Reraise Earring III"]  = { lvl=40, jobs="all",     src="NPC/quest",                 notes="Reraise III" },
    ["Melody Earring"]       = { lvl=71, jobs="BRD",     src="BRD AF+1 quest",            notes="Music skill+" },
    ["Attuned Earring"]      = { lvl=69, jobs="mages",   src="HNM drop",                  notes="CHR+4" },
    ["Bushinomimi"]          = { lvl=72, jobs="SAM DRK", src="ZNM: Experimental Lacquer", notes="Store TP+1 STR+1" },
    ["Hecate's Earring"]     = { lvl=74, jobs="BLM RDM SCH", src="HNM Hecatoncheir",      notes="MAB+5" },
    ["Energy Earring +1"]    = { lvl=50, jobs="all",     src="NPC HQ",                    notes="MP+15" },
    ["Energy Earring +2"]    = { lvl=50, jobs="all",     src="NPC HQ2",                   notes="MP+20" },
    ["Relaxing Earring"]     = { lvl=55, jobs="mages",   src="Lottery NM",                notes="MP+ refresh tick" },
    ["Dodge Earring"]        = { lvl=70, jobs="MNK",     src="MNK AF3 quest",             notes="Dodge dur+" },
    ["Focus Earring"]        = { lvl=68, jobs="MNK",     src="MNK quest",                 notes="Focus dur+" },
    ["Anticipate Earring"]   = { lvl=60, jobs="SAM",     src="SAM quest",                 notes="Third Eye dur+" },
    ["Pixie Earring"]        = { lvl=70, jobs="mages",   src="HNM drop",                  notes="Light MAB+" },
    -- Summoner's Horn is a BRD/SMN earring (quirky slot)
    ["Summoner's Horn"]      = { lvl=52, jobs="SMN",     src="SMN AF",                    notes="SMN earring (not head)" },
},

-- =============================================================================
-- RING (slots 14 + 15; same table)
-- =============================================================================
Ring = {
    -- 100-token BCNM rings (ToAU Divine Might)
    ["Rajas Ring"]           = { lvl=75, jobs="DD",       src="ToAU 100-token BCNM: Divine Might", notes="STR+5 Store TP+5 Dbl Atk+1%" },
    ["Sattva Ring"]          = { lvl=75, jobs="PLD tank", src="ToAU 100-token BCNM",       notes="Enmity+5 Regen" },
    ["Tamas Ring"]           = { lvl=75, jobs="mages",    src="ToAU 100-token BCNM",       notes="INT+6 MAB+3 MACC+3" },
    -- Common ACC rings
    ["Sniper's Ring"]        = { lvl=40, jobs="all",      src="Sumar NM / NPC",            notes="Acc+5" },
    ["Sniper's Ring +1"]     = { lvl=40, jobs="all",      src="NPC HQ",                    notes="Acc+6" },
    ["Toreador's Ring"]      = { lvl=40, jobs="all",      src="NPC Jeuno",                 notes="Acc+5" },
    ["Woodsman Ring"]        = { lvl=63, jobs="RNG SAM BRD WAR", src="NPC Mhaura",         notes="Ranged Acc+5 Store TP+2" },
    -- Defense
    ["Diamond Ring"]         = { lvl=25, jobs="all",      src="NPC",                       notes="MDT-3%" },
    ["Shell Ring"]           = { lvl=40, jobs="all",      src="NPC",                       notes="MDT-3%" },
    ["Dark Ring"]            = { lvl=75, jobs="all",      src="Nyzul Isle",                notes="PDT-5 MDT-5 (augments)" },
    ["Shadow Ring"]          = { lvl=72, jobs="all",      src="BCNM70",                    notes="MDT-6%" },
    -- Elemental MAB
    ["Flame Ring"]           = { lvl=75, jobs="BLM",      src="BCNM: Flames",              notes="Fire MAB+10" },
    ["Snow Ring"]            = { lvl=75, jobs="BLM",      src="BCNM: Jungle Boogiemen",    notes="Ice MAB+10" },
    ["Breeze Ring"]          = { lvl=75, jobs="BLM",      src="BCNM",                      notes="Wind MAB+10" },
    ["Aqua Ring"]            = { lvl=75, jobs="BLM",      src="BCNM",                      notes="Water MAB+10" },
    ["Soil Ring"]            = { lvl=75, jobs="BLM",      src="BCNM",                      notes="Earth MAB+10" },
    ["Thunder Ring"]         = { lvl=75, jobs="BLM",      src="BCNM",                      notes="Lightning MAB+10" },
    ["Light Ring"]           = { lvl=75, jobs="BLM",      src="BCNM",                      notes="Light MAB+10" },
    ["Icesoul Ring"]         = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Ice MAB+5" },
    ["Firesoul Ring"]        = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Fire MAB+5" },
    ["Windsoul Ring"]        = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Wind MAB+5" },
    ["Watersoul Ring"]       = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Water MAB+5" },
    ["Earthsoul Ring"]       = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Earth MAB+5" },
    ["Thundersoul Ring"]     = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Lightning MAB+5" },
    ["Lightsoul Ring"]       = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Light MAB+5" },
    ["Darksoul Ring"]        = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Dark MAB+5" },
    -- Mage MP / Refresh
    ["Ether Ring"]           = { lvl=27, jobs="mages",    src="BCNM20: Ocean Serpent",     notes="MP+10 refresh tick" },
    ["Star Ring"]            = { lvl=30, jobs="all",      src="BCNM30",                    notes="MP+20" },
    ["Serket Ring"]          = { lvl=65, jobs="all",      src="HNM: Serket drop",          notes="HP+15 MP+15" },
    ["Strendu Ring"]         = { lvl=73, jobs="BLM",      src="ZNM: Serket",               notes="MAB+5" },
    ["Hecate's Ring"]        = { lvl=72, jobs="mages",    src="BCNM70",                    notes="MAB+2 INT+2" },
    -- ZNM / ToAU
    ["Ulthalam's Ring"]      = { lvl=74, jobs="melee",    src="ZNM: Ulthalam",             notes="Att+5 STR+3" },
    ["Wivre Ring"]           = { lvl=74, jobs="PLD WAR",  src="ZNM: Wivre",                notes="VIT+4" },
    ["Barataria Ring"]       = { lvl=74, jobs="mages",    src="ZNM: Experimental Lacquer", notes="INT+3 MAB+3" },
    -- Job-specific
    ["Evoker's Ring"]        = { lvl=64, jobs="SMN",      src="SMN quest",                 notes="MP refresh tick" },
    ["Astral Ring"]          = { lvl=68, jobs="SMN",      src="SMN merit",                 notes="Avatar perp cost-5" },
    ["Beast Ring"]           = { lvl=61, jobs="BST",      src="BST AF quest",              notes="Charm+1" },
    -- Utility
    ["Mermaid Ring"]         = { lvl=11, jobs="all",      src="Fishing guild",             notes="Water Breathing" },
    ["Enfeebling Ring"]      = { lvl=71, jobs="mages",    src="BCNM: Groin Yoin's",        notes="Enfeeble skill+5" },
    ["Elemental Ring"]       = { lvl=71, jobs="mages",    src="BCNM70",                    notes="Elemental skill+5" },
},

-- =============================================================================
-- BACK (slot 16)
-- =============================================================================
Back = {
    ["Rainbow Cape"]         = { lvl=56, jobs="all",     src="BCNM30",                    notes="Elem+5 all" },
    ["Rainbow Cape +1"]      = { lvl=56, jobs="all",     src="BCNM30 HQ",                 notes="Elem+6 all" },
    ["Cerberus Mantle"]      = { lvl=72, jobs="melee",   src="HNM: Cerberus drop",        notes="STR+5 Att+10" },
    ["Cerberus Mantle +1"]   = { lvl=72, jobs="melee",   src="HNM HQ",                    notes="STR+6 Att+12" },
    ["Shadow Mantle"]        = { lvl=72, jobs="all",     src="CoP: Promyvion / Spire",    notes="20% absorb WS dmg" },
    ["Amemet Mantle"]        = { lvl=58, jobs="melee",   src="HNM: Simurgh drop",         notes="STR+2 Att+5" },
    ["Amemet Mantle +1"]     = { lvl=58, jobs="melee",   src="HNM HQ",                    notes="STR+3 Att+7" },
    ["Forager's Mantle"]     = { lvl=74, jobs="all",     src="ZNM: Daggerclaw",           notes="Acc+5 Att+5" },
    ["Nexus Cape"]           = { lvl=20, jobs="all",     src="CoP: Garden of Antiquity",  notes="Warp back to Mothercrystal" },
    ["Prism Cape"]           = { lvl=70, jobs="BLM",     src="BCNM: Rank 10 reward",      notes="MAB+5" },
    ["Antimatter Mantle"]    = { lvl=72, jobs="all",     src="CoP KSNM: Divine Might",    notes="Resist Terror" },
    ["Bat Cape"]             = { lvl=19, jobs="all",     src="NM: Jaggedy-Eared Jack",    notes="CHR-1 STR+3 (low-level)" },
    ["Errant Cape"]          = { lvl=52, jobs="mages",   src="BCNM40",                    notes="MP+15" },
    ["Astral Cape"]          = { lvl=60, jobs="SMN",     src="SMN BCNM",                  notes="Avatar perp cost-3" },
    ["Royal Knight's Cloak"] = { lvl=72, jobs="PLD",     src="San d'Oria mission",        notes="Enmity+3 MDT-2%" },
    ["Mohbwa Scarf"]         = { lvl=72, jobs="DD",      src="ZNM: Mandra Dynasty",       uncertain=true, notes="Haste+2%" },
    ["Hippomenes Cape"]      = { lvl=72, jobs="melee",   src="Nyzul Isle",                notes="Movement+10%" },
    ["Mecisto. Mantle"]      = { lvl=70, jobs="all",     src="Mecisto Cape upgrade",      event=true, wardrobe8=true, notes="+20% CP gain" },
    -- Reraise alt (era replacement for Twilight Mail body)
    ["Nascent Cape"]         = { lvl=68, jobs="RDM",     src="RDM AF3 quest",             notes="Fast Cast+" },
    ["Beast Mantle"]         = { lvl=60, jobs="BST",     src="BST AF",                    notes="Pet Att+" },
    ["Ninja Cape"]           = { lvl=69, jobs="NIN",     src="NIN AF+1 quest",            notes="Utsusemi casttime-" },
    ["Dragon Cape"]          = { lvl=60, jobs="DRG",     src="DRG AF",                    notes="Dragon stat+" },
},

-- =============================================================================
-- MAIN (slot 1) -- weapons grouped by type via `type=` field
-- =============================================================================
Main = {
    -- RELIC WEAPONS (Dynamis) -- all ERA lvl 75
    ["Mandau"]               = { lvl=75, jobs="THF", type="Dagger",       src="THF Relic (Dynamis)",   notes="Daze proc TH+2" },
    ["Mjollnir"]             = { lvl=75, jobs="WHM", type="Club",         src="WHM Relic",             notes="MND+ dmg proc" },
    ["Excalibur"]            = { lvl=75, jobs="PLD", type="Sword",        src="PLD Relic",             notes="Knights of Round WS" },
    ["Ragnarok"]             = { lvl=75, jobs="DRK", type="Great Sword",  src="DRK Relic",             notes="Catastrophe WS" },
    ["Guttler"]              = { lvl=75, jobs="BST", type="Axe",          src="BST Relic",             notes="Primal Rend WS" },
    ["Bravura"]              = { lvl=75, jobs="WAR", type="Great Axe",    src="WAR Relic",             notes="Metatron Torment WS" },
    ["Gungnir"]              = { lvl=75, jobs="DRG", type="Polearm",      src="DRG Relic",             notes="Geirskogul WS" },
    ["Kikoku"]               = { lvl=75, jobs="NIN", type="Katana",       src="NIN Relic",             notes="Blade: Metsu WS" },
    ["Amanomurakumo"]        = { lvl=75, jobs="SAM", type="Great Katana", src="SAM Relic",             notes="Tachi: Kaiten WS" },
    ["Spharai"]              = { lvl=75, jobs="MNK", type="H2H",          src="MNK Relic",             notes="Final Heaven WS" },
    ["Apocalypse"]           = { lvl=75, jobs="DRK", type="Scythe",       src="DRK Relic (alt)",       notes="Catastrophe WS alt" },
    ["Yoichinoyumi"]         = { lvl=75, jobs="RNG", type="Bow",          src="RNG Relic (ranged)",    notes="see Range slot entry" },
    ["Annihilator"]          = { lvl=75, jobs="RNG COR", type="Marksman", src="RNG Relic (ranged)",    notes="see Range slot entry" },
    ["Gjallarhorn"]          = { lvl=75, jobs="BRD", type="Instrument",   src="BRD Relic",             notes="Song +effect +range" },
    -- MYTHIC WEAPONS (ToAU)
    ["Joyeuse"]              = { lvl=71, jobs="PLD WAR RDM DRK BRD BST COR", type="Sword", src="BCNM70: Shattering Stars", notes="Extra attack proc (iconic DW sword)" },
    ["Nirvana"]              = { lvl=75, jobs="SMN", type="Staff",        src="SMN Mythic",            notes="Perp cost-14 pet skill+5" },
    ["Destroyers"]            = { lvl=75, jobs="MNK", type="H2H",          src="MNK Mythic",            notes="Stunning attack" },
    ["Terpsichore"]          = { lvl=75, jobs="DNC", type="Dagger",       src="DNC Mythic (WoTG)",     uncertain=true },
    -- Daggers
    ["Hornetneedle"]         = { lvl=75, jobs="THF",  type="Dagger",      src="ZNM: Experimental Lacquer", notes="High-TP dagger" },
    ["Senjuinrikio"]         = { lvl=73, jobs="THF RDM DNC NIN", type="Dagger", src="HNM",              notes="Acc+10" },
    ["Jammadhar"]            = { lvl=63, jobs="THF RNG", type="Dagger",   src="Craft",                 notes="High base dmg" },
    ["Blau Dolch"]           = { lvl=68, jobs="DNC COR WAR", type="Dagger", src="NPC Aht Urhgan",      notes="Haste+5%" },
    ["Thief's Knife"]        = { lvl=70, jobs="THF",  type="Dagger",      src="BCNM: Perfidious Bellies", notes="TH+1" },
    ["Mythril Dagger"]       = { lvl=15, jobs="many", type="Dagger",      src="NPC/craft",             notes="Low-lvl starter" },
    -- Swords
    ["Naegling"]             = { lvl=75, jobs="PLD RDM WAR DRK DNC", type="Sword", src="BCNM: Phantom Gem (CoP)", notes="Savage Blade" },
    ["Durandal"]             = { lvl=75, jobs="PLD WAR DRK BRD BST COR", type="Sword", src="HNM: Bahamut v1", notes="Att+15 Acc+15" },
    ["Carbide Sword"]        = { lvl=70, jobs="PLD WAR RDM DRK BRD BST COR", type="Sword", src="Craft/BCNM", notes="Mid-tier DD sword" },
    -- Clubs / staves (WHM / BLM / mages)
    ["Earth Staff"]          = { lvl=51, jobs="BLM BLU", type="Staff",    src="NPC/quest",             notes="Earth elemental staff" },
    ["Fire Staff"]           = { lvl=51, jobs="BLM BLU", type="Staff",    src="NPC/quest",             notes="Fire elemental staff" },
    ["Water Staff"]          = { lvl=51, jobs="BLM BLU", type="Staff",    src="NPC/quest",             notes="Water elemental staff" },
    ["Ice Staff"]            = { lvl=51, jobs="BLM BLU", type="Staff",    src="NPC/quest",             notes="Ice elemental staff" },
    ["Wind Staff"]           = { lvl=51, jobs="BLM BLU", type="Staff",    src="NPC/quest",             notes="Wind elemental staff" },
    ["Thunder Staff"]        = { lvl=51, jobs="BLM BLU", type="Staff",    src="NPC/quest",             notes="Lightning elemental staff" },
    ["Light Staff"]          = { lvl=51, jobs="mages",   type="Staff",    src="NPC/quest",             notes="Light staff (+healing, +Cure)" },
    ["Dark Staff"]           = { lvl=51, jobs="BLM DRK", type="Staff",    src="NPC/quest",             notes="Dark staff (+drain/aspir)" },
    ["Chatoyant Staff"]      = { lvl=70, jobs="all",     type="Staff",    src="NPC/BCNM",              notes="-enmity staff" },
    ["Terra's Staff"]        = { lvl=75, jobs="BLM",     type="Staff",    src="HNM / quest",           notes="HQ elemental staff" },
    -- Polearms (DRG)
    ["Thieving Lance"]       = { lvl=72, jobs="DRG",     type="Polearm",  src="ZNM",                   notes="TA proc" },
    -- Katanas (NIN)
    ["Hagun"]                = { lvl=71, jobs="SAM NIN", type="Great Katana", src="HNM",               notes="Great Katana dmg" },
    ["Pole Grip"]            = { lvl=60, jobs="all",     type="Grip",     src="NPC",                   notes="Staff/Polearm grip bonus" },
    -- H2H
    ["Ohtas"]                = { lvl=74, jobs="MNK",     type="H2H",      src="HNM",                   notes="Str+ Att+" },
    ["Kokou Ken"]            = { lvl=70, jobs="MNK",     type="H2H",      src="Craft/BCNM",            notes="Mid-tier H2H" },
    -- Instruments (BRD; see also Range)
    ["Marsyas"]              = { lvl=72, jobs="BRD",     type="Instrument", src="HNM",                 notes="March +1 effect" },
    ["Faerie Piccolo"]       = { lvl=50, jobs="BRD",     type="Instrument", src="NPC/craft",           notes="Wind instrument" },
    ["Mary's Horn"]          = { lvl=50, jobs="BRD",     type="Instrument", src="NPC/craft",           notes="String instrument" },
    ["Angel Lyre"]           = { lvl=50, jobs="BRD",     type="Instrument", src="NPC/craft",           notes="Fallback / Lullaby" },
    ["Daurdabla"]            = { lvl=74, jobs="BRD",     type="Instrument", src="CoP/Besieged",        uncertain=true, notes="-castcast" },
    ["Horn"]                 = { lvl=20, jobs="BRD",     type="Instrument", src="NPC",                 notes="Low-level starter" },
    ["Cornette"]             = { lvl=7,  jobs="BRD",     type="Instrument", src="NPC",                 notes="Starter wind" },
    ["Harpsichord"]          = { lvl=1,  jobs="BRD",     type="Instrument", src="NPC",                 notes="Starter" },
},

-- =============================================================================
-- SUB (slot 2) -- shields, grips, sub-weapons for dual wield
-- =============================================================================
Sub = {
    -- Shields (PLD / mage / off-hand)
    ["Genbu's Shield"]       = { lvl=70, jobs="PLD WHM BLM RDM BRD", src="HNM: Genbu drop",    notes="DEF+ MDB+ magical shield" },
    ["Aegis"]                = { lvl=75, jobs="PLD",     src="PLD Relic (Dynamis-Tavnazia)",  notes="MDB+ ultimate PLD shield" },
    ["Ochain"]               = { lvl=75, jobs="PLD",     src="PLD mythic / BCNM",             uncertain=true, notes="Perfect Shield chance" },
    ["Royal Squire's Shield"]= { lvl=52, jobs="PLD",     src="PLD AF quest",                   notes="AF shield" },
    ["Royal Knight's Shield"]= { lvl=71, jobs="PLD",     src="PLD AF+1 quest",                 notes="HQ AF shield" },
    ["Elemental Shield"]     = { lvl=70, jobs="PLD",     src="BCNM70",                         notes="Elem res" },
    ["Buckler"]              = { lvl=5,  jobs="many",    src="NPC",                            notes="Starter shield" },
    ["Lauan Shield"]         = { lvl=15, jobs="many",    src="Craft",                          notes="Mid-low shield" },
    -- Grips (staff / polearm)
    ["Pole Grip"]            = { lvl=60, jobs="all",     src="NPC",                            notes="Staff / Polearm grip" },
    ["Bugard Strap"]         = { lvl=65, jobs="staves",  src="Craft",                          notes="Staff grip +dmg" },
    -- Sub-weapons (dual wield NIN)
    ["Fuma Shuriken"]        = { lvl=50, jobs="NIN THF", src="Craft",                          notes="Shuriken ranged (NIN sub)" },
    -- Carnwenhan sub for BRD (Mythic sub-main)
    ["Kali"]                 = { lvl=72, jobs="BRD",     src="ZNM",                            uncertain=true, notes="BRD instrument sub" },
},

-- =============================================================================
-- RANGE (slot 3) -- bows, guns, crossbows, instruments if treated as ranged
-- =============================================================================
Range = {
    -- Bows (RNG primary; SAM/THF use too)
    ["Yoichinoyumi"]         = { lvl=75, jobs="RNG",  src="RNG Relic (Dynamis)",          notes="Namas Arrow WS" },
    ["Fail-Not"]             = { lvl=73, jobs="RNG SAM", src="ZNM / Salvage",             notes="High-tier bow" },
    ["Eurytos' Bow"]         = { lvl=71, jobs="RNG THF SAM", src="BCNM: ZNM",             notes="Acc/Att" },
    ["Selene's Bow"]         = { lvl=69, jobs="RNG THF SAM BLU", src="Craft HQ",          notes="Mid-tier bow" },
    ["Power Bow"]            = { lvl=60, jobs="RNG",  src="Craft",                        notes="Classic mid bow" },
    -- Guns (COR / RNG)
    ["Annihilator"]          = { lvl=75, jobs="RNG",  src="RNG Relic alt (Dynamis)",      notes="Marksman Relic" },
    ["Culverin"]             = { lvl=73, jobs="COR",  src="Craft/BCNM ToAU",              notes="Mid-high gun" },
    ["Heavy Crossbow"]       = { lvl=60, jobs="many", src="Craft",                        notes="Crossbow" },
    -- Instruments (BRD worn in Range)
    ["Faerie Piccolo"]       = { lvl=50, jobs="BRD",  src="NPC/craft",                    notes="Wind instrument -- Range slot" },
    ["Mary's Horn"]          = { lvl=50, jobs="BRD",  src="NPC/craft",                    notes="String instrument -- Range slot" },
    ["Angel Lyre"]           = { lvl=50, jobs="BRD",  src="NPC/craft",                    notes="Fallback -- Range slot" },
    ["Cornette"]             = { lvl=7,  jobs="BRD",  src="NPC",                          notes="Starter wind -- Range slot" },
    ["Horn"]                 = { lvl=20, jobs="BRD",  src="NPC",                          notes="Low-level -- Range slot" },
    ["Marsyas"]              = { lvl=72, jobs="BRD",  src="HNM",                          notes="March +1 effect -- Range slot" },
    ["Daurdabla"]            = { lvl=74, jobs="BRD",  src="CoP/Besieged",                 uncertain=true, notes="BRD -castcast" },
    -- PUP automaton controller (RNG slot on PUP)
    ["Animator"]             = { lvl=20, jobs="PUP",  src="PUP quest",                    notes="Automaton controller" },
    ["Animator P"]           = { lvl=50, jobs="PUP",  src="PUP quest",                    notes="Higher-tier automaton" },
    ["Animator P II"]        = { lvl=70, jobs="PUP",  src="PUP quest",                    notes="Top era automaton" },
},

-- =============================================================================
-- AMMO (slot 4) -- arrows, bullets, bolts, cards/dice/trumps
-- =============================================================================
Ammo = {
    -- Arrows (RNG/SAM/THF)
    ["Bone Arrow"]           = { lvl=10, jobs="RNG THF SAM", src="Craft",                 notes="Starter arrow" },
    ["Iron Arrow"]           = { lvl=20, jobs="RNG THF SAM", src="Craft",                 notes="STR mod WS arrow" },
    ["Beetle Arrow"]         = { lvl=30, jobs="RNG THF SAM", src="Craft",                 notes="Mid arrow" },
    ["Fire Arrow"]           = { lvl=40, jobs="RNG",         src="Craft",                 notes="TP-friendly" },
    ["Kabura Arrow"]         = { lvl=50, jobs="RNG",         src="Craft",                 notes="Higher Acc than TP" },
    ["Demon Arrow"]          = { lvl=55, jobs="RNG SAM",     src="Craft",                 notes="Acc+" },
    ["Sleep Arrow"]          = { lvl=50, jobs="RNG",         src="Craft",                 notes="Sleep status" },
    ["Fang Arrow"]           = { lvl=60, jobs="RNG",         src="Craft",                 notes="DEF mod WS" },
    -- Bolts (NIN/RDM/various)
    ["Bolt"]                 = { lvl=20, jobs="many",        src="NPC/craft",             notes="Basic bolt" },
    ["Acid Bolt"]            = { lvl=30, jobs="many",        src="Craft",                 notes="DEF down proc" },
    ["Sleep Bolt"]           = { lvl=40, jobs="many",        src="Craft",                 notes="Sleep status bolt" },
    ["Bloody Bolt"]          = { lvl=50, jobs="many",        src="Craft",                 notes="HP drain bolt" },
    ["Blind Bolt"]           = { lvl=35, jobs="many",        src="Craft",                 notes="Blind proc" },
    -- Bullets (COR/RNG gun)
    ["Bullet"]               = { lvl=1,  jobs="COR RNG",     src="NPC",                   notes="Basic bullet" },
    ["Silver Bullet"]        = { lvl=50, jobs="COR RNG",     src="Craft",                 notes="Stronger bullet" },
    ["Fire Bomblet"]         = { lvl=60, jobs="COR",         src="ToAU quest/craft",      notes="COR magical ammo" },
    -- COR cards/dice (ToAU)
    ["Trump Card"]           = { lvl=30, jobs="COR",         src="COR quest",             notes="COR Phantom Roll ammo" },
    ["Hedgehog Bomb"]        = { lvl=40, jobs="COR",         src="ToAU",                  notes="COR Quickdraw ammo" },
    ["Clarus Stone"]         = { lvl=75, jobs="SMN",         src="WoTG+ event",           uncertain=true, event=true, wardrobe8=true, notes="WoTG+; may not be in Phoenix" },
},

};
