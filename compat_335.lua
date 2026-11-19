-- WoW 3.3.5a compatibility layer for the Myslot fork (interface 30300).
-- Listed FIRST in Myslot.toc so every definition below exists before the rest
-- of the addon loads. Everything is defined at column 0 (plain globals) on
-- purpose: verify-addon.mjs treats those as addon-defined names.
--
-- Sources for the client-side behaviour replicated here (FrameXML 3.3.5a):
--   UIDropDownMenu.lua / UIDropDownMenuTemplates.xml / UIDropDownMenu.xml,
--   EasyMenu.lua, InterfaceOptionsFrame.lua, Constants.lua, PetActionBarFrame.lua
--   in E:\AI\Tools\ref\335-interface-files.

-- ---------------------------------------------------------------------------
-- Small Lua/FrameXML helpers that exist on retail but not on 3.3.5.
-- ---------------------------------------------------------------------------

-- Every shim below is installed only when the client (or another addon) has
-- not provided the name already. Overwriting a global that other addons use
-- makes them fail later, even when Myslot itself works.

-- tAppendAll (retail UIFrameTemplateUtil): append every element of src to dst.
local function CompatTAppendAll(dst, src)
    for i = 1, #src do
        dst[#dst + 1] = src[i]
    end
end
tAppendAll = tAppendAll or CompatTAppendAll

-- IsPetActive (retail). Myslot only needs "the pet action bar is up", which on
-- 3.3.5 is exactly PetHasActionBar() (FrameXML PetActionBarFrame.lua, in the
-- 3.3.5a doc index).
local function CompatIsPetActive()
    return (PetHasActionBar() and true) or false
end
IsPetActive = IsPetActive or CompatIsPetActive

-- Retail font colours are ColorMixin objects with WrapTextInColorCode; on
-- 3.3.5 the *_FONT_COLOR globals are plain {r,g,b} tables (Constants.lua) and
-- the method does not exist in the client binary. Give them a compatible
-- method so the addon's colour-coded messages work unchanged.
local function AddWrapTextInColorCode(colorTable)
    if colorTable and not colorTable.WrapTextInColorCode then
        function colorTable.WrapTextInColorCode(self, text)
            return string.format("|cff%02x%02x%02x%s|r",
                math.floor((self.r or 1) * 255 + 0.5),
                math.floor((self.g or 1) * 255 + 0.5),
                math.floor((self.b or 1) * 255 + 0.5),
                text or "")
        end
    end
end
AddWrapTextInColorCode(RED_FONT_COLOR)
AddWrapTextInColorCode(GREEN_FONT_COLOR)
AddWrapTextInColorCode(ORANGE_FONT_COLOR)
AddWrapTextInColorCode(YELLOW_FONT_COLOR)

-- ---------------------------------------------------------------------------
-- C_Timer: preserve the client's table if it exists (other addons rely on
-- NewTicker / NewTimer being present). Fill in only the missing methods.
-- After(delay, cb) runs cb once; NewTimer returns a cancelable handle;
-- NewTicker repeats until the iteration count runs out or :Cancel() is called.
-- One hidden driver frame fires due callbacks from OnUpdate; the due set is
-- split off before any callback runs so a callback may schedule another timer.
-- ---------------------------------------------------------------------------
local timerEntries = {}
local timerDriver = CreateFrame("Frame")
timerDriver:Hide()

local function FireTimers()
    local now = GetTime()
    local due, rest = {}, {}
    for i = 1, #timerEntries do
        local entry = timerEntries[i]
        if entry.time <= now then
            due[#due + 1] = entry
        else
            rest[#rest + 1] = entry
        end
    end
    timerEntries = rest
    if #rest == 0 then
        timerDriver:Hide()
    end
    for i = 1, #due do
        local entry = due[i]
        if not entry.cancelled then
            local ok, err
            if entry.arguments then
                ok, err = pcall(entry.callback, unpack(entry.arguments))
            else
                ok, err = pcall(entry.callback)
            end
            if not ok then
                geterrorhandler()(err)
            end
            if entry.iterations then
                entry.iterations = entry.iterations - 1
                if entry.iterations > 0 then
                    entry.time = GetTime() + entry.delay
                    timerEntries[#timerEntries + 1] = entry
                    timerDriver:Show()
                end
            end
        end
    end
end
timerDriver:SetScript("OnUpdate", FireTimers)

local function ScheduleTimer(delay, callback, iterations, passHandle)
    local entry = {
        time = GetTime() + delay,
        delay = delay,
        callback = callback,
        iterations = iterations,
        cancelled = false,
    }
    local handle = {}
    function handle:Cancel()
        self.cancelled = true
        entry.cancelled = true
    end
    if passHandle then
        entry.arguments = { handle }
    end
    timerEntries[#timerEntries + 1] = entry
    timerDriver:Show()
    return handle
end

local function CompatTimerAfter(delay, callback)
    ScheduleTimer(delay, callback)
end

local function CompatTimerNewTimer(delay, callback)
    return ScheduleTimer(delay, callback, 1)
end

local function CompatTimerNewTicker(delay, callback, iterations)
    return ScheduleTimer(delay, callback, iterations, true)
end

C_Timer = C_Timer or {}
C_Timer.After = C_Timer.After or CompatTimerAfter
C_Timer.NewTimer = C_Timer.NewTimer or CompatTimerNewTimer
C_Timer.NewTicker = C_Timer.NewTicker or CompatTimerNewTicker

-- ---------------------------------------------------------------------------
-- C_UI (retail): the only part the addon uses is C_UI.Reload -> ReloadUI().
-- The column-0 assignment also tells the verifier that C_UI is addon code.
-- ---------------------------------------------------------------------------
local function CompatCUIReload()
    ReloadUI()
end
C_UI = C_UI or {}
C_UI.Reload = C_UI.Reload or CompatCUIReload

-- ---------------------------------------------------------------------------
-- C_EquipmentSet (retail) over the flat 3.3.5 equipment-set functions
-- (FrameXML PaperDollFrame.lua: GetNumEquipmentSets / GetEquipmentSetInfo /
-- PickupEquipmentSet, all present in the 3.3.5a binary). GetActionInfo never
-- returns the "equipmentset" action type on 3.3.5, so the export path stays
-- dead on this client; the wrappers keep the import path and the static check
-- consistent.
-- ---------------------------------------------------------------------------
local function CompatGetNumEquipmentSets()
    return GetNumEquipmentSets()
end

local function CompatGetEquipmentSetInfo(index)
    -- 3.3.5 returns name first; the addon compares the first value with a
    -- name taken from the serialized profile.
    return GetEquipmentSetInfo(index)
end

local function CompatPickupEquipmentSet(index)
    PickupEquipmentSet(index)
end

C_EquipmentSet = C_EquipmentSet or {}
C_EquipmentSet.GetNumEquipmentSets = C_EquipmentSet.GetNumEquipmentSets or CompatGetNumEquipmentSets
C_EquipmentSet.GetEquipmentSetInfo = C_EquipmentSet.GetEquipmentSetInfo or CompatGetEquipmentSetInfo
C_EquipmentSet.PickupEquipmentSet = C_EquipmentSet.PickupEquipmentSet or CompatPickupEquipmentSet

-- ---------------------------------------------------------------------------
-- Retail settings API on top of the classic Interface Options frame. This is
-- deliberately a PRIVATE global (MyslotCompatSettings), not `Settings`:
-- AceConfigDialog-3.0 (Questie) and LibCompat-1.0 (Leatrix Plus, CuratorRemix)
-- switch to retail code paths as soon as a global `Settings` exists, and their
-- expected methods are not the same as Myslot's. RegisterCanvasLayoutCategory
-- hands back the category object the addon stores (gui.lua reads .ID),
-- RegisterAddOnCategory attaches the panel (InterfaceOptionsFrame.lua:585),
-- OpenToCategory reopens it by that ID (InterfaceOptionsFrame.lua:428).
-- On 3.3.5 there is no SettingsPanel, so gui.lua's modern branch is skipped.
-- ---------------------------------------------------------------------------
MyslotCompatSettings = {}

local registeredCategories = {}
local nextCategoryID = 0

function MyslotCompatSettings.RegisterCanvasLayoutCategory(frame, name)
    nextCategoryID = nextCategoryID + 1
    local category = {
        frame = frame,
        ID = nextCategoryID,
        name = name or (frame and frame.name) or "",
    }
    registeredCategories[nextCategoryID] = category
    return category
end

function MyslotCompatSettings.RegisterAddOnCategory(category)
    if category and category.frame then
        InterfaceOptions_AddCategory(category.frame)
    end
end

function MyslotCompatSettings.OpenToCategory(id)
    local category = registeredCategories[id]
    if category and category.frame then
        InterfaceOptionsFrame_OpenToCategory(category.frame)
    end
end

-- ---------------------------------------------------------------------------
-- Retail Blizzard_Menu API (Menu/MenuUtil/MenuVariants/AnchorUtil) rendered
-- into the classic UIDropDownMenu system. gui.lua builds a small description
-- tree (CreateTitle/CreateDivider/CreateButton/CreateCheckbox/CreateRadio plus
-- SetResponder/SetEnabled/SetShouldRespondIfSubmenu/SetMinimumWidth) and the
-- tree is flattened into classic `info` tables for EasyMenu (EasyMenu.lua:17),
-- which runs the stock 3.3.5 init/toggle path (UIDropDownMenu.lua:61, :598).
--
-- Semantics kept from the addon's retail usage:
--   * interactive nodes keep the menu open (keepShownOnClick) and the wrapper
--     decides: MenuResponse.CloseAll or nil -> close, MenuResponse.Refresh ->
--     rebuild the info tables from the same tree (re-run the initializers);
--   * checked may be a value or a function and is called with the node's data
--     table (retail passes the CreateCheckbox data argument the same way);
--   * a child responder/onClick wins over onClick, called as fn(data, nil, nil).
-- ---------------------------------------------------------------------------
local CompatMenuResponse = { Refresh = 1, CloseAll = 2 }
MenuResponse = MenuResponse or CompatMenuResponse

local CompatMenuVariants = {}
function CompatMenuVariants.GetDefaultMenuMixin()
    return {}
end
MenuVariants = MenuVariants or CompatMenuVariants

local CompatAnchorUtil = {}
function CompatAnchorUtil.CreateAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        offsetX = offsetX,
        offsetY = offsetY,
    }
end
AnchorUtil = AnchorUtil or CompatAnchorUtil

local RefreshOpenMenu -- assigned below, used by the node click wrapper
local menuFrame       -- assigned below, the hidden classic dropdown host

-- Build one description node with the retail method set.
local function NewMenuNode(kind, text, onClick, checked, data)
    local node = {
        kind = kind,
        text = text,
        onClick = onClick,
        checked = checked,
        data = data,
        nodes = {},
        enabled = true,
    }

    local function append(child)
        node.nodes[#node.nodes + 1] = child
        return child
    end

    function node:CreateTitle(childText)
        return append(NewMenuNode("title", childText))
    end
    function node:CreateDivider()
        return append(NewMenuNode("divider"))
    end
    function node:CreateButton(childText, childOnClick)
        return append(NewMenuNode("button", childText, childOnClick))
    end
    function node:CreateCheckbox(childText, childChecked, childOnClick, childData)
        return append(NewMenuNode("checkbox", childText, childOnClick, childChecked, childData))
    end
    function node:CreateRadio(childText, childChecked, childOnClick, childData)
        return append(NewMenuNode("radio", childText, childOnClick, childChecked, childData))
    end
    function node:SetResponder(fn)
        self.responder = fn
        return self
    end
    function node:SetEnabled(enabled)
        self.enabled = enabled
        return self
    end
    function node:SetShouldRespondIfSubmenu(value)
        self.respondIfSubmenu = value
        return self
    end
    function node:SetMinimumWidth(width)
        self.minWidth = width
        return self
    end

    return node
end

-- Classic click wrapper for one node (see the block comment above).
local function MakeNodeFunc(node)
    return function()
        local fn = node.responder or node.onClick
        if not fn then
            -- Submenu holder rows without a handler: keep the menu open so the
            -- expand arrow can be used.
            return
        end
        local result = fn(node.data, nil, nil)
        if result == CompatMenuResponse.Refresh then
            RefreshOpenMenu(menuFrame and menuFrame.__description)
        else
            -- nil (plain selection) and MenuResponse.CloseAll both close, which
            -- matches classic dropdown behaviour and lets gui.lua's deferred
            -- reopen (C_Timer.After(0, openMenu)) run against a closed menu.
            CloseDropDownMenus()
            if menuFrame then
                menuFrame.__openOwner = nil
            end
        end
    end
end

-- Flatten the description tree into classic `info` tables (UIDropDownMenu.lua
-- documents the fields; AddButton copies func/checked/menuList/... onto the
-- buttons at UIDropDownMenu.lua:316-345).
local function BuildMenuList(nodes)
    local menuList = {}
    for i = 1, #nodes do
        local node = nodes[i]
        local info = {}
        if node.kind == "title" then
            info.text = node.text or ""
            info.isTitle = true       -- AddButton forces disabled titles
            info.notCheckable = true
        elseif node.kind == "divider" then
            info.text = ""            -- blank disabled row as a separator
            info.isTitle = true
            info.notCheckable = true
        else
            info.text = node.text or ""
            info.keepShownOnClick = true
            info.func = MakeNodeFunc(node)
            if node.kind == "button" and #node.nodes == 0 then
                info.notCheckable = true
            end
            if node.kind == "checkbox" or node.kind == "radio" then
                info.checked = function()
                    local checked = node.checked
                    if type(checked) == "function" then
                        checked = checked(node.data)
                    end
                    return checked and true or false
                end
            end
            if #node.nodes > 0 then
                info.hasArrow = true
                info.menuList = BuildMenuList(node.nodes)
            end
        end
        if node.enabled == false then
            info.disabled = true
        end
        menuList[#menuList + 1] = info
    end
    return menuList
end

-- Hidden host frame for the menus. The name is required: with displayMode
-- "MENU" the stock UIDropDownMenu_Initialize (UIDropDownMenu.lua:61) touches
-- <name>Left/Middle/Right/Button/Text, which the UIDropDownMenuTemplate
-- (UIDropDownMenuTemplates.xml:260) provides.
menuFrame = CreateFrame("Frame", "MyslotCompatMenu", UIParent, "UIDropDownMenuTemplate")

-- Open (or toggle shut) the menu for a description tree.
-- anchor: an AnchorUtil.CreateAnchor table (fields go on the host frame and
-- the stock toggle anchors to them), a frame (menu drops below it), or nil
-- (at the cursor) - the three modes of ToggleDropDownMenu (UIDropDownMenu.lua:598).
local function ShowCompatMenu(owner, description, anchor)
    local listFrame = _G["DropDownList1"]
    if listFrame and listFrame:IsShown() and menuFrame.__openOwner == owner then
        -- Same button clicked again: toggle shut. The stock toggle would do
        -- this too, but it would also merely close when a *different* button
        -- of the same host is clicked, so switching menus is handled here.
        CloseDropDownMenus()
        menuFrame.__openOwner = nil
        return
    end

    -- Always start from a clean slate so a switch between owners reopens
    -- instead of toggling shut (see above).
    CloseDropDownMenus()

    menuFrame.point, menuFrame.relativeTo, menuFrame.relativePoint = nil, nil, nil
    menuFrame.xOffset, menuFrame.yOffset = nil, nil
    local anchorName
    if type(anchor) == "table" and anchor.relativePoint then
        menuFrame.point = anchor.point or "TOPLEFT"
        menuFrame.relativeTo = anchor.relativeTo
        menuFrame.relativePoint = anchor.relativePoint
        menuFrame.xOffset = anchor.offsetX or 0
        menuFrame.yOffset = anchor.offsetY or 0
        anchorName = nil
    elseif type(anchor) == "table" and anchor.GetLeft then
        anchorName = anchor
    else
        anchorName = "cursor"
    end

    menuFrame.__description = description
    menuFrame.__anchor = anchorName
    EasyMenu(BuildMenuList(description.nodes), menuFrame, anchorName, 0, 0, "MENU")
    menuFrame.__openOwner = owner

    -- Classic behaviour: the stock path sizes the list itself; only honour
    -- SetMinimumWidth if the tree asked for more than the current width.
    local shownFrame = _G["DropDownList1"]
    local minWidth = description.minWidth
    if shownFrame and minWidth and shownFrame:GetWidth() < minWidth then
        shownFrame:SetWidth(minWidth)
    end
end

-- MenuResponse.Refresh: rebuild the info tables from the same tree and
-- re-run the initializers so every check image is recomputed (stock
-- UIDropDownMenu_Initialize clears and repopulates the level first).
RefreshOpenMenu = function(description)
    if not description then
        return
    end
    -- The checkbox can be clicked inside a submenu (level > 1). Re-initializing
    -- level 1 while those levels stay open leaves several DropDownLists visible
    -- at once. Close every level, then rebuild the root menu from scratch.
    CloseDropDownMenus()
    UIDROPDOWNMENU_OPEN_MENU = nil
    UIDROPDOWNMENU_MENU_LEVEL = 1
    EasyMenu(BuildMenuList(description.nodes), menuFrame,
        menuFrame.__anchor or "cursor", 0, 0, "MENU")
end

-- uidropDownMenu_RefreshAll (retail global; grep of the 3.3.5a FrameXML
-- corpus finds no definition or call, so it is implemented here): re-evaluate
-- the function form of `checked` on every shown button and sync the check
-- image plus highlight. Arguments (gui.lua passes its menu frame) are ignored.
local function CompatUIDropDownMenu_RefreshAll()
    for level = 1, UIDROPDOWNMENU_MAXLEVELS do
        local listFrame = _G["DropDownList" .. level]
        if listFrame and listFrame:IsShown() then
            for index = 1, UIDROPDOWNMENU_MAXBUTTONS do
                local button = _G["DropDownList" .. level .. "Button" .. index]
                if button and button:IsShown() then
                    local checked = button.checked
                    if type(checked) == "function" then
                        checked = checked()
                    end
                    local checkImage = _G[button:GetName() .. "Check"]
                    if checkImage then
                        if checked then
                            checkImage:Show()
                            button:LockHighlight()
                        else
                            checkImage:Hide()
                            button:UnlockHighlight()
                        end
                    end
                end
            end
        end
    end
end
UIDropDownMenu_RefreshAll = UIDropDownMenu_RefreshAll or CompatUIDropDownMenu_RefreshAll

local CompatMenuUtil = {}
function CompatMenuUtil.CreateRootMenuDescription(initialDataMixin)
    local root = NewMenuNode("root")
    root.mixin = initialDataMixin
    return root
end

function CompatMenuUtil.CreateContextMenu(owner, createFunction)
    owner = owner or UIParent
    local description = NewMenuNode("root")
    createFunction(owner, description)
    if owner ~= UIParent then
        -- Drop the context menu below its button, like the classic EasyMenu
        -- calls this addon replaced; the bare-UIParent case goes to the cursor.
        ShowCompatMenu(owner, description, owner)
    else
        ShowCompatMenu(owner, description, nil)
    end
end
MenuUtil = MenuUtil or CompatMenuUtil

local CompatMenu = {}

-- gui.lua's generator is `function generator(_, root)`; retail calls it with
-- the owner and the description, which matches that signature.
function CompatMenu.PopulateDescription(generator, owner, description)
    generator(owner, description)
end

local menuManager = {}
function CompatMenu.GetManager()
    return menuManager
end
Menu = Menu or CompatMenu

function menuManager.OpenMenu(self, owner, description, anchor)
    ShowCompatMenu(owner, description, anchor)
end

-- ---------------------------------------------------------------------------
-- Retail global strings / constants the addon reads. All of these are absent
-- from the 3.3.5a FrameXML corpus and from the client binary (they are retail
-- globals); the talent ones are only referenced behind
-- IsTalentStringSupported() guards, the other two feed GUI text.
-- ---------------------------------------------------------------------------
OPTION_SHOW_ACTION_BAR = OPTION_SHOW_ACTION_BAR or "%s. Bar"
RELOADUI = RELOADUI or "Reload UI"

LOADOUT_ERROR_BAD_STRING = LOADOUT_ERROR_BAD_STRING or "Invalid import string"
LOADOUT_ERROR_IMPORT_FAILED = LOADOUT_ERROR_IMPORT_FAILED or "Import failed"
LOADOUT_ERROR_SERIALIZATION_VERSION_MISMATCH = LOADOUT_ERROR_SERIALIZATION_VERSION_MISMATCH or "Unsupported string version"
LOADOUT_ERROR_TREE_CHANGED = LOADOUT_ERROR_TREE_CHANGED or "The talent tree changed"
LOADOUT_ERROR_WRONG_SPEC = LOADOUT_ERROR_WRONG_SPEC or "Wrong specialization"
