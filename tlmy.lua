--[[
  tlmy.lua
  
  Date: 27.07.2016
  Author: wolfgang.keller@wobilix.de
  HW: frsky taranis plus X9d
  SW: open-tx 2.1.8
  
  ToDo:
    - hight warning
  
]]--

----------------------------------------------------------------------
-- Version String
local version = "v0.12.0" 

----------------------------------------------------------------------
-- telemetry table
-- can be adjusted according to own display need
local tlmy = {}
 
function tlmy:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function tlmy:Init()
  for key, value in pairs(self) do
    self[key] = getFieldInfo(key)
    if self[key] ~= nil then  
      self[key].unit = value
      self[key].data = ""
    end
  end 
end

function tlmy:Refresh()
  for key, value in pairs(self) do
    if self[key] ~= nil then
      self[key].data = getValue(self[key].id)
    end
  end
end

local telemetry = tlmy:New{}  -- 'telemetry shortcut' = 'unit'
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
-- battery limits and functions
-- low and critical are lipo limits
-- delta.low and delta.critical are timers to wait before alarming
local battery = {}
  battery["cels"] = 3               -- can be adjusted
  battery["min"] = 3.2
  battery["critical"] = 3.3
  battery["low"] = 3.5
  battery["max"] = 4.3
  battery["flag"] = {}
  battery["time"] = {}
  battery["delta"] = {}
  battery["delta"]["low"] = 10      -- can be adjusted
  battery["delta"]["critical"] = 5  -- can be adjusted
  
function battery:Increment()
  self.cels = self.cels + 1
end

function battery:Decrement()
  self.cels = self.cels - 1
  if self.cels < 1 then
    self.cels = 1
  end
end
  
function battery:Check(key, value, file)
  local cellVoltage

  if telemetry[key] ~= nil then
    cellVoltage = telemetry[key].data / self["cels"]
    if cellVoltage <= self[value] then
      if self.flag[value] ~= true then
        if self.time[value] == nil then
          self.time[value] = 0
        end
        if self.delta[value] == nil then
          self.delta[value] = 0
        end
        if getTime() - self.time[value] > self.delta[value] * 100 then
          self.flag[value] = true
          playFile(file)
        end
      end
    elseif cellVoltage > self[value] then
      self.flag[value] = false
      self.time[value] = getTime()
    end
  end
end
  
----------------------------------------------------------------------
-- rssi limits, critical and low value are copied from radio
local rssi = {}
  rssi["min"] = 40
  rssi["critical"] = 42
  rssi["low"] = 45
  rssi["max"] = 100
  
----------------------------------------------------------------------
-- mathematical utility function
local function round(value, decimal)
  local exponent = 10^(decimal or 0)
  return math.floor(value * exponent + 0.5) / exponent
end  

----------------------------------------------------------------------
-- dislay size for reciever display
local display = {}
  display["width"] = 212
  display["height"] = 64 
  
function display:Value(x, y, key, font, offset)
  if telemetry[key] ~= nil then
    if offset == nil then
      offset = 0
    end      
    lcd.drawText(x, y, telemetry[key].name .. ": " .. round(telemetry[key].data - offset, 2) .. telemetry[key].unit, font)
  end
end

function display:Key(x, y, key, value, font)
  if telemetry[key] ~= nil then
    if telemetry[key].data == value then
      lcd.drawText(x, y, telemetry[key].unit, font)
    end
  end
end

function display:Gauge(x, y, w, h, key, border, norm, factor)
  if telemetry[key] ~= nil then
    if norm == nil then
      norm = 1
    end
    if factor == nil then
      factor = 1
    end
    if telemetry[key].data / norm >= border["max"] then
      lcd.drawFilledRectangle(x, y, w, h, SOLID)
    elseif telemetry[key].data / norm >= border["min"] then
      lcd.drawGauge(x, y, w, h, (telemetry[key].data / norm - border["min"]) * factor , (border["max"] - border["min"]) * factor)
    else
      lcd.drawRectangle(x, y, w, h)
    end
  end
end

function display:Timer(x, y, key, font)
  if telemetry[key] ~= nil then
    lcd.drawText(x, y, telemetry[key].name .. ": ", font)
    lcd.drawTimer(lcd.getLastPos(), y, telemetry[key].data, font)
    return 1
  else
    return -1
  end
end

function display:Diagram(values, x, y, h)
  local min, max = values:MinMax()
  
  lcd.drawText(x + 2, y, values.key .. " " .. round(values[1], 2) .. "/" .. round(max, 2) .. "/" .. round(min, 2), SMLSIZE)

  for index = 1, #values - 1, 1 do
    if max ~= 0 then
      lcd.drawLine(x + index, y + h, x + index, y + h * (1 - values[index] / max), SOLID,GREY_DEFAULT)
      lcd.drawPoint(x + index, y + h * (1 - values[index] / max), SOLID, FORCE)
    end
  end
  
  lcd.drawLine(x, y, x, y + h, SOLID, FORCE)
  lcd.drawLine(x, y + h, x + values.length, y + h, SOLID, FORCE)
end

function display:Show(screen) 
  local flightMode = ( { getFlightMode() } )[2]
  local modelName = model.getInfo().name
      
  lcd.drawScreenTitle(modelName .. "  (" .. battery["cels"] .. "S)  " .. flightMode .. " - " .. version, screen.num, #screen)
  screen[screen.num]()
end

----------------------------------------------------------------------
-- ring buffer
local buffer = {}
  buffer["length"] = 100    -- can be adjusted
  buffer["maxValue"] = 0
  buffer["minValue"] = 0
  buffer["time"] = 0
  buffer["delta"] = 1
  buffer["key"] = "key"
  
function buffer:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end
    
function buffer:Add()
  if telemetry[self.key] ~= nil then
    if getTime() - self.time > self.delta * 100 then
      self.time = getTime()
      for index = self.length, 2, -1 do
        if self[index - 1] ~= nil then
          self[index] = self[index - 1]
        else
          self[index] = nil
        end
      end
      self[1] = telemetry[self.key].data  
    end 
  end
end

function buffer:MinMax()
  self.maxValue = self[1]
  self.minValue = self[1]
  for index = 1, #self - 1, 1 do
    if self[index] > self.maxValue then
      self.maxValue = self[index]
    end
    if self[index] < self.minValue then
      self.minValue = self[index]
    end
  end
  return self.minValue, self.maxValue
end

local altitude = buffer:New{ key = "Alt", length = 105, delta = 1 } -- can be modified, put telemetry 'Alt' every 1 sec into a table with 105 values

----------------------------------------------------------------------
-- heading offset
local offset = {}
  offset["key"] = "Hdg"
  offset["offset"] = 0

function offset:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function offset:SetOffset()
  if telemetry[self.key] ~= nil then
    self.offset = telemetry[self.key].data
  end
end

function offset:EraseOffset()
  self.offset = 0
end

local heading = offset:New{ key = "Hdg" }

----------------------------------------------------------------------
-- define different screens, to add screens increment number in [], do NOT leave a number out
local screen = {}
  screen["num"] = 1   -- can be adjusted
  
function screen:Next()
  self.num = self.num + 1
  if self.num > #self then
    self.num = 1
  end
end

function screen:Previous()
  self.num = self.num - 1
  if self.num < 1 then
    self.num = #self
  end
end

screen[1] = function() 
  display:Value(1, 9, "VFAS", MIDSIZE)
  display:Gauge(107, 9, 100, 12, "VFAS", battery, battery["cels"], 100)
  display:Value(1, 25, "RSSI", MIDSIZE)
  display:Gauge(107, 25, 100, 12, "RSSI", rssi)
  display:Value(107, 41, "Hdg", MIDSIZE, heading.offset)
  display:Key(1, 41, "ch13", 1024, MIDSIZE+INVERS+BLINK)
  display:Key(1, 56, "ch6", 0, SMLSIZE)
  display:Key(1+display["width"]/4, 56, "ch7", 0, SMLSIZE)
  display:Key(1+display["width"]/2, 56, "ch8", 0 , SMLSIZE)
  display:Key(1+display["width"]*3/4, 56, "ch11", 0, SMLSIZE)
end

screen[2] = function() 
  display:Value(1, 9,  "Alt", MIDSIZE)
  display:Value(107, 9,  "Alt+", SMLSIZE)
  display:Value(107, 17,  "Alt-", SMLSIZE)
  display:Value(1, 25, "VSpd", MIDSIZE)
  display:Value(107, 25, "VSpd+", SMLSIZE)
  display:Value(107, 33, "VSpd-", SMLSIZE)
  display:Timer(107, 41, "timer1", MIDSIZE)
  display:Key(1, 41, "ch13", 1024, MIDSIZE+INVERS+BLINK)
  display:Key(1, 56, "ch6", 0, SMLSIZE)
  display:Key(1+display["width"]/4, 56, "ch7", 0, SMLSIZE)
  display:Key(1+display["width"]/2, 56, "ch8", 0 , SMLSIZE)
  display:Key(1+display["width"]*3/4, 56, "ch11", 0, SMLSIZE)
end

screen[3] = function() 
  display:Diagram(altitude, 1, 10, 40)
end

----------------------------------------------------------------------
-- sound triggered by value
local function playSound(key, value, file)
  if telemetry[key] ~= nil then
    if telemetry[key].data == value then
      if telemetry[key].sound ~= value then
        telemetry[key].sound = value
        playFile(file)
      end
    end
  end
end

----------------------------------------------------------------------
local function init_func()
  -- init_func is called once when model is loaded  
  telemetry:Init()
end

local function bg_func()
  -- bg_func is called periodically when screen is not visible
  telemetry:Refresh() -- somehow is not working
  
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

  battery:Check("VFAS", "low", "batlow.wav")
  battery:Check("VFAS", "critical", "batcrit.wav")  
  
  altitude:Add()
end

local function run_func(event)
  -- run_func is called periodically when screen is visible
  bg_func() -- run typically calls bg_func to start
    
  lcd.clear()
    
  if event == EVT_ENTER_BREAK then  
    heading:EraseOffset()
  end  
  
  if event == EVT_EXIT_BREAK then  
    heading:SetOffset()
  end  

  if event == EVT_PLUS_BREAK then
    battery:Increment()
  end
  
  if event == EVT_MINUS_BREAK then
    battery:Decrement()
  end
  
  if event == EVT_PAGE_BREAK then
    screen:Next()
  end
  
  if event == EVT_PAGE_LONG then
    screen:Previous()
  end
    
  display:Show(screen)
end

return { run=run_func, background=bg_func, init=init_func  }