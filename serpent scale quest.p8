pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- global variables and constants
local current_level
local snake = {} -- snake segments
local snake_dir = {x=0, y=0} -- snake's direction
local snake_speed = 1 --snake starting speed
local scales_collected = 0 --scale floor
local obstacles = {} --obstacle generation table
local scales = {} -- stores the scales in the level
local snake_speed_increment = 0.2 -- the amount by which snake speed increases after each scale collection
local obstacle_speed = 0.1 --starting obstacle speed
local obstacle_speed_increment = 0.2 -- the amount by which obstacle speed increases after each scale collection
scale_sprite_id = 7 --scale sprites
local game_state = "start_screen" --starting game screen
level_sprites = {
    fire = {id=17, x=25, y=30},
    water = {id=19, x=45, y=30},
    earth = {id=21, x=65, y=30},
    air = {id=23, x=85, y=30},
} --level sprites for selection screen
final_level_sprite = {id=136 ,x=55, y=95}

local level_completed = {
    fire = false,
    water = false,
    earth = false,
    air = false,
    final_fire = false,
    final_water = false,
    final_earth = false,
    final_air = false
} --marks for level completed
local handled_level_completion = {
    fire = false,
    water = false,
    earth = false,
    air = false,
    final_fire = false,
    final_water = false,
    final_earth = false,
    final_air = false
} -- initial state for handled level completion

local potential_scale_positions = {} --potential scale positions in a level
weights = {} -- an array to store the weights in the playfield
balance_scale = {left=0, right=0} -- to store the cumulative weight on each side
tolerance = 15
arrow_side = "left"
previous_game_state = "start_screen"
-- constants for the air level
arrow_spawn_interval = 30
arrow_spawn_timer = arrow_spawn_interval 
base_arrow_speed = 1
arrows = {}
arrow_speed = 1
total_arrows = 0
hit_arrows = 0
arrow_left = 1
arrow_up = 2
arrow_right = 3
arrow_down = 4
arrow_x_left = 16
arrow_x_up = 40
arrow_x_right = 72
arrow_x_down = 96
buffer_size = 4
local stage = 1
local total_stages = 3
local stages_info = {
    {count = 50, speed_multiplier = 1, music_air = 09, music_speed = 70},
    {count = 75, speed_multiplier = 2, music_air = 10, music_speed = 45},
    {count = 100, speed_multiplier = 2.5, music_air = 11, music_speed = 20}
}
minimum_accuracy = 0.8
minimum_acc_perc = ceil(minimum_accuracy*100)
transitioning_to_selection = false
init_selection_called = 0
local final_level_unlocked = false
fire_level_win = 10
water_level_win = 10
max_total_weight = 20
update_fire_level_called = 0
update_final_level_called = 0
-->8
-- initialization and ability functions
function _init()
    snake = {
        {x=64, y=64},  -- head
        {x=63, y=64},  -- body segment
        {x=62, y=64},  -- body segment
        {x=61, y=64},  -- tail
    }
    snake_dir = {x=1, y=0}
    game_state = "start_screen"
				music(0)
end

-->8
--collision and flagging functions
--sprite flag functions
function sprite_has_flag(x, y, flag)
    local sprite_id = mget(flr(x / 8), flr(y / 8))
    return fget(sprite_id, flag)
end
function get_sprites_with_flag(flag)
    local flagged_sprites = {}
    for y=0, 15 do -- assuming a 16x16 map
        for x=0, 15 do
            local sprite_id = mget(x, y)
            if fget(sprite_id, flag) then
                add(flagged_sprites, {x=x*8, y=y*8, id=sprite_id})
            end
        end
    end
    return flagged_sprites
end
function collide_bbox(obj1, obj2, width, height)
    return obj1.x < obj2.x + width and
           obj1.x + width > obj2.x and
           obj1.y < obj2.y + height and
           obj1.y + height > obj2.y
end

-- collision function
function collide(obj1, obj2)
    return obj1.x < obj2.x + 8 and
           obj1.x + 8 > obj2.x and
           obj1.y < obj2.y + 8 and
           obj1.y + 8 > obj2.y
end
function collide_with_sprite(obj, sprite)
    return obj.x < sprite.x + 8 and
           obj.x + 8 > sprite.x and
           obj.y < sprite.y + 8 and
           obj.y + 8 > sprite.y
end



-->8
--update function and level functions
-- modified add_obstacles function
function add_obstacles(obstacle_count, types, position_bounds)
    obstacles = {}
    for i = 1, obstacle_count do
        local obstacle_type = types[flr(rnd(#types)) + 1]
        local obstacle = {
            x = flr(rnd(position_bounds.xmax - position_bounds.xmin + 1)) + position_bounds.xmin,
            y = flr(rnd(position_bounds.ymax - position_bounds.ymin + 1)) + position_bounds.ymin,
            type = obstacle_type,
            dx = rnd() - 0.5,  -- random horizontal speed
            dy = rnd() - 0.5   -- random vertical speed
        }
        add(obstacles, obstacle)
    end
end

-- function to initialize scale positions
function init_scale_positions(count, position_bounds)
    potential_scale_positions = {}
    for i = 1, count do
        local randx = flr(rnd(position_bounds.xmax - position_bounds.xmin + 1)) + position_bounds.xmin
        local randy = flr(rnd(position_bounds.ymax - position_bounds.ymin + 1)) + position_bounds.ymin
        add(potential_scale_positions, {x = randx, y = randy})
    end
end

-- function to add the first scale
function add_first_scale()
    local idx = flr(rnd(#potential_scale_positions)) + 1
    local scale_position = potential_scale_positions[idx]
    add(scales, {x = scale_position.x, y = scale_position.y, collected = false})
    active_scale = true -- set the first scale as active
end

-- initialize fire level with refactored functions
function init_fire_level()
    local position_bounds = {xmin = 16, xmax = 112, ymin = 16, ymax = 112}
    add_obstacles(10, {"magma", "rock"}, position_bounds)
    init_scale_positions(10, position_bounds)
    add_first_scale()
    scales_collected = 0
end

function place_weights()
    weights = {}
    local total_weight = 0
    local max_total_weight = 20  -- adjust as needed

    while total_weight < max_total_weight do
        local new_weight_value = flr(rnd(3)) + 1  -- weights between 1 and 3
        if total_weight + new_weight_value <= max_total_weight then
            local new_weight = {
                x = flr(rnd(104)) + 8,
                y = flr(rnd(104)) + 8,
                value = new_weight_value
            }
            add(weights, new_weight)
            total_weight = total_weight + new_weight_value
        end
    end
end

function _update_earth_level()
    local buffer = 4
    for weight in all(weights) do
        if abs(snake[1].x - weight.x) <= buffer and abs(snake[1].y - weight.y) <= buffer then
            -- add weight value to the appropriate side of the scale
            if arrow_side == "left" then
                balance_scale.left += weight.value
                arrow_side = "right"  -- toggle the arrow to the other side
            else
                balance_scale.right += weight.value
                arrow_side = "left"   -- toggle the arrow to the other side
            end

            -- remove the weight from the playfield
            del(weights, weight)
        end
    end

    local imbalance = abs(balance_scale.left - balance_scale.right)
    local no_weights_left = (#weights == 0)

    if imbalance > tolerance then
        -- too imbalanced, restart the level
        if game_state == "final" then
            restart_final_level()
        else
            restart_level()
        end
    elseif no_weights_left and imbalance > 0 then
        -- no weights left and scale is still imbalanced
        if game_state == "final" then
            restart_final_level()
        else
            restart_level()
        end
    elseif no_weights_left and balance_scale.left == balance_scale.right then
        -- level completed successfully
        level_completed[current_level] = true
    end
end

function init_earth_level()
  -- reset the scale
  balance_scale.left = 0
  balance_scale.right = 0
  -- decide which side the first weight will go
  arrow_side = "left"
  weights = {}
  place_weights()
end

--update function and level functions
function add_obstacles(obstacle_count, types, position_bounds)
    obstacles = {}
    for i = 1, obstacle_count do
        local obstacle_type = types[flr(rnd(#types)) + 1]
        local obstacle = {
            x = flr(rnd(position_bounds.xmax - position_bounds.xmin + 1)) + position_bounds.xmin,
            y = flr(rnd(position_bounds.ymax - position_bounds.ymin + 1)) + position_bounds.ymin,
            type = obstacle_type
        }
        -- initialize dx and dy for fish obstacles
        if obstacle_type == "fish" or obstacle_type == "jellyfish" then
            obstacle.dx = rnd() - 0.5  -- random horizontal speed
            obstacle.dy = rnd() - 0.5  -- random vertical speed
        end

        add(obstacles, obstacle)
    end
end

-- function to initialize scale positions
function init_scale_positions(count, position_bounds)
    potential_scale_positions = {}
    for i = 1, count do
        local randx = flr(rnd(position_bounds.xmax - position_bounds.xmin + 1)) + position_bounds.xmin
        local randy = flr(rnd(position_bounds.ymax - position_bounds.ymin + 1)) + position_bounds.ymin
        add(potential_scale_positions, {x = randx, y = randy})
    end
end

-- function to add the first scale
function add_first_scale()
    local idx = flr(rnd(#potential_scale_positions)) + 1
    local scale_position = potential_scale_positions[idx]
    add(scales, {x = scale_position.x, y = scale_position.y, collected = false})
    active_scale = true -- set the first scale as active
end

-- initialize fire level with refactored functions
function init_fire_level()
    local position_bounds = {xmin = 16, xmax = 112, ymin = 16, ymax = 112}
    add_obstacles(10, {"magma", "rock"}, position_bounds)
    init_scale_positions(10, position_bounds)
    add_first_scale()
    music(-1)
    music(03)
end

-- function to initialize water level
function init_water_level()
    local position_bounds = {xmin = 16, xmax = 112, ymin = 16, ymax = 112}
    add_obstacles(10, {"fish", "jellyfish"}, position_bounds)
    init_scale_positions(10, position_bounds)
    add_first_scale()
    scales_collected = 0
    music(-1)
    music(05)
end

-- update water obstacles (fish) with bouncing behavior
function update_water_obstacles()
    for _, obstacle in ipairs(obstacles) do
        -- update fish movement with bouncing behavior
        obstacle.x = obstacle.x + obstacle.dx
        obstacle.y = obstacle.y + obstacle.dy

        -- check if fish hits the level boundaries and bounce back
        if obstacle.x < 0 or obstacle.x > 127 then
            obstacle.dx = -obstacle.dx -- reverse horizontal direction
        end
        if obstacle.y < 0 or obstacle.y > 127 then
            obstacle.dy = -obstacle.dy -- reverse vertical direction
        end

        -- check for collisions with the snake
        if collide(snake[1], obstacle) then
											 if game_state == "final" then
                restart_final_level()
            else
                restart_level()
                return -- exit the loop early as we've already found a collision
           end 
        end
    end
end

function _update_water_level()
    local new_scale_needed = false

    -- check if the active scale is collected
    for i = #scales, 1, -1 do
        local scale = scales[i]
        if not scale.collected and collide(snake[1], scale) then
            scale.collected = true
            scales_collected += 1
            active_scale = false  -- reset the active scale flag

            -- increase snake speed and obstacle speed
            snake_speed = snake_speed + snake_speed_increment
            obstacle_speed = obstacle_speed + obstacle_speed_increment

            del(scales, scale)  -- remove the collected scale from the list

            -- mark that a new scale is needed
            if scales_collected < water_level_win then
                new_scale_needed = true
            end

            break -- exit the loop as a scale has been collected
        end
    end

    -- add a new scale if needed
    if new_scale_needed and not active_scale then
        add_new_scale()
    end

    -- if 10 scales are collected, mark the level as completed
            if scales_collected == fire_level_win then
                level_completed[current_level] = true
                if current_level then
                    level_completed[current_level] = true
                end
            end

    -- update water obstacles (fish) with bouncing behavior
    update_water_obstacles()
end


-- add this function to handle the generation of a new scale
function add_new_scale()
    local idx = flr(rnd(#potential_scale_positions)) + 1
    local scale_position = potential_scale_positions[idx]
    add(scales, {x = scale_position.x, y = scale_position.y, collected = false})
    active_scale = true
end

function place_weights()
    weights = {}
    local total_weight = 0
  -- adjust as needed

    while total_weight < max_total_weight do
        local new_weight_value = flr(rnd(3)) + 1  -- weights between 1 and 3
        if total_weight + new_weight_value <= max_total_weight then
            local valid_position = false
            local new_weight_x, new_weight_y

            -- keep trying until a valid position is found
            while not valid_position do
                new_weight_x = flr(rnd(104)) + 8
                new_weight_y = flr(rnd(104)) + 8
                valid_position = true

                -- check against all existing weights
                for _, existing_weight in ipairs(weights) do
                    if abs(new_weight_x - existing_weight.x) <= 8 and abs(new_weight_y - existing_weight.y) <= 8 then
                        valid_position = false
                        break  -- exit the loop as an invalid position is found
                    end
                end
            end

            -- add the new weight with a valid position
            local new_weight = {
                x = new_weight_x,
                y = new_weight_y,
                value = new_weight_value
            }
            add(weights, new_weight)
            total_weight = total_weight + new_weight_value
        end
    end
end

function _update_earth_level()
    local buffer = 4
for weight in all(weights) do
    if abs(snake[1].x - weight.x) <= buffer and abs(snake[1].y - weight.y) <= buffer then
            -- add weight value to the appropriate side of the scale
            if arrow_side == "left" then
                balance_scale.left += weight.value
                arrow_side = "right"  -- toggle the arrow to the other side
            else
                balance_scale.right += weight.value
                arrow_side = "left"   -- toggle the arrow to the other side
            end

            -- remove the weight from the playfield
            del(weights, weight)
    end
end
if abs(balance_scale.left - balance_scale.right) > tolerance then
  -- too imbalanced, restart the level or reduce player's life
  restart_level()
elseif #weights == 0 and balance_scale.left ~= balance_scale.right then   
  restart_level()
elseif #weights == 0 and balance_scale.left == balance_scale.right then
  -- level completed successfully
level_completed[current_level] = true end
end

function init_earth_level()
  music(-1)
  music(06)
  -- reset the scale
  balance_scale.left = 0
  balance_scale.right = 0
  -- decide which side the first weight will go
  arrow_side = "left"
  weights = {}
  place_weights()
  
end

function init_air_level()
    music(-1)
    music(stages_info[stage].music_air)
    -- global variables for the air level
    arrows = {}
    total_arrows = 0
    hit_arrows = 0

    -- calculate arrow spawn interval based on music speed
    local beats_per_minute = 60 / stages_info[stage].music_speed -- convert to beats per minute
    local beats_per_frame = beats_per_minute / 30 -- convert to beats per frame (30 frames per second)
    arrow_spawn_interval = 1 / beats_per_frame -- adjust for spawning every 4 beats

    -- adjust the arrow speed based on the current stage
    arrow_speed = base_arrow_speed * stages_info[stage].speed_multiplier
end

function _update_air_level()
    -- update spawn timer and generate new arrow if needed
    arrow_spawn_timer -= 1
    if arrow_spawn_timer <= 0 then
        generate_arrow()
        arrow_spawn_timer = arrow_spawn_interval
    end

    -- move existing arrows and check for player input within the buffer zone
				for i = #arrows, 1, -1 do
    local arrow = arrows[i]
    arrow.y -= arrow_speed

    if arrow.y >= 16 - buffer_size and arrow.y <= 16 + buffer_size then
        local correctbuttonpressed = (
            (arrow.direction == 1 and btnp(0)) or
            (arrow.direction == 3 and btnp(1)) or
            (arrow.direction == 2 and btnp(2)) or
            (arrow.direction == 4 and btnp(3))
        )

        if correctbuttonpressed then
            hit_arrows += 1
            del(arrows, arrow)
        end
    elseif arrow.y < 8 - buffer_size then
        del(arrows, arrow)
    end
end

    -- delayed check for stage completion until after all arrows are processed
    if #arrows == 0 and total_arrows >= stages_info[stage].count then
        local accuracy = hit_arrows / total_arrows
        if accuracy < minimum_accuracy then
            init_air_level()  -- restart level if accuracy is below minimum
            return
        elseif stage < #stages_info then
            stage += 1  -- proceed to the next stage
            total_arrows = 0
            hit_arrows = 0
            arrow_speed = base_arrow_speed * stages_info[stage].speed_multiplier
            init_air_level()  -- reinitialize for the next stage
        else
            level_completed[current_level] = true
        end
    end
end

-- function to generate an arrow
function generate_arrow()
    if total_arrows < stages_info[stage].count then
        local arrow_direction = flr(rnd(4)) + 1
        -- determine the starting x position based on the direction
        local startx
        if arrow_direction == arrow_left then
            startx = arrow_x_left
        elseif arrow_direction == arrow_up then
            startx = arrow_x_up
        elseif arrow_direction == arrow_right then
            startx = arrow_x_right
        else  -- arrow_down
            startx = arrow_x_down
        end

        local new_arrow = {
            x = startx,
            y = 128,  -- y position (bottom of the screen)
            direction = arrow_direction
        }
        add(arrows, new_arrow)
        total_arrows += 1
    end
end
-- function to update arrows
function update_arrows()
    arrow_spawn_timer -= 1
    if arrow_spawn_timer <= 0 then
        generate_arrow()
        arrow_spawn_timer = arrow_spawn_interval
    end

    for arrow in all(arrows) do
        arrow.y -= arrow_speed
        if arrow.y < -8 then  -- assuming arrow height is 8 pixels
            del(arrows, arrow)
        end
    end
end


function initialize_level(level_name)
    current_level = level_name
    scales_collected = 0
    obstacles = {}
    snake = {
        {x=64, y=64},  -- head
        {x=63, y=64},  -- body segment
        {x=62, y=64},  -- body segment
        {x=61, y=64},  -- tail
    }
    snake_dir = {x=1, y=0}

    if current_level == "fire" then
    init_fire_level() 
    
				elseif current_level == "water" then
    init_water_level()
    
    elseif current_level == "earth" then
				init_earth_level()

    elseif current_level == "air" then
    init_air_level()
    
    elseif game_state == "final" then
    restart_final_level()
    
    end

end

--restart level on fail
function restart_level()
    initialize_level(current_level)
    reset_game_state()
    if current_level == "fire" then
    init_fire_level()
    end
    if current_level == "water" then
    init_water_level()
    end
    if current_level == "earth" then
    init_earth_level()
    end
    if current_level == "air" then
    init_air_level()
    end

end

function reset_game_state()
    -- reset all variables and objects to their initial state
    scales = {}
    obstacles = {}
    obstacle = {}
    local obstacle_speed = 0.5 
    scales_collected = 0
    snake_speed = 1
end

function init_selection()
				init_selection_called += 1
    music(-1)
    music(01)
    torch_sprite=116
				frame_counter=0
				animation_speed=1
end

function reset_snake_position()
    snake = {
        {x=64, y=64},  -- head
        {x=63, y=64},  -- body segment
        {x=62, y=64},  -- body segment
        {x=61, y=64},  -- tail
    }
    snake_dir = {x=1, y=0}
end

function handle_level_completion()
    if level_completed[current_level] and not handled_level_completion[current_level] then
        if game_state ~= "selection" or "final" then
            transitioning_to_selection = true
            handled_level_completion[current_level] = true  -- set the flag for the specific level
            game_state = "selection"
            init_selection()
        end
        reset_game_state()
    end
    check_final_level_unlock()
end


function _update_fire_level()
update_fire_level_called += 1
    -- check if there is no active scale and potential scale positions are available
    if not active_scale and #potential_scale_positions > 0 then
        local idx = flr(rnd(#potential_scale_positions)) + 1
        local scale_position = potential_scale_positions[idx]

        add(scales, {x = scale_position.x, y = scale_position.y, collected = false})
        active_scale = true
    end

    -- check if the active scale is collected
    for _, scale in ipairs(scales) do
        if not scale.collected and collide(snake[1], scale) then
            scale.collected = true
            scales_collected += 1
            active_scale = false

            add(snake, {x = snake[#snake].x - 1, y = snake[#snake].y})
            snake_speed += snake_speed_increment
            obstacle_speed += obstacle_speed_increment
            del(scales, scale)

            if scales_collected == fire_level_win then
                level_completed[current_level] = true
                if current_level then
                    level_completed[current_level] = true
                end
            end
            break
        end
    end

    -- handle falling magma and rock movements
    for _, obstacle in ipairs(obstacles) do
        if obstacle.type == "magma" then
            obstacle.y += 1
        elseif obstacle.type == "rock" then
            obstacle.y += 0.5
        end

        if collide_bbox(snake[1], obstacle, 8, 8) then
            if game_state == "final" then
                restart_final_level()
            else
                restart_level()
                return -- exit the loop early as we've already found a collision
            
        end
        end

        if obstacle.y > 128 then
            obstacle.y = -8
            obstacle.x = flr(rnd(128))
        end
    end
end

-- main update function
function _update()
    if game_state == "start_screen" then
        if btnp(4) or btnp(5) then
            game_state = "first_story"
        end
    elseif game_state == "first_story" then
        if btnp(4) or btnp(5) then
            game_state = "selection"
            init_selection()
        end
    elseif game_state == "selection" then
        frame_counter += 1
    				local adjusted_animation_speed = animation_speed * 2

    -- change the sprite only every few frames based on animation_speed
    if frame_counter >= adjusted_animation_speed then
        torch_sprite += 1
        frame_counter = 0  -- reset the frame counter
 
        -- loop back to the first sprite if the end is reached
        if torch_sprite > 119 then
            torch_sprite = 116
        end
    end
 
        -- check for level selection collisions
        for level_name, level in pairs(level_sprites) do
            if collide_with_sprite(snake[1], level) then
                if btnp(5) then  -- x button pressed
                    initialize_level(level_name)
                    game_state = level_name
                end
            end
								    -- handle final level selection
								    if final_level_unlocked and collide_with_sprite(snake[1], {x=final_level_sprite.x, y=final_level_sprite.y}) then
								        if btnp(5) then
								            game_state = "final"
								            init_final_level()
								        end
								    end
        end
    end 

    -- change snake direction
    if btn(0) and snake_dir.x == 0 then snake_dir = {x=-1, y=0} end -- left
    if btn(1) and snake_dir.x == 0 then snake_dir = {x=1, y=0} end -- right
    if btn(2) and snake_dir.y == 0 then snake_dir = {x=0, y=-1} end -- up
    if btn(3) and snake_dir.y == 0 then snake_dir = {x=0, y=1} end -- down


    -- update snake position
    for i=#snake, 2, -1 do
        snake[i].x = snake[i-1].x
        snake[i].y = snake[i-1].y
    end
    snake[1].x += snake_dir.x * snake_speed
    snake[1].y += snake_dir.y * snake_speed
-- collision with bad
local flagged_sprites = get_sprites_with_flag(1)
for sprite in all(flagged_sprites) do
    if collide_bbox(snake[1], sprite, 8, 8) then
        -- only restart the level if snake is moving
        if snake_dir.x ~= 0 or snake_dir.y ~= 0 then
            if current_level == "air" then
                reset_snake_position()
            elseif game_state == "final" then
                restart_final_level()
            else
                restart_level()
                break -- exit the loop early as we've already found a collision
            end
        end
    end
end

    -- level-specific updates
    if current_level == "fire" then
				_update_fire_level()
				elseif current_level == "water" then
    _update_water_level()
    elseif current_level == "earth" then
    _update_earth_level()
    elseif current_level == "air" then
     _update_air_level()
    elseif game_state == "final" then
     _update_final_level()    
    end

				handle_level_completion()

end
function all_levels_completed()
    return level_completed["fire"] and level_completed["water"] and level_completed["earth"] and level_completed["air"]
   
end

function final_init_fire()
    local position_bounds = {xmin = 16, xmax = 112, ymin = 16, ymax = 112}
    add_obstacles(10, {"magma", "rock"}, position_bounds)
    init_scale_positions(10, position_bounds)
    add_first_scale()
        snake = {
        {x=64, y=64},  -- head
        {x=63, y=64},  -- body segment
        {x=62, y=64},  -- body segment
        {x=61, y=64},  -- tail
    }
    snake_dir = {x=0, y=0}
end

function final_init_water()
    local position_bounds = {xmin = 16, xmax = 112, ymin = 16, ymax = 112}
    add_obstacles(10, {"fish", "jellyfish"}, position_bounds)
    init_scale_positions(10, position_bounds)
    add_first_scale()
    scales_collected = 0
        snake = {
        {x=64, y=64},  -- head
        {x=63, y=64},  -- body segment
        {x=62, y=64},  -- body segment
        {x=61, y=64},  -- tail
    }
    snake_dir = {x=0, y=0}
end

function final_init_earth()
  -- reset the scale
  balance_scale.left = 0
  balance_scale.right = 0
  -- decide which side the first weight will go
  arrow_side = "left"
  weights = {}
  place_weights()
      snake = {
        {x=64, y=64},  -- head
        {x=63, y=64},  -- body segment
        {x=62, y=64},  -- body segment
        {x=61, y=64},  -- tail
    }
    snake_dir = {x=0, y=0}
end

function final_init_air()
    -- global variables for the air level
    arrows = {}
    total_arrows = 0
    hit_arrows = 0

    -- calculate arrow spawn interval based on music speed
    local beats_per_minute = 60 / stages_info[stage].music_speed -- convert to beats per minute
    local beats_per_frame = beats_per_minute / 30 -- convert to beats per frame (30 frames per second)
    arrow_spawn_interval = 1 / beats_per_frame -- adjust for spawning every 4 beats

    -- adjust the arrow speed based on the current stage
    arrow_speed = base_arrow_speed * stages_info[stage].speed_multiplier
end
function init_final_level()
    music(-1)
    music(13)
        -- resetting the level_completed table
    for level in pairs(level_completed) do
        level_completed[level] = false
    end

    -- resetting the handled_level_completion table
    for level in pairs(handled_level_completion) do
        handled_level_completion[level] = false
    end
    reset_game_state()
    current_level = "final_fire"
    final_init_fire()
    fire_level_win = 20
				water_level_win = 20
				max_total_weight = 48
				minimum_accuracy = 0.85
				local snake_speed_increment = 0.1 -- the amount by which snake speed increases after each scale collection
				minimum_acc_perc = ceil(minimum_accuracy*100)
				stage = 3
    snake = {
        {x=64, y=64},  -- head
        {x=63, y=64},  -- body segment
        {x=62, y=64},  -- body segment
        {x=61, y=64},  -- tail
    }
    snake_dir = {x=0, y=0}
end

function _update_final_level()
				update_final_level_called += 1
    if current_level == "final_fire" then
        _update_fire_level() 
    elseif current_level == "final_water" then
        _update_water_level()
    elseif current_level == "final_earth" then
        _update_earth_level()
    elseif current_level == "final_air" then
        _update_air_level()
    end

    -- handle level progression
    handle_final_level_progression()
end
function restart_final_level()
    reset_game_state()  -- reset the game state for the current level

    -- restart the same level within the final stage
    if current_level == "final_fire" then
        final_init_fire()
    elseif current_level == "final_water" then
        final_init_water()
    elseif current_level == "final_earth" then
        final_init_earth()
    elseif current_level == "final_air" then
        final_init_air()
    end
end

function handle_final_level_progression()

    if  level_completed[current_level] then
        if current_level == "final_fire" then
            current_level = "final_water"
            final_init_water()
        elseif current_level == "final_water" then
            current_level = "final_earth"
            final_init_earth()
        elseif current_level == "final_earth" then
            current_level = "final_air"
            final_init_air()
        elseif current_level == "final_air" then
            game_state = "final_story"
        end
    end
end
function check_final_level_unlock()
    final_level_unlocked = level_completed.fire and level_completed.water and level_completed.earth and level_completed.air
end
-->8
--draw functions
function _draw()
    if game_state == "start_screen" then
        draw_start_screen()
    elseif game_state == "final" then
        draw_final_level()
    elseif game_state == "selection" then
								draw_selection()

				elseif game_state == "fire" then
        draw_fire_level()
				elseif game_state == "water" then
								draw_water_level()
    elseif game_state == "earth" then
        draw_earth_level()
    elseif game_state == "air" then
        draw_air_level()
    elseif game_state == "final_story" then
        draw_final_story()
    elseif game_state == "first_story" then
        draw_first_story()
    else
        cls()
        -- this is a fallback for any other states or to capture an undefined state
        print("undefined state or error.", 40, 64, 8)
    end
    if game_state ~= "start_screen" then
        print("level:", 8, 2, 7)
    				print(game_state, 33, 2, 7)
    end
end
function draw_first_story()
				cls()
				map(16,16)
				print("in order to join us",25,65,7)
				print("you must first complete",20,75,7)
				print("the trials of the scale",20,85,7)
				print("press o or x to continue", 17, 121, 7)
				end
function draw_final_story()
				cls()
				map(16,16)
				print("you have proven yourself...",10,65,7)
				print("welcome to our clan!",25,75,7)
				print("thank you for playing", 22, 121, 7)
				end
-- drawing function for the final level
function draw_final_level()
    if current_level == "final_fire" then
        draw_fire_level()
    elseif current_level == "final_water" then
        draw_water_level()
    elseif current_level == "final_earth" then
        draw_earth_level()
    elseif current_level == "final_air" then
        draw_air_level()
    end
end 
function draw_start_screen()
								cls(1) -- clear screen with a background color
        map(0,16 )
        print("serpent's scale quest", 22, 35, 7)
        print("by: sadodare", 42, 45, 7)
        print("press o or x to start", 22, 60, 7)
end
function draw_selection()
        cls()
        map(0,0)  -- drawing the level selection map
								-- drawing the four level options
								print("level select", 40,15,11)
								for level_name, level in pairs(level_sprites) do
								    spr(level.id, level.x, level.y, 2, 2)
								    
								    -- check if the level is completed and draw the "completed" sprite above it
								    if level_completed[level_name] then
								        spr(43, level.x+4, level.y - 10) -- assuming you want it 10 pixels above
								    end
								    if final_level_unlocked then
            			 spr(final_level_sprite.id, final_level_sprite.x, final_level_sprite.y,2,2)
            			 print("final level",43,112,11)
            end
								end
        spr(torch_sprite, 12,35)
        spr(torch_sprite, 106,35)
        print("fire water earth air", 22, 50, 11)
    				print("move to level and press ❎", 12, 121, 7)
        -- draw the snake
        for _, segment in ipairs(snake) do
            rectfill(segment.x, segment.y, segment.x+7, segment.y+7, 11)
        end
end
function draw_fire_level()
cls()
    map(16,0)  -- drawing the fire level map
    print("scales:", 80, 2, 7)
    print(scales_collected, 110, 2, 7)
    print("/", 115, 2, 7)
    print(fire_level_win, 120, 2, 7)
    print("collect scales to complete", 12, 121, 7)

    -- draw magma and rocks
    for _, obstacle in ipairs(obstacles) do
        if obstacle.type == "magma" then
            spr(25, obstacle.x, obstacle.y, 2, 2)  
        elseif obstacle.type == "rock" then
            spr(27, obstacle.x, obstacle.y )
        end
    end
    -- draw snake
    for _, segment in ipairs(snake) do
        rectfill(segment.x, segment.y, segment.x+7, segment.y+7, 11)
    end
-- draw scales
for _, scale in ipairs(scales) do
    if not scale.collected then
        -- draw the scale sprite at scale's x and y position
        spr(scale_sprite_id, scale.x, scale.y)
    end
end
end
function draw_water_level()
    cls()
    map(32,0)  -- assuming the water level map starts at (0,30)
    -- draw snake and other specific elements...
    print("scales:", 80, 2, 7)
    print(scales_collected, 110, 2, 7)
    print("/", 115, 2, 7)
    print(water_level_win, 120, 2, 7)
    print("collect scales to complete", 12, 121, 7)

    -- draw water obstacles: fish and jellyfish
foreach(obstacles, function(obstacle)
    if obstacle.type == "fish" then
        -- determine if the fish sprite should be flipped
        local flip_x = obstacle.dx > 0

        -- draw fish, flipping horizontally if moving left
        spr(64, obstacle.x, obstacle.y, 2, 1, flip_x)
    elseif obstacle.type == "jellyfish" then
        -- draw jellyfish without flipping
        spr(66, obstacle.x, obstacle.y)
    end
end)


    -- draw snake
    for _, segment in ipairs(snake) do
        rectfill(segment.x, segment.y, segment.x+7, segment.y+7, 11)
    end
    -- draw scales
    for _, scale in ipairs(scales) do
        if not scale.collected then
            -- draw the scale sprite at scale's x and y position
            spr(scale_sprite_id, scale.x, scale.y) 
        end
    end
   
end
function draw_earth_level()
  cls(5) -- use whatever color index you want for the background
  map(48,0)
  -- draw the scale
  draw_scale()
  
  -- draw weights in the playfield
  draw_weights()
  
  -- draw the snake
  draw_snake()
  
  -- draw the balance indicator (arrows or highlights)
  draw_balance_indicator()
  
  -- update the display for left and right weights on the scale
  print("left: "..balance_scale.left, 58, 2, 7)
  print("right: "..balance_scale.right, 90, 2, 7)
  print("balance scale, starting left", 9, 121, 7)

end
function draw_air_level()
        cls()
        map(64,0)  -- assuming the air level map starts at (0,60)
        draw_arrows()
                -- calculate accuracy percentage
        local accuracy = 0
        if total_arrows > 0 then
            accuracy = (hit_arrows / total_arrows) * 100
        end
  print("use ⬅️⬆️➡️⬇️, >", 11, 121, 7)
  print(minimum_acc_perc, 75, 121, 7)
  print("% to win", 85, 121, 7)

    print("accuracy:", 70, 2, 7)
    print(flr(accuracy), 105, 2, 7)
    print("%", 117, 2, 7)

end
function draw_scale()
  sspr(24,32,16,16,8,8,112,112)
end

function draw_weights()
  for weight in all(weights) do
    -- the weight.value can determine the size or the sprite used
    spr(49, weight.x, weight.y)
    -- print the value on or near the weight
    print(weight.value, weight.x + 2, weight.y + 2, 7) -- 7 for white color in pico-8
  end
end

function draw_snake()
    -- draw snake
    for _, segment in ipairs(snake) do
        rectfill(segment.x, segment.y, segment.x+7, segment.y+7, 11)
    end
end

function draw_balance_indicator()
    local balance_scale_x = 64 -- assuming the scale is horizontally centered
    local balance_scale_y = 32 -- assuming the scale is at a vertical position of 90
    local indicator_x, indicator_y

    -- set the arrow position based on the current arrow side
    if arrow_side == "left" then
        indicator_x = balance_scale_x - 40 -- arrow position on the left side
    else -- arrow_side is "right"
        indicator_x = balance_scale_x + 32 -- arrow position on the right side
    end
    indicator_y = balance_scale_y -- y position remains the same

    -- draw the arrow sprite at the calculated position
    spr(120, indicator_x, indicator_y)
end
-- draw function to render arrows
function draw_arrows()
    for arrow in all(arrows) do
        -- select sprite based on arrow direction
        local sprite_num
        if arrow.direction == arrow_left then sprite_num = 130  -- replace with actual sprite number
        elseif arrow.direction == arrow_up then sprite_num = 128
        elseif arrow.direction == arrow_right then sprite_num = 134
        elseif arrow.direction == arrow_down then sprite_num = 132
        end

        -- draw the arrow sprite
        spr(sprite_num, arrow.x, arrow.y,2,2)
    end
end



__gfx__
0000000000000000000000000000000000666600000000000033300077722777000330000003300077778777cccccccc77333777777777775555555544444444
000000000000000000000000900009000600006000077700033b3300779aa977008338000003300077888887dcccddcc733b3377777111775555555544444444
00700700000000005500005599009f90600ccc06077770000333333079499497003333000033330077822887ddcdcddd73333337711117775555555544444444
0007700000000000556776559f99ffa9600c0c060770700003333b332a9779a2003333000033330077822287cddccccc73333b33711717775555555544444444
0007700000000000556776559f99fff9600ccc060000700033333b332a9779a2003333000033330078822287cccddccc33333b33777717775555555544444444
00700700000000005500005599009f9060000006000070003b33bb3379499497000330000033330078222288cccdddcc3b33bb33777717775555555544444444
0000000000000000000000009000090006000060000770003b333330779aa977000330000033330088222228ddddcddd3b333337777117775555555544444444
0000000000000000000000000000000000666600000770000333330077722777000330000003300088888888cccccccc73333377777117775555555544444444
00000000777777777777777777777777777777777777777777777777777777777777777700000111111000000088880000666600000000009999999988888888
00000000700000001000000770000000000ccc07700000000000000770000000000000070001aa88888110000844998006000060000000009999999988888888
0000000070000001810000077000ccc00ccc0cc77000033300033337700000000000000700188aaa888881008a4499a8600ccc06000000009999999988888888
00000000700000188110000770ccc0c000011007700033b33003bb3770000000111000070188899aaa9988108a9a99a8600c0c06000000009999999988888888
000000007000018888101007700000000001110770003bbb3033bb37700000015c510007018889999a99881089a944a8600ccc06000000009999999988888888
000000007000199aa9101107700011100111c11770003bbb303bbb3770001115ccc5100718888999aa9998818a9a44a860000006000000009999999988888888
00000000700019aa7a91110770111c1111cccc17703333333333b33770015c5ccccc1007189899aaaaaa998108aa448006000060000000009999999988888888
00000000710019a77a988107711cccc11c6666c7703b33333b3333077015ccc5cdcc110718999aaaaa9aa9910088880000666600000000009999999988888888
00000000711019a77a98810771cc666cc6717667703b30403b304007701ccdcccdc5cc17188aaa99aa999a9100000000000770000000000022222222cccccccc
0000000071819aa77a9981077c66777667117767703b30403b304007715cddcccccccd1718aa99999a999aaa00000000000770000000000022222222cccccccc
000000007189aa777aa981077677717771111767703b30403b30400771cccccccccccc17aaa888889a99888100000007000770000000000022222222cccccccc
000000007119a77777a981077777111711ccc17770040040040040077155555555555517018888889a99881000000070000770000000000022222222cccccccc
000000007019aa777aa910077711cc111c6cc11770040040040040077011111111111107018888889aa8881000000700700770070000000022222222cccccccc
000000007011aaa7aa910007711cc6c1c777c117700400400400400770000000000000070018888888aa880070007000770770770000000022222222cccccccc
00000000700111111110000771111111111111177004000004000007700000000000000700011888888a100007070000077777700000000022222222cccccccc
000000007777777777777777777777777777777777777777777777777777777777777777000001111110000000700000007777000000000022222222cccccccc
00066000001111001151115111111111c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1555555555551c1c1c5888888888888555555555588777777773333333311111111
000660000115511015111511111111111c1c1c1c1c1c1c1c1c1c1c1c1c1c155555555555555c1c55999999999999555555555599777777773333333311111111
00666600015555105111511111111111222222222222222222222222222255555555555555552555999999999999555555555599777777773333333311111111
06655660115555111115111111111111222222222222222222222222222555555555555555555522999999999999555555555599777777773333333311111111
06755760155555511151111511111111222222222222222255555552225555555555555555555522999999999995555555555559777777773333333311111111
6677776615555551151111511c1c1c1c222222222222225555555552255555555555555555555552999999999995555555555555777777773333333311111111
65577556155555515111151111c111c12222222222222555555555225555555555555555555555559a999a999a95555555555555777777773333333311111111
6666666611111111111151111c1c1c1c888888888888555555555888555555555555555555555555999a999a9995555555555555777777773333333311111111
0004444400000004000ee0000000000aa0000000cccc6cc11cccccccccccccc11cccccccccccc111111cccccccccccc11ccccccc111111111111111100000000
00499999440044440eeffee00000000990000000cccccc1661ccc6cccc6ccc161cccccccccccc166661cc6ccccccccc161cc6ccc111111111155111100000000
049999999944a9940effffe00000000990000000cc6cc166661ccccccc6cc1661cc6c6cccc6cc166661cccccc6c6ccc1661ccccc111111111551151100000000
49949aaaaaaaa940efff9ffe0000009999000000cccc16666661cccc6ccc16661cccccccccccc166661ccc6cccccccc16661cccc111111111111551100000000
49999aaaaaa4a940eeeeeeee009999aaaa999900ccc1666666661cc6ccc166661ccccccccc6cc166661cccccccccc6c166661c6c111111111155511100000000
0499aaaaa440494000e0e0e09990000990000999cc166666666661cccc16666611111111ccccc166661cc6cc11111111666661cc111111111551115500000000
00444aaa4000049400e0e0ee0000000990000000c16666666666661cc166666666666661ccccc166661ccccc166666666666661c111111111111555100000000
00000444000000440ee0e00e00000009900000001666666666666661166666666666666111111166661111111666666666666661111111111111111100000000
99999999999555555599999900000009900000001111116666111111166666666666666116666666666666611666666666666661111111111111555100000000
aaaaaaaaaa555555555aaaaa0000000990000000c6ccc166661c66ccc166666666666661c16666666666661c166666666666661c155555111115151500000000
aaaaaaaaaa555555555aaaaa0000000990000000ccccc166661ccccccc16666611111111cc166666666661cc11111111666661cc111111111115515500000000
aaaaaaaaaa555555555aaaaa0000000990000000ccccc166661cccccccc166661cccccccc6c1666666661cc6ccccccc166661ccc115555551115151500000000
aaaaaaaaaa555555555aaaaa0000009999000000c6ccc166661ccc6ccccc16661ccccc6ccccc16666661ccccccc6ccc16661cccc111111111111555100000000
aaaaaaaaaa555555555aaaaa00000a9999a00000cc6cc166661c6cccccccc1661cc6ccccccc6c166661cc6ccccccccc1661cccc6555551111111111100000000
a4a4a4a4a455555555a4a4a40000aaaaaaaa0000ccccc166661cccccc6cccc161cccc6ccccc6cc16616cccccc6cccc6161cc6ccc111111111111111100000000
4a4a4a4a4a455555554a4a4a0099999999999900ccc6c111111cccccccccccc11cccccccccccccc11cccccccccccccc11ccccccc111155551111111100000000
cccccccc555555555555555555555555cccccccccccaaaaaaaaaaaaaaaaaaccc444aa44994444444ccccccc44ccccccccccccccc944444aaaa44444900000000
cc6666cc5555555c5555555555555555cccccccccccaaaaaaaaaaaaaaaaaaccc944aa44444444494cccccc9449ccccccc6cccccc44444aaaaaa4444400000000
cc66666c5555555c5555555555555555cccccccccc99aaaa999aa999aaaa99cc444aa44444944944ccccc944449ccccccccccc6c44944aaaaaa4494400000000
c666666c5555556c5555555555555555cccccccccc999a99999aa99999a999cc444aa49444444449cccc44499444cccccccccccc4444aaaaaaaa444400000000
c66666cc555556cc5555555555555555cccccccc44499999999aa99999999444494aa44444444444ccc4444444444cccccc6cccc444aaaaaaaaaa44400000000
cccccccccccccccc55555555555555556c6c6c6c44449999449aa94499994444444aa44449444944cc444944449444cccccccc6c49aaaaaaaaaaaa9400000000
cccccccccccccccccccccccc55555cccc6c6c6c644444444444aa44444444444444aa44944444444c44444444444444cc6cccccc4aaaaaaaaaaaaaa400000000
cccccccccccccccccccccccc5555cccc6c6c6c6c44444444444aa44444444444944aa444449444444494444444444944ccccccccaaaaaaaaaaaaaaaa00000000
aaaaaaaa3333333333333333333bb333000880000000880000088000008800007700007700000000000000000000000000000000000000000000000000000000
aaaaaaaa33b3333333bb333333bbbb33008aa8000008aa80008aa80008aa80007770077700000000000000000000000000000000000000000000000000000000
aaaaaaaa3b3b33333bbbb33333bbbb33008aa8000008aa80008aa80008aa800007cccc7000000000000000000000000000000000000000000000000000000000
aaaaaaaa333333333bbbb333333bb333008aa800008aa800008aa800008aa80000c99c0000000000000000000000000000000000000000000000000000000000
aaaaaaaa3333333333bb3333333443330008800000088000000880000008800000c99c0000000000000000000000000000000000000000000000000000000000
aaaaaaaa33333b3333333333333443330008800000088000000880000008800007cccc7000000000000000000000000000000000000000000000000000000000
aaaaaaaa3333b3b33333333333344333000880000008800000088000000880007770077700000000000000000000000000000000000000000000000000000000
aaaaaaaa333333333333333333344333000880000008800000088000000880007700007700000000000000000000000000000000000000000000000000000000
00000001100000000000000110000000000001111110000000000001100000007777777777777777000000000000000000000000000000000000000000000000
00000016610000000000001610000000000001666610000000000001610000007033333333333307000000000000000000000000000000000000000000000000
00000166661000000000016610000000000001666610000000000001661000007333333333333337000000000000000000000000000000000000000000000000
00001666666100000000166610000000000001666610000000000001666100007333333333333337000000000000000000000000000000000000000000000000
00016666666610000001666610000000000001666610000000000001666610007338833333388337000000000000000000000000000000000000000000000000
00166666666661000016666611111111000001666610000011111111666661007338833333388337000000000000000000000000000000000000000000000000
01666666666666100166666666666661000001666610000016666666666666107333333333333337000000000000000000000000000000000000000000000000
16666666666666611666666666666661111111666611111116666666666666617333333333333337000000000000000000000000000000000000000000000000
11111166661111111666666666666661166666666666666116666666666666617333339339333337000000000000000000000000000000000000000000000000
00000166661000000166666666666661016666666666661016666666666666107333333333333337000000000000000000000000000000000000000000000000
00000166661000000016666611111111001666666666610011111111666661007333333333333307000000000000000000000000000000000000000000000000
00000166661000000001666610000000000166666666100000000001666610007003333883333007000000000000000000000000000000000000000000000000
00000166661000000000166610000000000016666661000000000001666100007000333883330007000000000000000000000000000000000000000000000000
00000166661000000000016610000000000001666610000000000001661000007000033883300007000000000000000000000000000000000000000000000000
00000166661000000000001610000000000000166100000000000001610000007000008888000007000000000000000000000000000000000000000000000000
00000111111000000000000110000000000000011000000000000001100000007777777777777777000000000000000000000000000000000000000000000000
__label__
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333733377737373777373333333337737773733377733773777377733773773333333333333333333333333333333333333333333333333333333333333
33333333733373337373733373333733373337333733373337333373337337373737333333333333333333333333333333333333333333333333333333333333
33333333733377337373773373333333377737733733377337333373337337373737333333333333333333333333333333333333333333333333333333333333
33333333733373337773733373333733333737333733373337333373337337373737333333333333333333333333333333333333333333333333333333333333
33333333777377733733777377733333377337773777377733773373377737733737333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
3333333300000000000000000000000000000000b000bbb0b0b0bbb0b00000000bb0bbb0b000bbb00bb0bbb00000000000000000000000000000000033333333
3333333300000000000000000000000000000000b000b000b0b0b000b0000000b000b000b000b000b0000b000000000000000000000000000000000033333333
3333333300000000000000000000000000000000b000bb00b0b0bb00b0000000bbb0bb00b000bb00b0000b000000000000000000000000000000000033333333
3333333300000000000000000000000000000000b000b000bbb0b000b000000000b0b000b000b000b0000b000000000000000000000000000000000033333333
3333333300000000000000000000000000000000bbb0bbb00b00bbb0bbb00000bb00bbb0bbb0bbb00bb00b000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000007777777777777777000077777777777777770000777777777777777700007777777777777777000000000000000000033333333
33333333000000000000000007000000010000007000070000000000ccc070000700000000000000700007000000000000007000000000000000000033333333
3333333300000000000000000700000018100000700007000ccc00ccc0cc70000700003330003333700007000000000000007000000000000000000033333333
33333333000000000000000007000001881100007000070ccc0c0000110070000700033b33003bb3700007000000011100007000000000000000000033333333
3333333300000000000000000700001888810100700007000000000011107000070003bbb3033bb370000700000015c510007000000000000000000033333333
33333333000000880000000007000199aa91011070000700011100111c117000070003bbb303bbb37000070001115ccc51007000000088000000000033333333
33333333000008aa800000000700019aa7a911107000070111c1111cccc170000703333333333b337000070015c5ccccc10070000008aa800000000033333333
33333333000008aa800000000710019a77a9881070000711cccc11c6666c70000703b33333b33330700007015ccc5cdcc11070000008aa800000000033333333
333333330000008aa80000000711019a77a988107000071cc666cc67176670000703b30403b3040070000701ccdcccdc5cc1700000008aa80000000033333333
333333330000000880000000071819aa77a99810700007c667776671177670000703b30403b3040070000715cddcccccccd17000000008800000000033333333
33333333000000088000000007189aa777aa98107000076777177711117670000703b30403b304007000071cccccccccccc17000000008800000000033333333
33333333000000088000000007119a77777a9810700007777111711ccc1770000700400400400400700007155555555555517000000008800000000033333333
33333333000000088000000007019aa777aa9100700007711cc111c6cc1170000700400400400400700007011111111111107000000008800000000033333333
33333333000000000000000007011aaa7aa9100070000711cc6c1c777c1170000700400400400400700007000000000000007000000000000000000033333333
33333333000000000000000007001111111100007000071111111111111170000700400000400000700007000000000000007000000000000000000033333333
33333333000000000000000007777777777777777000077777777777777770000777777777777777700007777777777777777000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
3333333300000000000000bbb0bbb0bbb0bbb00000b0b0bbb0bbb0bbb0bbb00000bbb0bbb0bbb0bbb0b0b00000bbb0bbb0bbb000000000000000000033333333
3333333300000000000000b0000b00b0b0b0000000b0b0b0b00b00b000b0b00000b000b0b0b0b00b00b0b00000b0b00b00b0b000000000000000000033333333
3333333300000000000000bb000b00bb00bb000000b0b0bbb00b00bb00bb000000bb00bbb0bb000b00bbb00000bbb00b00bb0000000000000000000033333333
3333333300000000000000b0000b00b0b0b0000000bbb0b0b00b00b000b0b00000b000b0b0b0b00b00b0b00000b0b00b00b0b000000000000000000033333333
3333333300000000000000b000bbb0b0b0bbb00000bbb0b0b00b00bbb0b0b00000bbb0b0b0b0b00b00b0b00000b0b0bbb0b0b000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
333333330000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbb000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333377733773737377733333777337733333733377737373777373333333777377337733333377737773777337733773333337777733333333333333
33333333333377737373737373333333373373733333733373337373733373333333737373737373333373737373733373337333333377373773333333333333
33333333333373737373737377333333373373733333733377337373773373333333777373737373333377737733773377737773333377737773333333333333
33333333333373737373777373333333373373733333733373337773733373333333737373737373333373337373733333733373333377373773333333333333
33333333333373737733373377733333373377333333777377733733777377733333737373737773333373337373777377337733333337777733333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333

__gff__
0000000000000000000000000000020200000000000000000002020200000202000000000000000000020200000002020000000000000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e33333333333333333333333333332e2f4d4d4d4d4d4d4d4d4d4d4d4d4d4d2f0f71717171717171717171717171710f0e606c6c6c6c6c6c6c6c6c6c6c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e34343434343434353637383934342e2f4d4d4d5d4d4d4d4d4d4d4d4d4e4d2f0f71717171717171717271717173710f0e6c47486c4546606c4b4c6c494a6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e3a3a3a3a3a3a3a3b3c3838383a3a2e2f4d4e4d4d4d4e4d4d4d4e4d4d4d4d2f0f71717171727271717171717172710f0e6c57586c55566c6c5b5c6c595a6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e50505050505050383838383852502e2f4d4d4d4d4d4d4d4d4d4d4d4d5e4d2f0f71737271717271717172717171710f0e6c6c6c6c6c6c6c6c6c6c6c6c6c600e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e60606060606060386362626160602e2f4d4d5d5e4d4d4d4d4e4d4e4d4d4d2f0f71737171717271717171727271710f0e6c606c6c6c6c6c606c6c6c6c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e64646464646465666764646464642e2f4d4d4d4d4d4d4d4d4d4d4d4d4d4d2f0f71717171717171717271727171710f0e6c6c6c6c606c6c6c6c6c6c6c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e6c6c6c6c6c6a6968696b6c6c6c6c2e2f4e4d4d4d4d4e4d4d5d4d4d4d4d4e2f0f71717171717171717171717172710f0e6c6c6c6c6c6c6c6c6c6c606c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e6c6c6c6c6a69696869696b6c6c6c2e2f4d4d4d4d4d4d4d4d4d4d4d4d4d4d2f0f72727171717171717171717171710f0e6c6c6c6c6c6c6c6c6c6c6c6c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e6c6c6c6a696969686969696b6c6c2e2f4d5d4d4d4e5d4d4d4e4d4d4d5d4d2f0f71717172717172717171727171710f0e6c6c6c6c6c6c606c6c6c6c6c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e6c6c6a6969696968696969696b6c2e2f4d4d4d4d4d4d4d4d4d4d4d4d4d4d2f0f71717171717172717171717173710f0e6c6c606c6c6c6c6c6c6c606c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e6c6a69696969696869696969696b2e2f4d4d4d4d4d4d4d4d4d5e4d4e4d4d2f0f71717171717172717171717171710f0e6c6c6c6c6c6c6c6c6c6c6c6c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e6a696969696969686969696969692e2f4d4d4e4d4d4d4d4d4d4d4d4d4d4d2f0f71717171717171717171727271710f0e6c6c6c6c6c6c6c6c6c6c6c6c6c6c0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e69696969696969686969696969692e2f4d5e4d4d4d4d4d4e4d4d4d4d4e4d2f0f71717171717171717172717171720f0e6c6c6c6c6c6c6c6c6c6c6c6c6c600e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e00000000000000000000000000003e2e6969696969696d706e69696969692e2f4d4d4d4e4d4d4d4d4d4d4d4d4d4d2f0f71717171717171717171717171710f0e64646464646464646464646464640e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e11120000000000000000000013141e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e21220000000000000000000023241e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000088890000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000098990000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000000000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e00000008000000000000000000001e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e15160009000000000000000017181e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e25260009000000000000000027281e3f00000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001400000e050100501105013050170001505017050180501a0501f0001a0501c0501d0501f05023000210502305024050230501f000210501f0501d0501c050180001a050180501705015050000000000000000
011400000c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0100c0000c00000000
011700000c0100c0100c010000000c0100c0100c010000000c0100c0100c010000000c0100c0100c010000000c0100c0100c010000000c0100c0100c010000000c0100c0100c010000000c0100c0100c01000000
0117000021050150500c0501c05015050210501a05015050210501c05021050150501c05021050150501c0501d05015050210501c05021050150501c050210500c05021050110501c05021050150500c0501c050
011700001112017120101201113017120101301112017130101201112017130111101713010120111101713011110101201711011130101201711010130111201711010130111201711011130101201711010160
111b00240c75500705007051175513755007050c7551175500705137550c75500705107551175513755007050c755107551175500705137550c75510755007051175513755007050c75511755107551375500705
d31b0000007750c7050c70500775007750c70500775007750c70500775007750c7050077500775007750c7050077500775007750c705007750077500775007050077500775007050077500775007750077500705
0018000011775077750c7750b77510775097751177507775077750b7751077500000107750000011775077750c775107750b7750977511775077750c7750b775107750977511775077750c775107750b77509775
001800000477500775027750477500775027750477502775047750077502775047750077502775047750077502775047750077502775047750077502775047750077502775047750077502775047750077502775
00180000077750977507775057750977507775057750b77509775097750b7750477509775097750b77507775097750b775057750977504775077750977509775057750b775097750000009775000000b77505775
001800001777511775157751777511775157751177518775177751377518775117751577510775157751377510775137751777511775157751877511775157751077511775137751077511775177750000017775
001800001a77513775187751a7751377515775177751a77518775137751577518775177751a7751577518775177751a7751377515775187751a77513775187751a7751577513775187751a775137751877515775
0018000013075180751a0751307515075180751a07513075180751307517075180751307515075180751a075170751807513075170751a07513075180751c0751a075180751a0751707500000170750000011075
0128000005075000000707500000090750000002075000000b07500000090750000000075000000007500000050750000009075000000b075000000407500000000750000007075000000b075000000507500000
2b2800000c174001040e1740010410174001040c174001041117400104131740010413174001040e174001040c17400104131740010415174001041517400104171740010410174001040c174001041317400104
b11500000e575035051157500505155750050513575005050e5750050513575005051757500505135750050510575005051357500505155750050510575005050c57500505115750050515575005050c57500505
212a0000301153911532115371153b11534115391153711535115371153c115391153711534115391153411539105371053b10535105391053b10532105371053710537105341053b105341053b1053510534105
012a000028110241102811019100151001311019110141101c1002811023110281101c1001111017110121100a100071000b10010100121001010004100001000000000000021000410006100051000210000100
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
314600000c3550030513305003051035500305133550030515355113051330500305133550030510355003051135500305003050030515355003050c355003051335500305003050030500305003050030500305
254600000c3551f300103552330013355213002330024300113550030015355003001835500300003000030015355003000c3550030010355003000030000300133550030017352003001a352003000030000300
7e4600000535500305003050030500305003050030500305053550030500305003050030500305003050030505355003050030500305003050030500305003050535500305003050030500305003050030500305
312d0000181551a1501f1501d15010155211501315523150151551c1501a150211501315518150101552315011155181501c1501f15015155231500c1551a15013155211501c1501f1501a1501c1501a15000105
252d00000c1551515010155111501315515150101500c1500e1550e150151551515018155111501515010150151550e1500c155151501015511150151500e150131550e150171520e1501a152151500e15000100
7f2d000005155001050c1500010511150001050c1500010505155001050c1500010511150001050c1500010505155001050c1500010511150001050c1500010505155001050c1500010511150001050c15000105
31140000185621a5621f5621d56210562215621356223562155621c5621a562215621356218562105622356211562185621c5621f56215562235620c5621a56213562215621c5621f5621a5621c5621a56200502
251400000c5551555010555115501355515550105500c5500e5550e550155551555018555115501555010550155550e5500c555155501055511550155500e550135550e550175520e5501a552155500e55000500
7f14000005655006050c6500060511650006050c6500060505655006050c6500060511650006050c6500060505655006050c6500060511650006050c6500060505655006050c6500060511650006050c65000605
c114000005675075720c6700257211670075720c6700257205675075720c6700257211670075720c6700257205675075720c6700257211670075720c6700257205675075720c6700257211670075720c67000605
017800003605033050310502905026050210501e0501b0501805013050000000f0500d0500c0500b050000000a0500a0500a0500a0500c0500e0500f05011050120501305014050160501a050190501705016050
091200000e452104521145213452174021545217452184521a4521f4021a4521c4521d4521f45223402214522345224452234521f402214521f4521d4521c452184021a452184521745215452004020040200402
791200000023300233002330023300233002330023300233002330023300233002330023300233002330023300233002330023300233002330023300233002330023300233002330023300233002030020300203
091200000e1521d152111521d152231521c1521c1521d1521a1521a152231521c1521c1521a15226152231521a15224152231521a1521c152241521d15226152241521c152231521a15215152001020010200102
0112000018233000001f23300000232330000018233000001f23300000232330000018233000001f23300000232330000018233000001f23300000232330000018233000001f2330000023233000000000000000
0912000010152211521015218152211521f1521815223152181521d1521a1521c1521a1521c1521f1521d152211521a152231521d152211521f152181521a152231521a1521c152211521d152181021810200102
091200001315218152171520e152101521515213152151520e15218152101521a1521315215152181521d152181521a1521a1521715210152111521515213152181521a152171522115217152181020000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003f30000000
__music__
03 00014344
03 02030444
00 05064344
01 0708090a
02 08090b0c
03 0d0e4c45
01 0f505147
01 0f104944
02 0f101144
03 14151644
03 17181968
03 1a1b1c1d
00 1f206144
01 21202244
00 23202244
02 24202244

