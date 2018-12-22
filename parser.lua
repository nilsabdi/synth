require "tokenizer"
require 'common'

--[[
   operators
      e?  - one or none
      e*  - none or more
      e+  - one or more
      e!  - all but e
      r.v - rule.variant
      a:e - alias:element
]]

-- process(tokens: table, template: table) -> table
function process(tokens, template, flags)
   flags = flags or {}
   local global = {file = template.__config__.file} -- oh the irony

   assert(tokens, "tokens required")
   assert(template, "language template required")

   if type(template.__config__.ignore) == 'string' then
      template.__config__.ignore =
         iter(template.__config__.ignore:trim():split(" "))
         :map(function(e)
            return T(e)
         end)
   end

   tokens.__iter__.skips = template.__config__.ignore
   tokens.__iter__.skips_off = template.__config__.ignore

   local ast
   local out
   local rout
   local entry

   for s, segment in ipairs(template) do
      if segment.__config__.type == "parse" then
         dprint('>> parse')
         entry = assert(segment.__config__.entry, "parse segments need an entry point")

         local old_ignores = tokens.__iter__.skips
         if type(segment.__config__.ignore) == 'string' then
            segment.__config__.ignore =
               iter(segment.__config__.ignore:trim():split(" "))
               :map(function(e)
                  return T(e)
               end)
         end
         tokens.__iter__.skips = segment.__config__.ignore

         assert(segment[segment.__config__.entry], 'entry point <'..segment.__config__.entry..'> does not exist')

         if type(segment[segment.__config__.entry]) == 'table' then
            for v, pattern in pairs(segment[segment.__config__.entry]) do
               local iter = iter(collect(tokenize(pattern, {file = "template"})))
               ast = parse(tokens, segment, {segment.__config__.entry, v}, iter)

               if ast then
                  setmetatable(ast, {type={segment.__config__.entry}})
                  break
               end
            end

         else
            local pattern = segment[segment.__config__.entry]
            local iter = iter(collect( tokenize(pattern, {file = "template"}) ))
            ast = parse(tokens, segment, {segment.__config__.entry, v}, iter)

            if ast then
               setmetatable(ast, {type={segment.__config__.entry}})
            end
         end

         if tokens:peek() then
            error(
               'Unexpected token'
               .. errfmt(tokens[tokens:getlast()] or tokens[tokens:getlast()-1])
            )
         end

         tokens.__iter__.skips = old_ignores
         ast = setmetatable({[entry]=ast}, {type={'<entry>'}})
      --    dprint(dump(ast, nil, false))
      end

      if segment.__config__.type == "script" then
         dprint('>> script')
         assert(entry, "a parser segment is required with an entry point to have an AST to modify with scripts")

         script(segment, ast, global)
      end

      if segment.__config__.type == "output" then
         dprint('>> output')
         out = ''
         assert(entry, "a parser segment is required with an entry point to have anything to output")

         if type(segment[entry]) == "table" then
            for v, pattern in pairs(segment[entry]) do
               assert(
                  type(v) == 'string' or #segment[entry] == 1,
                  'ambiguous unnamed output rule, name it or dont use a table\n'
                  ..'in: output -> '..__config__.entry..' -> '..v
               )
               local iter = iter(collect(tokenize(pattern, {file = "template"})))
               out = out .. output(segment, ast[entry], iter)
            end

         else
            local pattern = segment[entry]
            local iter = iter(collect(tokenize(pattern, {file = "template"})))
            out = out .. output(segment, ast[entry], iter)
         end

         if segment.__config__.target and flags.out ~= false then
            dprint('writing to', segment.__config__.target)
            local outf = assert(io.open(segment.__config__.target, 'w'))
            assert(outf:write(out))
            outf:close()
         end
         rout = rout and rout or out
      end
   end
   return rout
end

function script(segment, ast, _global)
   local direction = segment.__config__.direction
   if  direction
   and direction ~= 'up'
   and direction ~= 'down' then
      error(
         'unknown direction "'..direction
         .. '"\nsegment direction should be either "up", "down" or nil (default: "up")'
      )
   end

   global = _global

   for alias, child in pairs(copy(ast)) do
      if type(child) == 'table' and direction ~= 'down' then script(segment, child, global) end
      if meta(child) and meta(child).type then

         local func = segment

         for _, t in ipairs(meta(child).type) do
            if type(func) == 'table' then
               func = func[t] or findOrderedKey(func, t)
            end
         end

         if type(func) == 'function' then
            -- dprint(dump(func), dump(meta(child).type), dump(child.name), dump(child))
            if type(child) == 'table' and #child > 0 then
               -- dprint('ah')
               for _,item in ipairs(child) do
                  -- dprint(dump(meta(item).type), dump(item.name))
                  func(item, alias, global)
               end

            else
               -- dprint(dump(child))
               func(child, alias, global)
            end

         elseif type(func) == 'string' then
            if type(child) == 'table' and #child > 0 then
               for _,item in ipairs(child) do
                  -- dprint(dump(meta(item).type), dump(item.name))
                  -- self, alias = item, alias
                  self = item
                  assert(loadstring(func))()
               end

            else
               -- dprint(dump(child))
               -- self, alias = child, alias
               self = child
               assert(loadstring(func))()
            end

         end

      end
      if type(child) == 'table' and direction == 'down' then script(segment, child, global) end
   end
end

function output(segment, ast, pattern, dent, interline)
   pattern.__iter__.skips = {T"space", T"newline", T"tab"}
   dent = dent or {0}
   local elem = pattern:peek()
   local out = ""

   while elem do
      if pattern:check(T"word") then
         local nalias = pattern:next()
         local alias = nalias.lexeme

         if #ast > 0 then
            for _,ast in ipairs(ast) do
               -- dprint(alias, dump(meta(ast).parent))
               local child = assert(
                  ast[alias],
                  "no such child '"
                  .. alias
                  .. "' in node '"
                  .. dump(meta(ast) and meta(ast).type)
                  .. "'"
                  .. dump(meta(ast).parent[1])
               )

               if meta(child) and meta(child).type then
                  local pattern = segment
                  local typename = table.concat(meta(child).type,'.')

                  for _, t in ipairs(meta(child).type) do
                     pattern = assert(
                        pattern[t] or findOrderedKey(pattern, t),
                        "rule '"..typename.."' has no output defined " .. errfmt(nalias)
                     )
                  end

                  local iter = iter(collect(tokenize(pattern, {file = "template"})))
                  out = out..assert(output(segment, child, iter, dent, interline), "error in " .. "{" .. pattern .. "}")

               else
                  out = out..child
               end
            end

         else
            if not ast[alias] then
               dprint(dump(meta(meta(ast).parent)))
               error("no such child '" .. alias .. "' in node '" .. dump(meta(ast).type) .. "'")
            end

            local parent = ast[alias]
            -- dprint(dump(child), #child)

            if type(parent) == 'table' and #parent > 0 then
               -- dprint('inner',dump(ast))
               for _,child in ipairs(parent) do
                  if meta(child).type then
                     local pattern = segment
                     local typename = table.concat(meta(child).type,'.')

                     for _, t in ipairs(meta(child).type) do
                        if type(pattern) ~= 'string' then
                           pattern = assert(
                              pattern[t] or findOrderedKey(pattern, t),
                              "rule '"..typename.."' has no output defined "..errfmt(nalias)
                           )
                        end
                     end

                     if type(pattern) == "table" then
                        variant, pattern = next(pattern)
                     end

                     local iter = iter(collect(tokenize(pattern, {file = "template"})))
                     out = out..assert(output(segment, child, iter, dent), "error in " .. "{" .. pattern .. "}")

                     if interline and _ < #parent then
                        out = out .. '\n' .. (' '*dent[1]*dentsize)
                     end

                  else
                     out = out .. child
                  end
               end

            else
               if meta(parent) and meta(parent).type then
                  local pattern = segment
                  local typename = table.concat(meta(parent).type,'.')

                  for _, t in ipairs(meta(parent).type) do
                     pattern = assert(
                        pattern[t] or findOrderedKey(pattern, t),
                        "rule '"..typename.."' has no output defined " .. errfmt(nalias)
                     )
                  end

                  local iter = iter(collect(tokenize(pattern, {file = "template"})))
                  out = out..assert(output(segment, parent, iter, dent), "error in " .. "{" .. pattern .. "}")

               else
                  assert(
                     type(parent)=='string' or (type(parent) == 'table' and parent.meta.__token__),
                     'empty list node'..errfmt(nalias)..dump(parent)
                  )

                  -- dprint(dump(ast, nil, true))
                  out = out .. parent
               end

            end
         end

      elseif pattern:check {T = "symbol", "'"} or pattern:check {T = "symbol", '"'} then
         out = out .. pstring(pattern, pattern:next().lexeme)

      elseif pattern:match {T='symbol', '>'} then
         dent[1] = dent[1] + 1
         out = out .. '\n' .. (' '*dent[1]*dentsize)

      elseif pattern:match {T='symbol', '<'} then
         dent[1] = dent[1] - 1
         out = out .. '\n' .. (' '*dent[1]*dentsize)

      elseif pattern:match {T='symbol', '/'} then
         out = out .. '\n' .. (' '*dent[1]*dentsize)

      elseif pattern:match {T='symbol', '^'} then
         interline = true

      else
         error('unexpected token'..errfmt(pattern:next()))

      end

      elem = pattern:peek()
   end

   return out
end

-- parse(tokens:table, segment:segment, nrule:string, nvariant:string, pattern:table) -> ast:table
function parse(tokens, segment, rule, pattern)
   -- dprint('parse()')
   pattern.__iter__.skips = {T"space",T"tab",T"newline"}

   local elem = pattern:peek()
   local node = {}
   local last_token = tokens:peek()

   local save = tokens:getpos()

   while elem do
      -- capturing match
      if pattern:check(T"word", {T="symbol", ":"}) then
         local alias = pattern:next().lexeme ; pattern:skip(":")
         local branch = element(tokens, segment, rule, pattern)

         if not branch then
            tokens:setpos(save)
            return
         end

         if type(meta(branch))=='table' then
            meta(branch).parent = node
         end

         node[alias] = branch

      -- non-capturing match
      else
         if not element(tokens, segment, rule, pattern) then
            tokens:setpos(save)
            return
         end
      end

      elem = pattern:peek()

      if last_token and elem and (last_token == elem) then
         error("token iterator hasn't moved, likely a parse loop"..errfmt(last_token))
      end
   end

   return node
end

function element(tokens, segment, rule, pattern)
   -- dprint('element()')
   local element

   -- tokentype match
   if pattern:check(T'word') and pattern:peek().lexeme:isupper() then
      local typename = pattern:next().lexeme
      local ops = getops(pattern)

      if ops['*'] or ops['+'] then
         -- element = setmetatable({},{type=rule})

         repeat
            if ops['!'] then
               if not tokens:check(T(typename)) then
                  element = tokens:inext()
               end

            else
               if tokens:check(T(typename)) then
                  element = tokens:next()
               end
            end
         until not item

         if ops['*'] and #element == 0 then
            element = ''
         -- else
         --    element = nil
         end

      else
         if ops['!'] then
            if not tokens:check(T(typename)) then
               element = tokens:inext()
            end

         else
            if tokens:check(T(typename)) then
               element = tokens:next()
            end
         end
      end

   -- string match
   elseif pattern:check{T="symbol", "'"} or pattern:check{T="symbol", '"'} then
      local tokenstr = collect(tokenize(pstring(pattern, pattern:next().lexeme)))
      local ops = getops(pattern)
      -- dprint(dump(tokenstr), dump(ops), dump(pattern), dump(pattern:peek()))

      -- none-or-more OR one-or-more
      if ops['*'] or ops['+'] then
         element = setmetatable({},{type=rule})
         -- element = {}

         repeat
            -- all-except
            if ops['!'] then
               tokens:skip_off()
               if not tokens:check(unpack(tokenstr)) then
                  item = tokens:next()
                  element[#element+1] = item
                  tokens:skip_on()

               else
                  tokens:skip_on()
                  break
               end

            else
               local save = tokens:getpos()

               if tokens:match(unpack(tokenstr)) then
                  local last = tokens:getpos() ; tokens:setpos(save)
                  item = {}

                  while tokens:getpos() ~= last do
                     item[#item+1] = tokens:next()
                  end

                  element[#element+1] = item
                  -- dprint(dump(item))
               end
            end
            -- dprint(item)
         until not item

         if ops['*'] and #element == 0 then
            element = ''
         else
            element = nil
         end

      else
         -- all-except
         if ops['!'] then
            tokens:skip_off()
            if not tokens:check(unpack(tokenstr)) then
               element = tokens:next()
            end
            tokens:skip_on()

         else
            local save = tokens:getpos()
            if tokens:match(unpack(tokenstr)) then
               local last = tokens:getpos() ; tokens:setpos(save)
               element = {}
               while tokens:getpos() ~= last do
                  element[#element+1] = tokens:next()
               end
               -- dprint(dump(element))
            end
         end
      end

   -- rule match
   elseif pattern:check(T'word') then
      local erule = getrule(pattern)
      local ops = getops(pattern)
      local pattern = getpattern(segment, erule)
      -- dprint(dump(erule))

      -- none-or-more OR one-or-more
      if ops['*'] or ops['+'] then
         -- element = setmetatable({},{type=erule})
         element = {}

         repeat
            local item = apply(tokens, segment, erule, pattern)

            -- all-except-element
            if ops['!'] then
               if item then
                  -- matched element, return nothing
                  item = nil
               else
                  -- didn't match element, return the next token
                  item = tokens:inext()
               end
            end

            if type(meta(item))=='table' then
               meta(item).parent = element
            end

            element[#element+1] = item
         until not item

         if ops['*'] and #element == 0 then
            element = ''
         end

         -- dprint(dump(element))

      else
         element = apply(tokens, segment, erule, pattern)

         -- all-except-element
         if ops['!'] then
            if element then
               -- matched element, return nothing
               element = nil
            else
               -- didn't match element, return the next token
               element = tokens:inext()
            end
         end
      end
   end

   return element
end

function apply(tokens, segment, rule, pattern)
   if type(pattern) == 'string' then
      local ret = parse(tokens, segment, rule, iter(collect(tokenize(pattern))))
      if ret then
         -- dprint(dump(rule))
         return setmetatable(ret,{type=rule})
      end

   else
      for name,child in pairs(pattern) do
         -- dprint(dump(name), dump(child))
         -- dprint(dump(name))

         local ret = apply(
            tokens,
            segment,
            {[#rule+1]=type(name)=='string' and name or nil,unpack(rule)},
            child
         )
         if ret then return ret end
      end
   end
end

function getrule(pattern)
   -- dprint('getrule()')
   if pattern:check(T'word') then
      local path = {pattern:next().lexeme}
      while pattern:match{T='symbol','.'} do
         assert(pattern:check(T'word'), 'expected subpath after .')
         path[#path+1] = pattern:next().lexeme
      end
      return path
   end
end

function getpattern(segment, rule)
   local pattern = segment
   for _, child in ipairs(rule) do
      pattern = assert(
         pattern[child] or findOrderedKey(pattern, child),
         'no such rule in segment: '..child
      )
   end
   return pattern
end

function getops(pattern)
   -- dprint('getops()')
   local knownops = {'*','+','?','!'}
   local xor = {{'*','+','?'}}
   local operators = {}

   -- dprint(dump(pattern))
   while pattern:check(T'symbol') do
      local op = pattern:peek()
      if not table.contains(knownops, op.lexeme) then
         break
      end

      pattern:next()
      if operators[op.lexeme] then
         error(
            'operator already specified'
            ..errfmt(operators[op.lexeme])
            ..errfmt(op))
      end
      operators[op.lexeme] = op
   end

   for _, group in ipairs(xor) do
      for a=0, #group-1 do
         for b=a+1, #group do
            if operators[group[a]] and operators[group[b]] then
               error(
                  'only one of '..dump(table.keys(operators))..' can be used at a time'
                  ..errfmt(operators[group[a]])
                  ..errfmt(operators[group[b]]))
            end
         end
      end
   end

   return operators
end


-- pstring(pattern:table) -> string
function pstring(pattern, delim)
   local str = ""
   -- unset ignores to capture everything
   local save = pattern:getpos()-1
   local ignores = pattern.__iter__.skips
   pattern.__iter__.skips = {}

   while not pattern:match(delim) do
      if not pattern:peek() then
         error('unclosed string'..errfmt(pattern:setpos(save):peek()))
      end

      if pattern:match("\\") then
         local sym = pattern:next().lexeme

         if sym:starts("n") then
            str = str .. "\n"
            str = str .. sym:sub(2)
         elseif sym:starts("t") then
            str = str .. "\t"
            str = str .. sym:sub(2)
         elseif sym:starts("0") then
            str = str .. "\0"
            str = str .. sym:sub(2)
         elseif sym:starts("e") then
            str = str .. "\27"
            str = str .. sym:sub(2)
         else
            str = str .. sym
         end
      else
         str = str .. pattern:next().lexeme
      end
   end
--   pattern:next()
   -- reset ignores
   pattern.__iter__.skips = ignores

   return str
end

function synth(source, template, flags)
   return process(iter(collect(tokenize(source))), template, flags)
end


function main()
   __debug__ = true

   local in_version = fetch('version') or 'boota'
   local out_version = in_version == 'boota' and 'bootb' or 'boota'

   dprint('?? '..in_version..'.lua + '..out_version..'.st'..' -> '..out_version..'.lua')

   in_template = require(in_version)
   -- out_template = require(out_version)

   -- print(">> input",'\n'..input,'\n\n>>output')
   synth(fetch(out_version..'.st'), in_template)

   dprint('?? '..out_version..'.lua + '..in_version..'.st'..' -> '..'validate: '..in_version..'.lua')
   out_template = require(out_version)
   local succ, state = pcall(synth, fetch(in_version..'.st'), out_template, {out=false})

   if succ then
      dprint('?? validating Lua syntax')
      if loadstring(state) then
         f = io.open('version', 'w+')
         f:write(out_version)
         f:close()
      else
         dprint('?? result is not valid lua, dump in failure.lua')
         f = io.open('failure.lua', 'w+')
         f:write(state)
         f:close()
         local _,err = loadfile('failure.lua')
         dprint('!! '..err)
      end
   else
      print(state)
   end

   print("\n>> done")
end

main()

-- custom operators
-- parse: operator { |:Rule }