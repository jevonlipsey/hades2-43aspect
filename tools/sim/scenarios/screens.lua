-- Opens one screen (FLOW env var) the way the game does and returns everything drawn before it waits for input.
SIM.Verbose = os.getenv( "SIM_VERBOSE" ) ~= nil
SIM.MapLoad()

local function loot( name )
	local l = DeepCopyTable( LootData[name] )
	l.ObjectId = 77
	l.Name = name
	return l
end

local function firstTextLines( source )
	for _, set in pairs( source.InteractTextLineSets or {} ) do
		if type( set ) == "table" and #set > 0 then return set end
	end
end

local function npc( name )
	local u = DeepCopyTable( EnemyData[name] )
	u.ObjectId = 78
	u.Name = name
	return u
end

local flows = {}
flows.Dialogue = function()
	local l = loot( "ZeusUpgrade" )
	PlayTextLines( l, { Name = "SimLines", { Cue = "/VO/Zeus_0001", Text = "Sim line" } } )
end
flows.DialogueNarration = function()
	local l = loot( "ZeusUpgrade" )
	PlayTextLines( l, { Name = "SimLines", IsNarration = true, { Cue = "/VO/Zeus_0001", Text = "Sim line" } } )
end
flows.DialogueChoices = function()
	local u = npc( "NPC_Nemesis_01" )
	PlayTextLines( u, { Name = "SimLines", { Cue = "/VO/Nemesis_0001", Text = "Sim line",
		Choices = { { ChoiceText = "ChoiceA", { Cue = "/VO/Nemesis_0002", Text = "a" } }, { ChoiceText = "ChoiceB", { Cue = "/VO/Nemesis_0003", Text = "b" } } } } } )
end
flows.Boon = function() OpenUpgradeChoiceMenu( loot( "ZeusUpgrade" ), {} ) end
flows.BoonHermes = function() OpenUpgradeChoiceMenu( loot( "HermesUpgrade" ), {} ) end
flows.BoonChaos = function() OpenUpgradeChoiceMenu( loot( "TrialUpgrade" ), {} ) end
flows.Spell = function()
	local s = loot( "SpellDrop" )
	s.ResourceCosts = nil
	OpenSpellScreen( s, {} )
end
flows.Talent = function()
	CurrentRun.Hero.SlottedSpell = nil
	local t = DeepCopyTable( ConsumableData.TalentDrop ); t.ObjectId = 79; OpenTalentScreen( {}, t )
end
flows.Trade = function()
	local u = npc( "NPC_Nemesis_01" )
	NemesisTradeChoice( u, DeepCopyTable( PresetEventArgs.NemesisBuyItemChoices ), { Components = {} } )
end
flows.TradeInDialogue = function()
	local u = npc( "NPC_Nemesis_01" )
	PlayTextLines( u, { Name = "SimLines", PrePortraitExitFunctionName = "NemesisTradeChoice",
		PrePortraitExitFunctionArgs = DeepCopyTable( PresetEventArgs.NemesisBuyItemChoices ), { Cue = "/VO/Nemesis_0001", Text = "Sim line" } } )
end
flows.Store = function() ShowStoreScreen() end
flows.SellTrait = function() OpenSellTraitMenu( {} ) end
flows.SurfaceShop = function() ShowSurfaceShopScreen() end

-- hub and menu screens, opened bare (for measuring how wide their layouts are)
for flow, call in pairs({ Keepsake = "OpenKeepsakeRackScreen", QuestLog = "OpenQuestLogScreen", Arcana = "OpenMetaUpgradeCardScreen",
	Aspects = "OpenWeaponUpgradeScreen", Shrine = "OpenShrineScreen", Market = "OpenMarketScreen", Cauldron = "OpenGhostAdminScreen",
	Codex = "OpenCodexScreen", Inventory = "OpenInventoryScreen", WeaponShop = "OpenWeaponShopScreen", Mailbox = "OpenMailboxScreen",
	Bounty = "OpenBountyBoardScreen", FamiliarShop = "OpenFamiliarShopScreen", Cosmetics = "OpenCosmeticsShopScreen",
	RunHistory = "OpenRunHistoryScreen", GameStats = "OpenGameStatsScreen", MusicPlayer = "OpenMusicPlayerScreen" }) do
	flows[flow] = function() _G[call]( {}, {} ) end
end

local name = os.getenv( "FLOW" )
if os.getenv( "ADVANCE" ) then SIM.AutoEvents = { NarrativeLineNextInput = true } end
assert( flows[name], "unknown FLOW " .. tostring( name ) )
SIM.Reset()
local ok, status = pcall( SIM.Run, flows[name] )
local spawns = {}
for _, e in ipairs( SIM.Log ) do
	if e._kind == "Spawn" or e._kind == "Text" or e._kind == "Attach" or e._kind == "Teleport" or e._kind == "SetScale" or e._kind == "Anim" then
		spawns[#spawns + 1] = { K = e._kind, Id = e.Id, Dest = e.DestinationId, Name = e.Name, Anim = e.Animation, Group = e.Group,
			X = e.X, Y = e.Y, Scale = e.Scale, OX = e.OffsetX, OY = e.OffsetY, FontSize = e.FontSize, Width = e.Width,
			Fraction = e.Fraction, Text = type( e.Text ) == "string" and e.Text or nil, Stack = table.concat( e._stack, "<" ) }
	end
end
return { Flow = name, Ok = ok, Status = tostring( status ), Log = spawns }
