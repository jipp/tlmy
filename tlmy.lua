--[[
  tlmy.lua
  
  Date: 27.07.2016
  Author: wolfgang.keller@wobilix.de
  
  ToDo:
  
]]--

----------------------------------------------------------------------
-- Version String
local version = "v0.11.0" 

----------------------------------------------------------------------
-- dislay size for reciever
local displayWidth = 212 
local displayHeight = 64

----------------------------------------------------------------------
-- screen start number and table
local screenDisplay = 1
local screen = {}

----------------------------------------------------------------------
-- telemetry tables
-- the '-' and '+' at the end of some keys force to fill the table this way
local telemetry = {} -- telemetry and unit
  telemetry["VFAS"] = "V"
  telemetry["Alt"] = "m"
  telemetry["Alt-"] = "m"
  telemetry["Alt+"] = "m"
  telemetry["VSpd"] = "m/s"
  telemetry["VSpd-"] = "m/s"
  telemetry["VSpd+"] = "m/s"
  telemetry["RSSI"] = "dB"
  telemetry["Hdg"] = ""
  telemetry["timer1"] = ""
  telemetry["ch5"] = "mode"
  telemetry["ch6"] = "baro"
  telemetry["ch7"] = "air"
  telemetry["ch8"] = "beeper"
  telemetry["ch11"] = "gtune"
  telemetry["ch13"] = "arm"

----------------------------------------------------------------------
-- battery limits, can be changed on personal needs
local battery = {
  cels = 3, -- adjustable via +/- in all screens
  min = 3.2,  -- minimal alllowed, used for diagram
	critical = 3.3,  -- alarm for critical
	low = 3.5, -- alarm for low
	max = 4.3, -- maximal possible, used for diagram
	delta = {
	  low = 10, -- seconds 
	  critical = 5 -- seconds
	},
	flag = {},
	time = {}
}
	
----------------------------------------------------------------------
-- rssi limits, critical and ow vale are copied from radio
local rssi = {
  min = 40,
  critical = 42,
  low = 45,
  max = 105
}

----------------------------------------------------------------------
-- heading offset
local headingOffset = 0  

----------------------------------------------------------------------
-- mathematical utility function
local function round(value, decimal)
  local exponent = 10^(decimal or 0)
  return math.floor(value * exponent + 0.5) / exponent
end

----------------------------------------------------------------------
-- display value with name and unit
local function displayValue(x, y, key, font, offset)
  if telemetry[key].id ~= nil then
    if offset == nil then
      offset = 0
    end      
    lcd.drawText(x, y, telemetry[key].name .. ": " .. round(telemetry[key].data - offset, 2) .. telemetry[key].unit, font)
  end
end

-- display channel value as name  
local function displayKey(x, y, key, value, font)
  if telemetry[key].id ~= nil then
    if telemetry[key].data == value then
      lcd.drawText(x, y, telemetry[key].unit, font)
    end
  end
end

-- display gauge from min to max value, catch if value is lower than min 
local function displayGauge(x, y, w, h, fill, maxfill, min)
  if fill >= min then
    lcd.drawGauge(x, y, w, h, (fill - min) , (maxfill - min))
  else
    lcd.drawRectangle(x, y, w, h)
  end
end

-- display timer with name
local function displayTimer(x, y, key, font)
  if telemetry[key].id ~= nil then
    lcd.drawText(x, y, telemetry[key].name .. ": ", font)
    lcd.drawTimer(lcd.getLastPos(), y, telemetry[key].data, font)
    return 1
  else
    return -1
  end
end

-- overall screen display, will call separate screen
local function displayScreen(screenDisplay) 
  local flightMode = ( { getFlightMode() } )[2]
  local modelName = model.getInfo().name
      
  lcd.drawScreenTitle(modelName .. "  (" .. battery.cels .. "S)  " .. flightMode .. " - " .. version, screenDisplay, #screen)
  screen[screenDisplay]()
end

-- define different screens, to add screens increment number, do NOT leave a number out
screen[1] = function() 
  displayValue(1, 9, "VFAS", MIDSIZE)
  displayGauge(107, 9, 100, 12, telemetry["VFAS"].data/battery.cels * 100, battery["max"] * 100, battery["min"] * 100)
  displayValue(1, 25, "RSSI", MIDSIZE)
  displayGauge(107, 25, 100, 12, telemetry["RSSI"].data, rssi["max"], rssi["min"])
  displayValue(107, 41, "Hdg", MIDSIZE, headingOffset)
  displayKey(1, 41, "ch13", 1024, MIDSIZE+INVERS+BLINK)
  displayKey(1, 56, "ch6", 0, SMLSIZE)
  displayKey(1+displayWidth/4, 56, "ch7", 0, SMLSIZE)
  displayKey(1+displayWidth/2, 56, "ch8", 0 , SMLSIZE)
  displayKey(1+displayWidth*3/4, 56, "ch11", 0, SMLSIZE)
end

screen[2] = function() 
  displayValue(1, 9,  "Alt", MIDSIZE)
  displayValue(107, 9,  "Alt+", SMLSIZE)
  displayValue(107, 17,  "Alt-", SMLSIZE)
  displayValue(1, 25, "VSpd", MIDSIZE)
  displayValue(107, 25, "VSpd+", SMLSIZE)
  displayValue(107, 33, "VSpd-", SMLSIZE)
  displayTimer(107, 41, "timer1", MIDSIZE)
  displayKey(1, 41, "ch13", 1024, MIDSIZE+INVERS+BLINK)
  displayKey(1, 56, "ch6", 0, SMLSIZE)
  displayKey(1+displayWidth/4, 56, "ch7", 0, SMLSIZE)
  displayKey(1+displayWidth/2, 56, "ch8", 0 , SMLSIZE)
  displayKey(1+displayWidth*3/4, 56, "ch11", 0, SMLSIZE)
end

-- sound funtions, to be played as well in the background
local function checkBattery(key, value, file)
	local cellVoltage

  if telemetry[key].id ~= nil then
    cellVoltage = telemetry[key].data / battery.cels
	  if cellVoltage <= battery[value] then
		  if battery.flag[value] ~= true then
		    if battery.time[value] == nil then
		      battery.time[value] = 0
		    end
		    if battery.delta[value] == nil then
		      battery.delta[value] = 0
		    end
	   	  if getTime() - battery.time[value] > battery.delta[value] * 100 then
          battery.flag[value] = true
			    playFile(file)
			  end
		  end
	  elseif cellVoltage > battery[value] then
  		battery.flag[value] = false
  	  battery.time[value] = getTime()
	  end
  end
end

local function playSound(key, value, file)
  if telemetry[key].id ~= nil then
    if telemetry[key].data == value then
      if telemetry[key].sound ~= value then
        telemetry[key].sound = value
        playFile(file)
      end
    end
  end
end

-- offset calculation
local function getOffset(key)
  if telemetry[key].id ~= nil then
    return telemetry[key].data
  else
    return 0
  end
end

local function initTable()
  for key, value in pairs(telemetry) do
    telemetry[key] = getFieldInfo(key)
    telemetry[key].unit = value
    telemetry[key].data = ""
  end 
end

-- skeleton funtions
local function init_func()
  -- init_func is called once when model is loaded  
  initTable() 
end

local function bg_func()
  -- bg_func is called periodically when screen is not visible
  for key, value in pairs(telemetry) do
    telemetry[key].data = getValue(telemetry[key].id)
  end
  
  playSound("ch5", 1024, "acromd.wav")
  playSound("ch5", 0, "hrznmd.wav")
  playSound("ch5", -1024, "anglmd.wav")
  
  playSound("ch6", 1024, "brmtrof.wav")  
  playSound("ch6", 0, "brmtr.wav")
  playSound("ch6", -1024, "brmtrof.wav")  

  playSound("ch7", 1024, "")
  playSound("ch7", 0, "bombawy.wav")
  playSound("ch7", -1024, "")

  playSound("ch11", 1024, "")
  playSound("ch11", 0, "automd.wav")
  playSound("ch11", -1024, "")

  playSound("ch13", 1024, "thract.wav")
  playSound("ch13", -1024, "thrdis.wav")

  checkBattery("VFAS", "low", "batlow.wav")
  checkBattery("VFAS", "critical", "batcrit.wav")
end

local function run_func(event)
  -- run_func is called periodically when screen is visible
  bg_func() -- run typically calls bg_func to start
    
  lcd.clear()
    
  if event == EVT_ENTER_BREAK then  
    headingOffset = getOffset("Hdg")
  end  
  
  if event == EVT_EXIT_BREAK then  
    headingOffset = 0
  end  

  if event == EVT_PLUS_BREAK then
    battery.cels = battery.cels + 1
  end
  
  if event == EVT_MINUS_BREAK then
    battery.cels = battery.cels - 1
    if battery.cels < 1 then
      battery.cels = 1
    end
  end
  
  if event == EVT_PAGE_BREAK then
    screenDisplay = screenDisplay + 1
    if screenDisplay > #screen then
      screenDisplay = 1
    end
  end
  
  if event == EVT_PAGE_LONG then
    screenDisplay = screenDisplay - 1
    if screenDisplay < 1 then
      screenDisplay = #screen
    end
  end
    
  displayScreen(screenDisplay)
end

return { run=run_func, background=bg_func, init=init_func  }