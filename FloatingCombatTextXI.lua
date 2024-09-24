-- Required modules
local parser = require('parser')
local imgui = require('imgui')

addon.name = 'FloatingCombatTextXI'
addon.author = 'Oxos'
addon.version = '1.0'
addon.description = 'Logs and displays player damage from combat logs as floating text with separate sections for melee, weapon skills, and spells, with crits and misses.'

require('common')

local my_custom_font = nil  -- Declare font globally

-- ashita.events.register('load', 'addon_load', function()
--     -- Load the custom font from the provided file path
--     local font_path = '"D:/CatsXI/catseyexi-client/Ashita/addons/FloatingCombatTextXI/LondrinaOutline-Regular.ttf"/LondrinaOutline-Regular.ttf'  -- Update with the correct path
--     my_custom_font = imgui.AddFontFromFileTTF(font_path, 24.0)  -- Load the font with size 24.0
-- end)


-- Table to store player damage events with timestamps
local damage_display = {}
local my_actor_id = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)  -- Get player's server ID

-- Function to display floating damage with X-offset and Y-offset based on screen position
local function display_floating_damage(damage, index, is_weapon_skill, is_spell, is_crit, is_miss)
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
        x_position = center_x + 250 -- Right for spells
    else
        x_position = center_x - 500 -- Left for melee/normal hits
    end

    -- Determine the display text based on crits, misses, or normal hits
    local display_text = ""
    if is_miss then
        display_text = "Miss"
    elseif is_crit then
        display_text = tostring(damage) .. " (Crit)"
    else
        display_text = tostring(damage)
    end

    -- Add a new entry to the damage display table with appropriate positioning
    table.insert(damage_display, {
        text = display_text,
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
        for _, target in ipairs(action.target) do
            for i = #target.result, 1, -1 do
                local result = target.result[i]
                
                -- Check for miss or crit
                local is_miss = (result.miss == 1)
                local is_crit = (result.message == 67)  -- Replace with actual crit message ID

                -- Only display values if the result has actual damage or is a miss
                if result.value > 0 then
                    display_floating_damage(result.value, 0, is_weapon_skill, is_spell, is_crit)
                elseif is_miss then
                    display_floating_damage("Miss!")
                end
            end
        end
    end
end)

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
                imgui.SetNextWindowSize({800, 200})  -- Center window for weapon skills
                imgui.Begin('WeaponSkills', true, ImGuiWindowFlags_NoTitleBar + ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoBackground + ImGuiWindowFlags_NoScrollbar)

                -- Use the custom font
                if my_custom_font then
                    imgui.PushFont(my_custom_font)
                end

                imgui.SetWindowFontScale(2) 
                imgui.TextColored({1.0, 1.0, 0, alpha},"Weaponskill: " .. damage_event.text .. " !!")  -- Yellow for weapon skills

                if my_custom_font then
                    imgui.PopFont()  -- Reset to the default font after rendering
                end

            elseif damage_event.is_spell then
                imgui.SetNextWindowSize({500, 200})  -- Right window for spells
                imgui.Begin('Spells', true, ImGuiWindowFlags_NoTitleBar + ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoBackground + ImGuiWindowFlags_NoScrollbar)

                if my_custom_font then
                    imgui.PushFont(my_custom_font)
                end

                imgui.SetWindowFontScale(3) 
                imgui.TextColored({0.0, 0.75, 1.0, alpha},damage_event.text)  -- Blue for spells

                if my_custom_font then
                    imgui.PopFont()
                end

            else
                imgui.SetNextWindowSize({500, 200})  -- Left window for melee hits
                imgui.Begin('MeleeHits', true, ImGuiWindowFlags_NoTitleBar + ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoBackground + ImGuiWindowFlags_NoScrollbar)

                if my_custom_font then
                    imgui.PushFont(my_custom_font)
                end

                imgui.SetWindowFontScale(2) 
                imgui.TextColored({0.9, 0.9, 0.9, alpha},"Melee: " .. damage_event.text)  -- White for melee hits

                if my_custom_font then
                    imgui.PopFont()
                end
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
