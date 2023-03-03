local lunajson = require("lunajson")
local http_req = require("http.request")
local miami_api = require("miami-api")

--[[
instructor name
list of sessions
	weekday
	start time
	end time
	room number
	building
subject (department?) code
course number
section code
guid
--]]

--[[
local http_client = require("http.client")

local conn = http_client.connect({
	host = "ws.miamioh.edu",
	port = 80,
	tls = true
})

local s = conn:new_stream()
--]]

--[[
https://ws.apps.miamioh.edu/api/courseSection/v3/courseSection/
0a2e8a23-f934-457b-b1a8-bec9b79c4e08
?compose=enrollmentCount
%2Cschedules
%2Cinstructors
%2Cattributes
%2CcrossListedCourseSections
%2CenrollmentDistribution
--]]

--[[
local u = "https://ws.apps.miamioh.edu/api/courseSection/v3/courseSection"
local u2 =
"?campusCode=O" ..
"&termCode=202310" ..
"&course_subjectCode=CSE" ..
"&course_number=201" ..
""
local h, s = assert(
	http_req
--	.new_from_uri("https://ws.miamioh.edu/api/building/v1")
	.new_from_uri(u .. u2)
	:go()
)
print(s:get_body_as_string())
--]]

--local u = "https://ws.apps.miamioh.edu/api/courseSection/v3/courseSection/0a2e8a23-f934-457b-b1a8-bec9b79c4e08?compose=enrollmentCount%2Cschedules%2Cinstructors%2Cattributes%2CcrossListedCourseSections%2CenrollmentDistribution"


local function cacheList(db)
end

--local function guidToSection(guid)
--	local j = guidToSectionJson(guid)
--	return sectionDataToSection(j)
--end
--print(lunajson.encode(
--guidToSection("0a2e8a23-f934-457b-b1a8-bec9b79c4e08")
--))

--[[
what customer wants from the product
--]]

local wants = {
	{
		ct = 2,
		possible = {
			{ "CSE", "262" },
			{ "CSE", "374" },
			{ "CSE", "381" },
			{ "CSE", "383" },
		}
	},
	{
		ct = 2,
		possible = {
			{ "MTH", "441" },
			{ "MTH", "411" },
			{ "MTH", "438" },
			{ "MTH", "483" },
			{ "MTH", "486" },
			{ "MTH", "491" },
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

local function wantsToList(wants)
	local list = {}
	for k,v in pairs(wants) do
		for k2,c in pairs(v.possible) do
			table.insert(list, c)
		end
	end
	return list
end

local function sessionListsConflict(l1, l2)
	local sessionsConflict = function(a, b)
		if a.day ~= b.day then
			return false
		end
		return not((a.t0 > b.t2) or (b.t0 > a.t2))
	end
	for i,sess1 in pairs(l1) do
	for j,sess2 in pairs(l2) do
		if sessionsConflict(sess1, sess2) then
			return true
		end
	end
	end
	return false
end
local function sectionsConflict(s1, s2)
	return sessionListsConflict(s1.sessions, s2.sessions)
end


local function loadListInternet(list, term)
	local db = {}
	for i,c in pairs(list) do
		print("Getting " .. c[1] .. " " .. c[2])
		local secs = miami_api.infoToSections(c[1], c[2], term)
		local h = {
			subcode = c[1],
			cnum = c[2],
			sections = secs
		}
		local k = c[1] .. " " .. c[2]
		db[k] = h
	end
	local f = io.open("cache" .. term .. ".json", "w")
	f:write(lunajson.encode(db))
	f:close()
	return db
end
local function loadListLocal(list, term)
	local f = io.open("cache" .. term .. ".json", "r")
	local r = f:read()
	f:close()
	return lunajson.decode(r)
end
local function loadListHybrid(list, term)
	local db = loadListLocal(list, term)
	for i,c in pairs(list) do
		local k = c[1] .. " " .. c[2]
		if db[k] ~= nil then
			print(k .. " cached")
		else
			print("Getting " .. k)
			local secs = miami_api.infoToSections(c[1], c[2], term)
			db[k] = {
				subcode = c[1],
				cnum = c[2],
				sections = secs
			}
		end
	end
	local f = io.open("cache" .. term .. ".json", "w")
	f:write(lunajson.encode(db))
	f:close()
	return db
end
local db = loadListHybrid(wantsToList(wants), "202310")


local function printSection(sec)
	print(sec.subcode, sec.cnum, sec.section, sec.tmin)
	for i,sess in pairs(sec.sessions) do
		print("", "", sess.day, sess.t0, sess.t2, sess.building)
	end
end
local function printSchedule(sections)
	local sum = 0
	for i,sec in pairs(sections) do
		sum = sum + sec.hours
	end
	print("Credit hours: " .. sum)
	for i,sec in pairs(sections) do
		printSection(sec)
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
		print(dn[i])
		for j,sess in pairs(days[dl[i]]) do
			print("", sess.t0, sess.t2, sess.building)
		end
	end
end

local function getSched(
	wants, lc, sections,
	wanti, ci, workingSchedules
)
	if wants[wanti].ct == ci then
		ci = 0
		lc = 0
		wanti = wanti + 1
		if wanti > #wants then
--			print("Schedule:")
--			printSchedule(sections)
			local clone = {}
			for i = 1,#sections do
				table.insert(clone, sections[i])
			end
			table.insert(workingSchedules, clone)
			return
		end
	end

	local coursestart = lc + 1
	local courseend = #wants[wanti].possible

	local dosec = function(i, section)
		if section.tmin ~= nil and section.tmin < 605 then
			return
		end
		if section.tmax ~= nil and section.tmax > 17 * 60 then
			return
		end
		local conflict = false
		for j2,s2 in pairs(sections) do
			if sectionsConflict(section, s2) then
				conflict = true
				break
			end
		end
		if conflict then
			return
		end
		table.insert(sections, section)
		getSched(
			wants, i, sections,
			wanti, ci + 1, workingSchedules)
		table.remove(sections)
	end

	for i=coursestart, courseend do
		local subj = wants[wanti].possible[i][1]
		local num  = wants[wanti].possible[i][2]
		local sectionsb = db[subj .. " " .. num].sections
		local duplicate = false
		for j2,s2 in pairs(sections) do
			if s2.subcode == subj and s2.cnum == num then
				duplicate = true
			end
		end
		if duplicate then
			getSched(
				wants, i, sections,
				wanti, ci + 1, workingSchedules)
		else
			for j,section in pairs(sectionsb) do
				dosec(i, section)
			end
		end
	end
end

local function getSchedule(wants)
	local ws = {}
	getSched(wants, 0, {}, 1, 0, ws)
	print(#ws .. " schedules found")
	for i,sections in pairs(ws) do
		printSchedule(sections)
	end
end

getSchedule(wants)
