module('item', package.seeall)

require 'tcod'
require 'class'
require 'util'

local C = tcod.color

Item = class.Object:subclass {
   glyph = {'?'},
   name = '<item>',
}

function Item.get:descr()
   return self.name
end

function Item.get:descr_a()
   return util.descr_a(self.descr)
end

function Item.get:descr_the()
   return util.descr_the(self.descr)
end

Weapon = Item:subclass {
   slot = 'weapon',
}

function Weapon.get:descr()
   return ('%s (%s)'):format(
      Item.get.descr(self),
      dice.describe(self.attackDice))
end

Sword = Weapon:subclass {
   glyph = {'(', C.lightGrey},
   name = 'sword',

   attackDice = {1, 6, 0},
}

Armor = Item:subclass {
   armor = 0,
}

function Armor.get:descr()
   return ('%s [+%d]'):format(
      Item.get.descr(self),
      self.armor)
end

function Armor:onEquip(player)
   player.armor = player.armor + self.armor
end

function Armor:onUnequip(player)
   player.armor = player.armor - self.armor
end

Helmet = Armor:subclass {
   armor = 1,
   slot = 'helmet',
}
