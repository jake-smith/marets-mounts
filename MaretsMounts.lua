local Mounts = LibStub("AceAddon-3.0"):NewAddon("MaretsMounts", "AceConsole-3.0")
_G.Mounts = Mounts

local LibMountsData = LibStub("LibMounts-1.0_Data");
local LibMounts = LibStub("LibMounts-1.0");

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")

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
		Dismount()
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
	
	local type = LibMountsExt:GetMountType(idToCall)
	
	if type == LibMountsExt.Types.SPELL then
		local spellName = GetSpellInfo(idToCall);
		MMMountButton:SetAttribute("type", "spell")
		MMMountButton:SetAttribute("spell", spellName)
	elseif type == LibMountsExt.Types.ITEM then
		local itemName = GetItemInfo(idToCall);
		MMMountButton:SetAttribute("type", "item");
		MMMountButton:SetAttribute("item", itemName);
	else
		local mountid, creatureID, creatureName, creatureSpellID, icon, issummoned = LibMountsExt:GetMountInfo(idToCall)
		MMMountButton:SetAttribute("type", "spell");
		MMMountButton:SetAttribute("spell", creatureName);
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

function Mounts.OnInitialize()
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
	
	AceConfig:RegisterOptionsTable("MaretsMounts", options);
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
	local groundMounts = Mounts:GetMountList(LibMounts.GROUND);
	
	local shapeshiftGround = LibMountsExt:GetSpecialMountList(LibMounts.GROUND);
	
	for key,value in pairs(shapeshiftGround) do
		groundMounts[key] = value;
	end
	
	local groundGuys = {};
	
	Mounts:MakeMountTable(groundMounts, groundGuys, LibMounts.GROUND);
	
	Mounts.options.args['Ground'] = {};
	Mounts.options.args.Ground['type'] = 'group';
	Mounts.options.args.Ground['name'] = 'Ground';
	
	Mounts.options.args.Ground.args = groundGuys;
	
	--Create air mounts for options table
	local airMounts = Mounts:GetMountList(LibMounts.AIR);

	local shapeshiftAir = LibMountsExt:GetSpecialMountList(LibMounts.AIR);

	for key,value in pairs(shapeshiftAir) do
		airMounts[key] = value;
	end

	local airGuys = {};
	
	Mounts:MakeMountTable(airMounts, airGuys, LibMounts.AIR);
	
	Mounts.options.args['Air'] = {};
	Mounts.options.args.Air['type'] = 'group';
	Mounts.options.args.Air['name'] = 'Flying';
	
	Mounts.options.args.Air.args = airGuys;
	
	-- create water mounts for options table
	local waterMounts = Mounts:GetMountList(LibMounts.WATER);
	local vashjir = Mounts:GetMountList(LibMounts.VASHJIR);

	for key,value in pairs(vashjir) do
		waterMounts[key] = value;
	end

	local shapeshiftWater = LibMountsExt:GetSpecialMountList(LibMounts.WATER);

	for key,value in pairs(shapeshiftWater) do
		waterMounts[key] = value;
	end

	local waterGuys = {};
	
	Mounts:MakeMountTable(waterMounts, waterGuys, LibMounts.WATER);
	
	Mounts.options.args['Water'] = {};

	Mounts.options.args.Water['type'] = 'group';
	Mounts.options.args.Water['name'] = 'Swimming';
	
	Mounts.options.args.Water.args = waterGuys;
	
	-- create repair mounts for options table
	local repairGuys = {};
	local repairMounts = {};
	
	repairMounts = LibMountsExt.data["vendorrepair"];
	
	Mounts:MakeMountTable(repairMounts, repairGuys, LibMountsExt.REPAIR);
	
	Mounts.options.args['Repair'] = {};
	Mounts.options.args.Repair['type'] = 'group';
	Mounts.options.args.Repair['name'] = 'Repair/Vendor';
	
	Mounts.options.args.Repair.args = repairGuys;
end

function Mounts:GetMountList(mounttype)
	local mountList = {};

	local libMountsList = LibMounts:GetMountList(mounttype);
	local extMountsList = LibMountsExt:GetMountList(mounttype);
	
	if (libMountsList ~= nil) then
		for key,value in pairs(libMountsList) do
			mountList[key] = value;
		end
	end
	
	if (extMountsList ~= nil) then
		for key,value in pairs(extMountsList) do
			mountList[key] = value;
		end
	end
	
	return mountList;
end

function Mounts:MakeMountTable(mounts, optionsTable, mounttype)
	local allMounts = GetNumCompanions("MOUNT");

	for key,value in pairs(mounts) do
		local name;
		local spellid;
		local disabled, message = false, nil;

		local type = LibMountsExt:GetMountType(key)

		if type == LibMountsExt.Types.SPELL then
			local spellName = GetSpellInfo(key);
			spellid = key;
			name = spellName;
		elseif type == LibMountsExt.Types.ITEM then
			local itemName = GetItemInfo(key);
			spellid = key;
			name = itemName;
		else
			local mountId, creatureID, creatureName, creatureSpellID, icon, issummoned = LibMountsExt:GetMountInfo(key);
			
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
	local hasOther, otherSpellID = LibMountsExt:HasOtherFactionEquivalent(spellid)

	local tableToAddTo
	
	if mounttype == LibMounts.GROUND then
		tableToAddTo = Mounts.db.profile.Ground
	elseif mounttype == LibMounts.AIR then
		tableToAddTo = Mounts.db.profile.Flying
	elseif mounttype == LibMounts.WATER then
		tableToAddTo = Mounts.db.profile.Swimming
	elseif mounttype == LibMountsExt.REPAIR then
		tableToAddTo = Mounts.db.profile.Repair
	end
	
	tableToAddTo[#tableToAddTo+1] = spellid;
		
	if hasOther then
		tableToAddTo[#tableToAddTo+1] = otherSpellID;
	end
end

function Mounts:RemoveMountAsSummonable(spellid, mounttype)
	local tableToRemoveFrom
	
	local hasOther, otherSpellId = LibMountsExt:HasOtherFactionEquivalent(spellid)
	
	if mounttype == LibMounts.GROUND then
		tableToRemoveFrom = Mounts.db.profile.Ground
	elseif mounttype == LibMounts.AIR then
		tableToRemoveFrom = Mounts.db.profile.Flying
	elseif mounttype == LibMounts.WATER then
		tableToRemoveFrom = Mounts.db.profile.Swimming
	elseif mounttype == LibMountsExt.REPAIR then
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
		--for index = keyToRemove, #mountTable-1 do
			--mountTable[index] = mountTable[index+1];
		--end
	
		table.remove(mountTable, keyToRemove);
	end
end

function Mounts:GetMountSummonState(spellid, mounttype, info)

	if mounttype == LibMounts.GROUND then
		for key,value in pairs(Mounts.db.profile.Ground) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == LibMounts.AIR then
		for key,value in pairs(Mounts.db.profile.Flying) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == LibMounts.WATER then
		for key,value in pairs(Mounts.db.profile.Swimming) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == LibMountsExt.REPAIR then
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
	local summonable, profession, level = LibMounts:GetProfessionRestriction(spellid);
	
	local ground, air, water, speed, location, passengers = LibMounts:GetMountInfo(spellid);
	
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

	local type = LibMountsExt:GetMountType(id)

	if type == LibMountsExt.Types.ITEM then
		local count = GetItemCount(id, true)
		if count > 0 then
			return true
		else
			return false
		end
	elseif type == LibMountsExt.Types.SPELL then
		return IsSpellKnown(id)
	else
		local currentCanUse, restricted = LibMountsExt:IsMountClassRestricted(id)
		
		return currentCanUse
	end

	return true;
end

function Mounts:GetRandomMountID()
	local idToCall = nil

	-- Make sure they can use a swimming mount at all (they may be < level 20)
	if IsSwimming() and IsUsableSpell(64731) and #Mounts.db.profile.Swimming > 0 then
		while not LibMountsExt:IsMountUsable(idToCall) or not LibMountsExt:IsMountClassRestricted(idToCall) do
			idToCall = Mounts.db.profile.Swimming[random(#Mounts.db.profile.Swimming)];
		end
	--Instead of checking for flying skill, just check if a flyable mount can be used to handle not having the proper riding skill
	elseif IsFlyableArea() and IsUsableSpell(88718) and #Mounts.db.profile.Flying > 0 then 
		while not LibMountsExt:IsMountUsable(idToCall) or not LibMountsExt:IsMountClassRestricted(idToCall) do
			idToCall = Mounts.db.profile.Flying[random(#Mounts.db.profile.Flying)];
		end
	--Instead of checking riding skill, make sure they can use any ground mount, since all mounts scale with riding skill (they may be < level 20)
	elseif #Mounts.db.profile.Ground > 0 and IsUsableSpell(101542) then
		while not LibMountsExt:IsMountUsable(idToCall) or not LibMountsExt:IsMountClassRestricted(idToCall) do
			idToCall = Mounts.db.profile.Ground[random(#Mounts.db.profile.Ground)];
		end
	end
	
	return idToCall
end

--Mounting functions
function Mounts:Mount()
	local idToCall = nil;

	if IsMounted() then
		Dismount()
		return
	end

	if not Mounts:CanMountNow() then
		return
	end

	if not IsMounted() then
		idToCall = Mounts:GetRandomMountID()

		idToCall = LibMountsExt:GetMountInfo(idToCall);
		
		CallCompanion("Mount", idToCall);
	else
		Dismount();
	end
end

function Mounts:MountRepair()
	local idToCall = nil;

	if IsMounted() then
		Dismount()
		return
	end

	if not Mounts:CanMountNow() then
		return
	end
	
	while not LibMountsExt:IsMountUsable(idToCall) and #Mounts.db.profile.Repair > 0 do
		idToCall = Mounts.db.profile.Repair[random(#Mounts.db.profile.Repair)];
	end
	
	idToCall = LibMountsExt:GetMountInfo(idToCall);
		
	CallCompanion("Mount", idToCall);
end

function Mounts:CanMountNow()
	if IsIndoors() or InCombatLockdown() then
		-- If we are in combat, just try to call our first ground mount so we get the error message
		CallCompanion("MOUNT", LibMountsExt:GetMountSummonID(Mounts.db.profile.Ground[1]))
		return false
	end
	
	return true
end

--Helper for things that LibMounts does not have
LibMountsExt = {
	REPAIR = {},
	data = {},
	Types = {},
}

LibMountsExt.REPAIR = "repair"

LibMountsExt.Types.ITEM = "item"
LibMountsExt.Types.SPELL = "spell"
LibMountsExt.Types.MOUNT = "mount"

LibMountsExt.data[LibMounts.GROUND] = {

}

LibMountsExt.data[LibMounts.AIR] = {

}

LibMountsExt.data["paladin"] = {
	[34769] = true,
	[13819] = true,
	[66906] = true,
	[23214] = true,
	[34767] = true
}

LibMountsExt.data["warlock"] = {
	[5784] = true,
	[23161] = true
}

LibMountsExt.data["deathknight"] = {
	[48778] = true,
	[54729] = true
}

LibMountsExt.data["vendorrepair"] = {
	[61425] = true, -- Traveler's Tundra Mammoth (Alliance)
	[61447] = true, -- Traveler's Tundra Mammoth (Horde)
	[122708] = true -- Grand Expedition Yak
}

LibMountsExt.data["shapeshift"] = {
	[33943] = LibMounts.AIR, 
	[40120] = LibMounts.AIR,
	[783] = LibMounts.GROUND,
	[1066] = LibMounts.WATER
}

--Key = Horde, Value = Alliance
LibMountsExt.data["factionequivalent"] = {
		[118737] = 130985, --Pandaren Kite
		[61467] = 61465, -- Grand Black War Mammoth
		[61469] = 61470, -- Grand Ice Mammoth
		[61447] = 61425, -- Traveler's Tundra Mammoth
		[136163] = 136164,
		[135416] = 135418
}

LibMountsExt.data["items"] = {
	    [71086] = {
            LibMounts.AIR,
        },
        [37011] = {
            LibMounts.AIR,
            LibMounts.GROUND,
        }
}

function LibMountsExt:GetMountInfo(spellid)
	local allMounts = GetNumCompanions("MOUNT");

	for mountId = 1, allMounts do
		local creatureID, creatureName, creatureSpellID, icon, issummoned = GetCompanionInfo("MOUNT", mountId);
		if creatureID == nil then
				--continue
		elseif creatureSpellID == spellid then
			return mountId, creatureID, creatureName, creatureSpellID, icon, issummoned;
		end
	end
end

function LibMountsExt:GetMountList(mounttype)
	return LibMountsExt.data[mounttype];
end

function LibMountsExt:GetSpecialMountList(mounttype)

	local returnShifts = {};
	for k,v in pairs(LibMountsExt.data["shapeshift"]) do
		if v == mounttype then
			returnShifts[k] = true;
		end
	end
	
	for k,v in pairs(LibMountsExt.data["items"]) do
		for key, value in pairs(v) do
			if value == mounttype then
				returnShifts[k] = true;
			end
		end
	end

	return returnShifts;
end

function LibMountsExt:GetMountType(id)
	if LibMountsExt.data["shapeshift"][id] ~= nil then
		return LibMountsExt.Types.SPELL
	elseif LibMountsExt.data["items"][id] ~= nil then
		return LibMountsExt.Types.ITEM
	else
		return LibMountsExt.Types.MOUNT
	end
end

--Returns true, and other faction id. And just false otherwise
function LibMountsExt:HasOtherFactionEquivalent(id)
	for h,a in pairs(LibMountsExt.data["factionequivalent"]) do
		if h == id then
			return true, a
		elseif a == id then
			return true, h
		end
	end
	
	return false
end

--Returns CanPlayerUse and HasClassRestrictions
function LibMountsExt:IsMountClassRestricted(id)
	if (id == nil) then
		return false, false
	end

	local localizename, englishname = UnitClass("player");
	
	if LibMountsExt.data["paladin"][id] then
		if englishname ~= 'PALADIN' then
			return false, true;
		else
			return true, true
		end
	end
	if LibMountsExt.data["warlock"][id] then
		if englishname ~= 'WARLOCK' then
			return false, true;
		else
			return true, true
		end
	end
	if LibMountsExt.data["deathknight"][id] then
		if englishname ~= 'DEATHKNIGHT' then
			return false, true;
		else
			return true, true
		end
	end
	
	return true, false
end

function LibMountsExt:IsMountUsable(spellid)
	if spellid == nil then
		return false;
	end

	local type = LibMountsExt:GetMountType(spellid)

	if type == LibMountsExt.Types.ITEM then
		return LibMountsExt:IsItemUsable(spellid)
	elseif type == LibMountsExt.Types.SPELL then
		return IsSpellKnown(spellid)
	elseif type == LibMountsExt.Types.MOUNT then
	
		if LibMountsExt:GetMountSummonID(spellid) == nil then
			return false
		end
	
		local primary, secondary, thirdary = LibMounts:GetCurrentMountType();
		local ground, air, water, speed, location, passengers = LibMounts:GetMountInfo(spellid);

		if location == LibMounts.VASHJIR then
			if primary == LibMounts.VASHJIR or secondary == LibMounts.VASHJIR then
				return true;
			else
				return false;
			end
		end
	end
	return true;
end

function LibMountsExt:IsItemUsable(id)
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

function LibMountsExt:GetMountSummonID(spellid)
	local allMounts = GetNumCompanions("MOUNT");

	for mountId = 1, allMounts do
		local creatureID, creatureName, creatureSpellID, icon, issummoned = GetCompanionInfo("MOUNT", mountId);

		if creatureID == nil then
				--continue
		elseif creatureSpellID == spellid then
			return mountId;
		end
	end
end
