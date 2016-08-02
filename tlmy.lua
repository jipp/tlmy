--[[
  tlmy.lua
  
  Date: 27.07.2016
  Author: wolfgang.keller@wobilix.de
  
  ToDo:
   -battery alarm after timeout
   
  
]]--

----------------------------------------------------------------------
-- Version String
local version = "v0.10.2" 

----------------------------------------------------------------------
-- dislay size for reciever
local displayWidth = 212 
local displayHeight = 64

----------------------------------------------------------------------
-- screen start number and table
local screenNum = 1
local screen = {}

----------------------------------------------------------------------
-- telemetry tables
-- the '-' and '+' at the end of some keys force to fill the table this way
local telemetry = {}
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
  telemetry["flightModeName"] = ""
  telemetry["modelInfo"] = ""

----------------------------------------------------------------------
-- telemetry tables
local telemetryId = {}
local telemetryName = {}
local telemetryDesc = {}
local telemetryUnit = {}
local telemetryData = {}
local telemetrySound = {}

----------------------------------------------------------------------
-- battery limits, can be changed on personal needs
local cellNum = 3 -- adjustable via +/- in all screens
local batterySound = {}
local battery = { 
  min = 3.2,
	critical = 3.3,
	low = 3.5,
	max = 4.3
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
-- helper funtion
local function getTelemetryId(key)
   fieldInfo = getFieldInfo(key)
   if fieldInfo then
    return fieldInfo["id"]
  end
  return -1
end

local function getTelemetryName(key)
  fieldInfo = getFieldInfo(key)
   if fieldInfo then
    return fieldInfo["name"]
  end
  return -1
end

local function getTelemetryDesc(key)
  fieldInfo = getFieldInfo(key)
   if fieldInfo then
    return fieldInfo["desc"]
  end
  return -1
end

----------------------------------------------------------------------
-- mathematical utility function
local function round(value, decimal)
  local exponent = 10^(decimal or 0)
  return math.floor(value * exponent + 0.5) / exponent
end

----------------------------------------------------------------------
-- display value with name and unit
local function displayValue(x, y, key, font, offset)
  if telemetryId[key] ~= -1 then
    if offset == nil then
      offset = 0
    end      
    lcd.drawText(x, y, telemetryName[key] .. ": " .. round(telemetryData[key] - offset, 2) .. telemetryUnit[key], font)
    return 1
  else 
    return -1
  end
end

-- display channel value as name  
local function displayKey(x, y, key, value, font)
  if telemetryId[key] ~= -1 then
    if telemetryData[key] == value then
      lcd.drawText(x, y, telemetryUnit[key], font)
    end
    return 1
  else
    return -1
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
  if telemetryId[key] ~= -1 then
    lcd.drawText(x, y, telemetryName[key] .. ": ", font)
    lcd.drawTimer(lcd.getLastPos(), y, telemetryData[key], font)
    return 1
  else
    return -1
  end
end

-- overall screen display, will call separate screen
local function displayScreen(screenNum)  
  lcd.drawScreenTitle(telemetryData["modelInfo"] .. "  (" .. cellNum .. "S)  " .. telemetryName["flightModeName"] .. telemetryData["flightModeName"] .. " - " .. version, screenNum, #screen)
  screen[screenNum]()
end

-- define different screens, to add screens increment number, do NOT leave a number out
screen[1] = function() 
  displayValue(1, 9, "VFAS", MIDSIZE)
  displayGauge(107, 9, 100, 12, telemetryData["VFAS"]/cellNum * 100, battery["max"] * 100, battery["min"] * 100)
  displayValue(1, 25, "RSSI", MIDSIZE)
  displayGauge(107, 25, 100, 12, telemetryData["RSSI"], rssi["max"], rssi["min"])
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
end

-- sound funtions, to be played as well in the background
local function playBatterySound(key, value, file)
	local cellVoltage

  if telemetryId[key] ~= -1 then
    cellVoltage = telemetryData[key] / cellNum
	  if cellVoltage <= battery[value] then
		  if batterySound[value] ~= battery[value] then
			  playFile(file)
			  batterySound[value] = battery[value]
		  end
	  elseif cellVoltage > battery[value] then
  		batterySound[value] = ""
	  end
    return 1
	else 
	  return -1
  end
end

local function playSound(key, value, file)
  if telemetryId[key] ~= -1 then
    if telemetryData[key] == value then
      if telemetrySound[key] ~= value then
        playFile(file)
        telemetrySound[key] = value
      end
    end
    return 1
  else
    return -1
  end
end

-- offset calculation
local function getOffset(key)
  if telemetryId[key] ~= -1 then
    return telemetryData[key]
  end
  return 0
end

local function initTable()
  for key, value in pairs(telemetry) do
    if key == "flightModeName" then
      telemetryId[key] = "flightModeName"
      telemetryName[key] = ""
      telemetryDesc[key] = ""
      telemetryUnit[key] = value
      telemetryData[key] = ( { getFlightMode() } )[2]
    elseif key == "modelInfo" then
      telemetryId[key] = "modelInfo"
      telemetryName[key] = ""
      telemetryDesc[key] = ""
      telemetryUnit[key] = value
      telemetryData[key] = model.getInfo().name
    else      
      telemetryId[key] = getTelemetryId(key)
      telemetryName[key] = getTelemetryName(key)
      telemetryDesc[key] = getTelemetryDesc(key)
      telemetryUnit[key] = value
      telemetryData[key] = getValue(telemetryId[key])
    end
  end 
end

-- skeleton funtions
local function init_func()
  -- init_func is called once when model is loaded  
  initTable() 
end

local function bg_func()
  -- bg_func is called periodically when screen is not visible
  for key, value in pairs(telemetryName) do
    if key == "flightModeName" then
      telemetryData[key] = ( { getFlightMode() } )[2]
    elseif key == "modelInfo" then
      telemetryData[key] = model.getInfo().name
    else
      telemetryData[key] = getValue(telemetryId[key])
    end
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

  playBatterySound("VFAS", "low", "batlow.wav")
  playBatterySound("VFAS", "critical", "batcrit.wav")
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
    cellNum = cellNum + 1
  end
  
  if event == EVT_MINUS_BREAK then
    cellNum = cellNum - 1
    if cellNum < 1 then
      cellNum = 1
    end
  end
  
  if event == EVT_PAGE_BREAK then
    screenNum = screenNum + 1
    if screenNum > #screen then
      screenNum = 1
    end
  end
  
  if event == EVT_PAGE_LONG then
    screenNum = screenNum - 1
    if screenNum < 1 then
      screenNum = #screen
    end
  end
    
  displayScreen(screenNum)
end

return { run=run_func, background=bg_func, init=init_func  }