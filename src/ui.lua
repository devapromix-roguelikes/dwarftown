module('ui', package.seeall)

require 'tcod'
require 'map'
require 'mob'
require 'item'
require 'util'

local C = tcod.color

T = require "BearLibTerminal"

SCREEN_W = 80
SCREEN_H = 25

VIEW_W = 48
VIEW_H = 23

STATUS_W = 29
STATUS_H = 12

MESSAGES_W = 30
MESSAGES_H = 10

coloredMem = false

messages = {}

gametitle = 'Dwarftown v1.2'
dumpfilename = 'dwarftown.character.txt'

local ord = string.byte
local chr = string.char

function setColor(color)
  T.color(T.color_from_argb(255, color.r, color.g, color.b))
end

function setBkColor(color)
  T.bkcolor(T.color_from_argb(255, color.r, color.g, color.b))
end

function putChar(x, y, char, color, bkcolor)
   setBkColor(bkcolor)
   setColor(color)
   T.put(x, y, char);
end

function init()
   messages = {}
end

function update()
   T.clear()
   drawMap(map.player.x, map.player.y)
   drawMessages()
   drawStatus(map.player)
   T.refresh()
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
      msg.color = a or C.white
   end
   msg.text = util.capitalize(msg.text)
   table.insert(messages, msg)
   drawMessages()
end

-- ui.prompt({K.ENTER, K.KPENTER}, '[[Game over. Press ENTER]]')
function prompt(keys, ...)
   message(...)
   update()
   newTurn()
   while true do
      repeat until T.has_input()
      local key = T.read()
      for _, k in ipairs(keys) do
         if k == key then
            return k
         elseif not k then
            return false
         end
      end
   end
end

function promptYN(...)
   local result = prompt({T.TK_Y, false}, C.green, ...)
   return result == T.TK_Y
end

function promptEnter(...)
   prompt({T.TK_ENTER, T.TK_RETURN}, C.yellow, ...)
end

function promptItems(player, items, ...)
   update()
   local text = string.format(...)
   T.clear_area(1,1,VIEW_W, #items + 2)
   setColor(C.white)
   T.print(1, 1, text)
   local v = ('%d/%d'):format(#player.items, player.maxItems)
   T.print(VIEW_W - #v + 1, 1, v)

   local letter = ord('a')
   for i, it in ipairs(items) do
      local s
      local color
      if it.artifact then
         color = C.lightGreen
      else
         color = C.white
      end
      if it.equipped then
         s = ('%c *   %s'):format(letter+i-1, it.descr)
      else
         color = color * 0.5
         s = ('%c     %s'):format(letter+i-1, it.descr)
      end
      setColor(color)
      T.print(1, i+2, s)

      local char, color = glyph(it.glyph)
      putChar(5, i+2, char, color, C.black)
	end
   T.refresh()
   repeat until T.has_input()
   local key = T.read()
   if key >= T.TK_A and key <= T.TK_Z then
      local i = key - T.TK_A + 1
      if items[i] then
         return items[i]
      end
   end
end

function stringItems(items)
   local lines = {}
   for i, it in ipairs(items) do
      local letter = ord('a') - 1 + i
      local s
      if it.equipped then
         s = ('%c * %s %s'):format(letter, it.glyph[1], it.descr)
      else
         s = ('%c   %s %s'):format(letter, it.glyph[1], it.descr)
      end
      table.insert(lines, s)
   end
   return table.concat(lines, '\n')
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
   local sectorName, sectorColor
   if sector then
      sectorName = sector.name
      sectorColor = sector.color
   end
   local lines = {
      {sectorColor or C.white, sectorName or ''},
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

   T.clear_area(1+VIEW_W+1, 1, STATUS_W, STATUS_H)
   setColor(C.lightGrey)
   for i, msg in ipairs(lines) do
      local s
      if type(msg[1]) == 'string' then
         setColor(C.lightGrey)
         s = string.format(unpack(msg))
      else
        setColor(msg[1])
         s = string.format(unpack(msg, 2))
      end
      T.print(1+VIEW_W+1, i, s)
   end

   if player.hp < player.maxHp then
      local c = C.green
	  if player.hp < player.maxHp * .66 then
	     c = C.yellow
	  end
	  if player.hp < player.maxHp * .33 then
	     c = C.red
      end
      drawHealthBar(3, player.hp / player.maxHp, c)
   end

   if player.enemy then
      local m = player.enemy
      if m.x and m.visible and
         map.dist(player.x, player.y, m.x, m.y) <= 2
      then
	      local f = ('%s (%d/%d)'):format(m.descr, m.hp, m.maxHp)
         local s = ('L%d %-18s %s'):format(
            m.level, f, dice.describe(m.attackDice))
         setColor(m.glyph[2])
         T.print(1+VIEW_W+1, STATUS_H-1, s)
         if m.hp < m.maxHp then
            drawHealthBar(STATUS_H-1, m.hp/m.maxHp, m.glyph[2])
         end
      else
         player.enemy = nil
      end
   end
end

function drawHealthBar(y, fract, color)
   color = color or C.white
   local health = math.ceil((STATUS_W-2) * fract)
   putChar(1+VIEW_W+1, y+1, '[[', C.grey, C.black)
   putChar(1+VIEW_W+1+STATUS_W - 1, y+1, ']]', C.grey, C.black)
   for i = 1, STATUS_W-2 do
      if i - 1 < health then
         putChar(1+VIEW_W+1+i, y+1, ord('*'), color, C.black)
      else
         putChar(1+VIEW_W+1+i, y+1, ord('-'), C.grey, C.black)
      end
   end
end

function drawMessages()
   T.bkcolor('black')
   T.clear_area(1+VIEW_W+1, 1+STATUS_H+1, MESSAGES_W, MESSAGES_H)

   local y = MESSAGES_H
   local i = #messages

   while y > 0 and i > 0 do
      local msg = messages[i]
      local color = msg.color
      if not msg.new then
         color = color * 0.6
      end
      setColor(color)
      local lines = splitMessage(msg.text, MESSAGES_W)
      for i, line in ipairs(lines) do
         local y1 = y - #lines + i - 1
         if y1 >= 0 then
            T.print(1+VIEW_W+1, 1+STATUS_H+1+y1, line);
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
   T.clear_area(1, 1, VIEW_W, VIEW_H)
   for xv = 0, VIEW_W-1 do
      for yv = 0, VIEW_H-1 do
         local x = xv - xc + xPos
         local y = yv - yc + yPos
         local tile = map.get(x, y)
         if not tile.empty then
            local char, color = tileAppearance(tile)
            putChar(xv+1, yv+1, char, color, C.black)
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
            color = color * 0.7

            --[[
            local sat = color:getSaturation()
            local val = color:getValue()
            color = tcod.Color(color.r,color.g,color.b)
            color:setSaturation(sat*0.8)
            color:setValue(val*0.7)
            --]]
         end
      end
   else
      char, color = glyph(tile.memGlyph)
      if coloredMem then
         if tile.memLight == 0 then
            color = color * 0.35
         else
            color = color * 0.6
         end
      else
         if tile.memLight == 0 then
            color = C.darkerGrey * 0.6
         else
            color = C.darkerGrey
         end
      end
   end

   return char, color
end

function look()
   -- on-screen center
   local xc = math.floor(VIEW_W/2)
   local yc = math.floor(VIEW_H/2)
   -- on-map center
   local xPos, yPos = map.player.x, map.player.y
   -- on-screen cursor position
   local xv, yv = xc, yc

   local savedMessages = messages
   messages = {}

   ui.message('Look mode: use movement keys to look, ' ..
              'Alt-movement to jump.')
   ui.message('')
   local messagesLevel = #messages
   while true do

      -- Draw highlighted character
      local char = T.pick(xv+1, yv+1)
      local color = T.pick_color(xv+1, yv+1)
      --local tile = map.get(xv+1, yv+1)
      if char == 0 or char == 32 then
         color = 'grey'
         char = 32
      end

      T.bkcolor(color)
      T.color('black')
      T.put(xv+1, yv+1, char);

      -- Describe position
      local x, y = xv - xc + xPos, yv - yc + yPos
      describeTile(map.get(x, y))

      T.refresh()

      -- Clean up
      T.bkcolor('black')
      T.color(color)
      T.put(xv+1, yv+1, char);

      while #messages > messagesLevel do
         table.remove(messages, #messages)
      end

      -- Get keyboard input
      repeat until T.has_input()
      local key = T.read()
      local cmd = game.getCommand(key)
      if type(cmd) == 'table' and cmd[1] == 'walk' then
         local dx, dy = unpack(cmd[2])

         if T.check(T.TK_ALT) then
            dx, dy = dx*10, dy*10
            dx, dy = dx*10, dy*10
         end

         if 0 <= xv+dx and xv+dx < VIEW_W and
            0 <= yv+dy and yv+dy < VIEW_H
         then
            xv, yv = xv+dx, yv+dy
         else -- try to scroll instead of moving the cursor
            if 0 <= xPos+dx and xPos+dx < map.WIDTH and
               0 <= yPos+dy and yPos+dy < map.HEIGHT
            then
               xPos = xPos + dx
               yPos = yPos + dy
               drawMap(xPos, yPos)
            end
         end
      elseif key ~= T.TK_SHIFT and key ~= T.TK_ALT and key ~= T.TK_CONTROL then
         break
      end
   end

   messages = savedMessages
   T.refresh()
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

helpText = [[
--- Dwarftown ---

Dwarftown was once a rich, prosperous dwarven fortress. Unfortunately, a long
time ago it has fallen, conquered by goblins and other vile creatures.

Your task is to find Dwarftown and recover two legendary dwarven Artifacts
lost there. Good luck!

--- Keybindings ---

Move:  numpad,             Inventory:     i
       arrow keys,         Pick up:       g
                           Drop:          d
Wait:  5                   Quit:          Esc
Look:  x                   Help:          h
                           Last messages: m

--- Character dump ---

The game saves a character dump to ]]..dumpfilename..' file.'

function getTitleScreen()
   return {
      gametitle,
      '',
      'by hmp <humpolec@gmail.com>',
      '',
      '',
      'Press any key to continue',
   }
end

function getLoadingScreen()
   local sc = getTitleScreen()
   sc[6] = 'Creating the world, please wait...'
   return sc
end

function help()
   T.clear()
   setColor(C.lighterGrey)
   T.print(1, 1, helpText)
   T.refresh()
   repeat until T.has_input()
end

function lastMessages()
   setColor(C.lighterGrey)
   T.bkcolor('black')
   T.clear()
   T.print(1, 1, '--- Last messages ---')

   local j = 3
   for i = 1, 21 do
      local n = #ui.messages-21+i
      if ui.messages[n] then
         T.print(1, j, messages[n].text)
         j = j + 1
      end
   end

   T.refresh()
   repeat until T.has_input()
end

function screenshot()
   --tcod.system.saveScreenshot(nil)
end

function stringScreenshot()
   local lines = {}

   for y = 0, SCREEN_H-1 do
      local line = ''
      for x = 0, SCREEN_W-1 do
         local s = T.pick(x, y)
         if s == 0 then
            s = 32
         end
         line = line .. chr(s)
      end
      table.insert(lines, line)
   end

   local sep = ''
   for x = 0, SCREEN_W-1 do
      sep = sep .. '-'
   end
   table.insert(lines, sep)
   table.insert(lines, 1, sep)

   return table.concat(lines, '\n')
end

---[[
function mapScreenshot()
   --local con = tcod.Console(map.WIDTH, map.HEIGHT)
   --con:clear()
   ---[[
   for x = 0, map.WIDTH-1 do
      for y = 0, map.HEIGHT-1 do
         --print(x,y)
         local tile = map.get(x, y)
         if not tile.empty then
            local char, color = tileAppearance(tile)
            con:putCharEx(x, y, char, color, C.black)
         end
      end
   end
   --]]
   --local image = tcod.Image(con)
   --print(con:getWidth(), con:getHeight())
   --image:refreshConsole(con)
   --image:save('map.png')
end
--]]

function drawScreen(sc)
   T.clear()
   local start = math.floor((SCREEN_H-#sc-1)/2)
   local center = math.floor(SCREEN_W/2)
   for i, line in ipairs(sc) do
      if type(line) == 'table' then
         local color
         color, line = unpack(line)
         setColor(color)
      end
      T.print(center, start+i-1, 0, 0, T.TK_ALIGN_CENTER, line)
   end
   T.refresh()
end
