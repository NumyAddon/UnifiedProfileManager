local name, ns = ...;

local AceDB = LibStub('AceDB-3.0');
local AceDBOptions = LibStub('AceDBOptions-3.0');
local AceConfig = LibStub('AceConfig-3.0');
local AceConfigDialog = LibStub('AceConfigDialog-3.0');

local function SortAddons(name1, name2)
    return strcmputf8i(StripHyperlinks(name1), StripHyperlinks(name2)) < 0;
end

local currentCharacterName = UnitName('player')..' - '..GetRealmName();
local L;
do
    L = {
        choose_sub = 'Select one of your currently available profiles.',
        default = 'Default',
    };

    local LOCALE = GetLocale();
    if LOCALE == 'deDE' then
        L['choose_sub'] = 'Wählt ein bereits vorhandenes Profil aus.';
        L['default'] = 'Standard';
    elseif LOCALE == 'frFR' then
        L['choose_sub'] = 'Permet de choisir un des profils déjà disponibles.';
        L['default'] = 'Défaut';
    elseif LOCALE == 'koKR' then
        L['choose_sub'] = '현재 이용할 수 있는 프로필 중 하나를 선택합니다.';
        L['default'] = '기본값';
    elseif LOCALE == 'esES' or LOCALE == 'esMX' then
        L['choose_sub'] = 'Selecciona uno de los perfiles disponibles.';
        L['default'] = 'Por defecto';
    elseif LOCALE == 'zhTW' then
        L['choose_sub'] = '從當前可用的設定檔裡面選擇一個。';
        L['default'] = '預設';
    elseif LOCALE == 'zhCN' then
        L['choose_sub'] = '从当前可用的配置文件里面选择一个。';
        L['default'] = '默认';
    elseif LOCALE == 'ruRU' then
        L['choose_sub'] = 'Выбор одного из уже доступных профилей.';
        L['default'] = 'По умолчанию';
    elseif LOCALE == 'itIT' then
        L['choose_sub'] = 'Seleziona uno dei profili attualmente disponibili.';
        L['default'] = 'Predefinito';
    elseif LOCALE == 'ptBR' then
        L['choose_sub'] = 'Selecione um de seus perfis atualmente disponíveis.';
        L['default'] = 'Padrão';
    end
end

ns.resultCache = {};
function ns:FindGlobal(item)
    if not self.resultCache[item] then
        for k, v in pairs(_G) do
            if item == v then
                self.resultCache[item] = k;
                break;
            end
        end
	end

    return self.resultCache[item];
end

function ns:GetDuplicateAddons()
    local duplicateAddons = {};
    local addonNames = {};
    for db, _ in pairs(AceDB.db_registry) do
        if not db.parent then
            local addonName = self:GetAddonNameForDB(db);
            if addonNames[addonName] then
                duplicateAddons[addonName] = true;
            end
            addonNames[addonName] = true;
        end
    end

    return duplicateAddons;
end

ns.dbCache = {};
function ns:GetAddonNameForDB(db)
    if not ns.dbCache[db] then
        local _, addonName = issecurevariable(db, 'sv');
        _, addonName = C_AddOns.GetAddOnInfo(addonName);
        ns.dbCache[db] = addonName;
    end

    return ns.dbCache[db];
end

local altHandlerPrototype = {};
do
    local defaultProfilesProto = {
        ['Default'] = L['default'],
    };
    for classID = 1, GetNumClasses() do
        local className, classFilename = GetClassInfo(classID);
        if className then
            defaultProfilesProto[classFilename] = className;
        end
    end

    local defaultProfileCache = {};
    function altHandlerPrototype:GetDefaultProfilesForCharacter(characterName)
        if defaultProfileCache[characterName] then
            return defaultProfileCache[characterName];
        end
        local defaultProfiles = Mixin({
            [characterName] = characterName,
        }, defaultProfilesProto);
        local realm = characterName:match(' %- (.+)');
        if realm then
            defaultProfiles[realm] = realm;
        end

        defaultProfileCache[characterName] = defaultProfiles;
        return defaultProfiles;
    end

	function altHandlerPrototype:ListProfiles(info)
	    local db = self.db;
	    local characterName = info.arg;
        local profiles = {};
        for profile, _ in pairs(db.sv.profiles) do
            profiles[profile] = profile;
        end

        for k, v in pairs(self:GetDefaultProfilesForCharacter(characterName)) do
            profiles[k] = v;
        end

        return profiles;
	end

	function altHandlerPrototype:GetCurrentProfile(info)
        local db = self.db;
        local characterName = info.arg;
        local currentProfile = db.sv and db.sv.profileKeys and db.sv.profileKeys[characterName];

        return currentProfile;
    end

    function altHandlerPrototype:SetProfile(info, profile)
        local db = self.db;
        local characterName = info.arg;
        db.sv.profileKeys[characterName] = profile;
    end
end

ns.altHandlers = {};
function ns:MakeAltOptions(db)
    if not db.sv or not db.sv.profileKeys or not next(db.sv.profileKeys) then
        return nil;
    end
    local altHandler = self.altHandlers[db] or {db = db};
    Mixin(altHandler, altHandlerPrototype);

    local group = {
        type = 'group',
        name = 'Character Profiles',
        inline = true,
        order = -1,
        args = {},
        handler = altHandler,
    }
    local option = {
        name = '', -- character name
        desc = L['choose_sub'],
        type = 'select',
        order = 1, -- order by character name
        arg = '', -- character name
        get = 'GetCurrentProfile',
        set = 'SetProfile',
        values = 'ListProfiles',
    };

    local orderedCharacterNames = {};
    for characterName, _ in pairs(db.sv.profileKeys) do
        table.insert(orderedCharacterNames, characterName);
    end
    table.sort(orderedCharacterNames);
    orderedCharacterNames = tInvert(orderedCharacterNames);

    local i = 1;
    for characterName, _ in pairs(db.sv.profileKeys) do
        if characterName ~= currentCharacterName then
            i = i + 1;
            local charOption = CopyTable(option, true);
            charOption.name = characterName;
            charOption.arg = characterName;
            charOption.order = orderedCharacterNames[characterName] or i;
            group.args['char'..i] = charOption;
        end
    end
    if not next(group.args) then
        return nil;
    end

    return group;
end

local function DeepCopyTable(settings, ignoredValue)
	local copy = {};
	for k, v in pairs(settings) do
		if type(v) == "table" and v ~= ignoredValue then
			copy[k] = CopyTable(v);
		else
			copy[k] = v;
		end
	end
	return copy;
end

function ns:GetOptionsTable(skipAddons)
    local options = {
        type = 'group',
        args = {
            ['allProfiles'] = {
                type = 'group',
                order = 2,
                name = 'All Addons',
                desc = 'Overview of all addon profiles',
                args = {
                    desc = {
                        type = 'description',
                        name = 'You can change the profile for all addons here. Some addons may need you to reload the UI after switching, to avoid issues',
                        order = 1,
                    },
                    reloadUI = {
                        type = 'execute',
                        name = 'Reload UI',
                        order = 2,
                        width = 'full',
                        func = ReloadUI,
                    },
                },
            }
        },
    }
    if skipAddons then
        return options;
    end

    local addonNames = {};
    local addonOrder = {};
    local function getOrder(info)
        local addonName = info.option.name;

        return addonOrder[addonName] or -1;
    end
    local increment = CreateCounter(2);
    local allProfiles = options.args.allProfiles;

    local duplicateAddons = self:GetDuplicateAddons();

    for db, _ in pairs(AceDB.db_registry) do
        if not db.parent then
            local i = increment();

            local addonName = self:GetAddonNameForDB(db);
            if duplicateAddons[addonName] then
                local savedVariableName = self:FindGlobal(db.sv);
                addonName = addonName .. (savedVariableName and WHITE_FONT_COLOR:WrapTextInColorCode(' ('..savedVariableName..')') or '');
            end

            table.insert(addonNames, addonName);
            addonOrder[addonName] = i;

            local option = DeepCopyTable(AceDBOptions:GetOptionsTable(db), db);
            option.order = getOrder;
            option.name = addonName;
            option.inline = false;
            option.args.alts = self:MakeAltOptions(db);
            options.args['profiles'..i] = option;

            local choose = CopyTable(option.args.choose);
            choose.order = getOrder;
            choose.handler = option.handler;
            choose.name = addonName;
            allProfiles.args['profiles'..i] = choose;
        end
    end

    table.sort(addonNames, SortAddons);
    for i, addonName in ipairs(addonNames) do
        addonOrder[addonName] = i + 2;
    end

    return options;
end

function ns:Init()
    AceConfig:RegisterOptionsTable(name, ns:GetOptionsTable(true));
    local panel, category = AceConfigDialog:AddToBlizOptions(name, name);

    local ignoreHook = false;
    panel:HookScript('OnShow', function()
        if ignoreHook then return; end
        ignoreHook = true;
        AceConfig:RegisterOptionsTable(name, ns:GetOptionsTable());
        panel:Hide();
        panel:Show();
        RunNextFrame(function() ignoreHook = false; end);
    end);

    _G.SLASH_UNIFIED_PROFILE_MANAGER1 = '/upm';
    _G.SLASH_UNIFIED_PROFILE_MANAGER2 = '/profiles';
    SlashCmdList['UNIFIED_PROFILE_MANAGER'] = function()
        Settings.OpenToCategory(category);
    end;
end

ns:Init();
