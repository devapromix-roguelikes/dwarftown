module('ui', package.seeall)

require 'tcod'
require 'map'
require 'util'

local C = tcod.color

SCREEN_W = 80
SCREEN_H = 25

VIEW_W = 48
VIEW_H = 23

STATUS_W = 29
STATUS_H = 10

MESSAGES_W = 30
MESSAGES_H = 12

local viewConsole
local messagesConsole
local rootConsole
local statusConsole

local messages

local ord = string.byte

function init()
   tcod.console.setCustomFont(
      'fonts/terminal10x18.png', tcod.FONT_LAYOUT_ASCII_INROW)
   tcod.console.initRoot(
      SCREEN_W, SCREEN_H, 'Dwarftown', false, tcod.RENDERER_SDL)
   rootConsole = tcod.console.getRoot()
   viewConsole = tcod.Console(VIEW_W, VIEW_H)
   messagesConsole = tcod.Console(MESSAGES_W, MESSAGES_H)
   statusConsole = tcod.Console(STATUS_W, STATUS_H)

   messages = {}
end

function update()
   rootConsole:clear()
   drawMap(map.player.x, map.player.y)
   drawMessages()
   drawStatus(map.player)
   blitConsoles()
end

function blitConsoles()
   tcod.console.blit(
      viewConsole, 0, 0, VIEW_W, VIEW_H,
      rootConsole, 1, 1)
   tcod.console.blit(
      statusConsole, 0, 0, STATUS_W, STATUS_H,
      rootConsole, 1+VIEW_W+1, 1)
   tcod.console.blit(
      messagesConsole, 0, 0, MESSAGES_W, MESSAGES_H,
      rootConsole, 1+VIEW_W+1, 1+STATUS_H+1)
   tcod.console.flush()
end

-- ui.message(color, format, ...)
-- ui.message(format, ...)
function message(a, ...)
   local msg = {new = true}
   if type(a) == 'string' then
      msg.text = string.format(a, ...)
      msg.color = C.white
   else
      msg.text = string.format(...)
      msg.color = a
   end
   msg.text = util.capitalize(msg.text)
   table.insert(messages, msg)
   drawMessages()
end

-- ui.prompt({K.ENTER, K.KPENTER}, '[Game over. Press ENTER]')
function prompt(keys, ...)
   message(...)
   update()
   newTurn()
   while true do
      local key = tcod.console.waitForKeypress(true)
      for _, k in ipairs(keys) do
         if k == key.c or k == key.vk then
            return k
         end
      end
   end
end

function promptItems(items, ...)
   update()
   local text = string.format(...)
   itemConsole = tcod.Console(VIEW_W, #items + 2)
   itemConsole:setDefaultForeground(C.white)
   itemConsole:print(0, 0, text)

   local letter = ord('a')
   for i, item in ipairs(items) do
      local s
      if item.equipped then
         itemConsole:setDefaultForeground(C.white)
         s = ('%c *   %s'):format(letter+i-1, item.descr)
      else
         itemConsole:setDefaultForeground(C.lightGrey)
         s = ('%c     %s'):format(letter+i-1, item.descr)
      end
      itemConsole:print(0, i+1, s)

      local char, color = glyph(item.glyph)
      itemConsole:putCharEx(4, i+1, char, color,
                            C.black)
   end

   tcod.console.blit(itemConsole, 0, 0, VIEW_W, #items + 2,
             rootConsole, 1, 1)
   tcod.console.flush()
   local key = tcod.console.waitForKeypress(true)
   local i = ord(key.c) - letter + 1
   if items[i] then
      return items[i]
   end
end

function newTurn()
   local i = #messages
   while i > 0 and messages[i].new do
      messages[i].new = false
      i = i - 1
   end
end

function drawStatus(player)
   local sector = map.getSector(player.x, player.y)
   local sectorName
   if sector then
      sectorName = sector.name
   end
   local lines = {
      {sectorName or ''},
      {''},
      {'Turn     %d', game.turn},
      {''}, -- line 4: health bar
      {'HP       %d/%d', player.hp, player.maxHp},
      {'Level    %d (%d/%d)', player.level, player.exp, player.maxExp},
      {'Attack   %s', dice.describe(player.attackDice)},
   }

   if player.armor ~= 0 then
      table.insert(lines, {'Armor    %s', util.signedDescr(player.armor)})
   end
   if player.speed ~= 0 then
      table.insert(lines, {'Speed    %s', util.signedDescr(player.speed)})
   end

   statusConsole:clear()
   statusConsole:setDefaultForeground(C.lightGrey)
   for i, msg in ipairs(lines) do
      statusConsole:print(0, i-1, string.format(unpack(msg)))
   end

   if player.hp < player.maxHp then
      local y = 3
      local health = math.ceil((STATUS_W-2) * player.hp / player.maxHp)
      statusConsole:putCharEx(0, y, ord('['), C.grey, C.black)
      statusConsole:putCharEx(STATUS_W - 1, y, ord(']'), C.grey, C.black)
      for i = 1, STATUS_W-2 do
         if i - 1 < health then
            statusConsole:putCharEx(i, y, ord('*'), C.white, C.black)
         else
            statusConsole:putCharEx(i, y, ord('-'), C.grey, C.black)
         end
      end
   end

end

function drawMessages()
   messagesConsole:clear()

   local y = MESSAGES_H
   local i = #messages

   while y > 0 and i > 0 do
      local msg = messages[i]

      local color = msg.color
      if not msg.new then
         color = color * 0.6
      end

      messagesConsole:setDefaultForeground(color)
      local lines = splitMessage(msg.text, MESSAGES_W)
      for i, line in ipairs(lines) do
         local y1 = y - #lines + i - 1
         if y1 >= 0 then
            messagesConsole:print(0, y1, line)
         end
      end
      y = y - #lines
      i = i - 1
   end
end

function splitMessage(text, n)
   local lines = {}
   for _, w in ipairs(util.split(text, ' ')) do
      if #lines > 0 and w:len() + lines[#lines]:len() + 1 < n then
         lines[#lines] = lines[#lines] .. ' ' .. w
      else
         table.insert(lines, w)
      end
   end
   return lines
end

function drawMap(xPos, yPos)
   local xc = math.floor(VIEW_W/2)
   local yc = math.floor(VIEW_H/2)
   viewConsole:clear()
   for xv = 0, VIEW_W-1 do
      for yv = 0, VIEW_H-1 do
         local x = xv - xc + xPos
         local y = yv - yc + yPos
         local tile = map.get(x, y)
         if not tile.empty then
            local char, color = tileAppearance(tile)
            viewConsole:putCharEx(xv, yv, char, color,
                                  C.black)
         end
      end
   end
end

function glyph(g)
   local char = ord(g[1])
   local color = g[2] or C.pink
   return char, color
end

function tileAppearance(tile)
   local char, color

   if tile.visible then
      char, color = glyph(tile:getSeenGlyph())
      if map.player.nightVision then
         if tile.seenLight > 0 then
            color = color * 2
         end
      else
         if tile.seenLight == 0 then
            color = color * 0.8
         end
      end
   else
      char, color = glyph(tile.memGlyph)
      if tile.memLight == 0 then
         color = color * 0.35
      else
         color = color * 0.6
      end
   end

   return char, color
end

function look()
   local xc = math.floor(VIEW_W/2)
   local yc = math.floor(VIEW_H/2)
   local xv, yv = xc, yc

   local savedMessages = messages
   messages = {}

   ui.message('Look mode: use movement keys to look, any other key to exit.')
   ui.message('')
   local messagesLevel = #messages
   while true do

      -- Draw highlighted character
      local char = viewConsole:getChar(xv, yv)
      local color = viewConsole:getCharForeground(xv, yv)
      if char == ord(' ') then
         color = C.white
      end

      viewConsole:putCharEx(xv, yv, char, C.black, color)

      -- Describe position
      local x, y = xv - xc + map.player.x, yv - yc + map.player.y
      describeTile(map.get(x, y))

      blitConsoles()

      -- Clean up
      viewConsole:putCharEx(xv, yv, char, color, C.black)
      while #messages > messagesLevel do
         table.remove(messages, #messages)
      end

      -- Get keyboard input
      local key = tcod.console.waitForKeypress(true)
      local cmd = game.getCommand(key)
      if type(cmd) == 'table' and cmd[1] == 'walk' then
         local dx, dy = unpack(cmd[2])
         if 0 <= xv+dx and xv+dx < VIEW_W and 0 <= yv+dy and yv+dy < VIEW_H then
            xv, yv = xv+dx, yv+dy
         end
      elseif cmd == 'quit' then
         break
      end
   end

   messages = savedMessages
   blitConsoles()
end

function describeTile(tile)
   if tile and tile.visible then
      message(tile.glyph[2], '%s.', tile.name)
      if tile.mob and tile.mob.visible then
         message(tile.mob.glyph[2], '%s.', tile.mob.descr)
      end
      if tile.items then
         for _, item in ipairs(tile.items) do
            message(item.glyph[2], '%s.', item.descr)
         end
      end
   else
      message(C.grey, 'Out of sight.')
   end
end

local helpText = [[
--- Dwarftown ---

bla bla bla

--- Keybindings ---

Move:  numpad,             Inventory:    i
       arrow keys,         Pick up:      g, ,
       yuhjklbn            Drop:         d
Wait:  5, .                Quit:         q, Esc
Look:  x                   Help:  ?
]]

function help()
   rootConsole:clear()
   rootConsole:setDefaultForeground(C.lighterGrey)
   rootConsole:print(1, 1, helpText)
   tcod.console.flush()
   tcod.console.waitForKeypress(true)
end

function screenshot()
   tcod.system.saveScreenshot(nil)
end

--[[
function mapScreenshot()
   local con = tcod.Console(20,20)--map.WIDTH, map.HEIGHT)
   for x = 0, map.WIDTH-1 do
      for y = 0, map.HEIGHT-1 do
         local tile = map.get(x, y)
         if not tile.empty then
            local char, color = tileAppearance(tile)
            con:putCharEx(x, y, char, color,
                          C.black)
         end
      end
   end
   local image = tcod.Image(con)
   image:refreshConsole(con)
   image:save('map.png')
end
--]]
