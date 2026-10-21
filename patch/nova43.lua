-- Hades II 4:3 UI patch (nova43). Appended to Content/Scripts/RoomLogic.lua by patch.py / the web patcher.
-- https://github.com/jevonlipsey/hades2-43aspect
--
-- On a canvas taller than 16:9 (4:3 is 1920x1440) the game shows the 1920x1080 boon and dialogue
-- screens in a centred band with frame art above and below. This block zooms each of those two
-- compositions uniformly so it fills the canvas: a crop of the 16:9 scene, never a stretch. Text is
-- re-rendered at the larger size. Nothing changes at 16:9, and every other screen and the HUD are untouched.
--
-- How: the engine calls that build these screens (CreateScreenObstacle, CreateTextBox, Attach, ...) are
-- wrapped, and only rewritten when one of a few known layout functions is on the calling coroutine's stack.

local function nova43_install()

	local CFG = {
		-- which screens are rewritten (switched on one at a time during device testing)
		Enabled = { Boon = true, Dialogue = true },
		-- zoom = min(ScreenScaleY, Cap) about (ScreenCenterX + PivotDX, ScreenCenterY + PivotDY).
		-- The boon pivot sits left of centre so Mel stays in frame and the slot text stays on screen.
		Boon = { Cap = 1.34, PivotDX = -390, PivotDY = 0 },
		Dialogue = { Cap = 1.34, PivotDX = 0, PivotDY = 0 },
		-- skip the letterbox frame art while a zoomed screen is open (the zoomed art covers the bands)
		HideFrames = true,
		-- how many stack levels above a wrapped call to search for a layout function
		StackDepth = 12,
	}

	-- Survives a re-run of this file in the same Lua state, so functions are never wrapped twice.
	Nova43 = Nova43 or { Originals = {}, Wrappers = {} }
	local state = Nova43
	state.Version = 3
	state.Config = CFG

	local function original( name )
		local fn = rawget( _G, name )
		if fn ~= nil and state.Wrappers[name] == fn then
			return state.Originals[name]
		end
		return fn
	end

	local function sentinelsOk()
		local uc = ScreenData ~= nil and ScreenData.UpgradeChoice
		if not uc or uc.ButtonSpacingY ~= 256 or uc.MaxChoices ~= 3 or uc.TooltipOffsetX ~= 735 then return false end
		if not uc.DescriptionText or uc.DescriptionText.Width ~= 921.5 then return false end
		if not uc.ComponentData or not uc.ComponentData.UseNativeScreenCenter then return false end
		if not ScreenData.Dialog or ScreenData.Dialog.DefaultGroup ~= "Combat_Menu_Overlay" then return false end
		if type( debug ) ~= "table" or type( debug.getinfo ) ~= "function" then return false end
		for _, name in ipairs({ "CreateScreenObstacle", "CreateTextBox", "Attach", "Teleport", "SetScale",
			"CreateAnimation", "SetInteractProperty", "AltAspectRatioFramesShow", "CreateUpgradeChoiceButton",
			"TraitLockedPresentation", "DisplayTextLine", "CreateScreenFromData", "OpenUpgradeChoiceMenu" }) do
			if type( original( name ) ) ~= "function" then return false end
		end
		return true
	end

	if not sentinelsOk() then
		state.Active = false
		if DebugPrint then DebugPrint({ Text = "nova43: unexpected game scripts, patch disabled" }) end
		return
	end

	local CreateUpgradeChoiceButtonFn = original( "CreateUpgradeChoiceButton" )
	local TraitLockedPresentationFn = original( "TraitLockedPresentation" )
	local DisplayTextLineFn = original( "DisplayTextLine" )
	local CreateScreenFromDataFn = original( "CreateScreenFromData" )
	local OpenUpgradeChoiceMenuFn = original( "OpenUpgradeChoiceMenu" )

	local getinfo = debug.getinfo

	-- Returns "Boon", "Chrome", "Dialogue" or nil for the innermost layout function on this stack.
	-- Level 1 is this function, 2 the wrapper, 3 the wrapper's caller. 16:9 never walks the stack.
	local function currentContext()
		if not ScreenState or not ScreenState.NeedsLetterbox then return nil end
		for level = 3, CFG.StackDepth do
			local info = getinfo( level, "f" )
			if info == nil then return nil end
			local fn = info.func
			if fn == CreateUpgradeChoiceButtonFn or fn == TraitLockedPresentationFn then
				return "Boon"
			elseif fn == DisplayTextLineFn then
				return "Dialogue"
			elseif fn == CreateScreenFromDataFn then
				local parent = getinfo( level + 1, "f" )
				if parent ~= nil and parent.func == OpenUpgradeChoiceMenuFn then
					return "Chrome"
				end
				return nil
			end
		end
		return nil
	end

	-- Chrome (the boon screen's backgrounds, title and action bar) shares the boon zoom.
	local function transformFor( kind )
		local cfgKind = kind == "Chrome" and "Boon" or kind
		if not CFG.Enabled[cfgKind] then return nil end
		local s = ScreenScaleY or 1
		local c = CFG[cfgKind]
		if s > c.Cap then s = c.Cap end
		if s <= 1.001 then return nil end
		return { Kind = kind, S = s, PX = ScreenCenterX + c.PivotDX, PY = ScreenCenterY + c.PivotDY }
	end

	local function mapX( t, x ) return t.PX + t.S * ( x - t.PX ) end
	local function mapY( t, y ) return t.PY + t.S * ( y - t.PY ) end

	local function copy( tbl )
		local out = {}
		for k, v in pairs( tbl ) do out[k] = v end
		return out
	end

	local function isCentreX( x ) return math.abs( x - ScreenCenterX ) < 0.5 end

	-- Ids created by the wrappers, with how each was treated:
	--   "anchor"  chrome text anchors and the header, kept centred: their text is zoomed, their x is not
	--   "bar"     action bar pieces moved into the bottom band: unscaled, their text and children untouched
	--   { X, NX } a zoomed boon slot: original and new x, so the keyword tooltip keeps its vanilla anchor
	local tagged = {}
	local tagCount = 0
	local function tag( id, value )
		if id == nil then return end
		tagCount = tagCount + 1
		if tagCount > 512 then tagged, tagCount = {}, 1 end
		tagged[id] = value
	end

	local wrap = function( name, make )
		local base = original( name )
		local w = make( base )
		state.Originals[name] = base
		state.Wrappers[name] = w
		_G[name] = w
	end

	-- Native-layout y offset from the centre at which the boon action bar starts (ActionBarY 984 is +444).
	local ACTION_BAR_DY = 360

	wrap( "CreateScreenObstacle", function( base )
		return function( params )
			local kind = params ~= nil and currentContext()
			local t = kind and transformFor( kind )
			if not t then return base( params ) end
			if params.X == nil and params.Y == nil then
				params.X = ScreenCenterX
				params.Y = ScreenCenterY
			end
			local x, y = params.X or ScreenCenterX, params.Y or ScreenCenterY
			if t.Kind == "Chrome" then
				if y - ScreenCenterY >= ACTION_BAR_DY then
					-- action bar: keep x (pinned to the screen edges) and size, push into the bottom band
					params.Y = ScreenCenterY + ( ScreenScaleY or 1 ) * ( y - ScreenCenterY )
					local id = base( params )
					tag( id, "bar" )
					return id
				end
				local art = params.Animation or params.AnimationName or params.Graphic
				local textAnchor = params.Name == "BlankObstacle" and art == nil
				if isCentreX( x ) and ( textAnchor or params.Name == "BoonSelectHeader" or art == "BoonSelectHeader" ) then
					params.Y = mapY( t, y )
					params.Scale = ( params.Scale or 1 ) * t.S
					local id = base( params )
					tag( id, "anchor" )
					return id
				end
			end
			params.X = mapX( t, x )
			params.Y = mapY( t, y )
			params.Scale = ( params.Scale or 1 ) * t.S
			local id = base( params )
			if t.Kind == "Boon" then tag( id, { X = x, NX = params.X } ) end
			return id
		end
	end )

	wrap( "CreateTextBox", function( base )
		return function( params )
			local kind = params ~= nil and currentContext()
			local t = kind and transformFor( kind )
			if not t or tagged[params.Id] == "bar" then return base( params ) end
			params = copy( params )
			local s = t.S
			for _, key in ipairs({ "FontSize", "Width", "OffsetX", "OffsetY", "LineSpacingBottom", "LineSpacingTop", "OutlineThickness" }) do
				if type( params[key] ) == "number" then params[key] = params[key] * s end
			end
			if type( params.ShadowOffset ) == "table" then
				params.ShadowOffset = { ( params.ShadowOffset[1] or 0 ) * s, ( params.ShadowOffset[2] or 0 ) * s }
			end
			return base( params )
		end
	end )

	-- Relative offsets (Attach, CreateAnimation on a destination): multiply by the zoom.
	local function wrapOffsets( name, needsDestination )
		wrap( name, function( base )
			return function( params )
				local kind = params ~= nil and currentContext()
				local t = kind and transformFor( kind )
				if not t or tagged[params.Id] == "bar" or tagged[params.DestinationId] == "bar" then return base( params ) end
				if needsDestination and params.DestinationId == nil then return base( params ) end
				params = copy( params )
				if type( params.OffsetX ) == "number" then params.OffsetX = params.OffsetX * t.S end
				if type( params.OffsetY ) == "number" then params.OffsetY = params.OffsetY * t.S end
				return base( params )
			end
		end )
	end

	wrapOffsets( "Attach", false )
	wrapOffsets( "CreateAnimation", true )

	-- The keyword tooltip is engine-drawn at a fixed size; keep it where vanilla puts it on screen
	-- instead of pushing it off the right edge with the zoomed slot.
	wrap( "SetInteractProperty", function( base )
		return function( params )
			if params == nil or params.Property ~= "TooltipOffsetX" or type( params.Value ) ~= "number" then return base( params ) end
			local slot = tagged[params.DestinationId]
			if type( slot ) ~= "table" or currentContext() ~= "Boon" then return base( params ) end
			params = copy( params )
			params.Value = params.Value + slot.X - slot.NX
			return base( params )
		end
	end )

	-- Teleport without a destination places at absolute coordinates (the dialogue portrait).
	wrap( "Teleport", function( base )
		return function( params )
			local kind = params ~= nil and currentContext()
			local t = kind and transformFor( kind )
			if not t or type( tagged[params.Id] ) == "string" then return base( params ) end
			params = copy( params )
			if params.DestinationId == nil then
				if params.OffsetX ~= nil then params.OffsetX = mapX( t, params.OffsetX ) end
				if params.OffsetY ~= nil then params.OffsetY = mapY( t, params.OffsetY ) end
			else
				if params.OffsetX ~= nil then params.OffsetX = params.OffsetX * t.S end
				if params.OffsetY ~= nil then params.OffsetY = params.OffsetY * t.S end
			end
			return base( params )
		end
	end )

	wrap( "SetScale", function( base )
		return function( params )
			local kind = params ~= nil and currentContext()
			local t = kind and transformFor( kind )
			if not t or tagged[params.Id] == "bar" or type( params.Fraction ) ~= "number" then return base( params ) end
			params = copy( params )
			params.Fraction = params.Fraction * t.S
			return base( params )
		end
	end )

	-- The zoomed art fills the letterbox bands, so the frame art would only cover it.
	wrap( "AltAspectRatioFramesShow", function( base )
		return function( ... )
			if CFG.HideFrames and ScreenState and ScreenState.NeedsLetterbox then
				local caller = getinfo( 2, "f" )
				local fn = caller and caller.func
				if fn == OpenUpgradeChoiceMenuFn and transformFor( "Boon" ) then return end
				if fn == DisplayTextLineFn and transformFor( "Dialogue" ) then return end
			end
			return base( ... )
		end
	end )

	state.Active = true
	if DebugPrint then DebugPrint({ Text = "nova43: active" }) end
end
nova43_install()
