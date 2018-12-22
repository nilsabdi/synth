function collect(iter)
   local items = {}
   local k, v = iter()
   while k ~= nil do
      items[k] = v
      k, v = iter()
   end
   return items
end

function table.filter(array, condition)
   assert(type(array) == "table", "can only filter tables")
   local new = {}

   if type(condition) == 'function' then
      for i, v in pairs(array) do
         if condition(i, v) then
            new[#new + 1] = v
         end
      end

   else
      for i, v in pairs(array) do
         if condition == v then
            new[#new + 1] = v
         end
      end
   end

   return new
end

function table.contains(array, condition)
   assert(type(array) == "table", "can only filter tables")
   if type(condition) == 'function' then
      for i, v in pairs(array) do
         if condition(i, v) then
            return true
         end
      end

   else
      for i, v in pairs(array) do
         if condition == v then
            return true
         end
      end
   end

   return false
end

function table.map(array, func)
   assert(type(array) == "table", "can only map tables")
   local new = {}
   for i, v in pairs(array) do
      local ret = func(v, i)
      if ret then
         new[i] = ret
      end
   end
   return new
end

function table.keys(array)
   local keys = {}
   for k,v in pairs(array) do
      keys[#keys+1] = k
   end
   return keys
end

function table.values(array)
   local values = {}
   for k,v in pairs(array) do
      values[#values+1] = v
   end
   return values
end

function table:count()
   local count = 0
   for k, v in pairs(self) do
      count = count + 1
   end
   return count
end

function iter(array)
   assert(type(array) == "table", "can only iter tables")
   local iter = {}
   local __iter__ = {curr = 1, last = 1}
   __iter__.__iter__ = __iter__

   for k, v in pairs(array) do
      iter[k] = v
   end

   __iter__.collect = collect
   __iter__.filter = table.filter
   __iter__.map = table.map
   __iter__.contains = table.contains
   __iter__.count = table.count

   function __iter__:next()
      self.__iter__.last = self.__iter__.curr > self.__iter__.last and self.__iter__.curr or self.__iter__.last
      self.__iter__.curr = self.__iter__.curr + 1
      return self[self.__iter__.curr - 1]
   end
   function __iter__:peek()
      return self[self.__iter__.curr]
   end
   function __iter__:getpos()
      return self.__iter__.curr
   end
   function __iter__:getlast()
      return self.__iter__.last
   end
   function __iter__:setpos(n)
      self.__iter__.curr = n
      self.__iter__.last = self.__iter__.curr > self.__iter__.last and self.__iter__.curr or self.__iter__.last
      return self
   end


   return setmetatable(
      iter,
      {
         __call = function(self)
            self.__iter__.last = self.__iter__.curr > self.__iter__.last and self.__iter__.curr or self.__iter__.last
            self.__iter__.curr = self.__iter__.curr + 1
            return self[self.__iter__.curr - 1]
         end,
         __index = __iter__
      }
   )
end
