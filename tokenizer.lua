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
            "invalid token type '" .. key .. "'" .. (#options > 0 and ", did you mean: " .. options .. "?" or "")
         )
         return v
      end,
      __call = function(self, type)
         return {T = self[type]}
      end
   }
)

T = token.type

function token.new(meta, source, type, from, to, line)
   meta = meta or {}
   meta.source = source
   meta.__token__ = true
   return setmetatable(
      {
         type = type,
         lexeme = source {from, to},
      },
      {
         __type='token',
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

   error("partial must be lexeme or {<T|t|type> = opt_type, <L|l|lexeme> = opt_lexeme} got " .. dump(partial))
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

function tokenize(source, meta)
   assert(
      type(source) == "string",
      "source has to be a string, source is " .. tostring(type(source)) .. ": " .. dump(source)
   )
   local line = 1
   local curr = 1
   local last = curr
   local result = {}
   local count = 0

   if meta and meta.mode == "byte" then
      return function()
         count = count + 1
         if curr >= #source then
            return nil
         end
         curr, result = token.byte(meta, source, curr, line)
         return count, result
      end
   else
      return function(peek)
         if curr > #source then
            return nil
         end

         if source {curr}:isletter() then
            curr, result = token.word(meta, source, curr, line)
         elseif source {curr}:isdigit() then
            curr, result = token.number(meta, source, curr, line)
         elseif source {curr}:istab() then
            curr, result = token.tab(meta, source, curr, line)
         elseif source {curr}:isspace() then
            curr, result = token.space(meta, source, curr, line)
         elseif source {curr}:iseol() then
            curr, result = token.newline(meta, source, curr, line)
            line = line + 1
         else
            curr, result = token.symbol(meta, source, curr, line)
         end

         if peek then
            curr = last
         end

         count = count + 1
         last = curr

         return count, result
      end
   end
end
