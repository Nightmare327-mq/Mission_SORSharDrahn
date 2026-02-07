-- Mission_SORSharDrahn
-- Version 1.0
-- Error Reports:
-- 
---------------------------
local mq = require('mq')
LIP = require('lib.LIP')
Logger = require('utils.logger')
C = require('utils/common')

-- #region Variables
Logger.set_log_level(5) -- 4 = Info level, use 5 for debug, and 6 for trace
Zone_name = mq.TLO.Zone.ShortName()
Task_Name = "Shar'Drahn"
Command = 0

local Ready = false
local my_class = mq.TLO.Me.Class.ShortName()
local request_zone = 'ruinedrelic'
local request_npc = 'Gwork'
local request_phrase = 'smaller'
local zonein_phrase = 'ready'
local quest_zone = 'ruinedrelic_mission'
local delay_before_zoning = 30000  -- 27s
local section = 0

Settings = {
    general = {
        GroupMessage = 'dannet',        -- or "bc" - not yet implemented
        Automation = 'CWTN',            -- automation method, 'CWTN' for the CWTN plugins, or 'rgmercs' for the rgmercs lua automation.  KissAssist is not really supported currently, though it might work
        PreManaCheck = true,           -- true to pause until the check for everyone's mana, endurance, hp is full before proceeding, false if it stalls at that point
        Burn = true,                    -- Whether we should burn by default. Some people have a bit of trouble handling the adds when they burn, so you are able to turn this off if you want
        UseGlyphs = false,              -- If you want to use glyphs on all characters to try and burn before any Elder's spawn
        IgnoreStorms = true,            -- There are a lot of add mechanics that can mostly be avoided if you have the DPS to burn the named. If true, you will ignore adds and storms to just burn the named
        OpenChest = false,              -- true if you want to open the chest automatically at the end of the mission run. I normally do not do this as you can swap toon's out before opening the chest to get the achievements
        WriteCharacterIni = true,       -- Write/read character specific ini file to be able to run different groups with different parameters.  This must be changed in this section of code to take effect
    }
}
-- #endregion
Load_settings()

Logger.info('\awGroup Chat: \ay%s', Settings.general.GroupMessage)
if (Settings.general.GroupMessage ~= 'dannet')  then
   Logger.info("Unknown or invalid group command. Must be 'dannet'. Ending script. \ar")
   os.exit()
end

Logger.info('\awAutomation: \ay%s', Settings.general.Automation)
Logger.info('\awPreManaCheck: \ay%s', Settings.general.PreManaCheck)
Logger.info('\awBurn: \ay%s', Settings.general.Burn)
Logger.info('\awUse Glyphs: \ay%s', Settings.general.UseGlyphs)
Logger.info('\awIgnore Storms: \ay%s', Settings.general.IgnoreStorms)
Logger.info('\awOpen Chest: \ay%s', Settings.general.OpenChest)
Logger.info('\awWrite Character Ini: \ay%s\aw.', Settings.general.WriteCharacterIni)
if (Settings.general.WriteCharacterIni == true) then
    Load_settings()
elseif (Settings.general.WriteCharacterIni == false) then
else
    Logger.info("\awWrite Character Ini: %s \ar Invalid value. You can only use true or false.  Exiting script until you fix the issue.\ar", Settings.general.WriteCharacterIni)
    os.exit()
end

if my_class ~= 'WAR' and my_class ~= 'SHD' and my_class ~= 'PAL' then 
	Logger.info('You must run the script on a tank class...')
	os.exit()
end
mq.cmdf('/%s pause on', my_class)

if mq.TLO.Me.Combat() == true then 
    Logger.info('You started the script while you are in Combat.  Please kill the mobs first, then restart the script. Exiting script...')
	os.exit()
end

if mq.TLO.Group.AnyoneMissing() then
    Logger.info('You started the script, but not everyone is actually in zone with you. Exiting script...')
    os.exit()
end

if CheckGroupDistance(50) ~= true then 
    Logger.info('You started the script, but not everyone is within 50 feet of you. Exiting script...')
    os.exit()
end

if Zone_name == request_zone then 
	if mq.TLO.Spawn(request_npc).Distance() > 40 then 
		Logger.info('You are in %s, but too far away from %s to start the mission! We will attempt to invis and run to the mission npc', request_zone, request_npc)
        GroupInvis(1)
        MoveToAndSay(request_npc, request_phrase)
    end
    local task = Task(Task_Name, request_zone, request_npc, request_phrase)
    WaitForTask(delay_before_zoning)
    ZoneIn(request_npc, zonein_phrase, quest_zone)
    mq.delay(5000)
    local allinzone = WaitForGroupToZone(600)
    if allinzone == false then
        Logger.info('Timeout while waiting for everyone to zone in.  Please check what is happening and restart the script')
        os.exit()
    end
end

Zone_name = mq.TLO.Zone.ShortName()

if Zone_name ~= quest_zone then 
	Logger.info('You are not in the mission...')
	os.exit()
end

if mq.TLO.Group.AnyoneMissing() then
    Logger.info('You started the script in the mission zone, but not everyone is actually in zone.  Exiting script...')
    os.exit()
end
-- Check group mana / endurance / hp
while Settings.general.PreManaCheck == true and Ready == false do 
	Ready = CheckGroupStats()
	mq.cmd('/noparse /dgga /if (${Me.Standing}) /sit')
    Logger.info('Waiting for full hp / mana/ endurance to proceed...')
	mq.delay(15000)
    ZoneCheck(quest_zone)
    TaskCheck(Task_Name)
end

Logger.info('Doing some setup...')

DoPrep()

Logger.info('Starting the event in 10 seconds!')

mq.delay(10000)

-- mq.cmd('/squelch /nav locyx -240 50 log=off')
-- WaitForNav()

Logger.info('Starting the event...')
MoveToAndSay('Gwark', 'insist')

local event_zoned = function(line)
    -- zoned so quit
    Command = 1
end

local event_failed = function(line)
    -- failed so quit
    Command = 1
end

mq.event('Zoned','LOADING, PLEASE WAIT...#*#',event_zoned)
mq.event('Failed','#*#summons overwhelming enemies and your mission fails.#*#',event_failed)

if (Settings.general.UseGlyphs == true) then 
    mq.cmd('/dgga /timed 10 /alt act 5305')
    mq.cmd('/dgga /timed 11 /alt act 5304')
    mq.cmd('/dgga /timed 12 /alt act 5303')

    mq.cmd('/dgga /timed 30 /alt act 5305')
    mq.cmd('/dgga /timed 31 /alt act 5304')
    mq.cmd('/dgga /timed 32 /alt act 5303')
end

while true do
	mq.doevents()

	if Command == 1 then
        break
	end

	if mq.TLO.SpawnCount('_chest')() == 1 then
		Logger.info('I see the chest! You won!')
		break
	end

    if mq.TLO.SpawnCount('storm call npc')() > 0 and Settings.general.IgnoreStorms == false and mq.TLO.Spawn('storm call npc').Distance() > 20 then 
        StopAttack()
        mq.cmd('/nav spawn storm call')
        WaitForNav()
    elseif mq.TLO.SpawnCount('Elder Monolith npc')() > 0 and Settings.general.IgnoreStorms == false then 
        if (section ~= 2) then 
            section = 2
            Logger.info('Killing Elder Monolith...')
        end
        MoveToTargetAndAttack('Elder Monolith')
    elseif mq.TLO.SpawnCount('Younger npc')() > 0 and Settings.general.IgnoreStorms == false then 
        -- Need actual name of this mob that spawns with only 1 in the storm
        if (section ~= 3) then 
            section = 3
            Logger.info('Killing Younger...')
        end
        MoveToTargetAndAttack('Younger')
    elseif mq.TLO.SpawnCount('lost constituent npc')() > 0 and Settings.general.IgnoreStorms == false then 
        if (section ~= 4) then 
            section = 4
            Logger.info('Killing a lost constituent...')
        end
        MoveToTargetAndAttack('lost constituent')
    elseif (mq.TLO.SpawnCount('Shar`Drahn npc')() > 0 ) then 
        if (section ~= 1) then 
            section = 1
            Logger.info('Killing Shar`Drahn...')
        end
        Logger.debug('Shar`Drahn Attack branch...')
        MoveToTargetAndAttack('Shar`Drahn')
	end

    if mq.TLO.Target() ~= nil then 
        if mq.TLO.Target.Distance() > 20 then
            mq.cmd('/squelch /nav target distance=20 log=off') 
            WaitForNav()
        end
    end

    mq.delay(1000)
    ZoneCheck(quest_zone)
    TaskCheck(Task_Name)
end

if (Settings.general.OpenChest == true) then Action_OpenChest() end

mq.unevent('Zoned')
mq.unevent('Failed')
ClearStartingSetup()
Logger.info('...Ended')