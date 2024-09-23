--[[ 
* FloatingCombatTextXI - Copyright (c) 2024 Oxos
* Based on code from Ashita (bitreader), Copyright (c) 2024 Ashita Development Team
* Licensed under the GNU General Public License v3.0 
* (https://www.gnu.org/licenses/gpl-3.0.html)
* 
* This file includes portions of the Ashita project. Ashita is free software: 
* you can redistribute it and/or modify it under the terms of the GNU General 
* Public License as published by the Free Software Foundation, either version 
* 3 of the License, or any later version. 
*
* Ashita is distributed in the hope that it will be useful, but WITHOUT ANY 
* WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
* FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
--]]

-- Required modules
local breader = require('bitreader')

addon.name = 'FloatingCombatTextXI'
addon.author = 'Oxos'
addon.version = '1.0'
addon.description = 'Logs and stores player damage from combat logs.'

require('common')

-- Table to store player damage events
local player_damage = {}
local my_actor_id = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)  -- Get player's server ID

-- Function to parse the action packet using bitreader
local function parse_combat_packet(data)
    local reader = breader:new()
    reader:set_data(data)
    reader:set_pos(5)  -- Start after header

    local actor_id = reader:read(32)  -- Actor ID
    local target_sum = reader:read(6)
    local result_sum = reader:read(4)
    local cmd_no = reader:read(4)  -- Command number (attack, magic, etc.)
    local cmd_arg = reader:read(32)  -- Arguments for the command
    local info = reader:read(32)  -- Action info
    
    -- Check if the actor is the player
    if actor_id ~= my_actor_id then
        return nil, nil, nil  -- Not the player's action, ignore it
    end

    local targets = {}
    for i = 1, target_sum do
        local target = {}
        target.id = reader:read(32)  -- Target ID
        target.result_sum = reader:read(4)
        
        -- Parse results (damage, crit, etc.)
        target.results = {}
        for j = 1, target.result_sum do
            local result = {}
            result.miss = reader:read(3)
            result.kind = reader:read(2)  -- Kind: Regular hit or special
            result.sub_kind = reader:read(12)  -- Track the sub_kind for multiple hits
            result.info = reader:read(5)
            result.scale = reader:read(5)
            result.damage = reader:read(17)  -- DAMAGE VALUE
            result.message = reader:read(10)  -- Check message for crits or special conditions

            -- Store each result in the table
            table.insert(target.results, result)
        end

        table.insert(targets, target)
    end

    return actor_id, cmd_no, targets
end

-- Register for incoming packets
ashita.events.register('packet_in', 'IncomingPacket', function(e)
    if e.id == 0x028 then  -- Check for combat packets
        local actor_id, cmd_no, targets = parse_combat_packet(e.data)
        if not actor_id then
            return  -- Ignore if it's not the player's packet
        end

        -- Store and print damage for the player
        for _, target in ipairs(targets) do
            -- Print all hits related to this action
            for index, result in ipairs(target.results) do
                if result.damage > 0 then
                    -- Track each hit separately
                    local hit_type = "Regular"
                    if result.message == 67 then
                        hit_type = "Critical"
                    end

                    -- Store the event in the player_damage table
                    local dmg_event = {
                        target_id = target.id,
                        damage = result.damage,
                        hit_type = hit_type,
                        hit_index = index,  -- Track which hit this is
                        time = os.date("%H:%M:%S"),
                    }

                    table.insert(player_damage, dmg_event)

                    -- Print each damage event for debugging
                    print(string.format("%s: You hit target ID %d for %d damage (%s) [Hit %d]", 
                        dmg_event.time, dmg_event.target_id, dmg_event.damage, dmg_event.hit_type, dmg_event.hit_index))
                end
            end
        end
    end
end)

-- Command to view the damage log
ashita.events.register('command', 'CommandEvent', function(e)
    local args = e.command:args()
    if args[1] == '/damagelog' then
        -- Output all logged damage
        for i, event in ipairs(player_damage) do
            print(string.format("%s: You hit target ID %d for %d damage (%s) [Hit %d]", 
                event.time, event.target_id, event.damage, 
                event.hit_type, event.hit_index))
        end
        return true
    end
    return false
end)
