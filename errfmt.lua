function errfmt(token)
   local line = token.meta.source
   local before = line {0, token.pos.from} :split "\n"
   local after = line {token.pos.to, 0} :split "\n"
   return
      "\n" .. ("%5d| "):format(token.pos.line)
      ..  before[#before]
      .. "\27[41m" .. (token.type=='newline' and ' ' or token.lexeme) .. "\27[0m"
      .. (token.type~='newline' and after[1] or '')
end
