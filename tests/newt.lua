require 'template'

--[==[
   a = [[pattern]]
   b = { [[pattern]], ... }
   c = { unordered=[[pattern]], ... }
   d = { {ordered=[[pattern]]}, {...}
}--]==]

return template {
   ignore = 'eol tab space',
} {
   segment { 'parse', entry = 'program' } {
      program = {
         [[ program:statement* ]]
      },
      statement = {
         [[ greet:greeting.world ]],
         [[ greet:greeting.me ]]
      },
      greeting = {
         { world = [[ intro:intro.hello 'world' ]] },
         { me =    [[ intro 'me' ]] }
      },
      intro = {
         { hello = [[ word:'hello' ' ' ]] }
      }
   },

   segment { 'script' } {
      greeting = {
         world = function(self) self.intro = 'bye' end
      }
   },

   segment { 'output' } {
      program = [[ program ]],
      statement = [[ greet ]],
      greeting = {
         world = [[ intro 'earth' ]],
         me =    [[ 'not me' ]]
      },
      intro = {
         hello = [[ 'greetings ' ]]
      }
   },
}
