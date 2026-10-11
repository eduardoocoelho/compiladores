(* Erros intencionais e recuperação. Cada linha marcada ERRO deve gerar
   um diagnóstico. Classes e features corretas entre erros verificam retomada.
   Os erros que impedem fechar o arquivo são isolados no script de regressão. *)
class A {};
Class b inherits A {                       -- ERRO: nome de classe minúsculo
};
Class C inherits a {                       -- ERRO: pai não é TYPEID
};
Class D inherts A {                        -- ERRO: palavra reservada incorreta
};
class Features {
  x : Int <- ;                            -- ERRO: falta inicializador
  ok : Int <- 1;
  broken(p Int) : Int { 0 };               -- ERRO: falta ':' no formal
  fine(p : Int) : Int { p };
  y : Int <- #;                           -- ERRO: token léxico inválido
};
class Blocks {
  run() : Object { {
    1 + ;                                 -- ERRO: operando ausente, retoma em ';'
    7;
    { 2 * };                              -- ERRO: retoma no fechamento '}'
    8;
    #;                                    -- ERRO: comprova continuação no bloco
  } };
  valid() : Int { 9 };
};
class Lets {
  run() : Object { {
    let a Int,                            -- ERRO: vínculo sem ':'
        b : Int <- 1,
        c : Int <- ,                      -- ERRO: inicializador ausente
        d : Int <- 2 in d;
    let e : Int <- in 3;                  -- ERRO: recupera o último vínculo em IN
    #;                                    -- ERRO: comprova retomada após let
  } };
};
class Main {
  main() : Object { 0 };
  last : Int <- #;                        -- ERRO: alcança a última classe
};
