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

function indent() 
   local d = 0
   return function(offset) 
      d = d + offset
      return "\n" .. dent*d 
   end 
end

function inline(interline) 
   interline[1] = true return "" 
end

local parse_conf = { ignore = [[space newline tab]], entry = [[Template]], }
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
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.template = tokens:noneOrMore(R.Segment )
            if not node.template then break end
            
            return setmetatable(node, {type=("Template"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   Segment = setmetatable({
      {Parse = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match('parse')
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.config = tokens:noneOrMore(R.Config )
            if not node.config then break end
            
            if not tokens:match('[') then break end
            
            node.body = tokens:noneOrMore(R.ParseRule )
            if not node.body then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("Segment.Parse"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Script = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match('script')
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.config = tokens:noneOrMore(R.Config )
            if not node.config then break end
            
            if not tokens:match('[') then break end
            
            node.body = tokens:noneOrMore(R.ScriptRule )
            if not node.body then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("Segment.Script"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Output = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match('output')
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.config = tokens:noneOrMore(R.Config )
            if not node.config then break end
            
            if not tokens:match('[') then break end
            
            node.body = tokens:noneOrMore(R.OutputRule )
            if not node.body then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("Segment.Output"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   Config = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            node.item = tokens:match(R.RawString )
            if not node.item then break end
            
            return setmetatable(node, {type=("Config"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   ParseRule = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            node.body = tokens:match(R.ParseVariant )
            if not node.body then break end
            
            return setmetatable(node, {type=("ParseRule"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   ParseVariant = setmetatable({
      {Array = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('[') then break end
            
            node.children = tokens:noneOrMore(R.ParseVariant )
            if not node.children then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("ParseVariant.Array"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Named = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            node.pattern = tokens:match(R.ParseVariant )
            if not node.pattern then break end
            
            return setmetatable(node, {type=("ParseVariant.Named"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Anonymous = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.pattern = tokens:match(R.ParsePattern )
            if not node.pattern then break end
            
            return setmetatable(node, {type=("ParseVariant.Anonymous"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   ParsePattern = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('{') then break end
            
            node.chunks = tokens:noneOrMore(R.ParseChunk )
            if not node.chunks then break end
            
            if not tokens:match('}') then break end
            
            return setmetatable(node, {type=("ParsePattern"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   ParseChunk = setmetatable({
      {Aliased = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            if not tokens:match(':') then break end
            
            node.element = tokens:match(R.ParseElement )
            if not node.element then break end
            
            return setmetatable(node, {type=("ParseChunk.Aliased"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Plain = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.element = tokens:match(R.ParseElement )
            if not node.element then break end
            
            return setmetatable(node, {type=("ParseChunk.Plain"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   ParseElement = setmetatable({
      {Type = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.type = tokens:match(R.TokenType )
            if not node.type then break end
            
            node.operators = tokens:noneOrMore(R.Operator )
            if not node.operators then break end
            
            return setmetatable(node, {type=("ParseElement.Type"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Rule = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.rule = tokens:match(R.RulePath )
            if not node.rule then break end
            
            node.operators = tokens:noneOrMore(R.Operator )
            if not node.operators then break end
            
            return setmetatable(node, {type=("ParseElement.Rule"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Tokens = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.tokens = tokens:match(R.String )
            if not node.tokens then break end
            
            node.operators = tokens:noneOrMore(R.Operator )
            if not node.operators then break end
            
            return setmetatable(node, {type=("ParseElement.Tokens"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   RulePath = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.rule = tokens:match(R.Name )
            if not node.rule then break end
            
            node.variant = tokens:noneOrMore(R.VariantPart )
            if not node.variant then break end
            
            return setmetatable(node, {type=("RulePath"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   VariantPart = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('.') then break end
            
            node.variant = tokens:match(R.Name )
            if not node.variant then break end
            
            return setmetatable(node, {type=("VariantPart"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   TokenType = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.t = tokens:match("WORD")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.t = tokens:match("NUMBER")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.t = tokens:match("SYMBOL")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.t = tokens:match("SPACE")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.t = tokens:match("TAB")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.t = tokens:match("NEWLINE")
            if not node.t then break end
            
            return setmetatable(node, {type=("TokenType"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
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
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            node.body = tokens:match(R.ScriptVariant )
            if not node.body then break end
            
            return setmetatable(node, {type=("ScriptRule"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   ScriptVariant = setmetatable({
      {Array = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('[') then break end
            
            node.children = tokens:noneOrMore(R.ScriptVariant )
            if not node.children then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("ScriptVariant.Array"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Code = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.code = tokens:match(R.Method )
            if not node.code then break end
            
            return setmetatable(node, {type=("ScriptVariant.Code"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Named = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            node.children = tokens:match(R.ScriptVariant )
            if not node.children then break end
            
            return setmetatable(node, {type=("ScriptVariant.Named"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   OutputRule = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            node.body = tokens:match(R.OutputVariant )
            if not node.body then break end
            
            return setmetatable(node, {type=("OutputRule"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   OutputVariant = setmetatable({
      {Array = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('[') then break end
            
            node.children = tokens:noneOrMore(R.OutputVariant )
            if not node.children then break end
            
            if not tokens:match(']') then break end
            
            return setmetatable(node, {type=("OutputVariant.Array"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Pattern = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.pattern = tokens:match(R.OutputPattern )
            if not node.pattern then break end
            
            return setmetatable(node, {type=("OutputVariant.Pattern"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Named = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            node.pattern = tokens:match(R.OutputVariant )
            if not node.pattern then break end
            
            return setmetatable(node, {type=("OutputVariant.Named"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   OutputPattern = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('{') then break end
            
            if not tokens:noneOrOne(R.Padding ) then break end
            
            node.chunks = tokens:noneOrMore(R.OutputChunk )
            if not node.chunks then break end
            
            if not tokens:noneOrOne(R.Padding ) then break end
            
            if not tokens:match('}') then break end
            
            return setmetatable(node, {type=("OutputPattern"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   OutputChunk = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.element = tokens:match(R.OutputElement )
            if not node.element then break end
            
            return setmetatable(node, {type=("OutputChunk"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   OutputElement = setmetatable({
      {Whitespace = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.w = tokens:match(R.Whitespace )
            if not node.w then break end
            
            return setmetatable(node, {type=("OutputElement.Whitespace"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Newline = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match(R.Padding ) then break end
            
            return setmetatable(node, {type=("OutputElement.Newline"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Indent = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('>') then break end
            
            if not tokens:match(R.Padding ) then break end
            
            return setmetatable(node, {type=("OutputElement.Indent"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Dedent = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('<') then break end
            
            if not tokens:match(R.Padding ) then break end
            
            return setmetatable(node, {type=("OutputElement.Dedent"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Interline = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('^') then break end
            
            return setmetatable(node, {type=("OutputElement.Interline"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Child = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.name = tokens:match(R.Interpolate )
            if not node.name then break end
            
            return setmetatable(node, {type=("OutputElement.Child"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Chunk = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.chunk = tokens:match(R.LinePart )
            if not node.chunk then break end
            
            return setmetatable(node, {type=("OutputElement.Chunk"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   Interpolate = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('${') then break end
            
            node.name = tokens:match(R.Name )
            if not node.name then break end
            
            if not tokens:match('}') then break end
            
            return setmetatable(node, {type=("Interpolate"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   LinePart = setmetatable({
      {Nested = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.s = tokens:match(R.Bits )
            if not node.s then break end
            
            return setmetatable(node, {type=("LinePart.Nested"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {Any = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.s = tokens:match(R.AnyPart )
            if not node.s then break end
            
            return setmetatable(node, {type=("LinePart.Any"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   AnyPart = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.p = tokens:match(R.Whitespace )
            if not node.p then break end
            
            return setmetatable(node, {type=("AnyPart"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.p = tokens:allExcept('}')
            if not node.p then break end
            
            return setmetatable(node, {type=("AnyPart"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   Bits = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('{') then break end
            
            if not tokens:noneOrOne(R.Padding ) then break end
            
            node.bits = tokens:noneOrMore(R.OutputElement )
            if not node.bits then break end
            
            if not tokens:noneOrOne(R.Padding ) then break end
            
            if not tokens:match('}') then break end
            
            return setmetatable(node, {type=("Bits"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   Whitespace = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.s = tokens:match(T"SPACE")
            if not node.s then break end
            
            return setmetatable(node, {type=("Whitespace"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.s = tokens:match(T"TAB")
            if not node.s then break end
            
            return setmetatable(node, {type=("Whitespace"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   Padding = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match(T"NEWLINE") then break end
            
            if not tokens:noneOrMore(R.Whitespace ) then break end
            
            return setmetatable(node, {type=("Padding"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   Operator = setmetatable({
      {NoneOrMore = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.op = tokens:match('*')
            if not node.op then break end
            
            return setmetatable(node, {type=("Operator.NoneOrMore"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {OneOrMore = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.op = tokens:match('+')
            if not node.op then break end
            
            return setmetatable(node, {type=("Operator.OneOrMore"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {NoneOrOne = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.op = tokens:match('?')
            if not node.op then break end
            
            return setmetatable(node, {type=("Operator.NoneOrOne"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {AllExcept = function() 
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
      {A = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('"') then break end
            
            node.inner = tokens:noneOrMore(R.AString )
            if not node.inner then break end
            
            if not tokens:match('"') then break end
            
            return setmetatable(node, {type=("String.A"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
      {B = function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match("'") then break end
            
            node.inner = tokens:noneOrMore(R.BString )
            if not node.inner then break end
            
            if not tokens:match("'") then break end
            
            return setmetatable(node, {type=("String.B"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;};
   }, {__call = ruleiter});
   
   RawString = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('"') then break end
            
            node.inner = tokens:noneOrMore(R.AString )
            if not node.inner then break end
            
            if not tokens:match('"') then break end
            
            return setmetatable(node, {type=("RawString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match("'") then break end
            
            node.inner = tokens:noneOrMore(R.BString )
            if not node.inner then break end
            
            if not tokens:match("'") then break end
            
            return setmetatable(node, {type=("RawString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   AString = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.e = tokens:match('\\\\')
            if not node.e then break end
            
            return setmetatable(node, {type=("AString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.e = tokens:match('\\"')
            if not node.e then break end
            
            return setmetatable(node, {type=("AString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
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
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.e = tokens:match('\\\\')
            if not node.e then break end
            
            return setmetatable(node, {type=("BString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.e = tokens:match("\\'")
            if not node.e then break end
            
            return setmetatable(node, {type=("BString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
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
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            if not tokens:match('---') then break end
            
            node.inner = tokens:noneOrMore(R.MethodString )
            if not node.inner then break end
            
            if not tokens:match('---') then break end
            
            return setmetatable(node, {type=("Method"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   MethodString = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.e = tokens:match('\\\\')
            if not node.e then break end
            
            return setmetatable(node, {type=("MethodString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.e = tokens:match('\\-')
            if not node.e then break end
            
            return setmetatable(node, {type=("MethodString"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
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
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.head = tokens:match(R.NameHead )
            if not node.head then break end
            
            node.tail = tokens:noneOrMore(R.NamePart )
            if not node.tail then break end
            
            return setmetatable(node, {type=("Name"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   NameHead = setmetatable({
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.head = tokens:match(T"WORD")
            if not node.head then break end
            
            return setmetatable(node, {type=("NameHead"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
      function() 
         local __reset__, node = tokens.curr, {}
         repeat 
            node.head = tokens:match("_")
            if not node.head then break end
            
            return setmetatable(node, {type=("NameHead"):split(".")}) 
         until true
         
         tokens.curr = __reset__ 
      end;
   }, {__call = ruleiter});
   
   NamePart = setmetatable({
      function() 
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
      function() 
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

local script_conf = { }
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
    end
   };
   {LinePart = {
      Any = function (self, alias, segment) 
         self.s = collapse(self.s):gsub('\\', '\\\\'):gsub('"', '\\"')
       end
      ;
   }}; 
}
script(S, AST)

local script_conf = { direction = [[down]], }
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
       end
      ;
   }};
   {ParseElement = function (self, alias, segment) 
      local opends = ''
      if #self.operators == 0 then self.operators = {'tokens:match('} end
      for i=1, #self.operators do
         opends = opends..')'
      end
      self.opends = opends
    end
   };
   {ParseRule = function (self, alias, segment) 
      self.body.pname = self.name.string
    end
   };
   {ParseVariant = {
      Array = function (self, alias, segment) 
         for _,child in ipairs(self.children) do
            child.pname = self.pname
         end
       end
      ;
      Named = function (self, alias, segment) 
         self.pattern.pname = (self.pname and self.pname..'.' or '')..self.name.string
       end
      ;
      Anonymous = function (self, alias, segment) 
         self.pattern.pname = self.pname
       end
      ;
   }};
   {String = function (self, alias, segment) 
      self.inner = collapse(self.inner):gsub(']\\=]', ']=]')
    end
   }; 
}
script(S, AST)

local output_conf = { target = [[bootc.lua]], }
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
            if interline[1] then out[#out+1] = dent(0) end 
         end
         if interline[1] then out[#out] = nil end
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
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         "require"," ","\"","newtokenizer","\"",dent(0),
         "require"," ","\"","lib",".","iter","\"",dent(0),
         "require"," ","\"","lib",".","dump","\"",dent(0),
         "require"," ","\"","lib",".","stringext","\"",dent(0),
         "require"," ","\"","errfmt","\"",dent(0),
         "require"," ","\"","common","\"",dent(0),
         dent(0),
         "global"," ","="," ","{", "}", dent(0),
         "dent"," ","="," ","\""," "," "," ","\"",dent(0),
         dent(0),
         "source"," ","="," ","fetch","(",".",".",".",")",dent(0),
         "assert","(","source",","," ","\"","a"," ","source"," ","file"," ","must"," ","be"," ","specified","\"",")",dent(0),
         "tokens"," ","="," ","tokenize","(","source",")",dent(0),
         "assert","(","tokens",","," ","\"","tokenization"," ","failure","\"",")",dent(0),
         dent(0),
         "function"," ","indent","(",")"," ",dent(1), 
            "local"," ","d"," ","="," ","0",dent(0),
            "return"," ","function","(","offset",")"," ",dent(1), 
               "d"," ","="," ","d"," ","+"," ","offset",dent(0),
               "return"," ","\"","\\","n","\""," ",".","."," ","dent","*","d"," ",dent(-1), 
            "end"," ",dent(-1), 
         "end",dent(0),
         dent(0),
         "function"," ","inline","(","interline",")"," ",dent(1), 
            "interline","[","1","]"," ","="," ","true"," ","return"," ","\"","\""," ",dent(-1), 
         "end",dent(0),
         dent(0),
         output(assert_node(self, "template"), interline, dent),
         dent(0),
          
      }) 
   end
   ,
   Segment = { 
      Parse = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "local"," ","parse","_","conf"," ","="," ","{", " ",output(assert_node(self, "config"), interline, dent),
            "}", dent(0),
            "local"," ","ruleiter"," ","="," ","function","(","self",")"," ",dent(1), 
               "for"," ","n",",","rule"," ","in"," ","ipairs","(","self",")"," ","do"," ",dent(1), 
                  "if"," ","type","(","rule",")"," ","=","="," ","\"","table","\""," ","then"," ","n",",","rule"," ","="," ","next","(","rule",")"," ","end",dent(0),
                  "local"," ","v"," ","="," ","rule","(",")",dent(0),
                  "if"," ","v"," ","then"," ","return"," ","v"," ","end"," ",dent(-1), 
               "end"," ",dent(-1), 
            "end",dent(0),
            dent(0),
            "tokens",".","ignore"," ","="," "," ",dent(1), 
               "iter","(","parse","_","conf",".","ignore",":","trim","(",")",":","split","(","\""," ","\"",")",")",dent(0),
               ":","map","(","function","(","e",")"," ","return"," ","T","(","e",")"," ","end",")"," ",dent(-1), 
            dent(0),
            "R"," ","="," ","{", " ",dent(1), 
               inline(interline),output(assert_node(self, "body"), interline, dent),
               dent(-1), 
            "}", dent(0),
            "AST"," ","="," ","R",".",output(assert_node(self, "entry"), interline, dent),
            "(",")",dent(0),
            "if"," ","not"," ","AST"," ","and"," ","tokens",":","peek","(",")"," ","then"," ",dent(1), 
               "error","(","\"","unexpected"," ","token",":","\"",".",".","errfmt","(","tokens",":","getLast","(",")",")",")"," ",dent(-1), 
            "end",dent(0),
            dent(0),
             
         }) 
      end
      ,
      Script = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "local"," ","script","_","conf"," ","="," ","{", " ",output(assert_node(self, "config"), interline, dent),
            "}", dent(0),
            "script"," ","="," ","function","(","scripts",","," ","ast",")"," ",dent(1), 
               "local"," ","direction"," ","="," ","script","_","conf",".","direction",dent(0),
               "for"," ","alias",","," ","child"," ","in"," ","pairs","(","copy","(","ast",")",")"," ","do"," ",dent(1), 
                  "if"," ","type","(","child",")"," ","=","="," ","\"","table","\""," ","and"," ","direction"," ","~","="," ","\"","down","\""," ","then"," ",dent(1), 
                     "script","(","scripts",","," ","child",")"," ",dent(-1), 
                  "end",dent(0),
                  "if"," ","meta","(","child",")"," ","and"," ","meta","(","child",")",".","type"," ","then"," ",dent(1), 
                     "local"," ","func"," ","="," ","scripts",dent(0),
                     "for"," ","_",","," ","t"," ","in"," ","ipairs","(","meta","(","child",")",".","type",")"," ","do"," ",dent(1), 
                        "if"," ","type","(","func",")"," ","=","="," ","\"","table","\""," ","then"," ",dent(1), 
                           "func"," ","="," ","func","[","t","]"," ","or"," ","findOrderedKey","(","func",","," ","t",")"," ",dent(-1), 
                        "end"," ",dent(-1), 
                     "end",dent(0),
                     "if"," ","type","(","func",")"," ","=","="," ","\"","function","\""," ","then"," ",dent(1), 
                        "if"," ","type","(","child",")"," ","=","="," ","\"","table","\""," ","and"," ","#","child"," ",">"," ","0"," ","then"," ",dent(1), 
                           "for"," ","_",","," ","item"," ","in"," ","ipairs","(","child",")"," ","do"," ",dent(1), 
                              "func","(","item",","," ","alias",")"," ",dent(-1), 
                           "end"," ",dent(-1), 
                        "else"," ",dent(1), 
                           "func","(","child",","," ","alias",")"," ",dent(-1), 
                        "end"," ",dent(-1), 
                     "end"," ",dent(-1), 
                  "end",dent(0),
                  "if"," ","type","(","child",")"," ","=","="," ","\"","table","\""," ","and"," ","direction"," ","=","="," ","\"","down","\""," ","then"," ",dent(1), 
                     "script","(","scripts",","," ","child",")"," ",dent(-1), 
                  "end"," ",dent(-1), 
               "end"," ",dent(-1), 
            "end",dent(0),
            "S"," ","="," ","{", " ",dent(1), 
               inline(interline),output(assert_node(self, "body"), interline, dent),
               " ",dent(-1), 
            "}", dent(0),
            "script","(","S",","," ","AST",")",dent(0),
            dent(0),
             
         }) 
      end
      ,
      Output = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "local"," ","output","_","conf"," ","="," ","{", " ",output(assert_node(self, "config"), interline, dent),
            "}", dent(0),
            "local"," ","assert","_","node"," ","="," ","function","(","node",","," ","alias",")"," ",dent(1), 
               "if"," ","not"," ","node","[","alias","]"," ","then"," ",dent(1), 
                  "error","(","\"","node"," ","doesn","'","t"," ","exist",":"," ","\"",".",".","alias",".",".","\""," ","in"," ","\"",".",".","dump","(","node",")",".",".","\"",":","\"",".",".","dump","(","getmetatable","(","node",")",".","type",")",","," ","2",")"," ",dent(-1), 
               "end",dent(0),
               "return"," ","node","[","alias","]"," ",dent(-1), 
            "end",dent(0),
            "local"," ","function"," ","output","(","node",","," ","interline",","," ","dent",")"," ",dent(1), 
               "if"," ","type","(","node",")"," ","=","="," ","\"","string","\""," ","or"," ","node",".","meta"," ","and"," ","node",".","meta",".","_","_","token","_","_"," ","then"," ",dent(1), 
                  "return"," ","tostring","(","node",")"," ",dent(-1), 
               "else"," ",dent(1), 
                  "if"," ","#","node"," ",">"," ","0"," ","or"," ","not"," ","getmetatable","(","node",")",".","type"," ","then"," ",dent(1), 
                     "local"," ","out"," ","="," ","{", "}", dent(0),
                     "for"," ","_",","," ","node"," ","in"," ","ipairs","(","node",")"," ","do"," ",dent(1), 
                        "out","[","#","out","+","1","]"," ","="," ","output","(","node",","," ","false",","," ","dent",")",dent(0),
                        "if"," ","interline","[","1","]"," ","then"," ","out","[","#","out","+","1","]"," ","="," ","dent","(","0",")"," ","end"," ",dent(-1), 
                     "end",dent(0),
                     "if"," ","interline","[","1","]"," ","then"," ","out","[","#","out","]"," ","="," ","nil"," ","end",dent(0),
                     "return"," ","table",".","concat","(","out",")"," ",dent(-1), 
                  "else"," ",dent(1), 
                     "local"," ","fn"," ","="," ","O",dent(0),
                     "for"," ","_",","," ","t"," ","in"," ","ipairs","(","getmetatable","(","node",")",".","type",")"," ","do"," ",dent(1), 
                        "fn"," ","="," ","assert","(","fn","[","t","]",","," ","\"","type"," ","\"",".",".","t",".",".","\""," ","has"," ","no"," ","output","\"",")",dent(0),
                        "if"," ","type","(","fn",")"," ","=","="," ","\"","function","\""," ","then"," ","break"," ","end"," ",dent(-1), 
                     "end",dent(0),
                     "return"," ","fn","(","node",","," ","false",","," ","dent",")"," ",dent(-1), 
                  "end"," ",dent(-1), 
               "end"," ",dent(-1), 
            "end",dent(0),
            "O"," ","="," ","{", " ",dent(1), 
               inline(interline),output(assert_node(self, "body"), interline, dent),
               " ",dent(-1), 
            "}", dent(0),
            "print","(","output","(","AST",","," ","false",","," ","indent","(",")",")",")",dent(0),
            dent(0),
             
         }) 
      end
      ,
   },
   Config = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "name"), interline, dent),
         " ","="," ","[","[",output(assert_node(self, "item"), interline, dent),
         "]","]",","," ", 
      }) 
   end
   ,
   ParseRule = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "name"), interline, dent),
         " ","="," ","setmetatable","(","{", dent(1), 
            inline(interline),output(assert_node(self, "body"), interline, dent),
            dent(-1), 
         "}", ","," ","{", "_","_","call"," ","="," ","ruleiter","}", ")",";",dent(0),
          
      }) 
   end
   ,
   ParseVariant = { 
      Array = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            inline(interline),output(assert_node(self, "children"), interline, dent),
             
         }) 
      end
      ,
      Anonymous = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "pattern"), interline, dent),
            ";", 
         }) 
      end
      ,
      Named = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "{", output(assert_node(self, "name"), interline, dent),
            " ","="," ",output(assert_node(self, "pattern"), interline, dent),
            "}", ";", 
         }) 
      end
      ,
   },
   ParsePattern = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         "function","(",")"," ",dent(1), 
            "local"," ","_","_","reset","_","_",","," ","node"," ","="," ","tokens",".","curr",","," ","{", "}", dent(0),
            "repeat"," ",dent(1), 
               inline(interline),output(assert_node(self, "chunks"), interline, dent),
               dent(0),
               "return"," ","setmetatable","(","node",","," ","{", "type","=","(","\"",output(assert_node(self, "pname"), interline, dent),
               "\"",")",":","split","(","\"",".","\"",")","}", ")"," ",dent(-1), 
            "until"," ","true",dent(0),
            dent(0),
            "tokens",".","curr"," ","="," ","_","_","reset","_","_"," ",dent(-1), 
         "end", 
      }) 
   end
   ,
   ParseChunk = { 
      Aliased = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "node",".",output(assert_node(self, "name"), interline, dent),
            " ","="," ",output(assert_node(self, "element"), interline, dent),
            dent(0),
            "if"," ","not"," ","node",".",output(assert_node(self, "name"), interline, dent),
            " ","then"," ","break"," ","end",dent(0),
             
         }) 
      end
      ,
      Plain = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "if"," ","not"," ",output(assert_node(self, "element"), interline, dent),
            " ","then"," ","break"," ","end",dent(0),
             
         }) 
      end
      ,
   },
   ParseElement = { 
      Type = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "operators"), interline, dent),
            output(assert_node(self, "type"), interline, dent),
            output(assert_node(self, "opends"), interline, dent),
             
         }) 
      end
      ,
      Rule = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "operators"), interline, dent),
            "R",".",output(assert_node(self, "rule"), interline, dent),
            output(assert_node(self, "opends"), interline, dent),
             
         }) 
      end
      ,
      Tokens = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "operators"), interline, dent),
            output(assert_node(self, "tokens"), interline, dent),
            output(assert_node(self, "opends"), interline, dent),
             
         }) 
      end
      ,
   },
   RulePath = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "rule"), interline, dent),
         " ",output(assert_node(self, "variant"), interline, dent),
          
      }) 
   end
   ,
   VariantPart = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         "\"",output(assert_node(self, "variant"), interline, dent),
         "\"", 
      }) 
   end
   ,
   TokenType = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         "T","\"",output(assert_node(self, "t"), interline, dent),
         "\"", 
      }) 
   end
   ,
   ScriptRule = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         "{", output(assert_node(self, "name"), interline, dent),
         " ","="," ",output(assert_node(self, "body"), interline, dent),
         "}", ";", 
      }) 
   end
   ,
   ScriptVariant = { 
      Array = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "{", dent(1), 
               inline(interline),output(assert_node(self, "children"), interline, dent),
               dent(-1), 
            "}",  
         }) 
      end
      ,
      Code = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "code"), interline, dent),
             
         }) 
      end
      ,
      Named = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "name"), interline, dent),
            " ","="," ",output(assert_node(self, "children"), interline, dent),
            ";", 
         }) 
      end
      ,
   },
   OutputRule = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "name"), interline, dent),
         " ","="," ",output(assert_node(self, "body"), interline, dent),
          
      }) 
   end
   ,
   OutputVariant = { 
      Array = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "{", " ",dent(1), 
               inline(interline),output(assert_node(self, "children"), interline, dent),
               dent(-1), 
            "}", ",", 
         }) 
      end
      ,
      Pattern = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "pattern"), interline, dent),
            ",", 
         }) 
      end
      ,
      Named = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "name"), interline, dent),
            " ","="," ",output(assert_node(self, "pattern"), interline, dent),
             
         }) 
      end
      ,
   },
   OutputPattern = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         "function","(","self",","," ","interline",","," ","dent",")"," ",dent(1), 
            "local"," ","interline"," ","="," ","interline"," ","or"," ","{", "false","}", dent(0),
            "local"," ","dent"," ","="," ","dent"," ","or"," ","indent","(",")",dent(0),
            dent(0),
            "return"," ","table",".","concat","(","{", " ",dent(1), 
               output(assert_node(self, "chunks"), interline, dent),
               " ",dent(-1), 
            "}", ")"," ",dent(-1), 
         "end",dent(0),
          
      }) 
   end
   ,
   OutputChunk = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "element"), interline, dent),
          
      }) 
   end
   ,
   OutputElement = { 
      Whitespace = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "\"",output(assert_node(self, "w"), interline, dent),
            "\"",",", 
         }) 
      end
      ,
      Indent = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "dent","(","1",")",","," ",dent(1), 
                
            }) 
         end
         ,
         Dedent = function(self, interline, dent) 
            local interline = interline or {false}
            local dent = dent or indent()
            
            return table.concat({ 
               "dent","(","-","1",")",","," ",dent(-1), 
             
         }) 
      end
      ,
      Newline = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "dent","(","0",")",",",dent(0),
             
         }) 
      end
      ,
      Interline = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "inline","(","interline",")",",", 
         }) 
      end
      ,
      Child = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "output","(","assert","_","node","(","self",","," ","\"",output(assert_node(self, "name"), interline, dent),
            "\"",")",","," ","interline",","," ","dent",")",",",dent(0),
             
         }) 
      end
      ,
      Chunk = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            output(assert_node(self, "chunk"), interline, dent),
             
         }) 
      end
      ,
   },
   Interpolate = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "name"), interline, dent),
          
      }) 
   end
   ,
   LinePart = { 
      Nested = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "\"","{", "\"",","," ",output(assert_node(self, "s"), interline, dent),
            "\"","}", "\"",","," ", 
         }) 
      end
      ,
      Any = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "\"",output(assert_node(self, "s"), interline, dent),
            "\"",",", 
         }) 
      end
      ,
   },
   AnyPart = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "p"), interline, dent),
          
      }) 
   end
   ,
   Whitespace = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "s"), interline, dent),
          
      }) 
   end
   ,
   Bits = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "bits"), interline, dent),
          
      }) 
   end
   ,
   Operator = { 
      NoneOrMore = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "tokens",":","noneOrMore","(", 
         }) 
      end
      ,
      OneOrMore = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "tokens",":","oneOrMore","(", 
         }) 
      end
      ,
      NoneOrOne = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "tokens",":","noneOrOne","(", 
         }) 
      end
      ,
      AllExcept = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "tokens",":","allExcept","(", 
         }) 
      end
      ,
   },
   String = { 
      A = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "\"",output(assert_node(self, "inner"), interline, dent),
            "\"", 
         }) 
      end
      ,
      B = function(self, interline, dent) 
         local interline = interline or {false}
         local dent = dent or indent()
         
         return table.concat({ 
            "'",output(assert_node(self, "inner"), interline, dent),
            "'", 
         }) 
      end
      ,
   },
   RawString = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "inner"), interline, dent),
          
      }) 
   end
   ,
   AString = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "e"), interline, dent),
          
      }) 
   end
   ,
   BString = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "e"), interline, dent),
          
      }) 
   end
   ,
   Method = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         "function"," ","(","self",","," ","alias",","," ","segment",")"," ",output(assert_node(self, "inner"), interline, dent),
         " ","end",dent(0),
          
      }) 
   end
   ,
   MethodString = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "e"), interline, dent),
          
      }) 
   end
   ,
   Name = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "head"), interline, dent),
         output(assert_node(self, "tail"), interline, dent),
          
      }) 
   end
   ,
   NameHead = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "head"), interline, dent),
          
      }) 
   end
   ,
   NamePart = function(self, interline, dent) 
      local interline = interline or {false}
      local dent = dent or indent()
      
      return table.concat({ 
         output(assert_node(self, "head"), interline, dent),
         output(assert_node(self, "tail"), interline, dent),
          
      }) 
   end
   , 
}
print(output(AST, false, indent()))



