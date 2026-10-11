-- Inicializador vê vínculo anterior; vínculo posterior faz sombra.
class Main inherits IO {
  main() : Object {
    let x : Int <- 5 in {
      out_int(let x : Int <- x + 1, y : Int <- x + 2,
                  x : Int <- y + 1 in x + y).out_string("\n");
      out_int(x).out_string("\n");
      out_int(1 + let z : Int <- 2 in z * 3 + 4).out_string("\n");
    }
  };
};
