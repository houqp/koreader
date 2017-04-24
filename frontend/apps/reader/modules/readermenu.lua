local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Event = require("ui/event")
local InputContainer = require("ui/widget/container/inputcontainer")
local Screensaver = require("ui/screensaver")
local QuickStart = require("ui/quickstart")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local dbg = require("dbg")
local Screen = Device.screen
local _ = require("gettext")

local ReaderMenu = InputContainer:new{
    tab_item_table = nil,
    menu_items = {},
    registered_widgets = {},
}

function ReaderMenu:init()
    self.menu_items = {
        ["KOMenu:menu_buttons"] = {
            -- top menu
        },
        -- items in top menu
        navi = {
            icon = "resources/icons/appbar.page.corner.bookmark.png",
        },
        typeset = {
            icon = "resources/icons/appbar.page.text.png",
        },
        setting = {
            icon = "resources/icons/appbar.settings.png",
        },
        tools = {
            icon = "resources/icons/appbar.tools.png",
        },
        search = {
            icon = "resources/icons/appbar.magnify.browse.png",
        },
        filemanager = {
            icon = "resources/icons/appbar.cabinet.files.png",
            remember = false,
            callback = function()
                self:onTapCloseMenu()
                self.ui:onClose()
                local lastdir
                local last_file = G_reader_settings:readSetting("lastfile")
                -- ignore quickstart guide as last_file so we can go back to home dir
                if last_file and last_file ~= QuickStart.quickstart_filename then
                    lastdir = last_file:match("(.*)/")
                end
                local FileManager = require("apps/filemanager/filemanager")
                if FileManager.instance then
                    FileManager.instance:reinit(lastdir)
                else
                    FileManager:showFiles(lastdir)
                end
            end,
        },
        main = {
            icon = "resources/icons/menu-icon.png",
        }
    }

    self.registered_widgets = {}

    if Device:hasKeys() then
        self.key_events = { Close = { { "Back" }, doc = "close menu" }, }
        if Device:isTouchDevice() then
            self.key_events.TapShowMenu = { { "Menu" }, doc = "show menu", }
        else
            -- map menu key to only top menu because bottom menu is only
            -- designed for touch devices
            self.key_events.ShowReaderMenu = { { "Menu" }, doc = "show menu", }
        end
    end
end

function ReaderMenu:onReaderReady()
    -- deligate gesture listener to readerui
    self.ges_events = {}
    self.onGesture = nil
    if not Device:isTouchDevice() then return end

    self.ui:registerTouchZones({
        {
            id = "readermenu_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = { "rolling_swipe", "paging_swipe", },
            handler = function(ges) return self:onSwipeShowMenu(ges) end,
        },
        {
            id = "readermenu_pan",
            ges = "pan",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = { "rolling_pan", "paging_pan", },
            handler = function(ges) return self:onSwipeShowMenu(ges) end,
        },
    })
end

function ReaderMenu:setUpdateItemTable()
    for _, widget in pairs(self.registered_widgets) do
        local ok, err = pcall(widget.addToMainMenu, widget, self.menu_items)
        if not ok then
            logger.err("failed to register widget", widget.name, err)
        end
    end

    -- settings tab
    -- insert common settings
    for id, common_setting in pairs(require("ui/elements/common_settings_menu_table")) do
        self.menu_items[id] = common_setting
    end
    -- insert DjVu render mode submenu just before the last entry (show advanced)
    -- this is a bit of a hack
    if self.ui.document.is_djvu then
        self.menu_items.djvu_render_mode = self.view:getRenderModeMenuTable()
    end

    if Device:supportsScreensaver() and Screensaver:isUsingBookCover() then
        local excluded = function()
            return self.ui.doc_settings:readSetting("exclude_screensaver") or false
        end
        local proportional = function()
            return self.ui.doc_settings:readSetting("proportional_screensaver") or false
        end
        self.menu_items.screensaver = {
            text = _("Screensaver"),
            sub_item_table = {
                {
                    text = _("Use last book's cover as screensaver"),
                    checked_func = Screensaver.isUsingBookCover,
                    callback = function()
                        if Screensaver:isUsingBookCover() then
                            G_reader_settings:saveSetting(
                                "use_lastfile_as_screensaver", false)
                        else
                            G_reader_settings:delSetting(
                                "use_lastfile_as_screensaver")
                        end
                        G_reader_settings:flush()
                    end
                },
                {
                    text = _("Exclude this book's cover from screensaver"),
                    checked_func = excluded,
                    callback = function()
                        if excluded() then
                            self.ui.doc_settings:delSetting("exclude_screensaver")
                        else
                            self.ui.doc_settings:saveSetting("exclude_screensaver", true)
                        end
                        self.ui:saveSettings()
                    end
                },
                {
                    text = _("Auto stretch this book's cover image in screensaver"),
                    checked_func = proportional,
                    callback = function()
                        if proportional() then
                            self.ui.doc_settings:delSetting("proportional_screensaver")
                        else
                            self.ui.doc_settings:saveSetting(
                                "proportional_screensaver", not proportional())
                        end
                        self.ui:saveSettings()
                    end
                }
            }
        }
    end
    -- main menu tab
    -- insert common info
    for id, common_setting in pairs(require("ui/elements/common_info_menu_table")) do
        self.menu_items[id] = common_setting
    end

    self.menu_items.exit = {
        text = _("Exit"),
        callback = function()
            self:onTapCloseMenu()
            UIManager:scheduleIn(0.1, function() self.ui:onClose() end)
            local FileManager = require("apps/filemanager/filemanager")
            if FileManager.instance then
                FileManager.instance:onClose()
            end
        end,
    }

    local order = require("ui/elements/reader_menu_order")

    local MenuSorter = require("ui/menusorter")
    self.tab_item_table = MenuSorter:mergeAndSort("reader", self.menu_items, order)
end
dbg:guard(ReaderMenu, 'setUpdateItemTable',
    function(self)
        local mock_menu_items = {}
        for _, widget in pairs(self.registered_widgets) do
            -- make sure addToMainMenu works in debug mode
            widget:addToMainMenu(mock_menu_items)
        end
    end)

function ReaderMenu:onShowReaderMenu()
    if self.tab_item_table == nil then
        self:setUpdateItemTable()
    end

    local menu_container = CenterContainer:new{
        ignore = "height",
        dimen = Screen:getSize(),
    }

    local main_menu
    if Device:isTouchDevice() then
        local TouchMenu = require("ui/widget/touchmenu")
        main_menu = TouchMenu:new{
            width = Screen:getWidth(),
            last_index = self.last_tab_index,
            tab_item_table = self.tab_item_table,
            show_parent = menu_container,
        }
    else
        local Menu = require("ui/widget/menu")
        main_menu = Menu:new{
            title = _("Document menu"),
            item_table = Menu.itemTableFromTouchMenu(self.tab_item_table),
            width = Screen:getWidth() - 100,
            show_parent = menu_container,
        }
    end

    main_menu.close_callback = function ()
        self.ui:handleEvent(Event:new("CloseReaderMenu"))
    end

    main_menu.touch_menu_callback = function ()
        self.ui:handleEvent(Event:new("CloseConfigMenu"))
    end

    menu_container[1] = main_menu
    -- maintain a reference to menu_container
    self.menu_container = menu_container
    UIManager:show(menu_container)

    return true
end

function ReaderMenu:onCloseReaderMenu()
    self.last_tab_index = self.menu_container[1].last_index
    self:onSaveSettings()
    UIManager:close(self.menu_container)
    return true
end

function ReaderMenu:onSwipeShowMenu(ges)
    if ges.direction == "south" then
        self.ui:handleEvent(Event:new("ShowConfigMenu"))
        self.ui:handleEvent(Event:new("ShowReaderMenu"))
        return true
    end
end

function ReaderMenu:onTapCloseMenu()
    self.ui:handleEvent(Event:new("CloseReaderMenu"))
    self.ui:handleEvent(Event:new("CloseConfigMenu"))
end

function ReaderMenu:onReadSettings(config)
    self.last_tab_index = config:readSetting("readermenu_tab_index") or 1
end

function ReaderMenu:onSaveSettings()
    self.ui.doc_settings:saveSetting("readermenu_tab_index", self.last_tab_index)
end

function ReaderMenu:registerToMainMenu(widget)
    table.insert(self.registered_widgets, widget)
end

return ReaderMenu
