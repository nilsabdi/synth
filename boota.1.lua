require 'template'
return template {}
{
   
   segment {'parse', ignore = [===[space newline tab]===], entry = [[Template]], }
   {
      
      Template = [===[ template:Segment* ]===],
      
      Segment = {
         
         { Parse = [===[ name:'parse'  ':' config:Config* '[' body:ParseRule*  ']' ]===] },
         { Script = [===[ name:'script' ':' config:Config* '[' body:ScriptRule* ']' ]===] },
         { Output = [===[ name:'output' ':' config:Config* '[' body:OutputRule* ']' ]===] },
         
      },
      
      Config = [===[ name:Name item:String ]===],
      
      ParseRule = [===[ name:Name body:ParseVariant  ]===],
      
      ParseVariant = {
         
         { Array = [===[ '[' children:ParseVariant* ']' ]===] },
         { Anonymous = [===[ pattern:ParsePattern ]===] },
         { Named = [===[ name:Name pattern:ParseVariant ]===] },
         
      },
      
      ParsePattern = [===[ '{' chunks:ParseChunk*  '\}' ]===],
      
      ParseChunk = {
         
         { Aliased = [===[ name:Name ':' element:ParseElement ]===] },
         { Plain = [===[ element:ParseElement ]===] },
         
      },
      
      ParseElement = {
         
         { Rule = [===[ rule:RulePath operators:Operator* ]===] },
         { Tokens = [===[ tokens:String operators:Operator* ]===] },
         
      },
      
      RulePath = [===[ rule:Name variant:VariantPart* ]===],
      
      VariantPart = [===[ '.' variant:Name ]===],
      
      ScriptRule = [===[ name:Name body:ScriptVariant ]===],
      
      ScriptVariant = {
         
         { Array = [===[ '[' children:ScriptVariant* ']' ]===] },
         { Code = [===[ code:Method ]===] },
         { Named = [===[ name:Name children:ScriptVariant ]===] },
         
      },
      
      OutputRule = [===[ name:Name body:OutputVariant ]===],
      
      OutputVariant = {
         
         { Array = [===[ '[' children:OutputVariant* ']' ]===] },
         { Pattern = [===[ pattern:OutputPattern ]===] },
         { Named = [===[ name:Name pattern:OutputVariant ]===] },
         
      },
      
      OutputPattern = [===[ '{' chunks:OutputChunk* '\}' ]===],
      
      OutputChunk = [===[ element:OutputElement ]===],
      
      OutputElement = {
         
         { Child = [===[ name:Name ]===] },
         { String = [===[ string:String ]===] },
         { Indent = [===[ ">" ]===] },
         { Dedent = [===[ "<" ]===] },
         { Newline = [===[ "/" ]===] },
         
      },
      
      Operator = {
         
         [===[ op:'*' ]===],
         [===[ op:'+' ]===],
         [===[ op:'?' ]===],
         [===[ op:'!' ]===],
         
      },
      
      String = {
         
         [===[ '"' inner:AString* '"' ]===],
         [===[ "'" inner:BString* "'" ]===],
         
      },
      
      AString = {
         
         [===[ e:'\\\\' ]===],
         [===[ e:'\\"' ]===],
         [===[ e:'"'! ]===],
         
      },
      
      BString = {
         
         [===[ e:'\\\\' ]===],
         [===[ e:"\\'" ]===],
         [===[ e:"'"! ]===],
         
      },
      
      Method = [===[ '---' inner:MethodString* '---' ]===],
      
      MethodString = {
         
         [===[ e:'\\\\' ]===],
         [===[ e:'\\-' ]===],
         [===[ e:'---'! ]===],
         
      },
      
      Name = [===[ head:WORD tail:NamePart* ]===],
      
      NamePart = {
         
         [===[ head:'_' tail:WORD ]===],
         [===[ head:'_' tail:NUMBER ]===],
         
      },
      
   },
   segment {'script', }
   {
      
      Name = [===[
      self.string = collapse(self)
   ]===],
      
   },
   segment {'script', }
   {
      
      Rule = {
         
         { Entry = [===[
         if global.template_entry then
            error(
               "duplicate parse segment entrypoints"
               ..errfmt(global.template_entry.node.name.string)
               ..errfmt(self.name.string)
            )
         end

         global.template_entry = self
      ]===] },
         
      },
      
   },
   segment {'script', }
   {
      
      Segment = [===[
      if 'parse' == self.name.string and type(self.config) == 'table' then
         local cfg = self.config

         if not global.template_entry then
            error("parse segment requires an entry point"..errfmt(self.name.string))
         end

         cfg[#cfg + 1] = node(
            {
               name = 'entry',
               item = '[['..global.template_entry.name.string..']]',
            },
            {'Config'},
            cfg
         )
      end
   ]===],
      
   },
   segment {'output', target = [===[bootb.lua]===], }
   {
      
      Template = [===[
      'require "template"' /
      'return template {\} {' //
         ^template
      // '\}'
   ]===],
      
      Segment = [===[
      "segment {[[" name "]], " config "\} {"
         > ^body <
      "\},"
   ]===],
      
      Config = [===[ name ' = [[' item ']], ' ]===],
      
      ParseRule = [===[ name ' = ' ^body ]===],
      
      ParseVariant = {
         
         { Array = [===[ '{' >^children< '\},' ]===] },
         { Anonymous = [===[ pattern ',' ]===] },
         { Named = [===[ '{' name ' = ' pattern '\},' ]===] },
         
      },
      
      ParsePattern = [===[ '[===[ ' chunks ']\===]' ]===],
      
      ParseChunk = {
         
         { Aliased = [===[ name ':' element ' ' ]===] },
         { Plain = [===[ element ' ' ]===] },
         
      },
      
      ParseElement = {
         
         { Rule = [===[ rule operators ]===] },
         { Tokens = [===[ '"' tokens '"' operators ]===] },
         
      },
      
      RulePath = [===[ rule variant ]===],
      
      VariantPart = [===[ '.' variant ]===],
      
      ScriptRule = [===[ name ' = ' body ]===],
      
      ScriptVariant = {
         
         { Array = [===[ '{' >^children< '\},' ]===] },
         { Code = [===[ code ',' ]===] },
         { Named = [===[ name ' = ' children ]===] },
         
      },
      
      OutputRule = [===[ name ' = ' body ]===],
      
      OutputVariant = {
         
         { Array = [===[ '{' >^children< '\},' ]===] },
         { Pattern = [===[ pattern ',' ]===] },
         { Named = [===[ name ' = ' pattern ]===] },
         
      },
      
      OutputPattern = [===[ '[[ ' >chunks< ']]' ]===],
      
      OutputChunk = [===[ element ]===],
      
      OutputElement = {
         
         { Child = [===[ name " " ]===] },
         { String = [===[ '"' string '" ' ]===] },
         { Indent = [===[ > "> " ]===] },
         { Dedent = [===[ "< " < ]===] },
         { Newline = [===[ "/ " / ]===] },
         { Interline = [===[ "^" ]===] },
         
      },
      
      Operator = [===[ op ]===],
      
      String = [===[ inner ]===],
      
      AString = [===[ e ]===],
      
      BString = [===[ e ]===],
      
      Method = [===[ 'function (self, alias, segment)' inner 'end' ]===],
      
      MethodString = [===[ e ]===],
      
      Name = [===[ head tail ]===],
      
      NamePart = [===[ head tail ]===],
      
   },
}