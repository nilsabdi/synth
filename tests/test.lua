require "template"

return template {} {
	segment {"parse", entry='program', ignore = {T"space", T"newline"}} {
      program =[[ body:statement* ]],

      statement = {
         func =[[ begin:func.s body:func.b end:func.e ]],
         print =[[ 'TALK TO THE HAND' str:string ]]
      },
   
      func = {
         s =[[ "IT'S SHOWTIME" ]],
         b =[[ body:statement* ]],
         e =[[ "YOU HAVE BEEN TERMINATED" ]]
      },
   
      string = {
         [[ "'" inner:"'"!* "'" ]],
         [[ '"' inner:'"'!* '"' ]]
      }
   },

	segment {"output"} {
      program =[[ body ]],

      statement = {
         func =[[ begin >body< end ]],
         print =[[ / 'print(' str ')' ]]
      },
   
      func = {
         s =[[ 'function()' ]],
         b =[[ body ]],
         e =[[ 'end' ]]
      },
   
      string =[[ '"' inner '"' ]]
   }
}
