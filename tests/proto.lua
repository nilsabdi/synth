--[[token = {
	type = TYPE
	lexeme = string
	pos = {
		from = num
		to = num
		line = num
	}
}

parse modes
	KEEP (default)
	DISCARD
 ]]

return {

	__config__ = {
		mode = 'byte',
	},


	comments = {
		__config__ = {
			ignore = [[ WORD NUMBER SYMBOL SPACE TAB NEWLINE ]],
			mode = 'parse',
			parse_mode = 'discard',
			enter = 'comment'
		},

		comment = {
			single = [[ single.begin !single.end single.end ]],
			multi = {
				c = [[ multiline.begin.c !multiline.end.c multiline.end.c ]],
				lua = [[ multiline.begin.lua !multiline.end.lua multiline.end.lua ]]
			}
		},

		single = {
			begin = {
				[[ '//' ]],
				[[ '--' ]]
			},
			endc = {
				[[ '\n' ]]
			}
		},

		multiline = {
			begin = {
				c = [[ '/*' ]],
				lua = [=[ '--[[' ]=]
			},
			endc = {
				c = [[ '*/' ]],
				lua = [=[ '--]]' ]=]
			}
		}
	},

	assign_types = {
		__config__ = {
			mode = 'script',
			walk_mode = 'up'
		},

		num = function (self)
			self.type = 'number'
		end,

		string = function(self)
			self.type = 'string'
		end
	}


}
