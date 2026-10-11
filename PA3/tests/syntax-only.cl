-- Sintaxe legal, semântica intencionalmente inválida: PA3 deve aceitar.
class Main inherits Missing {
  x : Unknown;
  main(self : SELF_TYPE) : Unknown { self <- 1 + false };
};
