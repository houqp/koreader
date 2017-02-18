local Migration = {}

local function applyUpgradePatch()
    local footer_mode = G_reader_settings:readSetting("reader_footer_mode")
    if footer_mode == nil then return end

    if footer_mode > 0 then
        -- progress_bar was added as mode 1, so shift all subsequent modes
        footer_mode = footer_mode + 1
        G_reader_settings:saveSetting("reader_footer_mode", footer_mode)
    end
end

function Migration:upgrade()
    -- FIXME: catch all error?
    applyUpgradePatch()
    G_reader_settings:saveSetting("setting_version", 1)
end

return Migration
