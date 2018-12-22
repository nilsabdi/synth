require "template"

function associate_prep(self)
   self.next.left = self.right
end

function associate_left(self)
   self.next.left = node(
      move(self, {'left','right'}), 
      {meta(self).type[1], meta(self).type[2]:sub(1,3)..'e'}
   )
end

return template {} {
   segment {"parse", entry = "program", ignore = {T"space", T"newline"}} {
      program = [[ expr:add+ ]],

      add = {
         {add = [[ left:mul right:addr ]]},
         {mul = [[ exp:mul ]]}
      },

      addr = {
         {add  = [[ '+' right:mul next:addr ]]},
         {sub  = [[ '-' right:mul next:addr ]]},
         {adde = [[ '+' right:mul ]]},
         {sube = [[ '-' right:mul ]]},
      },

      mul = {
         {mul  = [[ left:term right:mulr ]]},
         {term = [[ exp:term ]]}
      },

      mulr = {
         {mul  = [[ '*' right:term next:mulr ]]},
         {div  = [[ '/' right:term next:mulr ]]},
         {mule = [[ '*' right:term ]]},
         {dive = [[ '/' right:term ]]},
      },

      term = [[ term:NUMBER ]],
   },

   segment {'script'} {
      add = {
         add = function(self) self.right.left = self.left end,
      },
      addr = {
         add = associate_prep,
         sub = associate_prep,
      },
      mul = {
         mul = function(self) self.right.left = self.left end,
      },
      mulr = {
         mul = associate_prep,
         div = associate_prep,
      },

   },

   segment {'script', direction='down'} {
      addr = {
         add = associate_left,
         sub = associate_left,
      },
      mulr = {
         mul = associate_left,
         div = associate_left,
      },
   },

   segment {'output'} {
      program = [[ expr ]],
      
      mul = {
         mul  = [[ right ]],
         term = [[ exp ]]
      },

      mulr = {
         mul  = [[ next ]],
         div  = [[ next ]],
         mule = [[ '(' left '*' right ')']],
         dive = [[ '(' left '/' right ')']],
      },

      add = {
         add = [[ right ]],
         mul = [[ exp ]]
      },
      addr = {
         add  = [[ next ]],
         sub  = [[ next ]],
         adde = [[ '(' left ' + ' right ')' ]],
         sube = [[ '(' left ' - ' right ')' ]],
      },
      term = [[ term ]]
   }
}
