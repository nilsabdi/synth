require "newtokenizer"
require "lib.iter"
require "lib.dump"
require "lib.stringext"
require "errfmt"
require "common"

source = fetch(...)
assert(source, "a source file must be specified")
tokens = tokenize(source)
assert(tokens, "tokenization failure")

local parse_conf = {ignore = [[space newline tab]], entry = [[Template]], }
local ruleiter = function(self)
   if name then return findOrderedKey(name) end
   for n,rule in ipairs(self) do
      if type(rule) == "table" then n,rule = next(rule) end
      local v = rule()
      if v then return setmetatable(v, {
         type={"parse", type(n)=="string" and n}
      }) end
   end
end

tokens.ignore = 
   iter(parse_conf.ignore:trim():split(" "))
   :map(function(e) return T(e) end)

R = {
   Template = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.template = tokens:noneOrMore(R.Segment)
         if not node.template then tokens.curr = __reset__ return end
         
         print("parsed Template")
         return node
      end;
   }, {__call = ruleiter});
   
   Segment = setmetatable({
      {Parse = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match('parse')
         if not node.name then tokens.curr = __reset__ return end
         
         if not tokens:match(':') then return end
         
         node.config = tokens:noneOrMore(R.Config)
         if not node.config then tokens.curr = __reset__ return end
         
         if not tokens:match('[') then return end
         
         node.body = tokens:noneOrMore(R.ParseRule)
         if not node.body then tokens.curr = __reset__ return end
         
         if not tokens:match(']') then return end
         
         print("parsed Segment.Parse")
         return node
      end;};
      {Script = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match('script')
         if not node.name then tokens.curr = __reset__ return end
         
         if not tokens:match(':') then return end
         
         node.config = tokens:noneOrMore(R.Config)
         if not node.config then tokens.curr = __reset__ return end
         
         if not tokens:match('[') then return end
         
         node.body = tokens:noneOrMore(R.ScriptRule)
         if not node.body then tokens.curr = __reset__ return end
         
         if not tokens:match(']') then return end
         
         print("parsed Segment.Script")
         return node
      end;};
      {Output = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match('output')
         if not node.name then tokens.curr = __reset__ return end
         
         if not tokens:match(':') then return end
         
         node.config = tokens:noneOrMore(R.Config)
         if not node.config then tokens.curr = __reset__ return end
         
         if not tokens:match('[') then return end
         
         node.body = tokens:noneOrMore(R.OutputRule)
         if not node.body then tokens.curr = __reset__ return end
         
         if not tokens:match(']') then return end
         
         print("parsed Segment.Output")
         return node
      end;};
   }, {__call = ruleiter});
   
   Config = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         node.item = tokens:match(R.RawString)
         if not node.item then tokens.curr = __reset__ return end
         
         print("parsed Config")
         return node
      end;
   }, {__call = ruleiter});
   
   ParseRule = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         node.body = tokens:match(R.ParseVariant)
         if not node.body then tokens.curr = __reset__ return end
         
         print("parsed ParseRule")
         return node
      end;
   }, {__call = ruleiter});
   
   ParseVariant = setmetatable({
      {Array = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('[') then return end
         
         node.children = tokens:noneOrMore(R.ParseVariant)
         if not node.children then tokens.curr = __reset__ return end
         
         if not tokens:match(']') then return end
         
         print("parsed ParseVariant.Array")
         return node
      end;};
      {Named = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         node.pattern = tokens:match(R.ParseVariant)
         if not node.pattern then tokens.curr = __reset__ return end
         
         print("parsed ParseVariant.Named")
         return node
      end;};
      {Anonymous = function ()
         local __reset__, node = tokens.curr, {}
         
         node.pattern = tokens:match(R.ParsePattern)
         if not node.pattern then tokens.curr = __reset__ return end
         
         print("parsed ParseVariant.Anonymous")
         return node
      end;};
   }, {__call = ruleiter});
   
   ParsePattern = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('{') then return end
         
         node.chunks = tokens:noneOrMore(R.ParseChunk)
         if not node.chunks then tokens.curr = __reset__ return end
         
         if not tokens:match('}') then return end
         
         print("parsed ParsePattern")
         return node
      end;
   }, {__call = ruleiter});
   
   ParseChunk = setmetatable({
      {Aliased = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         if not tokens:match(':') then return end
         
         node.element = tokens:match(R.ParseElement)
         if not node.element then tokens.curr = __reset__ return end
         
         print("parsed ParseChunk.Aliased")
         return node
      end;};
      {Plain = function ()
         local __reset__, node = tokens.curr, {}
         
         node.element = tokens:match(R.ParseElement)
         if not node.element then tokens.curr = __reset__ return end
         
         print("parsed ParseChunk.Plain")
         return node
      end;};
   }, {__call = ruleiter});
   
   ParseElement = setmetatable({
      {Rule = function ()
         local __reset__, node = tokens.curr, {}
         
         node.rule = tokens:match(R.RulePath)
         if not node.rule then tokens.curr = __reset__ return end
         
         node.operators = tokens:noneOrMore(R.Operator)
         if not node.operators then tokens.curr = __reset__ return end
         
         print("parsed ParseElement.Rule")
         return node
      end;};
      {Tokens = function ()
         local __reset__, node = tokens.curr, {}
         
         node.tokens = tokens:match(R.String)
         if not node.tokens then tokens.curr = __reset__ return end
         
         node.operators = tokens:noneOrMore(R.Operator)
         if not node.operators then tokens.curr = __reset__ return end
         
         print("parsed ParseElement.Tokens")
         return node
      end;};
   }, {__call = ruleiter});
   
   RulePath = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.rule = tokens:match(R.Name)
         if not node.rule then tokens.curr = __reset__ return end
         
         node.variant = tokens:noneOrMore(R.VariantPart)
         if not node.variant then tokens.curr = __reset__ return end
         
         print("parsed RulePath")
         return node
      end;
   }, {__call = ruleiter});
   
   VariantPart = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('.') then return end
         
         node.variant = tokens:match(R.Name)
         if not node.variant then tokens.curr = __reset__ return end
         
         print("parsed VariantPart")
         return node
      end;
   }, {__call = ruleiter});
   
   ScriptRule = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         node.body = tokens:match(R.ScriptVariant)
         if not node.body then tokens.curr = __reset__ return end
         
         print("parsed ScriptRule")
         return node
      end;
   }, {__call = ruleiter});
   
   ScriptVariant = setmetatable({
      {Array = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('[') then return end
         
         node.children = tokens:noneOrMore(R.ScriptVariant)
         if not node.children then tokens.curr = __reset__ return end
         
         if not tokens:match(']') then return end
         
         print("parsed ScriptVariant.Array")
         return node
      end;};
      {Code = function ()
         local __reset__, node = tokens.curr, {}
         
         node.code = tokens:match(R.Method)
         if not node.code then tokens.curr = __reset__ return end
         
         print("parsed ScriptVariant.Code")
         return node
      end;};
      {Named = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         node.children = tokens:match(R.ScriptVariant)
         if not node.children then tokens.curr = __reset__ return end
         
         print("parsed ScriptVariant.Named")
         return node
      end;};
   }, {__call = ruleiter});
   
   OutputRule = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         node.body = tokens:match(R.OutputVariant)
         if not node.body then tokens.curr = __reset__ return end
         
         print("parsed OutputRule")
         return node
      end;
   }, {__call = ruleiter});
   
   OutputVariant = setmetatable({
      {Array = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('[') then return end
         
         node.children = tokens:noneOrMore(R.OutputVariant)
         if not node.children then tokens.curr = __reset__ return end
         
         if not tokens:match(']') then return end
         
         print("parsed OutputVariant.Array")
         return node
      end;};
      {Pattern = function ()
         local __reset__, node = tokens.curr, {}
         
         node.pattern = tokens:match(R.OutputPattern)
         if not node.pattern then tokens.curr = __reset__ return end
         
         print("parsed OutputVariant.Pattern")
         return node
      end;};
      {Named = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         node.pattern = tokens:match(R.OutputVariant)
         if not node.pattern then tokens.curr = __reset__ return end
         
         print("parsed OutputVariant.Named")
         return node
      end;};
   }, {__call = ruleiter});
   
   OutputPattern = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('{') then return end
         
         node.chunks = tokens:noneOrMore(R.OutputChunk)
         if not node.chunks then tokens.curr = __reset__ return end
         
         if not tokens:match('}') then return end
         
         print("parsed OutputPattern")
         return node
      end;
   }, {__call = ruleiter});
   
   OutputChunk = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.element = tokens:match(R.OutputElement)
         if not node.element then tokens.curr = __reset__ return end
         
         print("parsed OutputChunk")
         return node
      end;
   }, {__call = ruleiter});
   
   OutputElement = setmetatable({
      {Child = function ()
         local __reset__, node = tokens.curr, {}
         
         node.name = tokens:match(R.Name)
         if not node.name then tokens.curr = __reset__ return end
         
         print("parsed OutputElement.Child")
         return node
      end;};
      {String = function ()
         local __reset__, node = tokens.curr, {}
         
         node.string = tokens:match(R.String)
         if not node.string then tokens.curr = __reset__ return end
         
         print("parsed OutputElement.String")
         return node
      end;};
      {Indent = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match(">") then return end
         
         print("parsed OutputElement.Indent")
         return node
      end;};
      {Dedent = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match("<") then return end
         
         print("parsed OutputElement.Dedent")
         return node
      end;};
      {Newline = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match("/") then return end
         
         print("parsed OutputElement.Newline")
         return node
      end;};
      {Interline = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match("^") then return end
         
         print("parsed OutputElement.Interline")
         return node
      end;};
   }, {__call = ruleiter});
   
   Operator = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.op = tokens:match('*')
         if not node.op then tokens.curr = __reset__ return end
         
         print("parsed Operator")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.op = tokens:match('+')
         if not node.op then tokens.curr = __reset__ return end
         
         print("parsed Operator")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.op = tokens:match('?')
         if not node.op then tokens.curr = __reset__ return end
         
         print("parsed Operator")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.op = tokens:match('!')
         if not node.op then tokens.curr = __reset__ return end
         
         print("parsed Operator")
         return node
      end;
   }, {__call = ruleiter});
   
   String = setmetatable({
      {A = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('"') then return end
         
         node.inner = tokens:noneOrMore(R.AString)
         if not node.inner then tokens.curr = __reset__ return end
         
         if not tokens:match('"') then return end
         
         print("parsed String.A")
         return node
      end;};
      {B = function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match("'") then return end
         
         node.inner = tokens:noneOrMore(R.BString)
         if not node.inner then tokens.curr = __reset__ return end
         
         if not tokens:match("'") then return end
         
         print("parsed String.B")
         return node
      end;};
   }, {__call = ruleiter});
   
   RawString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('"') then return end
         
         node.inner = tokens:noneOrMore(R.AString)
         if not node.inner then tokens.curr = __reset__ return end
         
         if not tokens:match('"') then return end
         
         print("parsed RawString")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match("'") then return end
         
         node.inner = tokens:noneOrMore(R.BString)
         if not node.inner then tokens.curr = __reset__ return end
         
         if not tokens:match("'") then return end
         
         print("parsed RawString")
         return node
      end;
   }, {__call = ruleiter});
   
   AString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:match('\\\\')
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed AString")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:match('\\"')
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed AString")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:allExcept('"')
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed AString")
         return node
      end;
   }, {__call = ruleiter});
   
   BString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:match('\\\\')
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed BString")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:match("\\'")
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed BString")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:allExcept("'")
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed BString")
         return node
      end;
   }, {__call = ruleiter});
   
   Method = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         if not tokens:match('---') then return end
         
         node.inner = tokens:noneOrMore(R.MethodString)
         if not node.inner then tokens.curr = __reset__ return end
         
         if not tokens:match('---') then return end
         
         print("parsed Method")
         return node
      end;
   }, {__call = ruleiter});
   
   MethodString = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:match('\\\\')
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed MethodString")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:match('\\-')
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed MethodString")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.e = tokens:allExcept('---')
         if not node.e then tokens.curr = __reset__ return end
         
         print("parsed MethodString")
         return node
      end;
   }, {__call = ruleiter});
   
   Name = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.head = tokens:match(T"WORD")
         if not node.head then tokens.curr = __reset__ return end
         
         node.tail = tokens:noneOrMore(R.NamePart)
         if not node.tail then tokens.curr = __reset__ return end
         
         print("parsed Name")
         return node
      end;
   }, {__call = ruleiter});
   
   NamePart = setmetatable({
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.head = tokens:match('_')
         if not node.head then tokens.curr = __reset__ return end
         
         node.tail = tokens:match(T"WORD")
         if not node.tail then tokens.curr = __reset__ return end
         
         print("parsed NamePart")
         return node
      end;
      function ()
         local __reset__, node = tokens.curr, {}
         
         node.head = tokens:match('_')
         if not node.head then tokens.curr = __reset__ return end
         
         node.tail = tokens:match(T"NUMBER")
         if not node.tail then tokens.curr = __reset__ return end
         
         print("parsed NamePart")
         return node
      end;
   }, {__call = ruleiter});
   
}
AST = R.Template()assert(AST, "unexpected token:"..errfmt(tokens:peek()))
print(dump(AST))