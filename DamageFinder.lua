local f = CreateFrame("Frame", "DamageFinderFrame", UIParent)
f:SetSize(200, 100)
f:SetPoint("CENTER")

f:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeSize = 1,
})
f:SetBackdropColor(0, 0, 0, .5)
f:SetBackdropBorderColor(0, 0, 0)

f:EnableMouse(true)
f:SetMovable(true)
f:SetUserPlaced(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetScript("OnHide", f.StopMovingOrSizing)

local closeButton = CreateFrame("Button", "CloseButton", f, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT")
closeButton:SetScript("OnClick", function()
	f:Hide()
end)

f:SetResizable(true)
f:SetScript("OnMouseDown", function(self, button)
	if button == "RightButton" then
		f:StartSizing("BOTTOMRIGHT")
	end
end)
f:SetScript("OnMouseUp", function()
	f:StopMovingOrSizing()
end)


f.text = f:CreateFontString(nil,"ARTWORK", f) 
f.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
f.text:SetAllPoints(f)
f.text:SetText("")





Queue = {}
function Queue.new()
    return {first = 0, last = -1}
end

function Queue.push(q, v)
      local last = q.last + 1
      q.last = last
      q[last] = v
end
    
function Queue.pop(q)
    local first = q.first
    if first > q.last then
		return nil
	end
    local v = q[first]
    q[first] = nil
    q.first = first + 1
    return v
end

function Queue.peek(q)
    local first = q.first
    if first > q.last then
		return nil
	end
    local v = q[first]
    return v
end

function pack(...)
    return {n = select("#", ...), ...}
end

function getKeysSortedByValue(t)
  local keys = {}
  for key in pairs(t) do
    table.insert(keys, key)
  end

  table.sort(keys, function(a, b)
    return t[a] > t[b]
  end)
  return keys
end

local damageQueue = Queue.new()
local damageTable = {}
local totalDamage = 0
setmetatable(damageTable, {__index = function () return 0 end})












f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", function(self, event_name, ...)
    return self[event_name](self, event_name, ...)
end)
function f:COMBAT_LOG_EVENT_UNFILTERED(event,...)
	if not f:IsShown() then
		return
	end
    local event = {CombatLogGetCurrentEventInfo()}
    local timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags,
        srcFlags2, dstGUID, dstName, dstFlags, dstFlags2 = unpack(event)

    local prefix, suffix = eventType:match("^(.-)_?([^_]*)$");
	affiliation = bit.band(dstFlags, COMBATLOG_OBJECT_AFFILIATION_MASK)
	in_raid = bit.band(affiliation, bit.bnot(COMBATLOG_OBJECT_AFFILIATION_OUTSIDER))
	if (in_raid > 0) then
		if eventType:match("DAMAGE") then
			if prefix == "SWING" then
				source = "Basic attack"
				amount = select(12, unpack(event))
			elseif prefix:match("SPELL") then
				spellId, source = select(12, unpack(event))
				amount = select(15, unpack(event))
			else
				return
			end
			Queue.push(damageQueue, pack(timestamp, source, amount))
			damageTable[source] = damageTable[source] + amount
			totalDamage = totalDamage + amount
		end
	end
end


DamageFinder_UpdateInterval = 1.0;

local timeSinceLastUpdate = 0
function f:onUpdate(elapsed)
  timeSinceLastUpdate = timeSinceLastUpdate + elapsed; 	

  if (timeSinceLastUpdate > DamageFinder_UpdateInterval) then
  
	while true do
		firstDamage = Queue.peek(damageQueue)
		if not firstDamage then
			break
		end
		timestamp, source, amount = unpack(firstDamage)
		if timestamp + 10 <= time() then
			Queue.pop(damageQueue)
			damageTable[source] = damageTable[source] - amount
			totalDamage = totalDamage - amount
			if damageTable[source] == 0 then
				damageTable[source] = nil
			end
		else
			break
		end
	end

	txt = ""
	for _, src in ipairs(getKeysSortedByValue(damageTable)) do
		dmg = damageTable[src]
		txt = txt .. src .. ": " .. math.floor(100 * dmg / totalDamage) .. "%\n"
	end
	f.text:SetText(txt)

    timeSinceLastUpdate = 0;
  end
end
f:SetScript("OnUpdate", f.onUpdate)