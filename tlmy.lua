--[[
  tlmy.lua
  
  Date: 27.07.2016
  Author: wolfgang.keller@wobilix.de
  HW: frsky taranis plus X9d
  SW: open-tx 2.1.9
  
  ToDo:
    - hight warning
]]--

----------------------------------------------------------------------
-- Version String
local version = "v0.12.4" 

----------------------------------------------------------------------
-- mathematical utility function
local function round(value, decimal)
  local exponent = 10^(decimal or 0)
  return math.floor(value * exponent + 0.5) / exponent
end  

----------------------------------------------------------------------
-- gauge limits and functions
local gauge = {}
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

function gauge:Increment()
  self.factor = self.factor + 1
end

function gauge:Decrement()
  self.factor = self.factor - 1
  if self.factor < 1 then
    self.factor = 1
  end
end

----------------------------------------------------------------------
-- ring buffer limits and functions
local buffer = {}
  buffer["length"] = 100
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

----------------------------------------------------------------------
-- battery limits and functions
local battery = {}
  battery["cels"] = 3
  battery["limit"] = 1
  battery["key"] = "key"
  battery["file"] = "file"
  battery["time"] = 0
  battery["delta"] = 10
  battery["flag"] = false 

function battery:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function battery:Check()
  local value = getValue(self.key) / battery.cels

  if value ~= nil then
    if value <= self.limit then
      if self.flag ~= true then
        if getTime() - self.time > self.delta * 100 then
          self.flag = true
          playFile(self.file)
        end
      end
    elseif value > self.limit then
      self.flag = false
      self.time = getTime()
    end
  end
end

function battery:Increment()
  battery.cels = battery.cels + 1
end

function battery:Decrement()
  battery.cels = battery.cels - 1
  if battery.cels < 1 then
    battery.cels = 1
  end
end

----------------------------------------------------------------------
-- channel limits and functions
local channel = {}
  channel["key"] = "key"
 
function channel:New(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function channel:getName()
  local value = getValue(self.key)
  
  if value ~= nil then 
    for index, data in ipairs(self) do
      if data.position == value then
        return data.name
      end
    end
  end
end

function channel:Play()
  local value = getValue(self.key)
  
  if value ~= nil then
    for index, data in ipairs(self) do
      if data.position == value then
        if self.flag ~= value then 
          self.flag = value
          if data.file ~= nil then
            playFile(data.file)
          end
        end
      end
    end
  end
end

----------------------------------------------------------------------
-- local definitions
local rssi = gauge:New{ min = 40, max = 100 }
local vfas = gauge:New{ min = 3.2, max =  4.3, factor = 3, smooth = 100 }
local altitude = buffer:New{ key = "Alt", length = 102, delta = 1 }
local verticalSpeed = buffer:New{ key = "VSpd", length = 102, delta = 1 }
local vfasLow = battery:New{ limit = 3.5, delta = 10, key = "VFAS", file = "batlow.wav" }
local vfasCritical = battery:New{ limit = 3.3, delta = 5, key = "VFAS", file = "batcrit.wav" }

local ch5 = channel:New{ key = "ch5", 
  { name = "acromd", position = 1024, file = "acromd.wav" },
  { name = "hrznmd", position = 0, file = "hrznmd.wav" },
  { name = "anglmd", position = -1024, file = "anglmd.wav" }
}
local ch6 = channel:New{ key = "ch6", 
  { position = -1024, file = "brmtrof.wav" }, 
  { name = "baro", position = 0, file = "brmtr.wav" },
  { position = 1024, file = "brmtrof.wav" } 
}
local ch7 = channel:New{ key = "ch7", 
  { position = -1024 },
  { name = "air", position = 0, file = "bombawy.wav" },
  { position = 1024 }
}
local ch8 = channel:New{ key = "ch8", 
  { position = -1024},
  { name = "beeper", position = 0},
  { position = 1024},
}
local ch11 = channel:New{ key = "ch11", 
  { position = -1024 },
  { name = "gtune", position = 0, file = "automd.wav" },
  { position = 1024 }
}
local ch13 = channel:New{ key = "ch13", 
  { name = "arm", position = 1024, file = "thract.wav" },
  { position = -1024, file = "thrdis.wav" }
}

----------------------------------------------------------------------
-- dislay limits and functions
local display = {}
  display["width"] = 212
  display["height"] = 64 
  
function display:Channel(x, y, key, font)
  local value = getValue(key)
  
  if value ~= nil then
    lcd.drawText(x, y, key .. ": ", font)
    lcd.drawChannel(lcd.getLastPos(), y, key, font+ LEFT)
  end
end

function display:Name(x, y, channel, font)
  local value = channel:getName()
   
  if value ~= nil then
    lcd.drawText(x, y, value, font)
  end
end

function display:Gauge(x, y, w, h, key, border)
  local value = getValue(key)
  
  if value ~= nil then
    if value >= border["max"] * border["factor"] then
      lcd.drawFilledRectangle(x, y, w, h, SOLID)
    elseif value >= border["min"] * border["factor"] then
      lcd.drawGauge(x, y, w, h, (value - border["min"] * border["factor"]) * border["smooth"], (border["max"] - border["min"]) * border["factor"] * border["smooth"])
    else
      lcd.drawRectangle(x, y, w, h)
    end
  end
end

function display:Timer(x, y, key, font)
  local value = getValue(key)
  
  if value ~= nil then
    lcd.drawText(x, y, key .. ": ", font)
    lcd.drawTimer(lcd.getLastPos(), y, value, font)
  end
end

function display:Diagram(values, x, y, h)
  local min, max = values:MinMax()
  local diff = 0
  
  lcd.drawText(x + 2, y, values.key .. " " .. round(values[1], 2) .. "/" .. round(max, 2) .. "/" .. round(min, 2), SMLSIZE)

  if min > 0 then
    min = 0
  end
  if max < 0 then
    max = 0
  end

  diff = max - min

  for index = 1, #values, 1 do
    if max ~= 0 then
      lcd.drawLine(x + index, y + h * max / diff, 
        x + index, y + h * (max - values[index]) / diff, 
        SOLID,GREY_DEFAULT)
      lcd.drawPoint(x + index, y + h * (max - values[index]) / diff, 
        SOLID, FORCE)
    end
  end
  
  lcd.drawLine(x, y, 
    x, y + h, 
    SOLID, FORCE)
  lcd.drawLine(x, y + h * max / diff, 
    x + values.length, y + h * max / diff, 
    SOLID, FORCE)
end

function display:Show(screen) 
  local flightMode = ( { getFlightMode() } )[2]
  local modelName = model.getInfo().name
      
  lcd.drawScreenTitle(modelName .. "  (" .. battery["cels"] .. "S)  " .. flightMode .. " - " .. version, screen.num, #screen)
  screen[screen.num]()
end

----------------------------------------------------------------------
-- define different screens, to add screens increment number in [], do NOT leave a number out
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
  display:Channel(1, 9, "VFAS", MIDSIZE)
  display:Gauge(107, 9, 100, 12, "VFAS", vfas)
  display:Channel(1, 25, "RSSI", MIDSIZE)
  display:Gauge(107, 25, 100, 12, "RSSI", rssi)
  display:Channel(107, 41, "Hdg", MIDSIZE)
  display:Name(1, 41, ch13, MIDSIZE+INVERS+BLINK)
  display:Name(1, 56, ch6, SMLSIZE)
  display:Name(1+display["width"]/4, 56, ch7, SMLSIZE)
  display:Name(1+display["width"]/2, 56, ch8, SMLSIZE)
  display:Name(1+display["width"]*3/4, 56, ch11, SMLSIZE)
end

screen[2] = function() 
  display:Channel(1, 9, "Alt", MIDSIZE)
  display:Channel(107, 9, "Alt+", SMLSIZE)
  display:Channel(107, 17, "Alt-", SMLSIZE)
  display:Channel(1, 25, "VSpd", MIDSIZE)
  display:Channel(107, 25, "VSpd+", SMLSIZE)
  display:Channel(107, 33, "VSpd-", SMLSIZE)
  display:Timer(107, 41, "timer1", MIDSIZE)
  display:Name(1, 41, ch13, MIDSIZE+INVERS+BLINK)
  display:Name(1, 56, ch6, SMLSIZE)
  display:Name(1+display["width"]/4, 56, ch7, SMLSIZE)
  display:Name(1+display["width"]/2, 56, ch8, SMLSIZE)
  display:Name(1+display["width"]*3/4, 56, ch11, SMLSIZE)
end

screen[3] = function() 
  display:Diagram(altitude, 1, 10, 40)
  display:Diagram(verticalSpeed, 107, 10, 40)
end

----------------------------------------------------------------------
local function init_func()
  -- init_func is called once when model is loaded   
end

local function bg_func()
  -- bg_func is called periodically when screen is not visible
  altitude:Add()
  verticalSpeed:Add()
  vfasLow:Check()  
  vfasCritical:Check()  
  ch5:Play()
  ch6:Play()
  ch7:Play()
  ch11:Play()
  ch13:Play()
end

local function run_func(event)
  -- run_func is called periodically when screen is visible
  bg_func() -- run typically calls bg_func to start
    
  lcd.clear()
    
  if event == EVT_PLUS_BREAK then
    vfas:Increment()
    battery:Increment()
  end
  
  if event == EVT_MINUS_BREAK then
    vfas:Decrement()
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