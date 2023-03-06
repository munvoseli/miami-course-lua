local want_resolution = require("want-resolution")

local wants = {
	{
		ct = 4,
		possible = {
			{ "CSE", "262" },
			{ "CSE", "374" },
			{ "CSE", "381" },
			{ "CSE", "383" },
			{ "CSE", "385" },
			{ "CSE", "474" },
			{ "ENG", "313" },
			-- CSE 480 / 491?
			{ "MTH", "425" },
			{ "MTH", "441" },
			{ "MTH", "411" },
			{ "MTH", "438" },
			{ "MTH", "483" },
			{ "MTH", "486" },
			{ "MTH", "491" },
--			{ "STC", "135" },
		}
	},
	{
		ct = 1,
		possible = {
			{ "BIO", "115H" },
			{ "RUS", "101H" },
		}
	},
}

--want_resolution.loadDb(wants)
local schedules = want_resolution.wantsToSchedule(wants)


local function drawSchedule(sections, xo, yo, colwidth, height)
	-- 8:00 to 21:00/9:00pm
	local day_start = 60 * 8
	local mins_in_day = 60 * 13
	love.graphics.setColor(0,1/3,2/3)
	love.graphics.rectangle("fill", xo, yo, 5*colwidth, height)
	local map = {}
	map["M"] = 0
	map["T"] = 1
	map["W"] = 2
	map["R"] = 3
	map["F"] = 4
	for k,sec in pairs(sections) do
		for j,sess in pairs(sec.sessions) do
			local col = map[sess.day]
			local x = col * colwidth
			local y0 = (sess.t0 - day_start)
				/ mins_in_day * height
			local y2 = (sess.t2 - day_start)
				/ mins_in_day * height
			love.graphics.setColor(0,0,0)
			love.graphics.rectangle(
				"fill",
				x + xo, y0 + yo,
				colwidth, y2 - y0
			)
			love.graphics.setColor(255,255,255)
			love.graphics.print(sess.building,
				x + xo, y0 + yo)
		end
	end
end

local scrolly = 0
local seltile = nil
local margin = 20
local tilew = 140
local tileh = 150
local colwidth = tilew / 5
local hspace = margin + tilew
local vspace = margin + tileh
local perrow = 10

local function drawScheduleDetailed(sections)
	local x0 = perrow * hspace
	local x1 = x0 + 20
	local x2 = x1 + 80
	local x3 = x2 + 80
	local y = 0
	local lh = 20
	local sum = 0
	love.graphics.setColor(0,0,0)

	for i,sec in pairs(sections) do
		sum = sum + sec.hours
	end
	love.graphics.print("Credit hours: " .. sum, x0, y)
	y = y + lh
	for i,sec in pairs(sections) do
		love.graphics.print(sec.subcode .. " " .. sec.cnum, x1, y)
		y = y + lh
	end
	local days = {}
	days['M'] = {}
	days['T'] = {}
	days['W'] = {}
	days['R'] = {}
	days['F'] = {}
	local insert = function(arr, sess)
		local i = 1
		while i <= #arr and arr[i].t0 < sess.t0 do
			i = i + 1
		end
		table.insert(arr, i, sess)
	end
	for i,sec in pairs(sections) do
		for j,sess in pairs(sec.sessions) do
			insert(days[sess.day], sess)
		end
	end
	for i=1,5 do
		local dl = { 'M', 'T', 'W', 'R', 'F' }
		local dn = { 'Monday', 'Tuesday',
			'Wednesday', 'Thursday', 'Friday' }
		love.graphics.print(dn[i], x0, y)
		y = y + lh
		for j,sess in pairs(days[dl[i]]) do
			love.graphics.print(sess.t0, x1, y)
			love.graphics.print(sess.t2, x2, y)
			love.graphics.print(sess.building, x3, y)
			y = y + lh
		end
	end
end
local function modulo(a, b)
	return a - b * math.floor(a/b)
end

function love.wheelmoved(x, y)
	scrolly = -10 * y + scrolly
end
function love.mousepressed(x, y, button, istouch, presses)
	if modulo(x, hspace) > tilew then return end
	if modulo(y, vspace) > tileh then return end
	local col = math.floor(x / hspace)
	local row = math.floor((y + scrolly) / vspace)
	local i = row * perrow + col + 1
	seltile = i
end

function love.load()
	love.window.setFullscreen(true)
end
function love.draw()
	local margin = 20
	local tilew = 140
	local tileh = 150
	local colwidth = tilew / 5
	local hspace = margin + tilew
	local vspace = margin + tileh
	local perrow = 10
	love.graphics.clear(255,255,255)
	local ww, wh = love.graphics.getDimensions()
	for i=1,math.min(300,#schedules) do
		local x = ((i-1) % perrow) * hspace
		local y = math.floor((i-1) / perrow) * vspace - scrolly
		if -vspace < y and y < wh then
			drawSchedule(schedules[i], x, y, colwidth, tileh)
		end
	end
	if seltile ~= nil then
		local sched = schedules[seltile]
		drawScheduleDetailed(sched)
	end
end
