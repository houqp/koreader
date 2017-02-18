local Migrator = {}

-- FIXME: warn older version of reader
function Migrator:updateToVersoin(to_ver)
    local cur_ver = G_reader_settings:readSetting('setting_version') or 0
    if cur_ver == to_ver then return end


end

return Migrator
