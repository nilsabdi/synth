return
{
   ignore='indent dedent eol tab space';

	{  'parse'; mode = 'parse'; entry = 'program'; ------------------------------------

      {  'program';
         [[ program:statement* ]]
      },
      {  'statement';
         [[ greet:greeting.world ]],
         [[ greet:greeting.me ]]
      },
      {  'greeting';
         { world = [[ intro:intro.hello 'world' ]] },
         { me =    [[ intro 'me' ]] }
      },
      {  'intro';
         { hello = [[ word:'hello' ' ' ]] }
      }
	},

   {  'goodbye'; mode = 'script'; ----------------------------------------------------

      {  'greeting';
         { world = function(self) self.intro = 'bye' end }
      }
   },

   {  'output'; mode = 'output'; -----------------------------------------------------

      {  'program'; [[ program ]] },
      {  'statement'; [[ greet ]] },
      {  'greeting';
         { world = [[ intro 'earth' ]] },
         { me =    [[ 'not me' ]] }
      },
      {  'intro';
         { hello = [[ 'greetings ' ]] }
      }
   }
}

--[[
-- source --

   hello world
   hello me

-- ast --

   { 'program',
      { 'statement'
         greet = { 'greeting.world',
            intro = { 'intro.hello', word = 'hello' },
         }
      },
      { 'statement'
         greet = { 'greeting.me',
            intro = 'bye',
         }
      }
   }

-- output --

   greetings earthnot me

--]]
