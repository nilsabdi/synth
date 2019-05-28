parse:
   ignore "space newline tab"
   entry "Template"
[
   Template { template:Segment* }

   Segment
   [
      Parse  { name:'parse'  ':' config:Config* '[' body:ParseRule*  ']' }
      Script { name:'script' ':' config:Config* '[' body:ScriptRule* ']' }
      Output { name:'output' ':' config:Config* '[' body:OutputRule* ']' }
   ]

   Config { name:Name item:RawString }


   ParseRule  { name:Name body:ParseVariant  }
   ParseVariant
   [
      Array     { '[' children:ParseVariant* ']' }
      Named     { name:Name pattern:ParseVariant }
      Anonymous { pattern:ParsePattern }
   ]
   ParsePattern  { '{' chunks:ParseChunk*  '}' }
   ParseChunk
   [
      Aliased { name:Name ':' element:ParseElement }
      Plain   { element:ParseElement }
   ]
   ParseElement
   [
      Type   { type:TokenType operators:Operator* }
      Rule   { rule:RulePath operators:Operator* }
      Tokens { tokens:String operators:Operator* }
   ]
   RulePath { rule:Name variant:VariantPart* }
   VariantPart { '.' variant:Name }

   TokenType [
      { t:"WORD" }
      { t:"NUMBER" }
      { t:"SYMBOL" }
      { t:"SPACE" }
      { t:"TAB" }
      { t:"NEWLINE" }
      { t:"BYTE" }
   ]

   ScriptRule { name:Name body:ScriptVariant }
   ScriptVariant
   [
      Array { '[' children:ScriptVariant* ']' }
      Code  { code:Method }
      Named { name:Name children:ScriptVariant }
   ]


   OutputRule { name:Name body:OutputVariant }
   OutputVariant
   [
      Array { '[' children:OutputVariant* ']' }
      Pattern  { pattern:OutputPattern }
      Named { name:Name pattern:OutputVariant }
   ]
   OutputPattern { '{' Padding? chunks:OutputChunk* Padding? '}' }
   OutputChunk   { element:OutputElement }
   OutputElement
   [
      Whitespace{ w:Whitespace }
      Newline   { Padding }
      Indent    { '>' Padding }
      Dedent    { '<' Padding }
      Interline { '^' }
      Child     { name:Interpolate }
      Chunk     { chunk:LinePart }
   ]
   Interpolate { '${' name:Name '}' }
   LinePart [
      Nested { s:Bits }
      Any    { s:AnyPart }
   ]
   AnyPart [
      { p:Whitespace }
      { p:'}'! }
   ]
   Bits { '{' Padding? bits:OutputElement* Padding?  '}' }
   Whitespace [
      { s:SPACE }
      { s:TAB }
   ]
   Padding { NEWLINE Whitespace* }


   Operator
   [
      NoneOrMore  { op:'*' }
      OneOrMore   { op:'+' }
      NoneOrOne   { op:'?' }
      AllExcept   { op:'!' }
   ]

   String
   [
      A { '"' inner:AString* '"' }
      B { "'" inner:BString* "'" }
   ]
   RawString
   [
      { '"' inner:AString* '"' }
      { "'" inner:BString* "'" }
   ]
   AString [ { e:'\\\\' } { e:'\\"' } { e:'"'! } ]
   BString [ { e:'\\\\' } { e:"\\'" } { e:"'"! } ]

   Method { '---' inner:MethodString* '---' }
   MethodString [ { e:'\\\\' } { e:'\\-' } { e:'---'! } ]


   Name { head:NameHead tail:NamePart* }
   NameHead [
      { head:WORD }
      { head:"_" }
   ]
   NamePart
   [
      { head:'_' tail:WORD }
      { head:'_' tail:NUMBER }
   ]
]

script:
[
   Name ---
      self.string = collapse(self)
   ---

   LinePart [
      Any ---
         self.s = collapse(self.s):gsub('\\', '\\\\'):gsub('"', '\\"')
      ---
   ]
]

script:
   direction "down"
[
   Segment [
      Parse ---
         for _,conf in pairs(self.config) do
            if conf.name.string == 'entry' then
               assert(not self.entry, 'entry point already specified')
               self.entry = collapse(conf.item)
            end
         end
         assert(self.entry, 'Parse segment must have an entry point')
      ---
   ]
   ParseElement ---
      local opends = ''
      if #self.operators == 0 then self.operators = {'tokens:match('} end
      for i=1, #self.operators do
         opends = opends..')'
      end
      self.opends = opends
   ---
   ParseRule ---
      self.body.pname = self.name.string
   ---
   ParseVariant
   [
      Array ---
         for _,child in ipairs(self.children) do
            child.pname = self.pname
         end
      ---
      Named ---
         self.pattern.pname = (self.pname and self.pname..'.' or '')..self.name.string
      ---
      Anonymous ---
         self.pattern.pname = self.pname
      ---
   ]
   String ---
      self.inner = collapse(self.inner):gsub(']\\=]', ']=]')
   ---
]

output:
   target 'bootc.lua'
[
   Template
   {
      require "newtokenizer"
      require "lib.iter"
      require "lib.dump"
      require "lib.stringext"
      require "errfmt"
      require "common"

      global = {}
      dent = "   "

      source = fetch(...)
      assert(source, "a source file must be specified")
      tokens = tokenize(source)
      assert(tokens, "tokenization failure")

      function indent() >
         local d = 0
         return function(offset) >
            d = d + offset
            return "\n" .. dent*d <
         end <
      end

      function inline(interline) >
         interline[1] = true return "" <
      end

      ${template}
   }

   Segment [
      Parse {
         local parse_conf = { ${config}}
         local ruleiter = function(self) >
            for n,rule in ipairs(self) do >
               if type(rule) == "table" then n,rule = next(rule) end
               local v = rule()
               if v then return v end <
            end <
         end

         tokens.ignore =  >
            iter(parse_conf.ignore:trim():split(" "))
            :map(function(e) return T(e) end) <

         R = { >
            ^${body}<
         }
         AST = R.${entry}()
         if not AST and tokens:peek() then >
            error("unexpected token:"..errfmt(tokens:getLast())) <
         end

      }
      Script {
         local script_conf = { ${config}}
         script = function(scripts, ast) >
            local direction = script_conf.direction
            for alias, child in pairs(copy(ast)) do >
               if type(child) == "table" and direction ~= "down" then >
                  script(scripts, child) <
               end
               if meta(child) and meta(child).type then >
                  local func = scripts
                  for _, t in ipairs(meta(child).type) do >
                     if type(func) == "table" then >
                        func = func[t] or findOrderedKey(func, t) <
                     end <
                  end
                  if type(func) == "function" then >
                     if type(child) == "table" and #child > 0 then >
                        for _, item in ipairs(child) do >
                           func(item, alias) <
                        end <
                     else >
                        func(child, alias) <
                     end <
                  end <
               end
               if type(child) == "table" and direction == "down" then >
                  script(scripts, child) <
               end <
            end <
         end
         S = { >
            ^${body} <
         }
         script(S, AST)

      }
      Output {
         local output_conf = { ${config}}
         local assert_node = function(node, alias) >
            if not node[alias] then >
               error("node doesn't exist: "..alias.." in "..dump(node)..":"..dump(getmetatable(node).type), 2) <
            end
            return node[alias] <
         end
         local function output(node, interline, dent) >
            if type(node) == "string" or node.meta and node.meta.__token__ then >
               return tostring(node) <
            else >
               if #node > 0 or not getmetatable(node).type then >
                  local out = {}
                  for _, node in ipairs(node) do >
                     out[#out+1] = output(node, false, dent)
                     if interline[1] then out[#out+1] = dent(0) end <
                  end
                  if interline[1] then out[#out] = nil end
                  return table.concat(out) <
               else >
                  local fn = O
                  for _, t in ipairs(getmetatable(node).type) do >
                     fn = assert(fn[t], "type "..t.." has no output")
                     if type(fn) == "function" then break end <
                  end
                  return fn(node, false, dent) <
               end <
            end <
         end
         O = { >
            ^${body} <
         }
         print(output(AST, false, indent()))

      }
   ]

   Config {${name} = [[${item}]], }


   ParseRule  {
      ${name} = setmetatable({>
         ^${body}<
      }, {__call = ruleiter});
   }
   ParseVariant
   [
      Array     {^${children}}
      Anonymous {${pattern};}
      Named     {{${name} = ${pattern}};}
   ]
   ParsePattern  {
      function() >
         local __reset__, node = tokens.curr, {}
         repeat >
            ^${chunks}
            return setmetatable(node, {type=("${pname}"):split(".")}) <
         until true

         tokens.curr = __reset__ <
      end}
   ParseChunk
   [
      Aliased {
         node.${name} = ${element}
         if not node.${name} then break end
      }
      Plain   {
         if not ${element} then break end
      }
   ]
   ParseElement
   [
      Type   {${operators}${type}${opends}}
      Rule   {${operators}R.${rule}${opends}}
      Tokens {${operators}${tokens}${opends}}
   ]
   RulePath {${rule} ${variant}}
   VariantPart {"${variant}"}

   TokenType {T"${t}"}

   ScriptRule {{${name} = ${body}};}
   ScriptVariant
   [
      Array {
         {>
            ^${children}<
         }}
      Code  {${code}}
      Named {${name} = ${children};}
   ]


   OutputRule {${name} = ${body}}
   OutputVariant
   [
      Array {{ >
         ^${children}<
      },}
      Pattern {${pattern},}
      Named {${name} = ${pattern}}
   ]
   OutputPattern {
      function(self, interline, dent) >
         local interline = interline or {false}
         local dent = dent or indent()

         return table.concat({ >
            ${chunks} <
         }) <
      end
   }
   OutputChunk   {${element}}
   OutputElement
   [
      Whitespace {"${w}",}
      Indent  {dent(1), >
      }
      Dedent  {dent(-1), <
      }
      Newline {dent(0),
      }
      Interline {inline(interline),}
      Child   {output(assert_node(self, "${name}"), interline, dent),
      }
      Chunk     {${chunk}}
   ]
   Interpolate {${name}}
   LinePart [
      Nested {"{", ${s}"}", }
      Any {"${s}",}
   ]
   AnyPart {${p}}
   Whitespace {${s}}
   Bits {${bits}}

   Operator
   [
      NoneOrMore {tokens:noneOrMore(}
      OneOrMore  {tokens:oneOrMore(}
      NoneOrOne  {tokens:noneOrOne(}
      AllExcept  {tokens:allExcept(}
   ]

   String [
      A {"${inner}"}
      B {'${inner}'}
   ]
   RawString {${inner}}
   AString {${e}}
   BString {${e}}

   Method {
      function (self, alias, segment) ${inner} end
   }
   MethodString {${e}}

   Name {${head}${tail}}
   NameHead {${head}}
   NamePart {${head}${tail}}
]