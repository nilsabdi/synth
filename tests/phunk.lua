-*-
   funk inspired minimalist statically typed lambda calculus
-*-



-- core methods

   -- imports
   with file

   -- core
   function := load file funcname -- ffi
   panic message -- prints a stacktrace

   -- ffi loaded core methods
   bytes:   Result<[u8], [u8]> = read  file bytecount
   success: Result<bool, [u8]> = write file bytes
   file:    Result<u64, [u8]>  = open  filename mode -- returns handle

   -- standard io streams
   stdin  := 0
   stdout := 1
   stderr := 2

   -- functions
   fac := {
      |2| 2
      |n:i32| n * fac (n - 1)
   }

   fac 4
   fac(4)

   -/-
      fac = function(n)
         if n == 2 then return 2 end
         return n * ( fac ( n - 1 ) )
      end

      fac(4)
   -\-
   -/-
      fac:
         store 4, n
         if_1:
            load 4, n
            push 4, 2
            jne  4, fi_1
            push 4, 2
            ret
         fi_1:
            load 4, n
            load 4, n
            push 4, 1
            sub  4
            call fac
            mul  4
            ret

      push 4, 4
      call fac
   -\-

   -- primitive typedefs
   T iu8 iu16 iu32 iu64 f32 f64
   [T] -- arrays which know their size

   -- complex types
   -- :: is shorthand for := {...}
   Ok :: |value: T| { -- single capital letter acts as a generic
      |'is_ok'|  bool -> True
      |'is_err'| bool -> False
      |'unwrap'| T    -> value
   }

   Err :: |message: T| {
      |'is_ok'|  bool -> False
      |'is_err'| bool -> True
      |'unwrap'|      -> panic 'Error while unwrapping a Result: {message}'
   }

   Result :: |ok:$ err:$| { -- a $ sign acts as a type container
      |v:Ok:ok|   Ok:ok   -> v
      |v:Err:err| Err:err -> v
      |_|                 -> panic 'Result type did not match'
   }

   r: Result(i32, [u8]) = Ok(10)

   -/-
      Ok = function (value)
         return function(_)
            if _ == 'is_ok' then return true end
            if _ == 'is_err' then return false end
            if _ == 'unwrap' then return value end
         end
      end

      Err = function (message)
         return function(_)
            if _ == 'is_ok' then return false end
            if _ == 'is_err' then return true end
            if _ == 'unwrap' then
               panic('Error while unwrapping a Result: {}', message)
            end
         end
      end

      Result = function(ok) return function(err)
         return function(v)
            if v.type == ok then return v end
            if v.type == err then return v end
            panic 'Result type did not match'
         end
      end end

      r = Result (i32) (arr(u8)) (Ok(10))
      -- r = Ok{} (i32) (arr(u8)) (Ok(10))
      -- r = Err{i32} (arr(u8)) (Ok(10))
      -- r = v{i32, arr(u8)} (Ok(10))
      -- r =
   -\-

   vec2 :: |_x:f32 _y:f32| {
      |'x'| _x
      |'y'| _y
      |'+' v:vec2| vec2(_x + v.x, _y + v.y)
   }

   vec2 := { |_x:f32 _y:f32| {
      |'x'| _x
      |'y'| _y
      |'+' v:vec2| vec2(_x + v.x, _y + v.y)
   }}

   v1 := vec2(1, 2)

      -/-
      vec2 = function(_x) return function(_y)
         return function (_)
            if _ == 'x' then return _x end
            if _ == 'y' then return _y end
            if _ == '+' then
               return function(v)
                  return vec2 (_x + v'x') (_y + v'y')
               end
            end
         end
      end end

      v1 = vec2(1)(2)
      -\-


