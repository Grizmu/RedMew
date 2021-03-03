local Event = require 'utils.event'
local Global = require 'utils.global'
local Task = require 'utils.task'
local Token = require 'utils.token'
local table = require 'utils.table'
local Utils = require 'utils.core'
local Settings = require 'utils.redmew_settings'

local Public = {}

local ping_own_death_name = 'corpse_util.ping_own_death'
local ping_other_death_name = 'corpse_util.ping_other_death'

Public.ping_own_death_name = ping_own_death_name
Public.ping_other_death_name = ping_other_death_name

Settings.register(ping_own_death_name, Settings.types.boolean, true, 'corpse_util.ping_own_death')
Settings.register(ping_other_death_name, Settings.types.boolean, false, 'corpse_util.ping_other_death')

local player_corpses = {}

Global.register(player_corpses, function(tbl)
    player_corpses = tbl
end)

local function player_died(event)
    local player_index = event.player_index
    local player = game.get_player(player_index)

    if not player or not player.valid then
        return
    end

    local pos = player.position
    local entities = player.surface.find_entities_filtered {
        area = {{pos.x - 0.5, pos.y - 0.5}, {pos.x + 0.5, pos.y + 0.5}},
        name = 'character-corpse'
    }

    local tick = game.tick
    local entity
    for _, e in ipairs(entities) do
        if e.character_corpse_player_index == event.player_index and e.character_corpse_tick_of_death == tick then
            entity = e
            break
        end
    end

    if not entity or not entity.valid then
        return
    end

    local text = player.name .. "'s corpse"
    local position = entity.position
    local tag = player.force.add_chart_tag(player.surface, {
        icon = {type = 'item', name = 'power-armor-mk2'},
        position = position,
        text = text
    })

    if not tag then
        return
    end

    if Settings.get(player_index, ping_own_death_name) then
        player.print({
            'corpse_util.own_corpse_location',
            string.format('%.1f', position.x),
            string.format('%.1f', position.y),
            player.surface.name
        })
    end

    for _, other_player in pairs(player.force.players) do
        if other_player ~= player and Settings.get(other_player.index, ping_other_death_name) then
            other_player.print({
                'corpse_util.other_corpse_location',
                player.name,
                string.format('%.1f', position.x),
                string.format('%.1f', position.y),
                player.surface.name
            })
        end
    end

    player_corpses[player_index * 0x100000000 + tick] = tag
end

local function remove_tag(player_index, tick)
    local index = player_index * 0x100000000 + tick

    local tag = player_corpses[index]
    player_corpses[index] = nil

    if not tag or not tag.valid then
        return
    end

    tag.destroy()
end

local function corpse_expired(event)
    local entity = event.corpse

    if entity and entity.valid then
        remove_tag(entity.character_corpse_player_index, entity.character_corpse_tick_of_death)
    end
end

local corpse_util_mined_entity = Token.register(function(data)
    if not data.entity.valid then
        remove_tag(data.player_index, data.tick)
    end
end)

local function mined_entity(event)
    local entity = event.entity

    if not entity or not entity.valid or entity.name ~= 'character-corpse' then
        return
    end

    -- The corpse may be mined but not removed (if player doesn't have inventory space)
    -- so we wait one tick to see if the corpse is gone.
    Task.set_timeout_in_ticks(1, corpse_util_mined_entity, {
        entity = entity,
        player_index = entity.character_corpse_player_index,
        tick = entity.character_corpse_tick_of_death
    })

    local player_index = event.player_index
    local corpse_owner_index = entity.character_corpse_player_index

    if player_index == corpse_owner_index then
        return
    end

    local player = game.get_player(player_index)
    local corpse_owner = game.get_player(corpse_owner_index)

    if player and corpse_owner and entity.active then
        local message = table.concat {player.name, ' has looted ', corpse_owner.name, "'s corpse"}
        Utils.action_warning('[Corpse]', message)
    end
end

local function on_gui_opened(event)
    local entity = event.entity
    if not entity or not entity.valid or entity.name ~= 'character-corpse' then
        return
    end

    local player_index = event.player_index
    local corpse_owner_index = entity.character_corpse_player_index

    if player_index == corpse_owner_index then
        return
    end

    local player = game.get_player(player_index)
    local corpse_owner = game.get_player(corpse_owner_index)

    if player and corpse_owner and entity.active then
        local message = table.concat {player.name, ' is looting ', corpse_owner.name, "'s corpse"}
        Utils.action_warning('[Corpse]', message)
    end
end

Event.add(defines.events.on_player_died, player_died)
Event.add(defines.events.on_character_corpse_expired, corpse_expired)
Event.add(defines.events.on_pre_player_mined_item, mined_entity)
Event.add(defines.events.on_gui_opened, on_gui_opened)

function Public.clear()
    table.clear_table(player_corpses)
end

Public._player_died = player_died
Public.player_corpses = player_corpses

return Public
