// (add (sub (add (sub 3 2) 1) 2) 3)

parse:
   ignore { space newline }
   entry { program }
[
   program { expr:add }

   add { left:term right:addr }
   addr [
      add { '+' right:term next:addr }
      sub { '-' right:term next:addr }
      adde { '+' right:term }
      sube { '-' right:term }
   ]

   term { term:NUMBER }
]

script: direction { up } [
   add {
      self.right.left = self.left
      self.left = nil
   }

   addr [
      add {
         self.next.left = self.right
         self.right = nil
      }

      sub {
         self.next.left = self.right
         self.right = nil
      }
   ]
]

output: [
   program { expr }

   add { right }
   addr [
      add  { '(add ' left ' ' next  ')' }
      sub  { '(sub ' left ' ' next  ')' }
      adde { '(add ' left ' ' right ')' }
      sube { '(sub ' left ' ' right ')' }
   ]

   term { term }
]
