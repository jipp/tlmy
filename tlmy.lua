--[[
  tlmy.lua

  Date: 06.08.2017
  Author: wolfgang.keller@wobilix.de
  HW: FrSky Taranis X9D Plus
  SW: OpenTX 2.1.8; OpenTX 2.2.0
]]--

----------------------------------------------------------------------
-- Version String
----------------------------------------------------------------------
local version = "v0.16.0"

----------------------------------------------------------------------
-- Mathematical Utility Function
----------------------------------------------------------------------
local function round(value, decimal)
  local exponent = 10^(decimal or 0)
  return math.floor(value * exponent + 0.5) / exponent
end

----------------------------------------------------------------------
-- Wrapper
----------------------------------------------------------------------
local function showChannel(x, y, key, font)
  local value = getValue(key)

  if value ~= nil then
    lcd.drawText(x, y, key .. ": ", font)
    lcd.drawChannel(lcd.getLastPos(), y, key, font + LEFT)
  end
end

local function showNameNumber(x, y, name, value, font)
  if value ~= nil then
    lcd.drawText(x, y, name .. ": ", font)
    lcd.drawNumber(lcd.getLastPos(), y, value, font)
  end
end

local function showTimer(x, y, key, font)
  local value = getValue(key)

  if value ~= nil then
    lcd.drawText(x, y, key .. ": ", font)
    lcd.drawTimer(lcd.getLastPos(), y, value, font)
  end
end

local function showNameTimer(x, y, name, value, font)
  if value ~= nil then
    lcd.drawText(x, y, name .. ": ", font)
    lcd.drawTimer(lcd.getLastPos(), y, value, font)
  end
end

local function showGauge(x, y, w, h, key)
  local value = getValue(key.key)

  if value ~= nil then
    if type(key.factor) == "function" then
      factor = key.factor()
    else
      factor = key.factor
    end
    if value >= key.max * factor then
      lcd.drawFilledRectangle(x, y, w, h, SOLID)
    elseif value >= key.min * factor then
      lcd.drawGauge(x, y, w, h, (value - key.min * factor) * key.smooth, (key.max - key.min) * factor * key.smooth)
    else
      lcd.drawRectangle(x, y, w, h)
    end
  end
end

----------------------------------------------------------------------
-- Classes
----------------------------------------------------------------------
-- Gauge
local Gauge = {}
  Gauge["key"] = "key"
  Gauge["min"] = 1
  Gauge["max"] = 100
  Gauge["factor"] = 1
  Gauge["smooth"] = 1

function Gauge:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Diagram
local Diagram = {}
  Diagram["key"] = "key"
  Diagram["length"] = 102
  Diagram["time"] = 0
  Diagram["delta"] = 1
  Diagram["extreme"] = 500

function Diagram:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Diagram:add()
  local value = getValue(self.key)
  local diff = 0

  if value ~= nil then
    if getTime() - self.time > self.delta * 100 then
      self.time = getTime()
      for index = self.length, 2, -1 do
        if self[index - 1] ~= nil then
          self[index] = self[index - 1]
        else
          self[index] = nil
        end
      end

      if (self[2] ~= nil) and (math.abs(value - self[2]) > self["extreme"]) then
        self[1] = self[2]
      else
        self[1] = value
      end

    end
  end
end

function Diagram:getMinMax()
  local maxValue = self[1]
  local minValue = self[1]

  for index = 1, #self - 1, 1 do
    if self[index] > maxValue then
      maxValue = self[index]
    end
    if self[index] < minValue then
      minValue = self[index]
    end
  end
  return minValue, maxValue
end

function Diagram:show(x, y, h)
  local min, max = self:getMinMax()
  local diff = 0

  lcd.drawText(x + 3, y, self.key .. " " .. round(self[1], 2) .. "/" .. round(max, 2) .. "/" .. round(min, 2), SMLSIZE)

  if min > 0 then
    min = 0
  end
  if max < 0 then
    max = 0
  end

  diff = max - min

  for index = 1, #self, 1 do
    if diff ~= 0 then
      lcd.drawLine(x + index, y + h * max / diff, x + index, y + h * (max - self[index]) / diff, SOLID, GREY_DEFAULT)
      lcd.drawPoint(x + index, y + h * (max - self[index]) / diff, SOLID, FORCE)
    end
  end

  lcd.drawLine(x, y, x, y + h, SOLID, FORCE)
  lcd.drawLine(x - 1, y + 1, x + 1, y + 1, SOLID, FORCE)

  if diff ~= 0 then
    lcd.drawLine(x, y + h * max / diff, x + self.length, y + h * max / diff, SOLID, FORCE)
    lcd.drawLine(x + self.length - 1, y + h * max / diff - 1, x + self.length - 1, y + h * max / diff + 1, SOLID, FORCE)
  else
    lcd.drawLine(x, y + h, x + self.length, y + h, SOLID, FORCE)
    lcd.drawLine(x + self.length - 1, y + h - 1, x + self.length - 1, y + h + 1, SOLID, FORCE)
  end

  lcd.drawText(x + self.length - 25, y + h + 2 , "I=" .. self["delta"] .. "s", SMLSIZE)
end

-- Switch
local Switch = {}
  Switch["key"] = "key"

function Switch:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Switch:getName()
  local value = getValue(self.key)

  if value ~= nil then
    for index, data in ipairs(self) do
      if data.position == value then
        return data.name
      end
    end
  end
end

function Switch:show(x, y, font)
  local value = self:getName()

  if value ~= nil then
    lcd.drawText(x, y, value, font)
  end
end

-- Lipo
local Lipo = {}
  Lipo["key"] = "key"
  Lipo["min"] = 1
  Lipo["max"] = 2

function Lipo:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Lipo:check()
  local value = getValue(self.key)

  if value ~= nil then
    for index, data in ipairs(self) do
      if data.time == nil then
        data.time = 0
      end
      if value <= data.limit then
        if data.flag ~= true then
          if getTime() - data.time > data.delta * 100 then
            data.flag = true
            playFile(data.file)
          end
        end
      elseif value > data.limit then
        data.flag = false
        data.time = getTime()
      end
    end
  end
end

function Lipo:getCels(key)
  local value = ""

  if getValue(key) ~=0 and getValue(self.key) ~= 0  then
    value = math.floor(getValue(key) / getValue(self.key) + 0.5)
  end

  return value
end

-- Altitude
local Altitude = {}
  Altitude["key"] = "key"
  Altitude["unit"] = 9
  Altitude["min"] = 1
  Altitude["max"] = 2

function Altitude:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Altitude:check()
  local value = getValue(self.key)

  if value ~= nil then
    for index, data in ipairs(self) do
      if data.time == nil then
        data.time = 0
      end
      if value >= data.limit then
        if getTime() - data.time > data.delta * 100 then
          data.time = getTime()
          playNumber(value, self.unit)
        end
      end
    end
  end
end

-- Correction
local Correction = {}
   Correction["key"] = "key"
   Correction["factor"] = 0

function Correction:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Correction:getAligned()
  return getValue(self.key) - self.factor
end

function Correction:reset()
  local value = getValue(self.key)

  if value ~= nil then
    self.factor = value
  end
end

function Correction:show(x, y, font)
  value = self:getAligned()

  if value ~= nil then
    lcd.drawText(x, y, self.key .. ": ", font)
    lcd.drawNumber(lcd.getLastPos(), y, value * 100, font + PREC2)
    lcd.drawText(lcd.getLastPos(), y, " aligned", font)
  end
end

-- RaceTimer
local RaceTimer = {}
  RaceTimer["triggerKey"] = "sh"
  RaceTimer["armedKey"] = "ch13"
  RaceTimer["throttleKey"] = "thr"
  RaceTimer["triggerKey"] = "sh"
  RaceTimer["flag"] = true
  RaceTimer["timerIndex"] = 2
  RaceTimer["timerName"] = "timer3"
  RaceTimer["lapTime"] = {}

function RaceTimer:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function RaceTimer:getName()
  return self.timerName
end

function RaceTimer:start()
  local timer = model.getTimer(self.timerIndex)

  timer.mode = 1
  model.setTimer(self.timerIndex, timer)
end

function RaceTimer:stop()
  local timer = model.getTimer(self.timerIndex)

  timer.mode = 0
  model.setTimer(self.timerIndex, timer)
end

function RaceTimer:reset()
  model.resetTimer(self.timerIndex)
  for index, data in ipairs(self) do
    self[index] = nil
  end
  for index, data in ipairs(self.lapTime) do
    self.lapTime[index] = nil
  end
  self.best = nil
  self.worst = nil
end

function RaceTimer:add()
  self[#self+1] = model.getTimer(self.timerIndex).value
  if #self == 1 then
    self.lapTime[#self.lapTime + 1] = self[#self]
    self.best = self[#self]
    self.worst = self[#self]
    self.average = self[#self]
  elseif #self > 1 then
    self.lapTime[#self.lapTime + 1] = self[#self] - self[#self - 1]
    if self.lapTime[#self.lapTime] > self.worst then
      self.worst = self.lapTime[#self.lapTime]
    end
    if self.lapTime[#self.lapTime] < self.best then
      self.best = self.lapTime[#self.lapTime]
    end
    self.average = 0
    for index, data in ipairs(self.lapTime) do
      self.average = self.average + data
    end
    self.average = round(self.average / #self.lapTime, 0)
  end
end

function RaceTimer:getBestTime()
  return self.best
end

function RaceTimer:getWorstTime()
  return self.worst
end

function RaceTimer:getLastTime()
  return self.lapTime[#self.lapTime]
end

function RaceTimer:getAverageTime()
  return self.average
end

function RaceTimer:getLapTime(lap)
  return self.lapTime[lap]
end

function RaceTimer:getTotalTime()
  return model.getTimer(self.timerIndex).value
end

function RaceTimer:getCurrentLap()
  return #self.lapTime + 1
end

function RaceTimer:printSummary()
  for index, data in ipairs(self.lapTime) do
    print(index .. ") " .. data)
  end
end

function RaceTimer:check()
  local Switch = getValue(self.triggerKey)
  local armed = getValue(self.armedKey)
  local throttle = getValue(self.throttleKey)
  local trigger = getValue(self.triggerKey)

  if (armed == 1024 and throttle > -1024 and model.getTimer(self.timerIndex).mode == 0) then
    self:reset()
    self:start()
    playNumber(1, 0)
  end
  if (armed == -1024 and model.getTimer(self.timerIndex).mode == 1) then
    self:stop()
    -- self:printSummary()
  end
  if (armed == 1024 and trigger == 1024 and model.getTimer(self.timerIndex).mode == 1 and self.flag == true) then
    self:add()
    playNumber(#self.lapTime + 1, 0)
    self.flag = false
  end
  if (self.flag == false and trigger == -1024) then
    self.flag = true
  end
end

----------------------------------------------------------------------
-- local definitions
----------------------------------------------------------------------
local energy = Lipo:new{ key = "A4",
  { limit = 3.3, delta = 10, file = "lowbat.wav" },
  { limit = 3.5, delta = 10, file = "lowbat.wav" }
}
local alt = Altitude:new{ key= "Alt", unit = 9,
  { limit = 90, delta = 10 }
}
local rssiGauge = Gauge:new{ key = "RSSI", min = 40, max = 100 }
local energyGauge = Gauge:new{ key = "A4", min = energy.min, max =  energy.max, smooth = 100 }
local altDiagram = Diagram:new{ key = "Alt", delta = 1, extreme = 100 }
local ch6 = Switch:new{ key = "ch6",
  { position = -1024, },
  { position = 0, name = "baro" },
  { position = 1024 }
}
local ch7 = Switch:new{ key = "ch7",
  { position = -1024 },
  { position = 0, name = "osd sw" },
  { position = 1024, name = "air mode" }
}
local ch8 = Switch:new{ key = "ch8",
  { position = -1024 },
  { position = 0, name = "beeper" },
  { position = 1024 },
}
local ch13 = Switch:new{ key = "ch13",
  { position = 1024, name = "armed" },
  { position = -1024 }
}
local heading = Correction:new{ key = "Hdg" }
local race = RaceTimer:new{}

----------------------------------------------------------------------
-- display
----------------------------------------------------------------------
local display = {}
  display["width"] = 212
  display["height"] = 64

function display:show(screen)
  local flightMode = ( { getFlightMode() } )[2]
  local modelName = model.getInfo().name

  lcd.drawScreenTitle(modelName .. "  (" .. energy:getCels("VFAS") .. "S)  " .. flightMode .. " - " .. version, screen.num, #screen)
  screen[screen.num]()
end

----------------------------------------------------------------------
-- define different screens, to add screens increment number in [], do NOT leave out a number
----------------------------------------------------------------------
local screen = {}
  screen["num"] = 1

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
  showChannel(1, 9, "VFAS", MIDSIZE)
  showGauge(107, 9, 100, 12, energyGauge)
  showChannel(1, 25, "RSSI", MIDSIZE)
  showGauge(107, 25, 100, 12, rssiGauge)
  showChannel(107, 41, "Hdg", SMLSIZE)
  heading:show(107, 49, SMLSIZE)
  ch13:show(1, 41, MIDSIZE+INVERS+BLINK)
  ch6:show(1, 57, SMLSIZE)
  ch7:show(1 + display["width"] * 1 / 5, 57, SMLSIZE)
  ch8:show(1 + display["width"] * 2 / 5, 57, SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 57, "total", race:getTotalTime(), SMLSIZE)
end

screen[2] = function()
  showChannel(1, 9, "Alt", MIDSIZE)
  altDiagram:show(107, 9, 38)
  ch13:show(1, 41, MIDSIZE+INVERS+BLINK)
  ch6:show(1, 57, SMLSIZE)
  ch7:show(1 + display["width"] * 1 / 5, 57, SMLSIZE)
  ch8:show(1 + display["width"] * 2 / 5, 57, SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 57, "total", race:getTotalTime(), SMLSIZE)
end

screen[3] = function()
  showNameTimer(1, 9, "t", race:getTotalTime(), MIDSIZE)
  showNameNumber(1 + display["width"] * 1 / 3, 9, "#", race:getCurrentLap(), MIDSIZE)
  showNameTimer(1, 25, "last", race:getLastTime(), SMLSIZE)
  showNameTimer(1, 34, "best", race:getBestTime(), SMLSIZE)
  showNameTimer(1, 43, "worst", race:getWorstTime(), SMLSIZE)
  showNameTimer(1, 52, "average", race:getAverageTime(), SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 9, "1", race:getLapTime(1), SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 18, "2", race:getLapTime(2), SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 27, "3", race:getLapTime(3), SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 36, "4", race:getLapTime(4), SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 45, "5", race:getLapTime(5), SMLSIZE)
  showNameTimer(1 + display["width"] * 3 / 5, 54, "6", race:getLapTime(6), SMLSIZE)
  showNameTimer(1 + display["width"] * 4 / 5, 9, "7", race:getLapTime(7), SMLSIZE)
  showNameTimer(1 + display["width"] * 4 / 5, 18, "8", race:getLapTime(8), SMLSIZE)
  showNameTimer(1 + display["width"] * 4 / 5, 27, "9", race:getLapTime(9), SMLSIZE)
  showNameTimer(1 + display["width"] * 4 / 5, 36, "10", race:getLapTime(10), SMLSIZE)
  showNameTimer(1 + display["width"] * 4 / 5, 45, "11", race:getLapTime(11), SMLSIZE)
  showNameTimer(1 + display["width"] * 4 / 5, 54, "12", race:getLapTime(12), SMLSIZE)
end

----------------------------------------------------------------------
local function init_func()
  -- init_func is called once when model is loaded
end

local function bg_func()
  -- bg_func is called periodically when screen is not visible
  altDiagram:add()
  alt:check()
  energy:check()
  race:check()
end

local function run_func(event)
  -- run_func is called periodically when screen is visible
  bg_func() -- run typically calls bg_func to start

  lcd.clear()

  if event == EVT_PAGE_BREAK then
    screen:Next()
  end

  if event == EVT_PAGE_LONG then
    screen:Previous()
  end

  if event == EVT_ENTER_BREAK then
    heading:reset()
  end

  display:show(screen)
end

return { run=run_func, background=bg_func, init=init_func  }
