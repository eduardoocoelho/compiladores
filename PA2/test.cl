-- =======================================================================
-- Bateria Completa de Testes Lexicos para a Linguagem Cool (TP02)
-- Autores: Trabalho Pratico - Compiladores PUC Minas
-- =======================================================================

-------------------------------------------------------------------------
-- 1. TESTE DE COMENTARIOS
-------------------------------------------------------------------------
-- Comentario simples de linha unica
---- Comentario com multiplos tracos
-- Comentario contendo palavras-chave e operadores: class if else <= <- =>

(* Comentario em bloco simples *)
(**** Comentario com multiplos asteriscos no inicio e fim ****)

(* 
   Comentarios aninhados em multiplos niveis:
   Nivel 1
   (* Nivel 2: inicio
      (* Nivel 3: mais profundo *)
      Nivel 2: retorno
   *)
   Nivel 1: finalizacao
*)

(* Comentario contendo codigo valido dentro:
   class Ignorada inherits Object {
       x : Int <- 10;
   };
*)

-------------------------------------------------------------------------
-- 2. TESTE DE PALAVRAS-CHAVE (Case-Insensitive)
-------------------------------------------------------------------------
class CLASS cLaSs ClAsS
else ELSE eLsE
fi FI fI
if IF iF
in IN iN
inherits INHERITS InHeRiTs
isvoid ISVOID IsVoId
let LET LeT
loop LOOP LoOp
pool POOL PoOl
then THEN ThEn
while WHILE WhIlE
case CASE CaSe
esac ESAC EsAc
new NEW NeW
of OF oF
not NOT nOt

-------------------------------------------------------------------------
-- 3. TESTE DE BOOLEANOS E CASOS DE BORDA (true / false vs TypeID)
-------------------------------------------------------------------------
-- Booleanos validos (obrigatoriamente iniciam com 't' ou 'f' minusculo)
true
tRuE
tRUE
false
fAlSe
fALSE

-- Identificadores de Tipo que se parecem com booleanos (iniciam com maiuscula)
True
TRUE
False
FALSE

-------------------------------------------------------------------------
-- 4. TESTE DE IDENTIFICADORES E LITERAIS
-------------------------------------------------------------------------
-- Type Identifiers (iniciam com letra maiuscula)
Main
Int
String
Bool
Object
IO
SELF_TYPE
Custom_Class_123
A_B_C_D

-- Object Identifiers (iniciam com letra minuscula)
self
x
y
z_value
my_variable_1
loop_counter
in_data
case_flag

-- Inteiros (INT_CONST)
0
1
42
1234567890
007

-------------------------------------------------------------------------
-- 5. TESTE DE OPERADORES E PONTUACAO
-------------------------------------------------------------------------
-- Operadores compostos
<=
<-
=>

-- Operadores de caractere unico e pontuacao
+
-
*
/
~
<
=
.
@
:
;
(
)
{
}
,

-------------------------------------------------------------------------
-- 6. TESTE DE CONSTANTES DE STRING (STR_CONST)
-------------------------------------------------------------------------
-- String vazia e simples
""
"Hello, World!"
"COOL Compiler Project - PUC Minas"

-- Sequencias de escape especiais
"Escape Sequences: \b backspace \t tab \n newline \f formfeed"

-- Caractere nulo escapado (\0 deve virar o caractere '0')
"Caractere zero escapado: \0 fim"

-- Outros caracteres escapados (\c deve virar c)
"Escapes gerais: \" aspas e \\ barra invertida e \a \d \? \!"

-- String com quebra de linha continuada por barra invertida
"Primeira linha \
segunda linha \
terceira linha"

-------------------------------------------------------------------------
-- 7. TESTE DE ERROS LEXICOS E RECUPERACAO DO ANALISADOR
-------------------------------------------------------------------------
-- Caracteres invalidos avulsos (devem emitir token ERROR com o caractere)
!
#
$
%
^
&
|
?
\
]
[
'
>

-- Fechamento de comentario sem abertura correspondente
*)

-- String nao terminada (quebra de linha sem barra de escape antes)
"String quebrada sem escape
"String normal na linha seguinte para verificar recuperacao"

-- String que ultrapassa o tamanho maximo permitido (1024 caracteres)
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

-------------------------------------------------------------------------
-- 8. TESTE DE CODIGO REAL COMPLETO (Sintaxe Cool Funcional)
-------------------------------------------------------------------------
class Main inherits IO {
    fat(n : Int) : Int {
        if n <= 1 then
            1
        else
            n * fat(n - 1)
        fi
    };
    
    main() : Object {
        let resultado : Int <- fat(5) in
            out_string("Fatorial de 5 calculado com sucesso!\n")
    };
};

-------------------------------------------------------------------------
-- 9. TESTE FINAL: EOF DENTRO DE COMENTARIO
-------------------------------------------------------------------------
(* Fim do arquivo com comentario aberto para testar EOF in comment
