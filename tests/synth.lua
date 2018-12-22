require "template"

function nameToStr(name)
   return output(
      { namePart = [[ part ]] },
      name,
      iter(collect(tokenize([[name]])))
   )
end

return template {} {
   segment {"parse", entry='template', ignore=[[ space newline tab ]]} {
      template = [[ template:segment* ]],

      segment =
         [[ name:namePart+  ':' cfg:config* body:rules ]],


      config = [[ name:namePart+ item:string ]],

      string = {
         [[ '{' inner:astring* '}' ]],
         [[ '|' inner:bstring* '|' ]],
      },

      astring = {
         [[ e:'\\\\' ]],
         [[ e:'\\}' ]],
         [[ e:'}'! ]],
      },
      bstring = {
         [[ e:'\\\\' ]],
         [[ e:'\\|' ]],
         [[ e:'|'! ]],
      },

      rules = [[ '[' rules:rule* ']' ]],

      rule = {
         {entry = [[ '->' name:namePart+ body:variant ]]},
         {plain = [[ name:namePart+ body:variant ]]},
      },

      variant = {
         {array = [[ '[' v:variant* ']' ]]},
         {anon  = [[ pattern:string ]]},
         {named = [[ name:namePart+ pattern:string ]]},
      },

      namePart = {
         [[ part:WORD ]],
         [[ part:"_" ]],
         [[ part:NUMBER ]]
      }
   },

   segment {"script"} {
      rule = {
         {entry = [[
            if template_entry then
               error(
                  "duplicate parse segment entrypoints"
                  ..errfmt(template_entry.node.name[1].part)
                  ..errfmt(self.name[1].part)
               )
            end

            template_entry = {
               node=self,
               string=nameToStr(self)
            }
         ]]}
      }
   },

   segment {"script"} {
      segment = [=[
         dprint(dump(type(self.cfg)), nameToStr(self))

         if nameToStr(self) == 'parse' and type(self.cfg)=='table' then
            local cfg = self.cfg

            if not template_entry then
               error("parse segment requires an entry point"..errfmt(self.name[1].part))
            end

            cfg[#cfg + 1] = node(
               {
                  name = 'entry',
                  item = '[['..template_entry.string..']]',
               },
               -- nil,
               {'config'},
               cfg
            )
         end
      ]=]
   },

   segment {"output", target='boot.lua'} {
      template = [[
         "require 'template'"/
         "return template {}" /
         "{"
            >template<
         "}"
      ]],
      segment = [[
         / "segment {'" name "', " cfg "}" /
         "{"
            >body<
         "},"
      ]],

      config = [[ name ' = ' item ', ' ]],

      string = [=[ "[===[" inner "]===]" ]=],
      astring = [[ e ]],
      bstring = [[ e ]],

      rules = [[ rules ]],

      rule = {
         entry = [[ / name ' = ' body ]],
         plain = [[ / name ' = ' body ]]
      },

      variant = {
         named = [[ '{ 'name ' = ' pattern' },' / ]],
         anon = [[ pattern ',' / ]],
         array = [[
            '{'
               >/v<
            '},' /
         ]]
      },

      namePart = [[ part ]],

   }
}