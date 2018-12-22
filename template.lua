function template (__config)
   return function (segments)
      for k, v in ipairs(segments) do
         assert(
            type(v)=='table',
            'segment "'..k..'" isn\'t a table, perhaps you forgot to define its body')
      end
      __config.__template__ = true
      __config.file = debug.getinfo(2, "S").source

      segments.__config__ = __config
      return segments
   end
end

function segment (__config)
   __config.type = __config[1] or __config.type
   __config[1] = nil

   assert(__config.type, 'segment must define its type')
   if __config.type == 'parse' then
      assert(__config.entry, 'parse segment must define its entry rule')
   end

   return function (rules)
      rules.__config__ = __config
      return rules
   end
end
