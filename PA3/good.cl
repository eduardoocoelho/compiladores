(* Todas as construções da figura 1; saída em tests/good.expected.
   Comentário aninhado: (* lexer oficial *). *)
class Empty {};
class Counter {
  value : Int;
  step(amount : Int) : SELF_TYPE { { value <- value + amount; self; } };
  read() : Int { value };
};
class Fancy inherits Counter {
  read() : Int { self@Counter.read() + 1 };
  fresh() : SELF_TYPE { new SELF_TYPE };
};
class Main inherits IO {
  first : Int;
  second : Int <- 5;
  title : String <- "Cool\n";
  blank : String <- "";
  enabled : Bool <- true;
  missing : Object;
  calc(x : Int, y : Int, z : Int) : Int { x + y * z };
  identity() : SELF_TYPE { self };
  main() : Object {
    {
      -- Init opcional, dependência entre vínculos, atribuição associativa à direita.
      let x : Int <- 1, y : Int <- x + 2, unused : Object in {
        first <- second <- calc(x, y, 4);
        out_int(first).out_string("\n");
        out_int(20 - 6 - 2).out_string("\n");
        out_int(24 / 3 / 2).out_string("\n");
        out_int((1 + 2) * 3).out_string("\n");
        out_int(~1 + 3).out_string("\n");
        if not x < y then out_string("bad\n") else out_string("lt\n") fi;
        if y <= 3 then out_string("le\n") else out_string("bad\n") fi;
        if x = 1 then out_string("eq\n") else out_string("bad\n") fi;
        while x < 3 loop { x <- x + 1; } pool;
        out_int(x).out_string("\n");
        if isvoid unused then out_string("void\n") else out_string("bad\n") fi;
      };
      -- Três despachos, encadeamento, SELF_TYPE e múltiplos ramos de case.
      let c : Fancy <- new Fancy in {
        out_int(c.step(9).read()).out_string("\n");
        out_int(c@Counter.read()).out_string("\n");
        case c.fresh() of
          f : Fancy => out_string("Fancy\n");
          b : Counter => out_string("Counter\n");
          o : Object => out_string("Object\n");
        esac;
      };
      if false then out_string("bad\n") else out_string(title) fi;
      identity();
      0;
    }
  };
};
