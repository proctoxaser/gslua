local table_insert = table.insert
local table_remove = table.remove
local globals_realtime = globals.realtime
local globals_tickcount = globals.tickcount
local globals_tickinterval = globals.tickinterval
local globals_frametime = globals.frametime
local globals_absoluteframetime = globals.absoluteframetime
local entity_get_all = entity.get_all
local entity_get_prop = entity.get_prop
local entity_get_local_player = entity.get_local_player
local client_draw_rectangle = client.draw_rectangle
local client_draw_text = client.draw_text
local client_screen_size = client.screen_size
local client_latency = client.latency
local ui_get = ui.get
local ui_set_visible = ui.set_visible
local math_floor = math.floor
local math_sqrt = math.sqrt
local math_min = math.min
local math_abs = math.abs
local string_format = string.format

--local pingspike_reference = ui.reference("MISC", "Miscellaneous", "Ping spike")
local antiut_reference = ui.reference("MISC", "Settings", "Anti-untrusted")
local enabled_reference = ui.new_combobox("VISUALS", "Effects", "Watermark", "Off", "On", "Rainbow")
local velocity_reference = ui.new_checkbox("VISUALS", "Effects", "Show velocity")

local frametimes = {}
local fps_prev = 0
local last_update_time = 0

local offset_x, offset_y = -193, 15
--local offset_x, offset_y = 525, 915 --debug, show above net_graph
local alpha = 230

function draw_container(ctx, x, y, w, h)
    local c = {10, 60, 40, 40, 40, 60, 20}
    for i = 0,6,1 do
        client_draw_rectangle(ctx, x+i, y+i, w-(i*2), h-(i*2), c[i+1], c[i+1], c[i+1], 255)
    end
end

function on_watermark_changed()
	local value = ui_get(enabled_reference)
	ui_set_visible(velocity_reference, value ~= "Off")
end
on_watermark_changed()

function hsv_to_rgb(h, s, v, a)
  local r, g, b

  local i = math_floor(h * 6);
  local f = h * 6 - i;
  local p = v * (1 - s);
  local q = v * (1 - f * s);
  local t = v * (1 - (1 - f) * s);

  i = i % 6

  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  elseif i == 5 then r, g, b = v, p, q
  end

  return r * 255, g * 255, b * 255, a * 255
end

local function accumulate_fps()
    local rt, ft = globals_realtime(), globals_absoluteframetime()

    if ft > 0 then
        table_insert(frametimes, 1, ft)
    end

    local count = #frametimes
    if count == 0 then
        return 0
    end

    local accum = 0
    local i = 0
    while accum < 0.5 do
        i = i + 1
        accum = accum + frametimes[i]
        if i >= count then
            break
        end
    end
    
    accum = accum / i
    
    while i < count do
        i = i + 1
        table_remove(frametimes)
    end
    
    local fps = 1 / accum
    local time_since_update = rt - last_update_time
    if abs(fps - fps_prev) > 4 or time_since_update > 1 then
        fps_prev = fps
        last_update_time = rt
    else
        fps = fps_prev
    end
    
    return floor(fps + 0.5)
end

local function on_paint(ctx)
	local fps = accumulate_fps()

	local enabled = ui_get(enabled_reference)
	if enabled == "Off" then
		return
	end

	local screen_width, screen_height = client_screen_size()
	local x = offset_x >= 0 and offset_x or screen_width + offset_x
	local y = offset_y >= 0 and offset_y or screen_height + offset_y

	local velocity_enabled = ui_get(velocity_reference)

	--watermark
	local local_player = entity_get_local_player()
	local ping = math_min(999, client_latency() * 1000)
	
	fps = math_min(999, fps)

	local fps_text = string_format("%d", fps)
	local ping_text = string_format("%dms", ping)

	local offset_x_temp = -7
	local velocity = 0
	local velocity_text

	if velocity_enabled then
		local velocityX, velocityY = entity_get_prop(local_player, "m_vecVelocity")
		if velocityX then
			velocity = math_sqrt(velocityX*velocityX + velocityY*velocityY)
			velocity = math_min(9999, velocity) + 0.2
			velocity_text = string_format("%d", velocity)
			offset_x_temp = 43
		end
	end

	local r, g, b = 255, 255, 255
	if enabled == "Rainbow" then
		r, g, b = hsv_to_rgb(globals_tickcount() % 350 / 350, 1, 1, 255)
	end

	draw_container(ctx, x-offset_x_temp, y, 182+offset_x_temp, 30)
	client_draw_text(ctx, x+11-offset_x_temp, y+8, 255, 255, 255, alpha, nil, 0, "game")
	client_draw_text(ctx, x+38-offset_x_temp, y+8, 149, 184, 6, alpha, nil, 0, "sense")
	client_draw_text(ctx, x+68-offset_x_temp, y+8, 255, 255, 255, alpha, nil, 0, " | ")

	local fps_r, fps_g, fps_b = r, g, b
	if fps < (1 / globals_tickinterval()) then
		fps_r, fps_g, fps_b = 255, 0, 0
	end

	local fps_x = 81-offset_x_temp
	client_draw_text(ctx, x+fps_x+38, y+8, fps_r, fps_g, fps_b, alpha, "r", 0, fps_text, " fps")

	client_draw_text(ctx, x+fps_x+37, y+8, 255, 255, 255, alpha, nil, 0, " | ")

	local ping_r, ping_g, ping_b = r, g, b
	local max_ping = 200
	if not ui_get(antiut_reference) then
		max_ping = 100
	--elseif not ui_get(pingspike_reference) then
	--	max_ping = 200
	end

	if ping > max_ping then
		ping_r, ping_g, ping_b = 255, 0, 0
	end

	local ping_x = 126-offset_x_temp
	client_draw_text(ctx, x+ping_x+38, y+8, ping_r, ping_g, ping_b, alpha, "r", 0, ping_text)

	if velocity_enabled then
		local velocity_x = 139-offset_x_temp
		client_draw_text(ctx, x+ping_x+38, y+8, 255, 255, 255, alpha, nil, 0, " | ")
		client_draw_text(ctx, x+velocity_x+38+26, y+8, 255, 255, 255, alpha, "r", 0, velocity_text)
		client_draw_text(ctx, x+velocity_x+38+26, y+11, 255, 255, 255, alpha, "-", 0, "u / t")

	end
end

client.set_event_callback("paint", on_paint)
ui.set_callback(enabled_reference, on_watermark_changed)
