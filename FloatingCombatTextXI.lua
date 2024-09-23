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

    local action = {}
    action.actor_id = reader:read(32)  -- Actor ID
    action.target_count = reader:read(6)
    action.result_count = reader:read(4)
    action.command = reader:read(4)
    action.command_arg = reader:read(32)
    action.info = reader:read(32)
    action.targets = {}

    -- Ensure that we only process packets related to the player
    if action.actor_id ~= my_actor_id then
        return nil, nil, nil
    end

    -- Loop through each target in the packet
    for i = 1, action.target_count do
        local target = {}
        target.id = reader:read(32)  -- Target ID
        target.result_count = reader:read(4)
        target.results = {}

        -- Handle each result (hit) for the target
        for j = 1, target.result_count do
            local result = {}
            result.miss = reader:read(3)
            result.kind = reader:read(2)
            result.sub_kind = reader:read(12)
            result.info = reader:read(5)
            result.scale = reader:read(5)

            -- Read damage for this hit
            result.damage = reader:read(17)

            -- Adjust for the second hit being scaled (4x issue)
            if j > 1 then
                result.damage = result.damage / 4
            end
            if j > 2 then
                result.damage = result.damage / 16
            end
            if j > 3 then
                result.damage = result.damage / 32
            end
            if j > 4 then
                result.damage = result.damage / 64
            end
            if j > 5 then
                result.damage = result.damage / 128
            end

            result.message = reader:read(10)
            result.bit = reader:read(31)

            -- Store the parsed result in the results table
            table.insert(target.results, result)
        end

        -- Add the target to the action's targets table
        table.insert(action.targets, target)
    end

    return action
end

-- Register for incoming packets
ashita.events.register('packet_in', 'IncomingPacket', function(e)
    if e.id == 0x028 then  -- Check for combat packets
        local action = parse_combat_packet(e.data)
        if not action then
            return  -- Ignore if it's not the player's packet
        end

        -- Iterate over all targets and their results (hits)
        for _, target in ipairs(action.targets) do
            local damage_list = {}

            -- Iterate through each result within the target
            for _, result in ipairs(target.results) do
                if result.damage > 0 then
                    -- Collect each hit's damage value
                    table.insert(damage_list, result.damage)
                end
            end

            -- Output the collected damage for the target
            local damage_string = table.concat(damage_list, ", ")
            print(string.format("%s: You hit target ID %d for Damage: %s", 
                os.date("%H:%M:%S"), target.id, damage_string))
        end
    end
end)

-- Command to view the damage log
ashita.events.register('command', 'CommandEvent', function(e)
    local args = e.command:args()
    if args[1] == '/damagelog' then
        -- Output all logged damage
        for i, event in ipairs(player_damage) do
            print(string.format("%s: You hit target ID %d for Damage: %d", 
                event.time, event.target_id, event.damage))
        end
        return true
    end
    return false
end)
