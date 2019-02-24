require "newtokenizer"
require "lib.iter"
require "lib.dump"
require "lib.stringext"
require "errfmt"
require "common"

global = {}
indent = "   "

source = fetch(...)
assert(source, "a source file must be specified")
tokens = tokenize(source)
assert(tokens, "tokenization failure")

local parse_conf = {ignore = [[space newline tab]], entry = [[Template]], }
local ruleiter = function(self)
   for n,rule in ipairs(self) do
      if type(rule) == "table" then n,rule = next(rule) end
      local v = rule()
      if v then return v end
   end
end

tokens.ignore = 
   iter(parse_conf.ignore:trim():split(" "))
   :map(function(e) return T(e) end)

R = {
   Template = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.template = tokens:noneOrMore(R.Segment)
            if not node.template then break end
            
            return setmetatable(node, {type=("Template"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   Segment = setmetatable({
      {Parse = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match('parse')
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.config = tokens:noneOrMore(R.Config)
            if not node.config then break end
            
            if not tokens:match('[') then break end
            
            node.body = tokens:noneOrMore(R.ParseRule)
            if not node.body then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("Segment.Parse"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Script = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match('script')
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.config = tokens:noneOrMore(R.Config)
            if not node.config then break end
            
            if not tokens:match('[') then break end
            
            node.body = tokens:noneOrMore(R.ScriptRule)
            if not node.body then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("Segment.Script"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Output = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match('output')
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.config = tokens:noneOrMore(R.Config)
            if not node.config then break end
            
            if not tokens:match('[') then break end
            
            node.body = tokens:noneOrMore(R.OutputRule)
            if not node.body then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("Segment.Output"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   Config = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            node.item = tokens:match(R.RawString)
            if not node.item then break end
            
            return setmetatable(node, {type=("Config"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   ParseRule = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            node.body = tokens:match(R.ParseVariant)
            if not node.body then break end
            
            return setmetatable(node, {type=("ParseRule"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   ParseVariant = setmetatable({
      {Array = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('[') then break end
            
            node.children = tokens:noneOrMore(R.ParseVariant)
            if not node.children then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("ParseVariant.Array"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Named = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            node.pattern = tokens:match(R.ParseVariant)
            if not node.pattern then break end
            
            return setmetatable(node, {type=("ParseVariant.Named"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Anonymous = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.pattern = tokens:match(R.ParsePattern)
            if not node.pattern then break end
            
            return setmetatable(node, {type=("ParseVariant.Anonymous"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   ParsePattern = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('{') then break end
            
            node.chunks = tokens:noneOrMore(R.ParseChunk)
            if not node.chunks then break end
            
            if not tokens:match('}') then break end
            
            return setmetatable(node, {type=("ParsePattern"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   ParseChunk = setmetatable({
      {Aliased = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.element = tokens:match(R.ParseElement)
            if not node.element then break end
            
            return setmetatable(node, {type=("ParseChunk.Aliased"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Plain = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.element = tokens:match(R.ParseElement)
            if not node.element then break end
            
            return setmetatable(node, {type=("ParseChunk.Plain"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   ParseElement = setmetatable({
      {Type = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.type = tokens:match(R.TokenType)
            if not node.type then break end
            
            node.operators = tokens:noneOrMore(R.Operator)
            if not node.operators then break end
            
            return setmetatable(node, {type=("ParseElement.Type"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Rule = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.rule = tokens:match(R.RulePath)
            if not node.rule then break end
            
            node.operators = tokens:noneOrMore(R.Operator)
            if not node.operators then break end
            
            return setmetatable(node, {type=("ParseElement.Rule"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Tokens = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.tokens = tokens:match(R.String)
            if not node.tokens then break end
            
            node.operators = tokens:noneOrMore(R.Operator)
            if not node.operators then break end
            
            return setmetatable(node, {type=("ParseElement.Tokens"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   RulePath = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.rule = tokens:match(R.Name)
            if not node.rule then break end
            
            node.variant = tokens:noneOrMore(R.VariantPart)
            if not node.variant then break end
            
            return setmetatable(node, {type=("RulePath"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   VariantPart = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('.') then break end
            
            node.variant = tokens:match(R.Name)
            if not node.variant then break end
            
            return setmetatable(node, {type=("VariantPart"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   TokenType = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.t = tokens:match("WORD")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.t = tokens:match("NUMBER")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.t = tokens:match("SYMBOL")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.t = tokens:match("SPACE")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.t = tokens:match("TAB")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.t = tokens:match("NEWLINE")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.t = tokens:match("BYTE")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   ScriptRule = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            node.body = tokens:match(R.ScriptVariant)
            if not node.body then break end
            
            return setmetatable(node, {type=("ScriptRule"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   ScriptVariant = setmetatable({
      {Array = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('[') then break end
            
            node.children = tokens:noneOrMore(R.ScriptVariant)
            if not node.children then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("ScriptVariant.Array"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Code = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.code = tokens:match(R.Method)
            if not node.code then break end
            
            return setmetatable(node, {type=("ScriptVariant.Code"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Named = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            node.children = tokens:match(R.ScriptVariant)
            if not node.children then break end
            
            return setmetatable(node, {type=("ScriptVariant.Named"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   OutputRule = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            node.body = tokens:match(R.OutputVariant)
            if not node.body then break end
            
            return setmetatable(node, {type=("OutputRule"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   OutputVariant = setmetatable({
      {Array = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('[') then break end
            
            node.children = tokens:noneOrMore(R.OutputVariant)
            if not node.children then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("OutputVariant.Array"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Pattern = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.pattern = tokens:match(R.OutputPattern)
            if not node.pattern then break end
            
            return setmetatable(node, {type=("OutputVariant.Pattern"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Named = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            node.pattern = tokens:match(R.OutputVariant)
            if not node.pattern then break end
            
            return setmetatable(node, {type=("OutputVariant.Named"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   OutputPattern = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('{') then break end
            
            node.chunks = tokens:noneOrMore(R.OutputChunk)
            if not node.chunks then break end
            
            if not tokens:match('}') then break end
            
            return setmetatable(node, {type=("OutputPattern"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   OutputChunk = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.element = tokens:match(R.OutputElement)
            if not node.element then break end
            
            return setmetatable(node, {type=("OutputChunk"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   OutputElement = setmetatable({
      {Child = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.name = tokens:match(R.Name)
            if not node.name then break end
            
            return setmetatable(node, {type=("OutputElement.Child"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {String = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.string = tokens:match(R.String)
            if not node.string then break end
            
            return setmetatable(node, {type=("OutputElement.String"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Indent = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match(">") then break end
            
            return setmetatable(node, {type=("OutputElement.Indent"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Dedent = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match("<") then break end
            
            return setmetatable(node, {type=("OutputElement.Dedent"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Newline = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match("/") then break end
            
            return setmetatable(node, {type=("OutputElement.Newline"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {Interline = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match("^") then break end
            
            return setmetatable(node, {type=("OutputElement.Interline"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   Operator = setmetatable({
      {NoneOrMore = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.op = tokens:match('*')
            if not node.op then break end
            
            return setmetatable(node, {type=("Operator.NoneOrMore"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {OneOrMore = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.op = tokens:match('+')
            if not node.op then break end
            
            return setmetatable(node, {type=("Operator.OneOrMore"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {NoneOrOne = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.op = tokens:match('?')
            if not node.op then break end
            
            return setmetatable(node, {type=("Operator.NoneOrOne"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {AllExcept = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.op = tokens:match('!')
            if not node.op then break end
            
            return setmetatable(node, {type=("Operator.AllExcept"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   String = setmetatable({
      {A = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('"') then break end
            
            node.inner = tokens:noneOrMore(R.AString)
            if not node.inner then break end
            
            if not tokens:match('"') then break end
            
            return setmetatable(node, {type=("String.A"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
      {B = function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match("'") then break end
            
            node.inner = tokens:noneOrMore(R.BString)
            if not node.inner then break end
            
            if not tokens:match("'") then break end
            
            return setmetatable(node, {type=("String.B"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;};
   }, {__call = ruleiter});
   
   RawString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('"') then break end
            
            node.inner = tokens:noneOrMore(R.AString)
            if not node.inner then break end
            
            if not tokens:match('"') then break end
            
            return setmetatable(node, {type=("RawString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match("'") then break end
            
            node.inner = tokens:noneOrMore(R.BString)
            if not node.inner then break end
            
            if not tokens:match("'") then break end
            
            return setmetatable(node, {type=("RawString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   AString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:match('\\\\')
            if not node.e then break end
            
            return setmetatable(node, {type=("AString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:match('\\"')
            if not node.e then break end
            
            return setmetatable(node, {type=("AString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:allExcept('"')
            if not node.e then break end
            
            return setmetatable(node, {type=("AString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   BString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:match('\\\\')
            if not node.e then break end
            
            return setmetatable(node, {type=("BString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:match("\\'")
            if not node.e then break end
            
            return setmetatable(node, {type=("BString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:allExcept("'")
            if not node.e then break end
            
            return setmetatable(node, {type=("BString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   Method = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            if not tokens:match('---') then break end
            
            node.inner = tokens:noneOrMore(R.MethodString)
            if not node.inner then break end
            
            if not tokens:match('---') then break end
            
            return setmetatable(node, {type=("Method"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   MethodString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:match('\\\\')
            if not node.e then break end
            
            return setmetatable(node, {type=("MethodString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:match('\\-')
            if not node.e then break end
            
            return setmetatable(node, {type=("MethodString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.e = tokens:allExcept('---')
            if not node.e then break end
            
            return setmetatable(node, {type=("MethodString"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   Name = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.head = tokens:match(T"WORD")
            if not node.head then break end
            
            node.tail = tokens:noneOrMore(R.NamePart)
            if not node.tail then break end
            
            return setmetatable(node, {type=("Name"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
   NamePart = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.head = tokens:match('_')
            if not node.head then break end
            
            node.tail = tokens:match(T"WORD")
            if not node.tail then break end
            
            return setmetatable(node, {type=("NamePart"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         repeat
            node.head = tokens:match('_')
            if not node.head then break end
            
            node.tail = tokens:match(T"NUMBER")
            if not node.tail then break end
            
            return setmetatable(node, {type=("NamePart"):split(".")})
         until true
         
         tokens.curr = __reset__
      end;
   }, {__call = ruleiter});
   
}
AST = R.Template()
if not AST and tokens:peek() then
   error("unexpected token:"..errfmt(tokens:getLast()))
end

local script_conf = {}
script = function(scripts, ast)
   local direction = script_conf.direction
   for alias, child in pairs(copy(ast)) do
      if type(child) == "table" and direction ~= "down" then
         script(scripts, child)
      end
      if meta(child) and meta(child).type then
         local func = scripts
         for _, t in ipairs(meta(child).type) do
            if type(func) == "table" then
               func = func[t] or findOrderedKey(func, t)
            end
         end
         if type(func) == "function" then
            if type(child) == "table" and #child > 0 then
               for _, item in ipairs(child) do
                  func(item, alias)
               end
            else
               func(child, alias)
            end
         end
      end
      if type(child) == "table" and direction == "down" then
         script(scripts, child)
      end
   end
end
S = {
   {Name = function (self, alias, segment)
      self.string = collapse(self)
   
   end};
}
script(S, AST)

local script_conf = {direction = [[down]], }
script = function(scripts, ast)
   local direction = script_conf.direction
   for alias, child in pairs(copy(ast)) do
      if type(child) == "table" and direction ~= "down" then
         script(scripts, child)
      end
      if meta(child) and meta(child).type then
         local func = scripts
         for _, t in ipairs(meta(child).type) do
            if type(func) == "table" then
               func = func[t] or findOrderedKey(func, t)
            end
         end
         if type(func) == "function" then
            if type(child) == "table" and #child > 0 then
               for _, item in ipairs(child) do
                  func(item, alias)
               end
            else
               func(child, alias)
            end
         end
      end
      if type(child) == "table" and direction == "down" then
         script(scripts, child)
      end
   end
end
S = {
   {Segment = {
      Parse = function (self, alias, segment)
         for _,conf in pairs(self.config) do
            if conf.name.string == 'entry' then
               assert(not self.entry, 'entry point already specified')
               self.entry = collapse(conf.item)
            end
         end
         assert(self.entry, 'Parse segment must have an entry point')
      
      end;
   }};
   {ParseElement = function (self, alias, segment)
      local opends = ''
      if #self.operators == 0 then self.operators = {'tokens:match('} end
      for i=1, #self.operators do
         opends = opends..')'
      end
      self.opends = opends
   
   end};
   {ParseRule = function (self, alias, segment)
      self.body.pname = self.name.string
   
   end};
   {ParseVariant = {
      Array = function (self, alias, segment)
         for _,child in ipairs(self.children) do
            child.pname = self.pname
         end
      
      end;
      Named = function (self, alias, segment)
         self.pattern.pname = (self.pname and self.pname..'.' or '')..self.name.string
      
      end;
      Anonymous = function (self, alias, segment)
         self.pattern.pname = self.pname
      
      end;
   }};
   {String = function (self, alias, segment)
      self.inner = collapse(self.inner):gsub(']\\=]', ']=]')
   
   end};
}
script(S, AST)

local output_conf = {target = [[bootc.lua]], }
local assert_node = function(node, alias)
   if not node[alias] then
      error("node doesn't exist: "..alias.." in "..dump(node)..":"..dump(getmetatable(node).type), 2)
   end
   return node[alias]
end
local function output(node, interline, dent)
   if type(node) == "string" or node.meta and node.meta.__token__ then
      return tostring(node)
   else
      if #node > 0 or not getmetatable(node).type then
         local out = {}
         for _, node in ipairs(node) do
            out[#out+1] = output(node, false, dent)
            if interline then out[#out+1] = "\n"..indent*dent end
         end
         if interline then out[#out] = nil end
         return table.concat(out)
         
      else
         local fn = O
         for _, t in ipairs(getmetatable(node).type) do
            fn = assert(fn[t], "type "..t.." has no output")
            if type(fn) == "function" then break end
         end
         return fn(node, false, dent)
      end
   end
end
O = {
   Template = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = 'require "newtokenizer"'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'require "lib.iter"'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'require "lib.dump"'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'require "lib.stringext"'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'require "errfmt"'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'require "common"'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'global = {}'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'indent = "   "'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'source = fetch(...)'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'assert(source, "a source file must be specified")'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'tokens = tokenize(source)'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'assert(tokens, "tokenization failure")'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = output(assert_node(self, "template"), interline, dent)
      
      return table.concat(out)
   end,
   Segment = {
      Parse = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = "local parse_conf = {"
         out[#out+1] = output(assert_node(self, "config"), interline, dent)
         out[#out+1] = "}"
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = "local ruleiter = function(self)"
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'for n,rule in ipairs(self) do'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(rule) == "table" then n,rule = next(rule) end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'local v = rule()'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if v then return v end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'tokens.ignore = '
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'iter('
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = '_conf.ignore:trim():split(" "))'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = ':map(function(e) return T(e) end)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'R = {'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         interline = true
         out[#out+1] = output(assert_node(self, "body"), interline, dent)
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = '}'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'AST = R.'
         out[#out+1] = output(assert_node(self, "entry"), interline, dent)
         out[#out+1] = '()'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if not AST and tokens:peek() then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'error("unexpected token:"..errfmt(tokens:getLast()))'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = "\n" .. indent*dent
         
         return table.concat(out)
      end,
      Script = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'local '
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = '_conf = {'
         out[#out+1] = output(assert_node(self, "config"), interline, dent)
         out[#out+1] = '}'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'script = function(scripts, ast)'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'local direction = '
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = '_conf.direction'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'for alias, child in pairs(copy(ast)) do'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(child) == "table" and direction ~= "down" then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'script(scripts, child)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if meta(child) and meta(child).type then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'local func = scripts'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'for _, t in ipairs(meta(child).type) do'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(func) == "table" then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'func = func[t] or findOrderedKey(func, t)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(func) == "function" then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(child) == "table" and #child > 0 then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'for _, item in ipairs(child) do'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'func(item, alias)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'else'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'func(child, alias)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(child) == "table" and direction == "down" then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'script(scripts, child)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'S = {'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         interline = true
         out[#out+1] = output(assert_node(self, "body"), interline, dent)
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = '}'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'script(S, AST)'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = "\n" .. indent*dent
         
         return table.concat(out)
      end,
      Output = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'local output_conf = {'
         out[#out+1] = output(assert_node(self, "config"), interline, dent)
         out[#out+1] = '}'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'local assert_node = function(node, alias)'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if not node[alias] then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'error("node doesn\'t exist: "..alias.." in "..dump(node)..":"..dump(getmetatable(node).type), 2)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'return node[alias]'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'local function output(node, interline, dent)'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(node) == "string" or node.meta and node.meta.__token__ then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'return tostring(node)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'else'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if #node > 0 or not getmetatable(node).type then'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'local out = {}'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'for _, node in ipairs(node) do'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'out[#out+1] = output(node, false, dent)'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if interline then out[#out+1] = "\\n"..indent*dent end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if interline then out[#out] = nil end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'return table.concat(out)'
         out[#out+1] = "\n" .. indent*dent
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'else'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'local fn = O'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'for _, t in ipairs(getmetatable(node).type) do'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'fn = assert(fn[t], "type "..t.." has no output")'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if type(fn) == "function" then break end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'return fn(node, false, dent)'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'end'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'O = {'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         interline = true
         out[#out+1] = output(assert_node(self, "body"), interline, dent)
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = '}'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'print(output(AST, false, 0))'
         out[#out+1] = "\n" .. indent*dent
         
         return table.concat(out)
      end,
   },
   Config = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "name"), interline, dent)
      out[#out+1] = ' = [['
      out[#out+1] = output(assert_node(self, "item"), interline, dent)
      out[#out+1] = ']], '
      
      return table.concat(out)
   end,
   ParseRule = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "name"), interline, dent)
      out[#out+1] = ' = setmetatable({'
      dent = dent + 1
      out[#out+1] = "\n" .. indent*dent
      interline = true
      out[#out+1] = output(assert_node(self, "body"), interline, dent)
      dent = dent - 1
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = '}, {__call = ruleiter});'
      out[#out+1] = "\n" .. indent*dent
      
      return table.concat(out)
   end,
   ParseVariant = {
      Array = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         interline = true
         out[#out+1] = output(assert_node(self, "children"), interline, dent)
         
         return table.concat(out)
      end,
      Anonymous = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "pattern"), interline, dent)
         out[#out+1] = ';'
         
         return table.concat(out)
      end,
      Named = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = '{'
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = ' = '
         out[#out+1] = output(assert_node(self, "pattern"), interline, dent)
         out[#out+1] = '};'
         
         return table.concat(out)
      end,
   },
   ParsePattern = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = 'function ()'
      dent = dent + 1
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'local __reset__, node = tokens.curr, {}'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'repeat'
      dent = dent + 1
      out[#out+1] = "\n" .. indent*dent
      interline = true
      out[#out+1] = output(assert_node(self, "chunks"), interline, dent)
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'return setmetatable(node, {type=("'
      out[#out+1] = output(assert_node(self, "pname"), interline, dent)
      out[#out+1] = '"):split(".")})'
      dent = dent - 1
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'until true'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'tokens.curr = __reset__'
      dent = dent - 1
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'end'
      
      return table.concat(out)
   end,
   ParseChunk = {
      Aliased = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'node.'
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = ' = '
         out[#out+1] = output(assert_node(self, "element"), interline, dent)
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'if not node.'
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = ' then break end'
         out[#out+1] = "\n" .. indent*dent
         
         return table.concat(out)
      end,
      Plain = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'if not '
         out[#out+1] = output(assert_node(self, "element"), interline, dent)
         out[#out+1] = ' then break end'
         out[#out+1] = "\n" .. indent*dent
         
         return table.concat(out)
      end,
   },
   ParseElement = {
      Type = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "operators"), interline, dent)
         out[#out+1] = output(assert_node(self, "type"), interline, dent)
         out[#out+1] = output(assert_node(self, "opends"), interline, dent)
         
         return table.concat(out)
      end,
      Rule = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "operators"), interline, dent)
         out[#out+1] = 'R.'
         out[#out+1] = output(assert_node(self, "rule"), interline, dent)
         out[#out+1] = output(assert_node(self, "opends"), interline, dent)
         
         return table.concat(out)
      end,
      Tokens = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "operators"), interline, dent)
         out[#out+1] = output(assert_node(self, "tokens"), interline, dent)
         out[#out+1] = output(assert_node(self, "opends"), interline, dent)
         
         return table.concat(out)
      end,
   },
   RulePath = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "rule"), interline, dent)
      out[#out+1] = output(assert_node(self, "variant"), interline, dent)
      
      return table.concat(out)
   end,
   VariantPart = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = '"'
      out[#out+1] = output(assert_node(self, "variant"), interline, dent)
      out[#out+1] = '"'
      
      return table.concat(out)
   end,
   TokenType = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = 'T"'
      out[#out+1] = output(assert_node(self, "t"), interline, dent)
      out[#out+1] = '"'
      
      return table.concat(out)
   end,
   ScriptRule = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = '{'
      out[#out+1] = output(assert_node(self, "name"), interline, dent)
      out[#out+1] = ' = '
      out[#out+1] = output(assert_node(self, "body"), interline, dent)
      out[#out+1] = '};'
      
      return table.concat(out)
   end,
   ScriptVariant = {
      Array = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = '{'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         interline = true
         out[#out+1] = output(assert_node(self, "children"), interline, dent)
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = '}'
         
         return table.concat(out)
      end,
      Code = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "code"), interline, dent)
         
         return table.concat(out)
      end,
      Named = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = ' = '
         out[#out+1] = output(assert_node(self, "children"), interline, dent)
         out[#out+1] = ';'
         
         return table.concat(out)
      end,
   },
   OutputRule = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "name"), interline, dent)
      out[#out+1] = ' = '
      out[#out+1] = output(assert_node(self, "body"), interline, dent)
      
      return table.concat(out)
   end,
   OutputVariant = {
      Array = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = '{'
         dent = dent + 1
         out[#out+1] = "\n" .. indent*dent
         interline = true
         out[#out+1] = output(assert_node(self, "children"), interline, dent)
         dent = dent - 1
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = '},'
         
         return table.concat(out)
      end,
      Pattern = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "pattern"), interline, dent)
         out[#out+1] = ','
         
         return table.concat(out)
      end,
      Named = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = ' = '
         out[#out+1] = output(assert_node(self, "pattern"), interline, dent)
         
         return table.concat(out)
      end,
   },
   OutputPattern = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = 'function(self, interline, dent)'
      dent = dent + 1
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'local out = {}'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'local interline = interline or false'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'local dent = dent or 0'
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = "\n" .. indent*dent
      interline = true
      out[#out+1] = output(assert_node(self, "chunks"), interline, dent)
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'return table.concat(out)'
      dent = dent - 1
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'end'
      
      return table.concat(out)
   end,
   OutputChunk = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "element"), interline, dent)
      
      return table.concat(out)
   end,
   OutputElement = {
      Child = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'out[#out+1] = output(assert_node(self, "'
         out[#out+1] = output(assert_node(self, "name"), interline, dent)
         out[#out+1] = '"), interline, dent)'
         
         return table.concat(out)
      end,
      String = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'out[#out+1] = '
         out[#out+1] = output(assert_node(self, "string"), interline, dent)
         
         return table.concat(out)
      end,
      Indent = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'dent = dent + 1'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'out[#out+1] = "\\n" .. indent*dent'
         
         return table.concat(out)
      end,
      Dedent = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'dent = dent - 1'
         out[#out+1] = "\n" .. indent*dent
         out[#out+1] = 'out[#out+1] = "\\n" .. indent*dent'
         
         return table.concat(out)
      end,
      Newline = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'out[#out+1] = "\\n" .. indent*dent'
         
         return table.concat(out)
      end,
      Interline = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'interline = true'
         
         return table.concat(out)
      end,
   },
   Operator = {
      NoneOrMore = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'tokens:noneOrMore('
         
         return table.concat(out)
      end,
      OneOrMore = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'tokens:oneOrMore('
         
         return table.concat(out)
      end,
      NoneOrOne = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'tokens:noneOrOne('
         
         return table.concat(out)
      end,
      AllExcept = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = 'tokens:allExcept('
         
         return table.concat(out)
      end,
   },
   String = {
      A = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = '"'
         out[#out+1] = output(assert_node(self, "inner"), interline, dent)
         out[#out+1] = '"'
         
         return table.concat(out)
      end,
      B = function(self, interline, dent)
         local out = {}
         local interline = interline or false
         local dent = dent or 0
         
         out[#out+1] = "'"
         out[#out+1] = output(assert_node(self, "inner"), interline, dent)
         out[#out+1] = "'"
         
         return table.concat(out)
      end,
   },
   RawString = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "inner"), interline, dent)
      
      return table.concat(out)
   end,
   AString = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "e"), interline, dent)
      
      return table.concat(out)
   end,
   BString = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "e"), interline, dent)
      
      return table.concat(out)
   end,
   Method = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = 'function (self, alias, segment)'
      out[#out+1] = output(assert_node(self, "inner"), interline, dent)
      out[#out+1] = "\n" .. indent*dent
      out[#out+1] = 'end'
      
      return table.concat(out)
   end,
   MethodString = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "e"), interline, dent)
      
      return table.concat(out)
   end,
   Name = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "head"), interline, dent)
      out[#out+1] = output(assert_node(self, "tail"), interline, dent)
      
      return table.concat(out)
   end,
   NamePart = function(self, interline, dent)
      local out = {}
      local interline = interline or false
      local dent = dent or 0
      
      out[#out+1] = output(assert_node(self, "head"), interline, dent)
      out[#out+1] = output(assert_node(self, "tail"), interline, dent)
      
      return table.concat(out)
   end,
}
print(output(AST, false, 0))

