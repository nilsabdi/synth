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
      Rule   { rule:RulePath operators:Operator* }
      Tokens { tokens:String operators:Operator* }
   ]
   RulePath { rule:Name variant:VariantPart* }
   VariantPart { '.' variant:Name }


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
      { op:'*' }
      { op:'+' }
      { op:'?' }
      { op:'!' }
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

output: target "boota.lua"
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
      Rule   { rule operators }
      Tokens { tokens operators }
   ]
   RulePath { rule variant }
   VariantPart { '.' variant }


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
