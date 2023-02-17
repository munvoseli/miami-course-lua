local M = {}

local lunajson = require("lunajson")
local http_req = require("http.request")

-- no longer used
local function guidToSectionJson(guid)
	local u = "https://ws.apps.miamioh.edu/"
	.. "api/courseSection/v3/courseSection/"
	.. guid .. "?compose="
	.. "%2Cschedules"
	.. "%2Cinstructors"
	.. "%2Cattributes"
	local h, s = assert(
		http_req
		.new_from_uri(u)
		:go()
	)
	local st = s:get_body_as_string()
	return lunajson.decode(st).data
end



local function timeofdayToMinutes(tod) -- 24-hour time
	if tod == nil then
		return nil
	end
	local hours = string.sub(tod, 1, 2)
	local mins = string.sub(tod, 4, 5)
	local total = tonumber(hours) * 60 + tonumber(mins)
	return total
end
local function splitSectionTimes(times)
	local res = {}
	local tmin, tmax
	for i,t in pairs(times) do
		if t.scheduleTypeCode == "CLAS" then
			local t0 = timeofdayToMinutes(t.startTime)
			local t2 = timeofdayToMinutes(t.endTime)
			if tmin == nil or t0 < tmin then
				tmin = t0
			end
			if tmax == nil or t2 > tmax then
				tmax = t2
			end
			if t.days ~= nil then
			for j=1,#t.days do
				table.insert(res, {
					t0 = t0,
					t2 = t2,
					day = string.sub(
						t.days,
						j, j),
					building = t.buildingCode,
					roomnum = t.roomNumber
				})
			end
			end
		end
	end
	return res, tmin, tmax
end

local function sectionDataToSection(j)
	local sessions, tmin, tmax = splitSectionTimes(j.schedules)
	local res = {
		guid = j.courseSectionGuid,
		subcode = j.course.subjectCode,
		cnum = j.course.number,
		section = j.courseSectionCode,
		sessions = sessions,
		tmin = tmin,
		tmax = tmax,
		attribs = j.attributes
	}
	if #j.instructors > 0 then
		res.instructor = j.instructors[1].person.formalDisplayedName
	end
	return res
end

M.infoToSections = function(subj, num, term)
	local u = "https://ws.apps.miamioh.edu/"
	.. "api/courseSection/v3/courseSection"
	.. "?campusCode=O"
	.. "&termCode=" .. term
	.. "&course_subjectCode=" .. subj
	.. "&course_number=" .. num
	.. "&compose=instructors%2Cschedules%2Cattributes"
	local h, s = assert(
		http_req
		.new_from_uri(u)
		:go()
	)
	local st = s:get_body_as_string()
--	print(st)
	local res = {}
	local j = lunajson.decode(st).data
	for i,sectionData in pairs(j) do
		local sec = sectionDataToSection(sectionData)
		if sectionData.courseSectionStatusDescription ~= "Inactive" then
			table.insert(res, sec)
		end
	end
	return res
end


return M
