local Mounts = LibStub("AceAddon-3.0"):NewAddon("MaretsMounts", "AceConsole-3.0")
_G.Mounts = Mounts

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local MacroName
local MacroIcon

local MountsDB

local defaults = {
	profile = {
		Ground = {},
		Flying = {},
		Swimming = {},
		Repair = {},
	}
}

local options = {
	name = "Marets Mounts",
	handler = Mounts,
    type = 'group',
    childGroups = "tab",
    args = {}	
}

local options_slashcmd = {
    name = "Maret's Mounts Slash Command",
    handler = Mounts,
    type = "group",
    order = -2,
    args = {
        config = {
            type = "execute",
            name = "Open Config",
            dialogHidden = true,
            order = 1,
            func = function(info) Mounts:OpenOptions() end
        },
        mount = {
            type = "execute",
            name = "Summon a Mount",
            desc = "Summon a mount based on the current location",
            order = 2,
            func = function(info) Mounts:Mount() end
        },
        repair = {
            type = "execute",
            name = "Summon Repair Mount",
            desc = "Summon a random repair mount",
            order = 3,
            func = function(info) Mounts:MountRepair() end
        }
    },
}

-- Buttons
MMMountButton = CreateFrame("Button", "MaretsMountsNormal", UIParent, "SecureActionButtonTemplate");
MMRepairMountButton = CreateFrame("Button", "MaretsMountsRepair", UIParent, "SecureActionButtonTemplate");

function MMMountButton:Initialize()
	MMMountButton:SetScript("PreClick", function(s,m,d) MMMountButton:PreClick() end)
end

function MMMountButton:PreClick()
	local idToCall = nil

	if IsMounted() then
		C_MountJournal.Dismiss();
		return
	end
	
	if not Mounts:CanMountNow() then
		return
	end
	
	if not IsMounted() then
		idToCall = Mounts:GetRandomMountID()
	else
		MMMountButton:SetAttribute("type", "macro")
		MMMountButton:SetAttribute("macrotext", "/dismount")
		return;
	end
	
	local type = MMHelper:GetMountType(idToCall)
	
	--Set button attributes to make things happen (we use GetSpellInfo for mounts cuz Mount Names and Spell Names for summoning a mount can be different)
	if type == MMHelper.Types.SPELL then
		local spellName = GetSpellInfo(idToCall);
		MMMountButton:SetAttribute("type", "spell")
		MMMountButton:SetAttribute("spell", spellName)
	elseif type == MMHelper.Types.ITEM then
		local itemName = GetItemInfo(idToCall);
		MMMountButton:SetAttribute("type", "item");
		MMMountButton:SetAttribute("item", itemName);
	else
		local spellName = GetSpellInfo(idToCall);
		MMMountButton:SetAttribute("type", "spell");
		MMMountButton:SetAttribute("spell", spellName);
	end
end

function MMRepairMountButton:Initialize()
	MMRepairMountButton:SetScript("PreClick", function(s,m,d) MMRepairMountButton:PreClick() end)
end

function MMRepairMountButton:PreClick()
	if IsMounted() then
		Dismount()
		return
	end

	if not Mounts:CanMountNow() then
		return
	end
	
	MMRepairMountButton:SetAttribute("type", "macro");
	MMRepairMountButton:SetAttribute("macrotext", "/mountyourface repair");
end

-- Initialization
function Mounts:OnInitialize()
	MountsDB = AceDB:New("MaretsMountsDB", defaults, true);
	
	MMMountButton:Initialize()
	MMRepairMountButton:Initialize()

	Mounts.db = MountsDB;
	Mounts.options = options;
	Mounts.optionsSlashCmd = options_slashcmd
	
	AceConfig:RegisterOptionsTable("Marets Mounts Slash Cmd", Mounts.optionsSlashCmd, {"mountyourface", "marets", "maretsmounts"})
end

function Mounts:OnEnable()
	Mounts:BuildMountOptions();
	
	Mounts.options.args.profiles = AceDBOptions:GetOptionsTable(Mounts.db)
	Mounts.options.args.profiles.order = -1
	
	AceConfig:RegisterOptionsTable("MaretsMounts", Mounts.options);
	Mounts.optionsFrame = AceConfigDialog.AddToBlizOptions("MaretsMounts", "MaretsMounts")
	
	Mounts.optionsFrame:RegisterEvent("COMPANION_LEARNED")
	Mounts.optionsFrame:RegisterEvent("COMPANION_UNLEARNED")
	Mounts.optionsFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
	Mounts.optionsFrame:SetScript("OnEvent", function (self, event) Mounts:UpdateMountOptions(self, event) end)
	
	local index = GetMacroIndexByName("Mount Your Face");
	
	if index == 0 then
		CreateMacro("Mount Your Face", "ability_mount_drake_proto", "/click [btn:2] MaretsMountsRepair; MaretsMountsNormal", nil);
	else
		EditMacro(index, "Mount Your Face", "ability_mount_drake_proto", "/click [btn:2] MaretsMountsRepair; MaretsMountsNormal");
	end
end

function Mounts:OnDisable()
	Mounts.optionsFrame:UnregisterEvent("COMPANION_LEARNED")
	Mounts.optionsFrame:UnregisterEvent("COMPANION_UNLEARNED")
	Mounts.optionsFrame:UnregisterEvent("LEARNED_SPELL_IN_TAB")
end

--Options config
function Mounts:OpenOptions()
	InterfaceOptionsFrame_OpenToCategory(Mounts.optionsFrame)
end

function Mounts:UpdateMountOptions(self, event)
	Mounts:BuildMountOptions()
	AceConfigRegistry:NotifyChange("MaretsMounts")
end

function Mounts:BuildMountOptions()

	Mounts.options.args = {}
	
	-- Create ground mounts for options table
	local groundMounts = {};
	local airMounts = {};
	local waterMounts = {};
	local vashjir = {};
	
	-- Use all mounts and create the mount list by their type
	local mountCount = C_MountJournal.GetNumMounts();
	for id=1, mountCount, 1 do
	
		local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = C_MountJournal.GetMountInfo(id);
		local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType = C_MountJournal.GetMountInfoExtra(id);
		
    if not hideOnChar and isCollected then
        if mountType == 230 or mountType == 269 or mountType == 247 or mountType == 241 then
          groundMounts[spellID] = true;
        end
        if mountType == 248 or mountType == 247 then
          airMounts[spellID] = true;
        end
        if mountType == 231 or mountType == 232 or mountType == 254 then
          waterMounts[spellID] = true;
        end
    end
	end
	
	local shapeshiftGround = MMHelper:GetSpecialMountList(MMHelper.GROUND);

	for key,value in pairs(shapeshiftGround) do
		groundMounts[key] = value;
	end
	
	local groundGuys = {};
	
	Mounts:MakeMountTable(groundMounts, groundGuys, MMHelper.GROUND);
	
	Mounts.options.args['Ground'] = {};
	Mounts.options.args.Ground['type'] = 'group';
	Mounts.options.args.Ground['name'] = 'Ground';
	
	Mounts.options.args.Ground.args = groundGuys;
	
	--Create air mounts for options table
	local shapeshiftAir = MMHelper:GetSpecialMountList(MMHelper.AIR);

	for key,value in pairs(shapeshiftAir) do
		airMounts[key] = value;
	end

	local airGuys = {};
	
	Mounts:MakeMountTable(airMounts, airGuys, MMHelper.AIR);
	
	Mounts.options.args['Air'] = {};
	Mounts.options.args.Air['type'] = 'group';
	Mounts.options.args.Air['name'] = 'Flying';
	
	Mounts.options.args.Air.args = airGuys;
	
	-- create water mounts for options table
	for key,value in pairs(vashjir) do
		waterMounts[key] = value;
	end

	local shapeshiftWater = MMHelper:GetSpecialMountList(MMHelper.WATER);

	for key,value in pairs(shapeshiftWater) do
		waterMounts[key] = value;
	end

	local waterGuys = {};
	
	Mounts:MakeMountTable(waterMounts, waterGuys, MMHelper.WATER);
	
	Mounts.options.args['Water'] = {};

	Mounts.options.args.Water['type'] = 'group';
	Mounts.options.args.Water['name'] = 'Swimming';
	
	Mounts.options.args.Water.args = waterGuys;
	
	-- create repair mounts for options table
	local repairGuys = {};
	local repairMounts = {};
	
	repairMounts = MMHelper.data["vendorrepair"];
	
	Mounts:MakeMountTable(repairMounts, repairGuys, MMHelper.REPAIR);
	
	Mounts.options.args['Repair'] = {};
	Mounts.options.args.Repair['type'] = 'group';
	Mounts.options.args.Repair['name'] = 'Repair/Vendor';
	
	Mounts.options.args.Repair.args = repairGuys;
end

function Mounts:MakeMountTable(mounts, optionsTable, mounttype)

	for key,value in pairs(mounts) do
		local name;
		local spellid;
		local disabled, message = false, nil;

		local type = MMHelper:GetMountType(key)

		if type == MMHelper.Types.SPELL then
			local spellName = GetSpellInfo(key);
			spellid = key;
			name = spellName;
		elseif type == MMHelper.Types.ITEM then
			local itemName = GetItemInfo(key);
			spellid = key;
			name = itemName;
		else
			local mountId, creatureName, creatureSpellID, icon, issummoned = MMHelper:GetMountInfo(key);
			
			name = creatureName
			spellid = creatureSpellID

			if (name ~= nil) then
				disabled, message = Mounts:GetRestrictions(spellid);
			end
		end
		if (name ~= nil and Mounts:IsMountValidForPlayer(spellid)) then
			optionsTable[name] = {
								type = 'toggle',
								name = name,
								desc = message,
								disabled = disabled,
								set = function(info, v) Mounts:SetMountSummonState(info, v, spellid, mounttype) end,
								get = function(info) return Mounts.GetMountSummonState(info, spellid, mounttype) end,
								};
		end
	end
end

--Getting and setting mount selection state

function Mounts:SetMountSummonState(info, value, spellid, mounttype)
	if value == true then
		Mounts:AddMountAsSummonable(spellid, mounttype);
	else
		Mounts:RemoveMountAsSummonable(spellid, mounttype);
	end
end

function Mounts:AddMountAsSummonable(spellid, mounttype)
	local hasOther, otherSpellID = MMHelper:HasOtherFactionEquivalent(spellid)

	local tableToAddTo
	
	if mounttype == MMHelper.GROUND then
		tableToAddTo = Mounts.db.profile.Ground
	elseif mounttype == MMHelper.AIR then
		tableToAddTo = Mounts.db.profile.Flying
	elseif mounttype == MMHelper.WATER then
		tableToAddTo = Mounts.db.profile.Swimming
	elseif mounttype == MMHelper.REPAIR then
		tableToAddTo = Mounts.db.profile.Repair
	end
	
	tableToAddTo[#tableToAddTo+1] = spellid;
		
	if hasOther then
		tableToAddTo[#tableToAddTo+1] = otherSpellID;
	end
end

function Mounts:RemoveMountAsSummonable(spellid, mounttype)
	local tableToRemoveFrom
	
	local hasOther, otherSpellId = MMHelper:HasOtherFactionEquivalent(spellid)
	
	if mounttype == MMHelper.GROUND then
		tableToRemoveFrom = Mounts.db.profile.Ground
	elseif mounttype == MMHelper.AIR then
		tableToRemoveFrom = Mounts.db.profile.Flying
	elseif mounttype == MMHelper.WATER then
		tableToRemoveFrom = Mounts.db.profile.Swimming
	elseif mounttype == MMHelper.REPAIR then
		tableToRemoveFrom = Mounts.db.profile.Repair
	end
	
	Mounts:RemoveMountFromTable(tableToRemoveFrom, spellid);
	
	if hasOther then
		Mounts:RemoveMountFromTable(tableToRemoveFrom, otherSpellId);
	end
end

function Mounts:RemoveMountFromTable(mountTable, valueToRemove)
	local keyToRemove;
	
	for key,value in pairs(mountTable) do
		if value == valueToRemove then
			keyToRemove = key;
			break;
		end
	end
	
	if keyToRemove ~= nil then
		table.remove(mountTable, keyToRemove);
	end
end

function Mounts:GetMountSummonState(spellid, mounttype, info)

	if mounttype == MMHelper.GROUND then
		for key,value in pairs(Mounts.db.profile.Ground) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == MMHelper.AIR then
		for key,value in pairs(Mounts.db.profile.Flying) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == MMHelper.WATER then
		for key,value in pairs(Mounts.db.profile.Swimming) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == MMHelper.REPAIR then
		for key,value in pairs(Mounts.db.profile.Repair) do
			if value == spellid then
				return true;
			end
		end
	end
	
	return false;
end

-- Helper functions
function Mounts:GetRestrictions(spellid)
	local summonable, profession, level = MMHelper:GetProfessionRestriction(spellid);
	
	local location = MMHelper:GetLocationRestriction(spellid);
	
	local disabled = false;
	local message;
	
	if summonable == false then
		disabled = true;
	end
	
	if location ~= nil then
		message = "Restricted to " .. location;
	end
	
	return disabled, message;
end

function Mounts:IsMountValidForPlayer(id)
	if id == nil then
		return false;
	end

	local type = MMHelper:GetMountType(id)

	if type == MMHelper.Types.ITEM then
		local count = GetItemCount(id, true)
		if count > 0 then
			return true
		else
			return false
		end
	elseif type == MMHelper.Types.SPELL then
		return IsSpellKnown(id)
	else
		local currentCanUse, restricted = MMHelper:IsMountClassRestricted(id)
		
		return currentCanUse
	end

	return true;
end

local draenorMapIds = {
[962] = true, --Draenor
[978] = true, --Ashran
[941] = true, --Frostfire Ridge
[976] = true, --Frostwall
[949] = true, --Gorgrond
[971] = true, --Lunarfall
[950] = true, --Nagrand
[947] = true, --Shadowmoon Valley
[948] = true, --Spires of Arak
[1009] = true, --Stormshield
[946] = true, --Talador
[945] = true, --Tanaan Jungle
[970] = true, --Tanaan Jungle - Assault on the Dark Portal
[1011] = true --Warspear
}

---
-- Check if the the location is in draenor and if the character has draenor flying
---
function Mounts:DraenorFlying()
  --save the selected map id so we can go back to it
  local currentMap = GetCurrentMapAreaID()
  SetMapToCurrentZone()
  local currentLocation = GetCurrentMapAreaID()
  SetMapByID(currentMap)

  --if we are in draenor but not in the special assault on the dark portal instance of tanaan
  if draenorMapIds[currentLocation] and currentLocation ~= 970 then
      local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuildAch, wasEarnedByMe, earnedBy  = GetAchievementInfo(10018);
      
      return completed;
  end
  
  return false;
end

function Mounts:GetRandomMountID()
	local idToCall = nil
  
	-- Make sure they can use a swimming mount at all (they may be < level 20)
	if IsSwimming() and IsUsableSpell(64731) and #Mounts.db.profile.Swimming > 0 then
		while not MMHelper:IsMountUsable(idToCall) or not MMHelper:IsMountClassRestricted(idToCall) do
			idToCall = Mounts.db.profile.Swimming[random(#Mounts.db.profile.Swimming)];
		end
	--Instead of checking for flying skill, just check if a flyable mount can be used to handle not having the proper riding skill
	elseif Mounts:DraenorFlying() or (IsFlyableArea() and IsUsableSpell(88718) and #Mounts.db.profile.Flying > 0) then 
		while not MMHelper:IsMountUsable(idToCall) or not MMHelper:IsMountClassRestricted(idToCall) do
			idToCall = Mounts.db.profile.Flying[random(#Mounts.db.profile.Flying)];
		end
	--Instead of checking riding skill, make sure they can use any ground mount, since all mounts scale with riding skill (they may be < level 20)
	elseif #Mounts.db.profile.Ground > 0 and IsUsableSpell(101542) then
		while not MMHelper:IsMountUsable(idToCall) or not MMHelper:IsMountClassRestricted(idToCall) do
			idToCall = Mounts.db.profile.Ground[random(#Mounts.db.profile.Ground)];
		end
	end
	
	return idToCall
end

--Mounting functions
function Mounts:Mount()
	local idToCall = nil;

	if IsMounted() then
		C_MountJournal.Dismiss();
		return
	end

	if not Mounts:CanMountNow() then
		return
	end

	if not IsMounted() then
		idToCall = Mounts:GetRandomMountID()

		idToCall = MMHelper:GetMountInfo(idToCall);
		
		C_MountJournal.Summon(idToCall);
	else
		Dismount();
	end
end

function Mounts:MountRepair()
	local idToCall = nil;

	if IsMounted() then
		C_MountJournal.Dismiss();
		return
	end

	if not Mounts:CanMountNow() then
		return
	end
	
	while not MMHelper:IsMountUsable(idToCall) and #Mounts.db.profile.Repair > 0 do
		idToCall = Mounts.db.profile.Repair[random(#Mounts.db.profile.Repair)];
	end
	
	idToCall = MMHelper:GetMountInfo(idToCall);
		
	C_MountJournal.Summon(idToCall);
end

function Mounts:CanMountNow()
	if IsIndoors() or InCombatLockdown() then
		-- If we are in combat, just try to call our first ground mount so we get the error message
		C_MountJournal.Summon(MMHelper:GetMountSummonID(Mounts.db.profile.Ground[1]))
		return false
	end
	
	return true
end

MMHelper = {
	REPAIR = {},
	data = {},
	Types = {},
	Locations = {},
}

MMHelper.REPAIR = "repair"

MMHelper.Types.ITEM = "item"
MMHelper.Types.SPELL = "spell"
MMHelper.Types.MOUNT = "mount"

MMHelper.GROUND = "ground";
MMHelper.AIR = "air";
MMHelper.WATER = "water";

MMHelper.Locations.Vashjir = "Vashj'ir";
MMHelper.Locations.AQ = "Temple of Ahn'Qiraj";

MMHelper.data["paladin"] = {
	[34769] = true,
	[13819] = true,
	[66906] = true,
	[23214] = true,
	[34767] = true
}

MMHelper.data["warlock"] = {
	[5784] = true,
	[23161] = true
}

MMHelper.data["deathknight"] = {
	[48778] = true,
	[54729] = true
}

MMHelper.data["vendorrepair"] = {
	[61425] = true, -- Traveler's Tundra Mammoth (Alliance)
	[61447] = true, -- Traveler's Tundra Mammoth (Horde)
	[122708] = true -- Grand Expedition Yak
}

MMHelper.data["shapeshift"] = {
  [783] = { MMHelper.AIR,
    MMHelper.GROUND,
    MMHelper.WATER},
}

--Key = Horde, Value = Alliance
MMHelper.data["factionequivalent"] = {
		[118737] = 130985, --Pandaren Kite
		[61467] = 61465, -- Grand Black War Mammoth
		[61469] = 61470, -- Grand Ice Mammoth
		[61447] = 61425, -- Traveler's Tundra Mammoth
		[136163] = 136164,
		[135416] = 135418
}

MMHelper.data["items"] = {
	    [71086] = {
            MMHelper.AIR,
        },
        [37011] = {
            MMHelper.AIR,
            MMHelper.GROUND,
        },
        [101675] = {
        	MMHelper.GROUND,
        }
}

MMHelper.data["profession"] = {
	[44151] = { 110403, 375 }, --Turbo-Charged Flying Machine
	[44153] = { 110403, 300 }, --Flying Machine
	[61451] = { 110426, 300 }, --Flying Carpet
	[61309] = { 110426, 425 }, --Magnificent Flying Carpet
	[75596] = { 110426, 425 }, --Frosty Flying Carpet
	[169952] = { 110426, 300 }, --Creeping Carpet
	[171844] = { 110423, 300 }, --Dustmane Direwolf
}

MMHelper.data["locationRestricted"] = {
	[26054] = MMHelper.Locations.AQ,
	[25953] = MMHelper.Locations.AQ,
	[26056] = MMHelper.Locations.AQ,
	[26055] = MMHelper.Locations.AQ,
	[75207] = MMHelper.Locations.Vashjir,--Abyssal Seahorse
}

function MMHelper:GetMountInfo(spellid)
	local allMounts = C_MountJournal.GetNumMounts();

	for mountId = 1, allMounts do
		local creatureName, mountSpellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = C_MountJournal.GetMountInfo(mountId);
		if creatureName == nil then
				--continue
		elseif mountSpellID == spellid then
			return mountId, creatureName, mountSpellID, icon, active;
		end
	end
end

function MMHelper:GetMountList(mounttype)
	return MMHelper.data[mounttype];
end

function MMHelper:GetSpecialMountList(mounttype)

	local returnShifts = {};
	for k,v in pairs(MMHelper.data["shapeshift"]) do
    for key,value in pairs(v) do
      if value == mounttype then
        returnShifts[k] = true;
      end
    end
	end
	
	for k,v in pairs(MMHelper.data["items"]) do
		for key, value in pairs(v) do
			if value == mounttype then
				returnShifts[k] = true;
			end
		end
	end

	return returnShifts;
end

function MMHelper:GetMountType(id)
	if MMHelper.data["shapeshift"][id] ~= nil then
		return MMHelper.Types.SPELL
	elseif MMHelper.data["items"][id] ~= nil then
		return MMHelper.Types.ITEM
	else
		return MMHelper.Types.MOUNT
	end
end

--Returns true, and other faction id. And just false otherwise
function MMHelper:HasOtherFactionEquivalent(id)
	for h,a in pairs(MMHelper.data["factionequivalent"]) do
		if h == id then
			return true, a
		elseif a == id then
			return true, h
		end
	end
	
	return false
end

--Returns CanPlayerUse and HasClassRestrictions
function MMHelper:IsMountClassRestricted(id)
	if (id == nil) then
		return false, false
	end

	local localizename, englishname = UnitClass("player");
	
	if MMHelper.data["paladin"][id] then
		if englishname ~= 'PALADIN' then
			return false, true;
		else
			return true, true
		end
	end
	if MMHelper.data["warlock"][id] then
		if englishname ~= 'WARLOCK' then
			return false, true;
		else
			return true, true
		end
	end
	if MMHelper.data["deathknight"][id] then
		if englishname ~= 'DEATHKNIGHT' then
			return false, true;
		else
			return true, true
		end
	end
	
	return true, false
end

function MMHelper:IsMountUsable(spellid)
	if spellid == nil then
		return false;
	end

	local type = MMHelper:GetMountType(spellid)

	if type == MMHelper.Types.ITEM then
		return MMHelper:IsItemUsable(spellid)
	elseif type == MMHelper.Types.SPELL then
		return IsSpellKnown(spellid)
	elseif type == MMHelper.Types.MOUNT then
	 local allMounts = C_MountJournal.GetNumMounts();

    for mountId = 1, allMounts do
      local creatureName, mountSpellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = C_MountJournal.GetMountInfo(mountId);

      if creatureName == nil then
      --continue
      elseif mountSpellID == spellid then
        return isUsable;
      end
    end
	end
	return true;
end

function MMHelper:IsItemUsable(id)
	local count = GetItemCount(id)
	if count > 0 then
		if IsEquippableItem(id) and IsEquippedItem(id) then
			return true
		elseif IsUsableItem(id) and not IsEquippableItem(id) then
			return true
		else
			return false
		end
	else
		return false
	end
end

function MMHelper:GetMountSummonID(spellid)
	local allMounts = C_MountJournal.GetNumMounts();

	for mountId = 1, allMounts do
		local creatureName, mountSpellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = C_MountJournal.GetMountInfo(mountId);

		if creatureName == nil then
				--continue
		elseif mountSpellID == spellid then
			return mountId;
		end
	end
end

function MMHelper:GetProfessionRestriction(id)
	if MMHelper.data["profession"][id] then
		local name = GetSpellInfo(MMHelper.data["profession"][id][1])
		local level = MMHelper.data["profession"][id][2]
		local userProf1, userProf2 = GetProfessions()
		if userProf1 then
			local name1, _, rank1 = GetProfessionInfo(userProf1)
			if name == name1 then
				return (rank1 >= level), name, level
			end
		end
		if userProf2 then
			local name2, _, rank2 = GetProfessionInfo(userProf2)
			if name == name2 then
				return (rank2 >= level), name, level
			end
		end
		return false, name, level
	else
		return true
	end
end

function MMHelper:GetLocationRestriction(id)
	return MMHelper.data["locationRestricted"][id];
end
