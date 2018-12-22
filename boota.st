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
   OutputPattern { '{' chunks:OutputChunk* '}' }
   OutputChunk   { element:OutputElement }
   OutputElement
   [
      Child     { name:Name }
      String    { string:String }
      Indent    { ">" }
      Dedent    { "<" }
      Newline   { "/" }
      Interline { "^" }
   ]


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


   Name { head:WORD tail:NamePart* }
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
]

output:
   target "bootb.lua"
[
   Template
   {
      'require "template"' /
      'return template {} {' /
      /
         ^template /
      /
      '}'
   }

   Segment
   {
      "segment {[[" name "]], " config "} {"
         > ^body <
      "},"
   }

   Config { name ' = [[' item ']], ' }


   ParseRule  { name ' = ' ^body }
   ParseVariant
   [
      Array     { '{' >^children< '},' }
      Anonymous { pattern ',' }
      Named     { '{' name ' = ' pattern '},' }
   ]
   ParsePattern  { '[=[ ' chunks ']\=]' }
   ParseChunk
   [
      Aliased { name ':' element ' ' }
      Plain   { element ' ' }
   ]
   ParseElement
   [
      Type   { type operators }
      Rule   { rule operators }
      Tokens { tokens operators }
   ]
   RulePath { rule variant }
   VariantPart { '.' variant }

   TokenType { t }

   ScriptRule { name ' = ' body }
   ScriptVariant
   [
      Array { '{' >^children< '},' }
      Code  { code ',' }
      Named { name ' = ' children }
   ]


   OutputRule { name ' = ' body }
   OutputVariant
   [
      Array { '{' >^children< '},' }
      Pattern { pattern ',' }
      Named { name ' = ' pattern }
   ]
   OutputPattern { '[=[ ' >chunks< ']\=]' }
   OutputChunk   { element }
   OutputElement
   [
      Child   { name " " }
      String  { string " " }
      Indent  { > "> " }
      Dedent  { "< " < }
      Newline { "/ " / }
      Interline { "^" }
   ]


   Operator { op }

   String [
      A { '"' inner '"' }
      B { "'" inner "'" }
   ]
   RawString { inner }
   AString { e }
   BString { e }

   Method { 'function (self, alias, segment)' inner 'end' }
   MethodString { e }

   Name { head tail }
   NamePart { head tail }
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

]

output:
   target 'bootc.lua'
[
   Template
   {
      'require "newtokenizer"' /
      'require "lib.iter"' /
      'require "lib.dump"' /
      'require "lib.stringext"' /
      'require "errfmt"' /
      'require "common"' /
      /
      'source = fetch(...)' /
      'assert(source, "a source file must be specified")' /
      'tokens = tokenize(source)' /
      'assert(tokens, "tokenization failure")' /
      /
      template
   }

   Segment [
      Parse {
         "local " name "_conf = {" config "}" /
         "local ruleiter = function(self)"
         >  'if name then return findOrderedKey(name) end' /
            'for n,rule in ipairs(self) do'
            >  'if type(rule) == "table" then n,rule = next(rule) end' /
               'local v = rule()' /
               'if v then return setmetatable(v, {'
                  >'type={"' name '", type(n)=="string" and n}'<
               '}) end'
            <'end'
         <'end' /
         /
         'tokens.ignore = ' >
            'iter(' name '_conf.ignore:trim():split(" "))' /
            ':map(function(e) return T(e) end)' <
         /
         'R = {'
            >^body<
         '}' /
         'AST = R.' entry '()'
         'assert(AST, "unexpected token:"..errfmt(tokens:peek()))' /
         'print(dump(AST))'
      }
      Script {
         ''
      }
      Output {}
   ]

   Config { name ' = [[' item ']], ' }


   ParseRule  {
      name ' = setmetatable({'
         >^body<
      '}, {__call = ruleiter});' /
   }
   ParseVariant
   [
      Array     { ^children }
      Anonymous { pattern ';' }
      Named     { '{' name ' = ' pattern '};' }
   ]
   ParsePattern  {
      'function ()'>
         'local __reset__, node = tokens.curr, {}' /
         /
         ^chunks /
         'print("parsed 'pname'")' /
         'return node'
      <'end'
   }
   ParseChunk
   [
      Aliased {
         'node.' name ' = ' element /
         'if not node.' name ' then tokens.curr = __reset__ return end' /
      }
      Plain   { 'if not ' element ' then return end' / }
   ]
   ParseElement
   [
      Type   { operators type opends }
      Rule   { operators 'R.'rule'' opends }
      Tokens { operators tokens opends }
   ]
   RulePath { rule variant }
   VariantPart { '"' variant '"' }

   TokenType { 'T"' t '"' }

   ScriptRule { '{' name ' = ' body '}' }
   ScriptVariant
   [
      Array { '{' >^children< '}' }
      Code  { code }
      Named { name ' = ' children }
   ]


   OutputRule { name ' = ' body }
   OutputVariant
   [
      Array { '{' >^children< '},' }
      Pattern { pattern ',' }
      Named { name ' = ' pattern }
   ]
   OutputPattern { '[=[ ' >chunks< ']\=]' }
   OutputChunk   { element }
   OutputElement
   [
      Child   { name " " }
      String  { string " " }
      Indent  { > "> " }
      Dedent  { "< " < }
      Newline { "/ " / }
      Interline { "^" }
   ]


   Operator
   [
      NoneOrMore { 'tokens:noneOrMore(' }
      OneOrMore  { 'tokens:oneOrMore(' }
      NoneOrOne  { 'tokens:noneOrOne(' }
      AllExcept  { 'tokens:allExcept(' }
   ]

   String [
      A { '"' inner '"' }
      B { "'" inner "'" }
   ]
   RawString { inner }
   AString { e }
   BString { e }

   Method { 'function (self, alias, segment)' inner 'end' }
   MethodString { e }

   Name { head tail }
   NamePart { head tail }
]