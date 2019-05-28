local _iter = iter
dentsize = 3
__debug__=true
function meta(node)
   return getmetatable(node)
end

require 'errfmt'

function findOrderedKey(table, key)
   for _, item in pairs(table) do
      if type(item) == 'table' and item[key] then
         return item[key]
      end
   end
end

function dprint(...)
   if __debug__ then
      io.stderr:write('['..debug.getinfo(2).short_src..'|'..debug.getinfo(2).currentline..'] ')
      io.stderr:write(...)
      io.stderr:write("\n")
   end
end

function iter(tokens)
   local it = _iter(tokens)
   local it_index = meta(it).__index

   -- auto skip tokens
   it_index.__iter__.skips = {}

   it_index.inext = it_index.next
   it_index.ipeek = it_index.peek

   function it_index:next()
      while 0 <
         #table.filter(
            self.__iter__.skips,
            function(_, elem)
               return self:ipeek() and self:ipeek():eq(elem)
            end
         ) do
         self:inext()
      end
      return self:inext()
   end

   function it_index:peek()
      local save = self:getpos()
      local next = self:next()
      self:setpos(save)
      return next
   end

   function it_index:get(off)
      return self[self.__iter__.curr + off]
   end

   function it_index:skip(...)
      while self:match(...) do end
      return self
   end

   function it_index:skip_off()
      self.__iter__.skips_off = self.__iter__.skips
      self.__iter__.skips = {}
   end

   function it_index:skip_on()
      self.__iter__.skips = self.__iter__.skips_off
   end

   function it_index:check(...)
      local save = self:getpos()
      local matched = self:match(...)
      self:setpos(save)
      return matched
   end

   function it_index:match(...)
      -- string for lexeme, {lexeme, T=string} for type and/or lexeme
      local save = self:getpos()

      for _, elem in pairs {...} do
         local tok = self:inext()

         if not tok then
            return false, self:setpos(save)
         end

         while tok and not tok:eq(elem) do
            local skipped = false

            -- try skipping tokens
            for _, skip in pairs(self.__iter__.skips) do
               if tok:eq(skip) then
                  skipped = true
                  tok = self:inext()

                  if not tok then
                     return false
                  end

                  -- skipped, try matching again
                  break
               end
            end

            -- token didn't match and nothing got skipped
            if not skipped then
               self:setpos(save)
               return false
            end
         end
      end
      return true
   end
   -- dprint(dump(it,true))

   return it
end


function node(children, type, parent)
   return setmetatable(children, {type=type, parent=parent or {}})
end

function collapse(branch)
   local res = ''
   if type(branch) == 'string' then return branch end
   if branch.meta and branch.meta.__token__ then
      return branch.lexeme
   end
   for name, branch in pairs(branch) do
      if type(branch) == 'table' then
         if branch.meta and branch.meta.__token__ then
            res = res .. branch.lexeme
         else
            res = res .. collapse(branch)
         end
      else
         res = res .. branch
      end
   end
   return res
end

function clone(item)
   if type(item) == 'table' then
      local cloned = {}
      for k,v in pairs(item) do
         cloned[k] = clone(v)
      end
      return cloned
   end
   return item
end

function copy(item)
   if type(item) == 'table' then
      local copied = {}
      for k,v in pairs(item) do
         copied[k] = v
      end
      return copied
   end
   return item
end

function move(table, keys)
   local moved = {}
   for _,key in ipairs(keys) do
      moved[key] = table[key]
      table[key] = nil
   end
   return moved
end

function fetch(file)
   local f = io.open(file, 'r')
   local out = f:read('*a')
   f:close()
   return out
end
