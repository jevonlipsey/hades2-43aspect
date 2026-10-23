-- Stubbed-engine tests for patch/nova43.lua. Run from the repo root: lua verify/test_nova43.lua
-- The stubs mirror the call chains of the real game scripts (UILogic.lua, UpgradeChoiceLogic.lua,
-- NarrativeLogic.lua, build 25481925) without needing the game.

local PATCH = arg and arg[1] or "patch/nova43.lua"
local failures, passed = 0, 0

local function check( cond, msg )
	if cond then passed = passed + 1 else failures = failures + 1; print( "FAIL: " .. msg ) end
end
local function near( a, b ) return a ~= nil and b ~= nil and math.abs( a - b ) < 1e-6 end

local log
local nextId

local function reset( aspect )
	log, nextId = {}, nextId or 100
	if aspect == "4:3" then
		ScreenState = { NeedsLetterbox = true }
		ScreenScaleY, ScreenCenterX, ScreenCenterY = 1440 / 1080, 960, 720
	else
		ScreenState = { NeedsLetterbox = false }
		ScreenScaleY, ScreenCenterX, ScreenCenterY = 1, 960, 540
	end
end

local function record( kind )
	return function( params )
		local c = {}
		for k, v in pairs( params ) do c[k] = v end
		c._kind = kind
		if kind == "Spawn" then
			nextId = nextId + 1
			c.Id = nextId
			table.insert( log, c )
			return nextId
		end
		table.insert( log, c )
	end
end

local function freshGlobals()
	ScreenData = {
		UpgradeChoice = { ButtonSpacingY = 256, MaxChoices = 3, TooltipOffsetX = 735, DescriptionText = { Width = 921.5 }, ComponentData = { UseNativeScreenCenter = true } },
		Dialog = { DefaultGroup = "Combat_Menu_Overlay" },
	}
	Nova43 = nil
	DebugPrint = nil
	SpawnScreenObstacle = record( "Spawn" )
	CreateTextBox = record( "Text" )
	Attach = record( "Attach" )
	Teleport = record( "Teleport" )
	SetScale = record( "SetScale" )
	CreateAnimation = record( "Anim" )
	SetInteractProperty = record( "Interact" )

	-- UILogic.lua:542 / :504 / :1205 (trimmed)
	function CreateScreenObstacle( params )
		if params.X == nil and params.Y == nil then params.X = ScreenCenterX; params.Y = ScreenCenterY end
		return SpawnScreenObstacle( params )
	end
	function CreateScreenComponent( params )
		local component = {}
		for k, v in pairs( params ) do component[k] = v end
		component.Id = CreateScreenObstacle( component )
		return component
	end
	function CreateTextBoxWithFormat( args )
		local p = { FontSize = 19.5, Font = "LatoMedium" }
		for k, v in pairs( args ) do p[k] = v end
		CreateTextBox( p )
	end
	AltAspectRatioFramesShow = function() table.insert( log, { _kind = "Frames" } ) end
	function CreateScreenFromData( screen, componentData )
		screen.Art = CreateScreenComponent({ Name = "BlankObstacle", AnimationName = "OlympusBackground_In", X = 960, Y = 540 + 180 })
		screen.Header = CreateScreenComponent({ Name = "BoonSelectHeader", X = 960, Y = 175 + 180 })
		local title = CreateScreenComponent({ Name = "BlankObstacle" })
		CreateTextBox({ Id = title.Id, FontSize = 32, OffsetY = -455 })
		local bar = CreateScreenComponent({ Name = "BlankObstacle", X = 960, Y = 984 + 180 })
		Attach({ Id = 999, DestinationId = bar.Id, OffsetX = 40 })
		screen.Title, screen.Bar = title, bar
	end
	function TraitLockedPresentation( args )
		args.Lock = CreateScreenComponent({ Name = "BaseInteractableButton", X = args.OffsetX, Y = args.OffsetY })
	end
	function CreateUpgradeChoiceButton( screen, lootData, itemIndex )
		local y = ( ScreenCenterY - 190 ) + 256 * ( itemIndex - 1 )
		local x = ScreenCenterX - 355
		local button = CreateScreenComponent({ Name = "BoonSlotBase", X = x + 350, Y = y })
		local icon = CreateScreenComponent({ Name = "BlankObstacle", Scale = 0.6, X = -504 + x + 350, Y = -54 + y })
		Attach({ Id = icon.Id, DestinationId = button.Id, OffsetX = -506, OffsetY = 70 })
		CreateTextBox({ Id = button.Id, FontSize = 27, OffsetX = -420, OffsetY = -60, ShadowOffset = { 0, 3 } })
		CreateTextBoxWithFormat({ Id = button.Id, OffsetX = -420, OffsetY = -35, Width = 921.5 })
		SetInteractProperty({ DestinationId = button.Id, Property = "TooltipOffsetX", Value = 735 })
		local co = coroutine.create( TraitLockedPresentation )
		local lockArgs = { OffsetX = x + 350, OffsetY = y }
		coroutine.resume( co, lockArgs )
		button.Icon, button.LockArgs = icon, lockArgs
		return button
	end
	function OpenUpgradeChoiceMenu( source )
		AltAspectRatioFramesShow()
		local screen = {}
		CreateScreenFromData( screen, {} )
		screen.Buttons = { CreateUpgradeChoiceButton( screen, source, 1 ), CreateUpgradeChoiceButton( screen, source, 2 ) }
		return screen
	end
	function DisplayTextLine( screen )
		AltAspectRatioFramesShow()
		screen.ContextArtId = CreateScreenObstacle({ Name = "BlankObstacle", X = ScreenCenterX, Y = ScreenCenterY })
		SetScale({ Id = screen.ContextArtId, Fraction = 1 })
		screen.PortraitId = CreateScreenObstacle({ Name = "BlankObstacle", X = ScreenCenterX - 490, Y = ScreenCenterY + 105 })
		Teleport({ Id = screen.PortraitId, OffsetX = ScreenCenterX - 490 + 10, OffsetY = ScreenCenterY + 105 - 20 })
		SetScale({ Id = screen.PortraitId, Fraction = 1.0 })
		screen.BackgroundId = CreateScreenObstacle({ Name = "DialogueSpeechBubble", X = ScreenCenterX + 198, Y = ScreenCenterY + 264 })
		screen.NameplateId = CreateScreenObstacle({ Name = "BlankObstacle", X = ScreenCenterX - 12, Y = ScreenCenterY + 103 })
		CreateTextBox({ Id = screen.NameplateId, FontSize = 32, Text = "Melinoe" })
		CreateTextBox({ Id = screen.BackgroundId, FontSize = 24, Width = 833, OffsetX = -397, OffsetY = 45 })
		CreateAnimation({ Name = "Emote", DestinationId = screen.PortraitId, OffsetX = 10, OffsetY = -20 })
		return screen
	end
	function SomeOtherScreen()
		AltAspectRatioFramesShow()
		return CreateScreenComponent({ Name = "BlankObstacle", X = 100, Y = 200, Scale = 2 })
	end
end

local function load()
	local chunk = assert( loadfile( PATCH ) )
	chunk()
end

local function find( kind, pred )
	for _, e in ipairs( log ) do
		if e._kind == kind and ( pred == nil or pred( e ) ) then return e end
	end
end

-- expected transforms (mirror CFG defaults): zoom S about (570, 720) for boons, (960, 720) for dialogue
local S = 1440 / 1080
local TS_DIAL = 1.05
local function bx( x ) return 570 + S * ( x - 570 ) end
local function by( y ) return 720 + S * ( y - 720 ) end
local function dx( x ) return 960 + S * ( x - 960 ) end
local function dy( y ) return 720 + S * ( y - 720 ) end

-- 1. boon slots + chrome at 4:3
freshGlobals(); load(); reset( "4:3" )
check( Nova43.Active == true, "patch active with vanilla sentinels" )
local screen = OpenUpgradeChoiceMenu({})
check( find( "Frames" ) == nil, "letterbox frames skipped for the zoomed boon screen" )
local slot1 = find( "Spawn", function( e ) return e.Name == "BoonSlotBase" end )
check( near( slot1.X, bx( 955 ) ) and near( slot1.Y, by( 530 ) ), "slot 1 position zoomed about the boon pivot" )
check( near( slot1.Scale, S ), "slot backing scaled" )
local icon = find( "Spawn", function( e ) return e.Name == "BlankObstacle" and e.Scale and near( e.Scale, 0.6 * S ) end )
check( icon ~= nil and near( icon.X, bx( 451 ) ) and near( icon.Y, by( 476 ) ), "icon position and scale" )
local texts = {}
for _, e in ipairs( log ) do if e._kind == "Text" and e.Id == screen.Buttons[1].Id then table.insert( texts, e ) end end
check( #texts == 2, "two text boxes on slot 1" )
check( near( texts[1].FontSize, 27 * S ) and near( texts[1].OffsetX, -420 * S ) and near( texts[1].ShadowOffset[2], 3 * S ), "title text scaled" )
check( near( texts[2].FontSize, 19.5 * S ) and near( texts[2].Width, 921.5 * S ), "description text (via format) scaled, width scaled" )
local att = find( "Attach", function( e ) return e.DestinationId == screen.Buttons[1].Id end )
check( near( att.OffsetX, -506 * S ) and near( att.OffsetY, 70 * S ), "attach offsets scaled" )
local tip = find( "Interact" )
check( near( 955 + tip.Value, 955 + 735 ) == false and near( bx( 955 ) + tip.Value, 955 + 735 ), "keyword tooltip keeps its vanilla screen anchor" )
local lock = find( "Spawn", function( e ) return e.Name == "BaseInteractableButton" end )
check( near( lock.X, bx( 955 ) ) and near( lock.Y, by( 530 ) ), "locked-slot overlay (own coroutine) zoomed like the slot" )
-- chrome
local art = find( "Spawn", function( e ) return e.AnimationName == "OlympusBackground_In" end )
check( near( art.X, bx( 960 ) ) and near( art.Y, 720 ) and near( art.Scale, S ), "background art zoomed about the boon pivot" )
local header = find( "Spawn", function( e ) return e.Name == "BoonSelectHeader" end )
check( header.X == 960 and near( header.Y, by( 355 ) ) and near( header.Scale, S ), "header kept centred, zoomed" )
local titleText = find( "Text", function( e ) return e.Id == screen.Title.Id end )
check( near( titleText.OffsetY, -455 * S ) and near( titleText.FontSize, 32 * S ), "chrome title text zoomed" )
local titleSpawn = find( "Spawn", function( e ) return e.Name == "BlankObstacle" and e.X == 960 and e.Y == 720 end )
check( titleSpawn ~= nil, "chrome title anchor stays at the screen centre" )
local bar = find( "Spawn", function( e ) return e.Y and e.Y > 1000 and e.X == 960 and not e.Scale end )
check( bar ~= nil and near( bar.Y, 720 + S * ( 1164 - 720 ) ), "action bar pushed into the bottom band, unscaled" )
local barAttach = find( "Attach", function( e ) return e.DestinationId == screen.Bar.Id end )
check( barAttach.OffsetX == 40, "action bar children untouched" )

-- 2. dialogue untouched when disabled
Nova43.Config.Enabled.Dialogue = false
reset( "4:3" )
local d = DisplayTextLine({})
local portrait = find( "Spawn", function( e ) return near( e.X, 470 ) end )
check( portrait ~= nil and portrait.Scale == nil, "dialogue untouched when Enabled.Dialogue is false" )
check( find( "Frames" ) ~= nil, "frames still shown when dialogue zoom is off" )
Nova43.Config.Enabled.Dialogue = true

-- 3. dialogue enabled: centre zoom of the whole composition
Nova43.Config.Enabled.Dialogue = true
reset( "4:3" )
d = DisplayTextLine({})
check( find( "Frames" ) == nil, "letterbox frames skipped for zoomed dialogue" )
local spawns = {}
for _, e in ipairs( log ) do if e._kind == "Spawn" then table.insert( spawns, e ) end end
check( spawns[1].X == 960 and spawns[1].Y == 720 and near( spawns[1].Scale, S ), "context art zoomed in place to fill" )
local artScale = find( "SetScale", function( e ) return e.Id == d.ContextArtId end )
check( near( artScale.Fraction, S ), "context art SetScale zoomed" )
check( near( spawns[2].X, dx( 470 ) ) and near( spawns[2].Y, dy( 825 ) ) and near( spawns[2].Scale, S ), "portrait zoomed" )
local tp = find( "Teleport" )
check( near( tp.OffsetX, dx( 480 ) ) and near( tp.OffsetY, dy( 805 ) ), "absolute teleport zoomed" )
local ps = find( "SetScale", function( e ) return e.Id == d.PortraitId end )
check( near( ps.Fraction, S ), "portrait override scale multiplied" )
local body = find( "Text", function( e ) return e.Id == d.BackgroundId end )
check( near( body.FontSize, 24 * TS_DIAL ) and near( body.Width, 833 * TS_DIAL ) and near( body.OffsetX, -397 * TS_DIAL ), "dialogue body text scaled with gentle TextScale" )
local np = find( "Spawn", function( e ) return e.Id == d.NameplateId end )
check( near( np.X, dx( 1158 ) - 210 ) and near( np.Y, dy( 984 ) - 161 ), "nameplate locked to dialogue bubble with relative offset" )
local emote = find( "Anim" )
check( near( emote.OffsetX, 10 * S ), "emote offset scaled" )

-- 4. other screens and 16:9 are untouched
reset( "4:3" )
local other = SomeOtherScreen()
local o = find( "Spawn" )
check( o.X == 100 and o.Y == 200 and o.Scale == 2, "non-target screen untouched at 4:3" )
check( find( "Frames" ) ~= nil, "letterbox frames still shown for other screens" )
reset( "16:9" )
OpenUpgradeChoiceMenu({})
slot1 = find( "Spawn", function( e ) return e.Name == "BoonSlotBase" end )
check( slot1.X == 955 and slot1.Y == 350 and slot1.Scale == nil, "boon slots untouched at 16:9" )

-- 5. re-running the block does not double-wrap
load(); reset( "4:3" )
OpenUpgradeChoiceMenu({})
slot1 = find( "Spawn", function( e ) return e.Name == "BoonSlotBase" end )
check( near( slot1.Scale, S ) and near( slot1.X, bx( 955 ) ), "idempotent after loading twice" )

-- 6. unexpected scripts disable the patch
freshGlobals()
ScreenData.UpgradeChoice.ButtonSpacingY = 300
local vanillaSpawn = CreateScreenObstacle
load()
check( Nova43.Active == false and CreateScreenObstacle == vanillaSpawn, "sentinel mismatch leaves functions unwrapped" )

print( string.format( "checks: %d passed, %d failed", passed, failures ) )
os.exit( failures == 0 and 0 or 1 )
