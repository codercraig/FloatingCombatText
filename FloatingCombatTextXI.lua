-- Required modules
local parser = require('parser')
local imgui = require('imgui')

addon.name = 'FloatingCombatTextXI'
addon.author = 'Oxos'
addon.version = '1.2'
addon.description = 'Logs and displays player damage from combat logs as floating text with separate sections for melee, weapon skills, and spells.'

require('common')

-- Table to store player damage events with timestamps
local damage_display = {}
local my_actor_id = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)  -- Get player's server ID

-- Function to display floating damage with X-offset and Y-offset based on screen position
local function display_floating_damage(damage, index, is_weapon_skill, is_spell)
    -- Dynamically retrieve screen dimensions
    local screen_width = imgui.GetIO().DisplaySize.x
    local screen_height = imgui.GetIO().DisplaySize.y
    
    -- Calculate center of the screen
    local center_x = screen_width / 2
    local center_y = screen_height / 2

    -- Adjust X position based on type (left for melee, center for weapon skills, right for spells)
    local x_position = center_x
    local y_position = center_y
    if is_weapon_skill then
        x_position = center_x  -- Middle of the screen for weapon skills
        y_position = center_y - 350
    elseif is_spell then
        x_position = center_x + 350 -- Right for spells
        --y_position = center_y + 250
    else
        x_position = center_x - 350 -- Left for melee/normal hits
        --y_position = center_y + 250
    end

    -- Add a new entry to the damage display table with appropriate positioning
    table.insert(damage_display, {
        damage = damage,
        is_weapon_skill = is_weapon_skill,
        is_spell = is_spell,
        start_time = os.clock(),
        x = x_position,
        y = y_position -- Offset Y for each hit
    })
end

-- Register for incoming packets
ashita.events.register('packet_in', 'IncomingPacket', function(e)
    if e.id == 0x028 then  -- Check for combat packets
        local action = parser.parse(e.data)

        if not action or action.m_uID ~= my_actor_id then
            return  -- Ignore if it's not the player's packet
        end

        -- Check for specific action command numbers to determine if it's a melee attack, weapon skill, or spell
        local is_melee_attack = (action.cmd_no == 1)  -- Command number 1 indicates a basic melee attack
        local is_weapon_skill = (action.cmd_no == 3)  -- Command number 3 indicates a weapon skill
        local is_ws_start = (action.cmd_no == 7)  -- Command number 7 indicates the start of a weapon skill
        local is_spell = (action.cmd_no == 4)  -- Command number 4 indicates a spell
        local is_spell_start = (action.cmd_no == 8)  -- Command number 8 indicates the start of a spell

        -- Only continue if it's a relevant action (melee, weapon skill, or spell)
        if not is_melee_attack and not is_weapon_skill and not is_ws_start and not is_spell and not is_spell_start then
            return  -- Ignore any irrelevant actions to prevent random values
        end

        -- Skip displaying values for cmd_no 7 (start of weapon skill) to avoid showing "40"
        if is_ws_start then
            return  -- Skip the action without displaying any damage value
        end

        if is_spell_start then
            return  -- Skip the action without displaying any damage value
        end


        -- Iterate over all targets and their results (hits)
        local hit_index = 0
        for _, target in ipairs(action.target) do
            for _, result in ipairs(target.result) do
                -- Only display values if the result has actual damage and is part of a relevant action
                if result.value > 0 then
                    display_floating_damage(result.value, hit_index, is_weapon_skill, is_spell)
                end
            end
        end
    end
end)

-- Function to render floating combat text
ashita.events.register('d3d_present', 'PresentCallback', function()
    local current_time = os.clock()

    -- Iterate over the damage display table
    for i = #damage_display, 1, -1 do
        local damage_event = damage_display[i]
        local elapsed_time = current_time - damage_event.start_time

        -- Fade out after 3 seconds
        if elapsed_time > 3 then
            table.remove(damage_display, i)  -- Remove the entry after 3 seconds
        else
            -- Calculate the fade effect
            local alpha = 1.0
            if elapsed_time > 2 then
                alpha = 1.0 - ((elapsed_time - 2) / 1.0)  -- Fade out during the last second
            end

            -- Move the text up the Y-axis as time progresses
            local y_position = damage_event.y - (elapsed_time * 75)

            -- Determine which window to use based on the event type
            imgui.SetNextWindowPos({damage_event.x, y_position})
            
            -- Set the window size and style for each type of event
            if damage_event.is_weapon_skill then
                imgui.SetNextWindowSize({500, 200})  -- Center window for weapon skills
                imgui.Begin('WeaponSkills', true, ImGuiWindowFlags_NoTitleBar + ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoBackground + ImGuiWindowFlags_NoScrollbar)
                imgui.SetWindowFontScale(3.0)
                imgui.TextColored({1.0, 1.0, 0.0, alpha}, tostring("WeaponSkill: " .. damage_event.damage))  -- Yellow for weapon skills
            elseif damage_event.is_spell then
                imgui.SetNextWindowSize({500, 200})  -- Right window for spells
                imgui.Begin('Spells', true, ImGuiWindowFlags_NoTitleBar + ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoBackground + ImGuiWindowFlags_NoScrollbar)
                imgui.SetWindowFontScale(2.0)
                imgui.TextColored({0.0, 0.5, 1.0, alpha}, tostring("Spell: " .. damage_event.damage))  -- Blue for spells
            else
                imgui.SetNextWindowSize({500, 200})  -- Left window for melee hits
                imgui.Begin('MeleeHits', true, ImGuiWindowFlags_NoTitleBar + ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoBackground + ImGuiWindowFlags_NoScrollbar)
                imgui.SetWindowFontScale(2.0)
                imgui.TextColored({1.0, 1.0, 1.0, alpha}, tostring("Melee: " .. damage_event.damage))  -- White for melee hits
            end

            imgui.End()
        end
    end
end)

-- Command to view the damage log
ashita.events.register('command', 'CommandEvent', function(e)
    local args = e.command:args()
    if args[1] == '/damagelog' then
        return true
    end
    return false
end)
