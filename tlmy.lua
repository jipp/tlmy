--[[
  tlmy.lua
  
  Date: 27.07.2016
  Author: wolfgang.keller@wobilix.de
  HW: frsky taranis plus X9d
  SW: open-tx 2.1.9
]]--

----------------------------------------------------------------------
-- Version String
local version = "v0.13.1"

----------------------------------------------------------------------
-- mathematical utility function
----------------------------------------------------------------------
local function Round(value, decimal)
  local exponent = 10^(decimal or 0)
  return math.floor(value * exponent + 0.5) / exponent
end  

----------------------------------------------------------------------
-- Wrapper
----------------------------------------------------------------------
function ShowValue(x, y, key, font)
  local value = getValue(key)
  
  if value ~= nil then
    lcd.drawText(x, y, key .. ": ", font)
    lcd.drawChannel(lcd.getLastPos(), y, key, font + LEFT)
  end
end

function ShowTimer(x, y, key, font)
  local value = getValue(key)
  
  if value ~= nil then
    lcd.drawText(x, y, key .. ": ", font)
    lcd.drawTimer(lcd.getLastPos(), y, value, font)
  end
end

function ShowGauge(x, y, w, h, key)
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
local gauge = {}
  gauge["key"] = "key"
  gauge["min"] = 1
  gauge["max"] = 1
  gauge["factor"] = 1
  gauge["smooth"] = 1
 
function gauge:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Diagram
local diagram = {}
  diagram["key"] = "key"
  diagram["length"] = 102
  diagram["time"] = 0
  diagram["delta"] = 1
  
function diagram:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end
    
function diagram:Add()
  local value = getValue(self.key)
  
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
      self[1] = value  
    end 
  end
end

function diagram:MinMax()
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

function diagram:Show(x, y, h)
  local min, max = self:MinMax()
  local diff = 0
  
  lcd.drawText(x + 2, y, self.key .. " " .. Round(self[1], 2) .. "/" .. Round(max, 2) .. "/" .. Round(min, 2), SMLSIZE)

  if min > 0 then
    min = 0
  end
  if max < 0 then
    max = 0
  end

  diff = max - min

  for index = 1, #self, 1 do
    if diff ~= 0 then
      lcd.drawLine(x + index, y + h * max / diff, 
        x + index, y + h * (max - self[index]) / diff, 
        SOLID,GREY_DEFAULT)
      lcd.drawPoint(x + index, y + h * (max - self[index]) / diff, 
        SOLID, FORCE)
    end
  end
  
  lcd.drawLine(x, y, 
    x, y + h, 
    SOLID, FORCE)
  if diff ~= 0 then
    lcd.drawLine(x, y + h * max / diff, 
      x + self.length, y + h * max / diff, 
      SOLID, FORCE)
  else
    lcd.drawLine(x, y + h, 
      x + self.length, y + h, 
      SOLID, FORCE)
  end    
end

-- Switch
local switch = {}
  switch["key"] = "key"
 
function switch:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function switch:GetName()
  local value = getValue(self.key)
  
  if value ~= nil then 
    for index, data in ipairs(self) do
      if data.position == value then
        return data.name
      end
    end
  end
end

function switch:Show(x, y, font)
  local value = self:GetName()
   
  if value ~= nil then
    lcd.drawText(x, y, value, font)
  end
end

----------------------------------------------------------------------
---- LiPo
local lipo = {}
  lipo["key"] = "VFAS"
  lipo["min"] = 3.2
  lipo["max"] = 4.3
  lipo["cels"] = 3
   
function lipo:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function lipo:Increment()
  self.cels = self.cels + 1
end

function lipo:Decrement()
  self.cels = self.cels - 1
  if self.cels < 1 then
    self.cels = 1
  end
end

function lipo:Check()
  local value = getValue(self.key) / self.cels

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

----------------------------------------------------------------------
-- local definitions
----------------------------------------------------------------------
local energy = lipo:New{ key = "VFAS", 
  { limit = 3.3, delta = 10,  file = "batcrit.wav" }, 
  { limit = 3.5, delta = 10,  file = "batlow.wav" }
}
local rssiGauge = gauge:New{ key = "RSSI", min = 40, max = 100 }
local vfasGauge = gauge:New{ key = "VFAS", min = energy.min, max =  energy.max, factor = function () return energy.cels end, smooth = 100 }
local altDiagram = diagram:New{ key = "Alt" }
local ch6 = switch:New{ key = "ch6", 
  { position = -1024, }, 
  { name = "baro", position = 0 },
  { position = 1024 } 
}
local ch7 = switch:New{ key = "ch7", 
  { position = -1024 },
  { name = "air", position = 0 },
  { position = 1024 }
}
local ch8 = switch:New{ key = "ch8", 
  { position = -1024},
  { name = "beeper", position = 0},
  { position = 1024},
}
local ch11 = switch:New{ key = "ch11", 
  { position = -1024 },
  { name = "gtune", position = 0 },
  { position = 1024 }
}
local ch13 = switch:New{ key = "ch13", 
  { name = "armed", position = 1024 },
  { position = -1024 }
}

----------------------------------------------------------------------
-- dislay limits and functions
----------------------------------------------------------------------
local display = {}
  display["width"] = 212
  display["height"] = 64 

function display:Show(screen) 
  local flightMode = ( { getFlightMode() } )[2]
  local modelName = model.getInfo().name
      
  lcd.drawScreenTitle(modelName .. "  (" .. energy.cels .. "S)  " .. flightMode .. " - " .. version, screen.num, #screen)
  screen[screen.num]()
end

----------------------------------------------------------------------
-- define different screens, to add screens increment number in [], do NOT leave a number out
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
  ShowValue(1, 9, "VFAS", MIDSIZE)
  ShowGauge(107, 9, 100, 12, vfasGauge)
  ShowValue(1, 25, "RSSI", MIDSIZE)
  ShowGauge(107, 25, 100, 12, rssiGauge)
  ShowValue(107, 41, "Hdg", MIDSIZE)
  ch13:Show(1, 41, MIDSIZE+INVERS+BLINK)
  ch6:Show(1, 56, SMLSIZE)
  ch7:Show(1+display["width"]/4, 56, SMLSIZE)
  ch8:Show(1+display["width"]/2, 56, SMLSIZE)
  ch11:Show(1+display["width"]*3/4, 56, SMLSIZE)
end

screen[2] = function() 
  altDiagram:Show(1, 10, 40)
  ShowValue(107, 9, "Alt", SMLSIZE)
  ShowValue(107, 17, "Alt+", SMLSIZE)
  ShowValue(107, 25, "Alt-", SMLSIZE)
  ShowValue(107, 33, "VSpd", SMLSIZE)
  ShowValue(107, 41, "VSpd+", SMLSIZE)
  ShowValue(107, 49, "VSpd-", SMLSIZE)
end

----------------------------------------------------------------------
local function init_func()
  -- init_func is called once when model is loaded   
end

local function bg_func()
  -- bg_func is called periodically when screen is not visible
  altDiagram:Add()
  energy:Check()
end

local function run_func(event)
  -- run_func is called periodically when screen is visible
  bg_func() -- run typically calls bg_func to start
    
  lcd.clear()
    
  if event == EVT_PLUS_BREAK then
    energy:Increment()
  end
  
  if event == EVT_MINUS_BREAK then
    energy:Decrement()
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