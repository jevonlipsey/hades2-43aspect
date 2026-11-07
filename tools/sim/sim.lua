-- Headless simulator for the real Hades II scripts (Lua 5.2), used to check which screens the nova43 block
-- rewrites and where their pieces land. Engine calls are stubs that record what the scripts ask for.
--
--   .cache/lua-5.2.4/src/lua tools/sim/sim.lua <Scripts dir> <patched RoomLogic.lua | -> <scenario.lua> [out.json]
--
-- The scenario file is run after boot with SIM (this module's API) in scope. See tools/sim/scenarios/.

local scriptsDir, roomLogic, scenarioPath, outPath = arg[1], arg[2], arg[3], arg[4]
assert( scriptsDir and roomLogic and scenarioPath, "usage: sim.lua <Scripts dir> <RoomLogic.lua|-> <scenario.lua> [out.json]" )

local SIM = { Log = {}, Objects = {}, NextId = 1000, Config = { X = 1280, Y = 960, UseMouse = false, DemoMode = false,
	EditingMode = false, AutoAdvanceNarration = false, Language = "en", HUDOpacity = 1.0, DebugRNGSeed = 0 } }
_G.SIM = SIM

-- engine functions: every name the scripts call but never define (tools/sim/engine_names.txt)
local here = scenarioPath:match( "^(.*)/scenarios/" ) or "tools/sim"
local names = {}
for line in io.lines( here .. "/engine_names.txt" ) do if line ~= "" then names[#names + 1] = line end end

local function shallow( t ) local o = {} if type( t ) == "table" then for k, v in pairs( t ) do o[k] = v end end return o end

-- the innermost few Lua functions on the stack, for attributing a call
local function where()
	local out = {}
	for level = 3, 40 do
		local info = debug.getinfo( level, "nS" )
		if info == nil then break end
		if info.what == "Lua" and info.name then out[#out + 1] = info.name end
		if #out >= 8 then break end
	end
	return out
end

local function record( kind, params )
	local e = shallow( params )
	e._kind = kind
	e._stack = where()
	SIM.Log[#SIM.Log + 1] = e
	return e
end

local special = {}
special.SpawnScreenObstacle = function( p )
	SIM.NextId = SIM.NextId + 1
	local e = record( "Spawn", p )
	e.Id = SIM.NextId
	SIM.Objects[e.Id] = { X = p.X, Y = p.Y, Scale = p.Scale or 1, Name = p.Name, Animation = p.Animation, Group = p.Group, Spawn = e }
	return e.Id
end
special.SpawnObstacle = function( p ) SIM.NextId = SIM.NextId + 1; record( "SpawnWorld", p ); return SIM.NextId end
special.SpawnUnit = special.SpawnObstacle
special.CreateTextBox = function( p ) record( "Text", p ) end
special.Attach = function( p ) record( "Attach", p ) end
special.Teleport = function( p ) record( "Teleport", p ) end
special.SetScale = function( p ) record( "SetScale", p ) end
special.SetScaleX = function( p ) record( "SetScaleX", p ) end
special.SetScaleY = function( p ) record( "SetScaleY", p ) end
special.CreateAnimation = function( p ) record( "Anim", p ) end
special.SetAnimation = function( p ) record( "SetAnim", p ) end
special.Shift = function( p ) record( "Shift", p ) end
special.Move = function( p ) record( "Move", p ) end
special.SetAlpha = function( p ) record( "SetAlpha", p ) end
special.SetInteractProperty = function( p ) record( "Interact", p ) end
special.ModifyTextBox = function( p ) record( "ModifyText", p ) end
special.TeleportCursor = function( p ) record( "Cursor", p ) end
special.GetConfigOptionValue = function( p ) return SIM.Config[p.Name] end
special.GetDisplayName = function( p ) return p and p.Text or "" end
special.HasDisplayName = function( p ) return true end
special.GetLanguage = function() return "en" end
special.GetTime = function() return 0 end
special.GetIds = function() return {} end
special.GetIdsByType = function() return {} end
special.GetInactiveIds = function() return {} end
special.GetClosestIds = function() return {} end
special.GetLocation = function() return { X = 0, Y = 0 } end
special.GetCursorScreenLocation = function() return { X = 0, Y = 0 } end
special.IdExists = function() return true end
special.IsAlive = function() return true end
special.utf8strlen = function( s ) return #( s or "" ) end
special.randomint = function( a, b ) return a or 0 end
special.randomgaussian = function() return 0 end
special.random = function() return 0.5 end
special.GetScrollOffsetFraction = function() return 0 end
special._istool = function() return false end
special._isdebug = function() return false end
special.GetUsername = function() return "sim" end
special.PlaySpeech = function() return 0 end
special.GetGroupName = function() return "Combat_Menu" end
special.GetAvgFps = function() return 60 end
special.DebugPrint = function( p ) if SIM.Verbose then print( "DebugPrint:", p and p.Text ) end end
special.DebugAssert = function( p ) end
special.OnPreThingCreation = function( t ) SIM.PreThing = SIM.PreThing or {}; table.insert( SIM.PreThing, t[1] ) end
special.OnAnyLoad = function( t ) SIM.AnyLoad = SIM.AnyLoad or {}; table.insert( SIM.AnyLoad, t[1] ) end
special.newFunctionCall = function() end
special.make = function() return {} end
local engineGetters = { GetLifeDataValue = true, GetUnitDataValue = true, GetWeaponDataValue = true, GetThingDataValue = true,
	GetProjectileDataValue = true, GetEffectDataValue = true, GetBaseDataValue = true, GetUnitProperty = true, GetWeaponProperty = true,
	GetProjectileProperty = true, GetDistance = true, GetAngle = true, GetAngleBetween = true, GetZLocation = true, GetClosest = true,
	GetEffectTimeRemaining = true, GetProjectileCount = true, NumAlive = true, GetWeaponChargeFraction = true, GetCharmDuration = true }

for _, name in ipairs( names ) do
	if special[name] then _G[name] = special[name]
	elseif engineGetters[name] then _G[name] = function() return 0 end
	elseif name:match( "^On%u" ) then _G[name] = function() end -- event registration
	else _G[name] = function() end end
end
for name, fn in pairs( special ) do _G[name] = fn end

-- Import as the engine does: each file once, relative to the Scripts dir
local imported = {}
function Import( name )
	if imported[name] then return end
	imported[name] = true
	local path = scriptsDir .. "/" .. name
	if name == "RoomLogic.lua" and roomLogic ~= "-" then path = roomLogic end
	local chunk, err = loadfile( path )
	if not chunk then error( "Import " .. name .. ": " .. tostring( err ) ) end
	chunk()
end

Import( "Main.lua" )
Import( "RoomLogic.lua" )

-- Map load: what OnPreThingCreation does (screen size, state init)
function SIM.MapLoad()
	for i, fn in ipairs( SIM.PreThing or {} ) do
		local ok, err = pcall( fn, { name = SIM.MapName or "F_Opening01" } )
		if not ok and SIM.Verbose then print( "PreThing " .. i .. ": " .. tostring( err ) ) end
	end
	UpdateConfigOptionCache()
	local function try( label, fn, ... )
		local ok, err = pcall( fn, ... )
		if not ok and SIM.Verbose then print( label .. ": " .. tostring( err ) ) end
	end
	try( "MapStateInit", MapStateInit )
	if CurrentRun and CurrentRun.Hero then
		local hero = CurrentRun.Hero
		hero.ObjectId = hero.ObjectId or 40000
		for _, k in ipairs({ "InvulnerableFlags", "UntargetableFlags", "ImmuneToForceFlags", "PhasingFlags", "QueuedVoiceLines",
			"SpeechParams", "ReserveManaSources", "ReserveHealthSources", "ActiveEffects" }) do hero[k] = hero[k] or {} end
	end
	for i, fn in ipairs( SIM.AnyLoad or {} ) do try( "AnyLoad " .. i, fn, { name = SIM.MapName or "F_Opening01" } ) end
end

-- Runs fn in a coroutine, resuming through timed waits until it blocks on an event (input) or finishes.
function SIM.Run( fn, ... )
	local co = coroutine.create( fn )
	local args = { ... }
	local ok, info = coroutine.resume( co, unpack( args ) )
	local steps = 0
	while true do
		if not ok then error( debug.traceback( co, tostring( info ) ) ) end
		if coroutine.status( co ) == "dead" then return "done" end
		steps = steps + 1
		if steps > 5000 then return "stuck" end
		if type( info ) == "table" and info.wait == -1 then
			if SIM.AutoEvents and SIM.AutoEvents[info.event] then
				-- input arrives: carry on
			elseif SIM.Events and SIM.Events[info.event] then
				local v = SIM.Events[info.event]
				SIM.Events[info.event] = nil
				if type( v ) == "function" then v() end
			else
				return "blocked:" .. tostring( info.event )
			end
		end
		ok, info = coroutine.resume( co )
	end
end

-- thread() from Main.lua runs on its own scheduler; run threads inline instead (they resume immediately in the game too)
function thread( fn, ... )
	local co = coroutine.create( fn )
	local ok, info = coroutine.resume( co, ... )
	local steps = 0
	while ok and coroutine.status( co ) ~= "dead" and steps < 50 do
		if type( info ) == "table" and info.wait == -1 then break end
		steps = steps + 1
		ok, info = coroutine.resume( co )
	end
	if not ok and SIM.Verbose then print( "thread error: " .. tostring( info ) ) end
end

-- Final screen-space rectangle centre of an object, following Attach chains.
function SIM.Resolve( id, depth )
	depth = depth or 0
	local o = SIM.Objects[id]
	if o == nil or depth > 10 then return nil end
	if o.AttachTo then
		local px, py = SIM.Resolve( o.AttachTo, depth + 1 )
		if px then return px + ( o.AttachX or 0 ), py + ( o.AttachY or 0 ) end
	end
	return o.X, o.Y
end

function SIM.Apply()
	for _, e in ipairs( SIM.Log ) do
		if e._kind == "Attach" and SIM.Objects[e.Id] then
			local o = SIM.Objects[e.Id]
			o.AttachTo, o.AttachX, o.AttachY = e.DestinationId, e.OffsetX or 0, e.OffsetY or 0
		elseif e._kind == "Teleport" and SIM.Objects[e.Id] and e.DestinationId == nil then
			local o = SIM.Objects[e.Id]
			o.X, o.Y = e.OffsetX or o.X, e.OffsetY or o.Y
		elseif e._kind == "SetScale" then
			for _, id in ipairs( e.Ids or { e.Id } ) do if SIM.Objects[id] then SIM.Objects[id].Scale = e.Fraction end end
		end
	end
end

function SIM.Reset() SIM.Log = {}; SIM.Objects = {} end

local function encode( v, depth )
	depth = depth or 0
	local t = type( v )
	if t == "number" then return ( v ~= v or v == math.huge or v == -math.huge ) and "null" or string.format( "%.4f", v ) end
	if t == "boolean" then return tostring( v ) end
	if t == "string" then
		return '"' .. v:gsub( '[%c"\\]', function( c ) return string.format( "\\u%04x", c:byte() ) end ) .. '"'
	end
	if t ~= "table" or depth > 4 then return "null" end
	if #v > 0 then
		local parts = {}
		for i = 1, #v do parts[i] = encode( v[i], depth + 1 ) end
		return "[" .. table.concat( parts, "," ) .. "]"
	end
	local parts = {}
	for k, val in pairs( v ) do
		if type( k ) == "string" and type( val ) ~= "function" then parts[#parts + 1] = encode( k, 0 ) .. ":" .. encode( val, depth + 1 ) end
	end
	return "{" .. table.concat( parts, "," ) .. "}"
end
SIM.Encode = encode

local scenario = assert( loadfile( scenarioPath ) )
local result = scenario()
if outPath then
	local f = assert( io.open( outPath, "w" ) )
	f:write( encode( result or SIM.Log ) )
	f:close()
end
