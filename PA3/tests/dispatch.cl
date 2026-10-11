-- Despacho dinâmico seleciona B, estático seleciona A.
class A { f() : Int { 10 }; clone() : SELF_TYPE { new SELF_TYPE }; };
class B inherits A { f() : Int { 20 }; };
class Main inherits IO {
  main() : Object {
    let a : A <- new B in {
      out_int(a.f()).out_string("\n");
      out_int(a@A.f()).out_string("\n");
      case a.clone() of
        b : B => out_string("B\n");
        o : Object => out_string("Object\n");
      esac;
    }
  };
};
