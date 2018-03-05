local eapi = ...
local MapObj = require("Libraries.map")

local t = {} --The tilemap editor

--=====-- Spritesheet Values --=====--

local imgw, imgh = 8, 8 --The sprite size (MUST NOT CHANGE)

local swidth, sheight = screenSize() --The screen size
local sheetW, sheetH = math.floor(swidth/imgw), math.floor(sheight/imgh) --The size of the spritessheet in cells (sprites)
local bankH = sheetH/4 --The height of each bank in cells (sprites)
local bsizeH = bankH*imgh --The height of each bank in pixels
local sizeW, sizeH = sheetW*imgw, sheetH*imgh --The size of the spritessheet in pixels

local SpriteMap --We be recieved later in t:entered()

--========-- Map Values --========--

local MapW, MapH = math.floor(swidth*0.75), sheight --The size of the map in cells.

local MapPW, MapPH = MapW*8, MapH*8 --The map size in pixels.

local MapVW, MapVH = swidth/8, sheight/8 --The visible map space in cells.

local MapVPW, MapVPH = MapVW*8, MapVH*8 --The visible map space in pixels.

local Map = MapObj(MapW, MapH)

local mapdx, mapdy = 0,0 --Map drawing offsets.

local bgsprite = eapi.editorsheet:extract(59):image() --The background image sprite.
local bgquad = bgsprite:quad(0,0,MapVPW,MapVPH) --The quad of the background image.

--=======-- GUI VARIABLES --=======--

local selectedTool = 0
local selectedSlot = 4

local toolbarGrid = {swidth-9,8,9,sheight-8,1,15}

local hotbarTiles = {0,22,23,73,46,47,48,70,71,49}

local mapRect = {0,8,swidth-8,sheight-8}

--=========-- Functions --=========--

function t:entered()
  SpriteMap = eapi.leditors[eapi.editors.sprite].SpriteMap
  eapi:drawTopBar()
  self:redraw()
end

function t:redraw()
  self:drawMap()
end

function t:drawToolbar()
  eapi:drawTopBar()
  
  --Draw the background
  rect(swidth-9,8, 9,sheight-8, false, 0)
  
  --Draw the hotbar tiles
  for i=0,9 do
    local sprid = hotbarTiles[i+1]
    
    if sprid == 0 then
      eapi.editorsheet:draw(120, swidth-8,8+i*8)
    else
      SpriteMap:draw(sprid, swidth-8,8+i*8)
    end
  end
  
  --Draw the tools
  rect(swidth-9,sheight-5*8,8,5*8, false, 9)
  for i=0,4 do
    local sprid = 114+i
    
    if i == selectedTool then sprid = sprid + 24 end
    
    eapi.editorsheet:draw(sprid,swidth-8,sheight-5*8+i*8)
  end
  
  --Draw hotbar selection box
  rect(swidth-9,8*selectedSlot-1, 10,10, true, 1)
  rect(swidth-11,8*selectedSlot-3, 12,14, true, 1)
  rect(swidth-10,8*selectedSlot-2, 11,12, true, 7)
end

function t:drawMap()
  --Clip to map area
  clip(0,8,swidth-9,sheight-8)
  
  --Draw the background.
  rect(0,8,swidth-9,sheight-8, false,0)
  pal(1,2) --Change blue to red.
  bgsprite:draw(0,8, 0,1,1, bgquad)
  pal() --Reset blue to blue.
  local bgx, bgy = 0,0
  if -mapdx < 0 then bgx = mapdx end
  if -mapdy < 0 then bgy = mapdy end
  if -mapdx > MapPW-MapVPW then bgx = MapPW-MapVPW+mapdx end
  if -mapdy > MapPH-MapVPH then bgy = MapPH-MapVPH+mapdy end
  
  clip(bgx,bgy+8,MapVPW,MapVPH)
  bgsprite:draw(0,0, 0,1,1, bgquad)
  clip(0,8,swidth-9,sheight-8)
  
  --Draw the map
  Map:draw(mapdx%8-8,mapdy%8,-math.floor(mapdx/8)-1,-math.floor(mapdy/8)-1,MapVW+1,MapVH+1, 1,1, SpriteMap)
  
  --Declip
  clip()
  
  --Draw the toolbar
  self:drawToolbar()
end

function t:selectTool(id)
  selectedTool = id
  self:drawToolbar()
end

function t:selectSlot(id)
  selectedSlot = id
  self:drawMap()
end

function t:nextSlot()
  self:selectSlot(id%10+1)
end

function t:prevSlot()
  self:selectSlot((id+8)%10+1)
end

local tbmouse = false

function t:toolbarmouse(x,y,it,state)
  local cx, cy = whereInGrid(x,y,toolbarGrid)
  if cx then
    if state == "pressed" and not it then
      tbmouse = true
    end
    
    if not it and not tbmouse then return end
    
    if cy < 11 then --Tile slots
      self:selectSlot(cy)
    else --Tool
      self:selectTool(cy-11)
    end
  end
  
  if state == "released" then tbmouse = false end
end

local mpmouse = false
local lastPX, lastPY = 0,0
local panflag = false

function t:mapmouse(x,y,it,state,dx,dy)
  if isInRect(x,y,mapRect) then
    if state == "pressed" and not it then
      mpmouse = true
    end
    
    if not it and not mpmouse then return end
    
    local cx = math.floor((x-mapdx)/8)
    local cy = math.floor((y-8-mapdy)/8)
    
    --Pencil
    if selectedTool == 0 then
      Map:cell(cx,cy,hotbarTiles[selectedSlot])
      self:drawMap()
    
    --Pan (Hand)
    elseif selectedTool == 2 then
      if state == "pressed" then
        panflag = true
      elseif state == "moved" and panflag then
        local pdx, pdy = dx+lastPX, dy+lastPY
        
        lastPX, lastPY = pdx-math.floor(pdx), pdy-math.floor(pdy)
        
        pdx, pdy = math.floor(pdx), math.floor(pdy)
        
        mapdx, mapdy = mapdx+dx, mapdy+dy
        
        
        cprint(state,mapdx,mapdy,dx,dy)
        
        self:drawMap()
      elseif state == "released" then
        panflag = false
      end
    end
  end
  
  if state == "released" then mpmouse = false end
end

function t:mousepressed(x,y,b,it)
  self:toolbarmouse(x,y,it,"pressed")
  self:mapmouse(x,y,it,"pressed")
end

function t:mousemoved(x,y,dx,dy,it)
  self:toolbarmouse(x,y,it,"moved",dx,dy)
  self:mapmouse(x,y,it,"moved",dx,dy)
end

function t:mousereleased(x,y,b,it)
  self:toolbarmouse(x,y,it,"released")
  self:mapmouse(x,y,it,"released")
end

function t:export()
  return Map:export()
end

function t:encode()
  return RamUtils.mapToBin(Map)
end

function t:import(data)
  if data then
    Map:import(data)
  else
    Map = MapObj(MapW,MapH)
  end
end

function t:decode(data)
  RamUtils.binToMap(Map,data)
end

return t