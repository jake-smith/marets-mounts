local Mounts = LibStub("AceAddon-3.0"):NewAddon("MaretsMounts", "AceConsole-3.0")
_G.Mounts = Mounts

local MountLib = LibStub("LibMounts-1.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")

local MountsDB

local defaults = {
	profile = {
		Ground = {},
		Flying = {},
		Swimming = {},
	}
}

local options = {
	name = "Marets Mounts",
	handler = Mounts,
    type = 'group',
    childGroups = "tab",
    args = {}	
}

local paladinMounts = {[34769] = true,[13819] = true, [66906] = true,[23214] = true, [34767] = true};
local warlockMounts = {[5784] = true, [23161] = true};
local dkMounts = {[48778] = true, [54729] = true}

local shapeshiftAir = {[33943] = true, [40120] = true};
local shapeshiftGround = {[783] = true};
local shapeshiftWater = {[1066] = true};
local itemMounts = {[101641] = true;}; 

function Mounts.OnInitialize()
	Mounts:RegisterChatCommand("mountyourface", Mount);
	
	MountsDB = AceDB:New("MaretsMountsDB", defaults, true);
	Mounts.db = MountsDB;
end

function Mounts:OnEnable()
	Mounts:BuildGroundMountOptions();
	
	if GetMacroInfo('Mount Your Face') == nil then
		CreateMacro("Mount Your Face", "ability_mount_drake_proto", "/mountyourface", nil);
	end
end

function Mounts:GetMountSpellIDFromSummonID(summonID)

	local creatureID, creatureName, creatureSpellID, icon, issummoned = GetCompanionInfo("MOUNT", summonID);

	return creatureSpellID;
end

function Mounts:BuildGroundMountOptions()
	local groundMounts = MountLib:GetMountList(MountLib.GROUND);
	
	for key,value in pairs(shapeshiftGround) do
		groundMounts[key] = value;
	end
	
	local groundGuys = {};
	
	Mounts:MakeMountTable(groundMounts, groundGuys, MountLib.GROUND);
	
	options.args['Ground'] = {};
	options.args.Ground['type'] = 'group';
	options.args.Ground['name'] = 'Ground Mounts';
	
	options.args.Ground.args = groundGuys;
	
	local airMounts = MountLib:GetMountList(MountLib.AIR);

	for key,value in pairs(shapeshiftAir) do
		airMounts[key] = value;
	end

	for key,value in pairs(itemMounts) do
		airMounts[key] = value;
	end

	local airGuys = {};
	
	Mounts:MakeMountTable(airMounts, airGuys, MountLib.AIR);
	
	options.args['Air'] = {};
	options.args.Air['type'] = 'group';
	options.args.Air['name'] = 'Flying Mounts';
	
	options.args.Air.args = airGuys;
	
	local waterMounts = MountLib:GetMountList(MountLib.WATER);
	local vashjir = MountLib:GetMountList(MountLib.VASHJIR);

	for key,value in pairs(vashjir) do
		waterMounts[key] = value;
	end

	for key,value in pairs(shapeshiftWater) do
		waterMounts[key] = value;
	end

	local waterGuys = {};
	
	Mounts:MakeMountTable(waterMounts, waterGuys, MountLib.WATER);
	
	options.args['Water'] = {};

	options.args.Water['type'] = 'group';
	options.args.Water['name'] = 'Swimming Mounts';
	
	options.args.Water.args = waterGuys;
	
	AceConfig:RegisterOptionsTable("MaretsMounts", options, {'config'});
	AceConfigDialog.AddToBlizOptions("MaretsMounts", "MaretsMounts")
end

function Mounts:MakeMountTable(mounts, optionsTable, mounttype)
	local allMounts = GetNumCompanions("MOUNT");

	for key,value in pairs(mounts) do
		local name;
		local spellid;
		local disabled, message = false, nil;

		if shapeshiftGround[key] or shapeshiftAir[key] or shapeshiftWater[key] or itemMounts[key] then
			local spellId, spellName, spellLink = GetSpellInfo(key);
			spellid = spellId;
			name = spellName;
		else
			for mountId = 1, allMounts do
				local creatureID, creatureName, creatureSpellID, icon, issummoned = GetCompanionInfo("MOUNT", mountId);

				if creatureID == nil then
					--continue;
				elseif creatureSpellID == key then
					name = creatureName;
					spellid = creatureSpellID;
					break;
				end
			end
			
			if (name ~= nil) then
				disabled, message = Mounts:GetRestrictions(spellid);
			end
		end
		if (name ~= nil) then
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

function Mounts:GetRestrictions(spellid)
	local summonable, profession, level = MountLib:GetProfessionRestriction(spellid);
	
	local ground, air, water, speed, location, passengers = MountLib:GetMountInfo(spellid);
	
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

function Mounts:GetMountSummonID(spellid)
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

function Mounts:SetMountSummonState(info, value, spellid, mounttype)
	if value == true then
		Mounts:AddMountAsSummonable(spellid, mounttype);
	else
		Mounts:RemoveMountAsSummonable(spellid, mounttype);
	end
end

function Mounts:AddMountAsSummonable(spellid, mounttype)
	if mounttype == 'ground' then
		MountsDB.profile.Ground[#MountsDB.profile.Ground+1] = spellid;
	elseif mounttype == 'air' then
		MountsDB.profile.Flying[#MountsDB.profile.Flying+1] = spellid;
	elseif mounttype == 'water' then
		MountsDB.profile.Swimming[#MountsDB.profile.Swimming+1] = spellid;
	end
end

function Mounts:RemoveMountAsSummonable(spellid, mounttype)
	if mounttype == 'ground' then
		Mounts:RemoveMountFromTable(MountsDB.profile.Ground, spellid);
	elseif mounttype == 'air' then
		Mounts:RemoveMountFromTable(MountsDB.profile.Flying, spellid);
	elseif mounttype == 'water' then
		Mounts:RemoveMountFromTable(MountsDB.profile.Swimming, spellid);
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
	
	for index = keyToRemove, #mountTable-1 do
		mountTable[index] = mountTable[index+1];
	end
	
	table.remove(mountTable);
end

function Mounts:GetMountSummonState(spellid, mounttype, info)

	if mounttype == 'ground' then
		for key,value in pairs(MountsDB.profile.Ground) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == 'air' then
		for key,value in pairs(MountsDB.profile.Flying) do
			if value == spellid then
				return true;
			end
		end
	elseif mounttype == 'water' then
		for key,value in pairs(MountsDB.profile.Swimming) do
			if value == spellid then
				return true;
			end
		end
	end
	
	return false;
end

function Mount()
	local idToCall = nil;
	
	if not IsMounted() then
		if IsFlyableArea() then
			while not IsMountUsable(idToCall) do
				idToCall = MountsDB.profile.Flying[random(#MountsDB.profile.Flying)];
			end
		elseif IsSwimming() then
			while not IsMountUsable(idToCall) do
				idToCall = MountsDB.profile.Swimming[random(#MountsDB.profile.Swimming)];
			end
		else
			while not IsMountUsable(idToCall) do
				idToCall = MountsDB.profile.Ground[random(#MountsDB.profile.Ground)];
			end
		end

		idToCall = Mounts:GetMountSummonID(idToCall);
		
		CallCompanion("Mount", idToCall);
	else
		Dismount();
	end
end

function IsMountUsable(spellid)
	if spellid == nil then
		return false;
	end

	local primary, secondary, thirdary = MountLib:GetCurrentMountType();
	local ground, air, water, speed, location, passengers = MountLib:GetMountInfo(spellid);
	local localizename, englishname = UnitClass("player");
	
	if location == MountLib.VASHJIR then		
		if primary == MountLib.VASHJIR or secondary == MountLib.VASHJIR then
			return true;
		else
			return false;
		end
	end
	if englishname ~= 'PALADIN' then
		if paladinMounts[spellid] then
			return false;
		end
	end
	if englishname ~= 'WARLOCK' then
		if warlockMounts[spellid] then
			return false;
		end
	end
	if englishname ~= 'DEATHKNIGHT' then
		if dkMounts[spellid] then
			return false;
		end
	end
	if englishname ~= 'DRUID' then
		if shapeshiftGround[spellid] or shapeshiftAir[spellid] or shapeshiftWater[spellid] or itemMounts[spellid] then
			return false;
		end
	end
	
	return true;
end
