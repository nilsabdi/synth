require "lib.dump"
require "lib.stringext"
require "lib.iter"

token = {}

token.type =
   setmetatable(
   {
      word = "word",
      number = "number",
      symbol = "symbol",
      space = "space",
      tab = "tab",
      newline = "newline",
      byte = "byte"
   },
   {
      __index = function(self, key)
         local v = rawget(self, key:lower())
         local options = ""
         if v == nil then
            for option in pairs(self) do
               if option:similar(key) then
                  options = options .. option .. ", "
               end
            end
            options = options:sub(1, -3)
         end
         assert(
            v ~= nil,
            "invalid token type '" ..
               key .. "'" .. (#options > 0 and ", did you mean: " .. options .. "?" or "")
         )
         return v
      end,
      __call = function(self, type)
         return {T = self[type], meta = {__tokentype__ = true}}
      end
   }
)

T = token.type

function token.new(meta, source, type, from, to, line)
   meta = meta or {}
   meta.source = function()
      return source
   end
   meta.__token__ = true
   return setmetatable(
      {
         type = type,
         lexeme = source {from, to}
      },
      {
         __tostring = function(self)
            return self.lexeme
         end,
         __concat = function(self, other)
            return tostring(self) .. tostring(other)
         end,
         __index = {
            pos = {
               from = from,
               to = to,
               line = line
            },
            meta = meta,
            eq = token.eq
         }
      }
   )
end

function token:eq(partial)
   assert(partial, "partial is nil")

   if type(partial) == "string" then -- lexeme
      return self.lexeme == partial
   elseif type(partial) == "table" then -- combo
      local t = partial.T or partial.t or partial.type
      local l = partial[1] or partial.l or partial.L or partial.lexeme

      if t and l then
         return self.lexeme == l and self.type == t -- type and lexeme
      elseif l then
         return self.lexeme == l -- lexeme
      elseif t then
         return self.type == t -- type
      end
   end

   error(
      "partial must be lexeme or {<T|t|type> = opt_type, <L|l|lexeme> = opt_lexeme} got " ..
         dump(partial)
   )
end

function token.word(meta, source, curr, line)
   local last = curr
   while source {curr}:isletter() do
      curr = curr + 1
   end
   return curr, token.new(meta, source, token.type.word, last, curr, line)
end
function token.number(meta, source, curr, line)
   local last = curr
   while source {curr}:isdigit() do
      curr = curr + 1
   end
   return curr, token.new(meta, source, token.type.number, last, curr, line)
end
function token.tab(meta, source, curr, line)
   return curr + 1, token.new(meta, source, token.type.tab, curr, curr + 1, line)
end
function token.space(meta, source, curr, line)
   return curr + 1, token.new(meta, source, token.type.space, curr, curr + 1, line)
end
function token.newline(meta, source, curr, line)
   local len = source {curr, curr + 2} == "\r\n" and 2 or 1
   return curr + len, token.new(meta, source, token.type.newline, curr, curr + len, line)
end
function token.symbol(meta, source, curr, line)
   return curr + 1, token.new(meta, source, token.type.symbol, curr, curr + 1, line)
end
function token.byte(meta, source, curr, line)
   return curr + 1, token.new(meta, source, token.type.byte, curr, curr + 1, line)
end

local TokenIter = {
   __index = {
      curr = 1,
      last = 1,
      ignore = {},
      inext = function(self)
         self.last = self.curr > self.last and self.curr or self.last
         self.curr = self.curr + 1
         return self[self.curr - 1]
      end,
      next = function(self)
         while 0 <
            #table.filter(
               self.ignore,
               function(_, elem)
                  return self[self.curr] and self[self.curr]:eq(elem)
               end
            ) do
            self:inext()
         end
         return self:inext()
      end,
      peek = function(self)
         local save = self.curr
         local next = self:next()
         self.curr = save
         return next
      end,
      get = function(self, off)
         return self[self.curr + off]
      end,
      getLast = function(self)
         return self[self.last]
      end,
      skip = function(self, ...)
         while self:match(...) do
         end
         return self
      end,
      check = function(self, ...)
         local save = self.curr
         local matches = self:match(...)
         self.curr = save
         return matches
      end,
      match = function(self, ...)
         -- string for lexeme, {lexeme, T=string} for type and/or lexeme
         local save = self.curr
         local matches = {}

         local elems = {...}
         if #elems == 1 and type(elems[1]) == "string" then
            -- print(dump(elems), dump(tokenize(elems[1])))
            elems = iter(tokenize(elems[1])):map(function(e) return tostring(e) end)
         end

         for _, elem in ipairs(elems) do
            if
               type(elem) == "string" or
                  (type(elem) == "table" and elem.meta and elem.meta.__token__) or
                  (type(elem) == "table" and elem.meta and elem.meta.__tokentype__)
             then
               local tok = self:inext()

               if not tok then
                  self.curr = save
                  return
               end

               while tok and not tok:eq(elem) do
                  local skipped = false

                  -- try skipping tokens
                  for _, skip in pairs(self.ignore) do
                     if tok:eq(skip) then
                        skipped = true
                        tok = self:inext()

                        if not tok then
                           self.curr = save
                           return
                        end

                        -- skipped, try matching again
                        break
                     end
                  end

                  -- token didn't match and nothing got skipped
                  if not skipped then
                     self.curr = save
                     return
                  end
               end

               matches[#matches + 1] = tok
            else
               local e = elem(tokens)
               if not e then
                  self.curr = save
                  return
               else
                  return e
               end
            end
         end

         return #matches > 1 and matches or matches[1]
      end,
      noneOrMore = function(self, ...)
         local matches = {}
         local match
         repeat
            match = self:match(...)
            matches[#matches + 1] = match
         until not match
         return #matches > 0 and matches or ""
      end,
      oneOrMore = function(self, ...)
         local save = self.curr
         local matches = self:noneOrMore(...)
         if #matches > 0 then
            return matches
         end
         self.curr = save
      end,
      noneOrOne = function(self, ...)
         local match = self:match(...)
         return match or ""
      end,
      allExcept = function(self, ...)
         local skip = self.ignore
         self.ignore = {}

         local exception = self:check(...)
         self.ignore = skip

         if not exception then
            return self:inext()
         end
      end
   }
}

function tokenize(source, meta)
   assert(
      type(source) == "string",
      "source has to be a string, source is " ..
         tostring(type(source)) .. ": " .. dump(source)
   )
   local line = 1
   local curr = 1
   local last = curr
   local result = setmetatable({}, TokenIter)
   local count = 0

   if meta and meta.mode == "byte" then
      while curr <= #source do
         curr, result[#result + 1] = token.byte(meta, source, curr, line)
      end
   else
      while curr <= #source do
         if source {curr}:isletter() then
            curr, result[#result + 1] = token.word(meta, source, curr, line)
         elseif source {curr}:isdigit() then
            curr, result[#result + 1] = token.number(meta, source, curr, line)
         elseif source {curr}:istab() then
            curr, result[#result + 1] = token.tab(meta, source, curr, line)
         elseif source {curr}:isspace() then
            curr, result[#result + 1] = token.space(meta, source, curr, line)
         elseif source {curr}:iseol() then
            curr, result[#result + 1] = token.newline(meta, source, curr, line)
            line = line + 1
         else
            curr, result[#result + 1] = token.symbol(meta, source, curr, line)
         end
      end
   end
   return result
end
