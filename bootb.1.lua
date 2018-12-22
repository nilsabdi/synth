require "template"
return template {} {

segment {[[parse]], ignore = [[space newline tab]], entry = [[Template]], } {
   Template = [===[ template:Segment* ]===],
   Segment = [===[ name:NamePart+ ":" config:Config* "[" body:Rule* "]" ]===],
   Config = [===[ name:NamePart+ item:String ]===],
   Rule = {
      {Entry = [===[ "->" name:NamePart+ body:Variant ]===],},
      {Plain = [===[ name:NamePart+ body:Variant ]===],},
   },
   Variant = {
      {Array = [===[ "[" children:Variant* "]" ]===],},
      {Anonymous = [===[ pattern:String ]===],},
      {Named = [===[ name:NamePart+ pattern:String ]===],},
   },
   String = {
      [===[ "{" inner:AString* "}" ]===],
      [===[ "---" inner:BString* "---" ]===],
   },
   AString = {
      [===[ e:"\\\\" ]===],
      [===[ e:"\\}" ]===],
      [===[ e:"}"! ]===],
   },
   BString = {
      [===[ e:"\\\\" ]===],
      [===[ e:"\\-" ]===],
      [===[ e:"---"! ]===],
   },
   NamePart = {
      [===[ part:WORD ]===],
      [===[ part:"_" ]===],
      [===[ part:NUMBER ]===],
   },
},
segment {[[script]], } {
   Rule = {
      Entry = function (self, alias, segment)
         if global.template_entry then
            error(
               "duplicate parse segment entrypoints"
               ..errfmt(global.template_entry.node.name[1].part)
               ..errfmt(self.name[1].part)
            )
         end

         global.template_entry = {
            node = self,
            string = output( {NamePart = [[part]]}, self, iter(collect(tokenize([[name]]))) )
         }
      end,
   },
},
segment {[[script]], } {
   Segment = function (self, alias, segment)
      if 'parse' == output( {NamePart = [[part]]}, self, iter(collect(tokenize([[name]]))) )
      and type(self.config) == 'table' then
         local cfg = self.config

         if not global.template_entry then
            error("parse segment requires an entry point"..errfmt(self.name[1].part))
         end

         cfg[#cfg + 1] = node(
            {
               name = 'entry',
               item = '[['..global.template_entry.string..']]',
            },
            {'Config'},
            cfg
         )
      end
   end,
},
segment {[[output]], target = [[boota.lua]], } {
   Template = [[ 
      "require 'template'" / 
      "return template {}" / 
      "{" 
         > template < 
      "}" 
   ]],
   Segment = [[ 
      / 
      "segment {'" name "', " config "}" / 
      "{" 
         > body < 
      "}," 
   ]],
   Config = [[ 
      name " = " item ", " 
   ]],
   Rule = [[ 
      / 
      name " = " body 
   ]],
   Variant = {
      Named = [[ 
         "{ " name " = " pattern " }," / 
         
      ]],
      Anonymous = [[ 
         pattern "," / 
         
      ]],
      Array = [[ 
         "{" 
            > / 
            children < 
         "}," / 
         
      ]],
   },
   String = [[ 
      "[===[" inner "]\===]" 
   ]],
   AString = [[ 
      e 
   ]],
   BString = [[ 
      e 
   ]],
   NamePart = [[ 
      part 
   ]],
},

}