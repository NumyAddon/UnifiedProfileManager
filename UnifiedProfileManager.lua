local name, ns = ...;

local AceDB = LibStub('AceDB-3.0');
local AceDBOptions = LibStub("AceDBOptions-3.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

local function SortAddons(name1, name2)
    return strcmputf8i(StripHyperlinks(name1), StripHyperlinks(name2)) < 0;
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

            local option = CopyTable(AceDBOptions:GetOptionsTable(db), true);
            option.order = getOrder;
            option.name = addonName;
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
