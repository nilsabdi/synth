getmetatable("").__call = function (self, arg)
	if type(arg) == "table" then
		return self:sub(arg[1], arg[2] and arg[2]-1 or arg[1])
	end
end

getmetatable("").__mul = function (self, count)
   local out = ''
   for i=1,count do out = out .. self end
   return out
end

function string:trim()
   return self:match'^()%s*$' and '' or self:match'^%s*(.*%S)'
end

function string:isdigit ()
	local char = self:byte()
	return char and (char >= 48 and char <= 57)
end

function string:isletter ()
	local char = self:byte()
	return char and ((char >= 65 and char <= 90) or (char >= 97 and char <= 122))
end

function string:isupper ()
	return self == self:upper()
end

function string:islower ()
	return self == self:lower()
end

function string:isspace ()
	local char = self:byte()
	return char and char == 32
end

function string:istab ()
	local char = self:byte()
	return char and char == 9
end

function string:iseol ()
	local char = self:byte()
	return char and (char == 10 or char == 13)
end

function string:split (delim)
	local items = {}
	local curr = self:find(delim, nil, true)
   local last = 1

	while curr do
		items[#items+1] = self{last, curr}
		last = curr+1
		curr = self:find(delim, curr+1, true)
	end

   items[#items+1] = self{last, #self+1}

   return items
end

function string:starts (sub)
	return self:sub(1,#sub) == sub
end

function string:ends (sub)
	return self:sub(-#sub) == sub
end

function string:similar (other)
	local self = self:upper()
   local other = other:upper()

	if self:find(other) then return true end
	if other:find(self) then return true end

   local a,b

   for i=1,#self do
		a,b = other:find(self:sub(1,i-1) .. '.?' .. self:sub(i+1))
		if a then return a,b end
	end

   if #self>3 then
		for i=1,#self do
			a,b = other:find(self:sub(1,i-1) .. '..' .. self:sub(i+2))
         if a then return a,b end
		end
	end
end

function string:escape(chars)
	return self:gsub(chars, '\\'..chars)
end

function string:chars (self)
   local char = 0

	return function ()
		char = char + 1
		if char > #self then return nil end
		return char, self{char}
	end
end
