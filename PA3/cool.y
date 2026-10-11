/*
 *  cool.y
 *              Parser definition for the COOL language.
 *
 */
%{
#include "cool-io.h"
#include "cool-tree.h"
#include "stringtab.h"
#include "utilities.h"

/* O leitor de tokens oficial declara, mas não define, este contador. */
int curr_lineno = 1;

extern int node_lineno;
#define SET_NODELOC(location) (node_lineno = (location).first_line)

/* O scanner fornecido atualiza curr_lineno, mas não yylloc. O adaptador
   abaixo registra a linha sem alterar tokens-lex.cc nem sua interface. */
extern int cool_yylex();
static int located_yylex();
#undef yylex
#define yylex located_yylex

extern char *curr_filename;

void yyerror(char *s);        /*  defined below; called for each parse error */
extern int yylex();           /*  the entry point to the lexer  */

/************************************************************************/
/*                DONT CHANGE ANYTHING IN THIS SECTION                  */

Program ast_root;	      /* the result of the parse  */
Classes parse_results;        /* for use in semantic analysis */
int omerrs = 0;               /* number of errors in lexing and parsing */
%}

/* A union of all the types that can be the result of parsing actions. */
%union {
  Boolean boolean;
  Symbol symbol;
  Program program;
  Class_ class_;
  Classes classes;
  Feature feature;
  Features features;
  Formal formal;
  Formals formals;
  Case case_;
  Cases cases;
  Expression expression;
  Expressions expressions;
  char *error_msg;
}

/* 
   Declare the terminals; a few have types for associated lexemes.
   The token ERROR is never used in the parser; thus, it is a parse
   error when the lexer returns it.

   The integer following token declaration is the numeric constant used
   to represent that token internally.  Typically, Bison generates these
   on its own, but we give explicit numbers to prevent version parity
   problems (bison 1.25 and earlier start at 258, later versions -- at
   257)
*/
%token CLASS 258 ELSE 259 FI 260 IF 261 IN 262 
%token INHERITS 263 LET 264 LOOP 265 POOL 266 THEN 267 WHILE 268
%token CASE 269 ESAC 270 OF 271 DARROW 272 NEW 273 ISVOID 274
%token <symbol>  STR_CONST 275 INT_CONST 276 
%token <boolean> BOOL_CONST 277
%token <symbol>  TYPEID 278 OBJECTID 279 
%token ASSIGN 280 NOT 281 LE 282 ERROR 283

/*  DON'T CHANGE ANYTHING ABOVE THIS LINE, OR YOUR PARSER WONT WORK       */
/**************************************************************************/
 
%locations
%type <program> program
%type <classes> class_list
%type <class_> class
%type <features> feature_list
%type <feature> feature
%type <formals> optional_formals formal_list
%type <formal> formal
%type <expressions> optional_actuals actual_list block_list
%type <cases> case_list
%type <case_> case_branch
%type <expression> expr optional_init let_tail

/* Seção 11.1: precedência crescente, restrita às expressões.
   LET_STMT não vem do lexer: faz o corpo do let estender-se à direita. */
%nonassoc LET_STMT
%right ASSIGN
%right NOT
%nonassoc '<' LE '='
%left '+' '-'
%left '*' '/'
%right ISVOID
%right '~'
%left '@'
%left '.'

%%
program
    : class_list
      { SET_NODELOC(@1); $$ = program($1); ast_root = $$; }
    ;

class_list
    : class
      { $$ = $1 ? single_Classes($1) : nil_Classes(); parse_results = $$; }
    | class_list class
      { $$ = $2 ? append_Classes($1, single_Classes($2)) : $1;
        parse_results = $$; }
    ;

class
    : CLASS TYPEID '{' feature_list '}' ';'
      { SET_NODELOC(@1);
        char object_name[] = "Object";
        $$ = class_($2, idtable.add_string(object_name), $4,
                    stringtable.add_string(curr_filename)); }
    | CLASS TYPEID INHERITS TYPEID '{' feature_list '}' ';'
      { SET_NODELOC(@1);
        $$ = class_($2, $4, $6, stringtable.add_string(curr_filename)); }
    /* A classe inválida não entra na AST. O NULL é apenas uma sentinela
       intermediária, filtrada por class_list antes de qualquer construtor. */
    | error '}' ';'
      { $$ = NULL; yyerrok; }
    ;

/* Listas recursivas à esquerda preservam ordem e economizam pilha LR. */
feature_list
    : /* empty */ { $$ = nil_Features(); }
    | feature_list feature ';'
      { $$ = append_Features($1, single_Features($2)); }
    | feature_list error ';'
      { $$ = $1; yyerrok; }
    ;

feature
    : OBJECTID ':' TYPEID optional_init
      { SET_NODELOC(@1); $$ = attr($1, $3, $4); }
    | OBJECTID '(' optional_formals ')' ':' TYPEID '{' expr '}'
      { SET_NODELOC(@1); $$ = method($1, $3, $6, $8); }
    ;

optional_init
    : /* empty */ { SET_NODELOC(@$); $$ = no_expr(); }
    | ASSIGN expr { $$ = $2; }
    ;

optional_formals
    : /* empty */ { $$ = nil_Formals(); }
    | formal_list { $$ = $1; }
    ;

formal_list
    : formal { $$ = single_Formals($1); }
    | formal_list ',' formal
      { $$ = append_Formals($1, single_Formals($3)); }
    ;

formal
    : OBJECTID ':' TYPEID
      { SET_NODELOC(@1); $$ = formal($1, $3); }
    ;

optional_actuals
    : /* empty */ { $$ = nil_Expressions(); }
    | actual_list { $$ = $1; }
    ;

actual_list
    : expr { $$ = single_Expressions($1); }
    | actual_list ',' expr
      { $$ = append_Expressions($1, single_Expressions($3)); }
    ;

/* Blocos e case exigem ao menos um elemento e ';' após cada um. */
block_list
    : expr ';' { $$ = single_Expressions($1); }
    | block_list expr ';'
      { $$ = append_Expressions($1, single_Expressions($2)); }
    | error ';'
      { $$ = nil_Expressions(); yyerrok; }
    | block_list error ';'
      { $$ = $1; yyerrok; }
    ;

case_list
    : case_branch { $$ = single_Cases($1); }
    | case_list case_branch
      { $$ = append_Cases($1, single_Cases($2)); }
    ;

case_branch
    : OBJECTID ':' TYPEID DARROW expr ';'
      { SET_NODELOC(@1); $$ = branch($1, $3, $5); }
    ;

/* Recursão à direita é intencional aqui: o primeiro vínculo deve ser
   o let externo; os seguintes entram em seu corpo, na ordem original. */
let_tail
    : OBJECTID ':' TYPEID optional_init IN expr %prec LET_STMT
      { SET_NODELOC(@1); $$ = let($1, $3, $4, $6); }
    | OBJECTID ':' TYPEID optional_init ',' let_tail
      { SET_NODELOC(@1); $$ = let($1, $3, $4, $6); }
    /* Descarta somente o vínculo defeituoso e preserva cauda/corpo. */
    | error ',' let_tail
      { $$ = $3; yyerrok; }
    | error IN expr %prec LET_STMT
      { $$ = $3; yyerrok; }
    ;

expr
    : OBJECTID ASSIGN expr
      { SET_NODELOC(@1); $$ = assign($1, $3); }
    | expr '.' OBJECTID '(' optional_actuals ')'
      { SET_NODELOC(@1); $$ = dispatch($1, $3, $5); }
    | expr '@' TYPEID '.' OBJECTID '(' optional_actuals ')'
      { SET_NODELOC(@1); $$ = static_dispatch($1, $3, $5, $7); }
    | OBJECTID '(' optional_actuals ')'
      { SET_NODELOC(@1);
        char self_name[] = "self";
        $$ = dispatch(object(idtable.add_string(self_name)), $1, $3); }
    | IF expr THEN expr ELSE expr FI
      { SET_NODELOC(@1); $$ = cond($2, $4, $6); }
    | WHILE expr LOOP expr POOL
      { SET_NODELOC(@1); $$ = loop($2, $4); }
    | '{' block_list '}'
      { SET_NODELOC(@1); $$ = block($2); }
    /* Fecha o bloco mesmo quando falta ';' após a expressão defeituosa. */
    | '{' error '}'
      { SET_NODELOC(@1); $$ = no_expr(); yyerrok; }
    | '{' block_list error '}'
      { SET_NODELOC(@1); $$ = block($2); yyerrok; }
    | LET let_tail %prec LET_STMT { $$ = $2; }
    | CASE expr OF case_list ESAC
      { SET_NODELOC(@1); $$ = typcase($2, $4); }
    | NEW TYPEID
      { SET_NODELOC(@1); $$ = new_($2); }
    | ISVOID expr
      { SET_NODELOC(@1); $$ = isvoid($2); }
    | expr '+' expr
      { SET_NODELOC(@1); $$ = plus($1, $3); }
    | expr '-' expr
      { SET_NODELOC(@1); $$ = sub($1, $3); }
    | expr '*' expr
      { SET_NODELOC(@1); $$ = mul($1, $3); }
    | expr '/' expr
      { SET_NODELOC(@1); $$ = divide($1, $3); }
    | '~' expr
      { SET_NODELOC(@1); $$ = neg($2); }
    | expr '<' expr
      { SET_NODELOC(@1); $$ = lt($1, $3); }
    | expr LE expr
      { SET_NODELOC(@1); $$ = leq($1, $3); }
    | expr '=' expr
      { SET_NODELOC(@1); $$ = eq($1, $3); }
    | NOT expr
      { SET_NODELOC(@1); $$ = comp($2); }
    | '(' expr ')' { $$ = $2; }
    | OBJECTID
      { SET_NODELOC(@1); $$ = object($1); }
    | INT_CONST
      { SET_NODELOC(@1); $$ = int_const($1); }
    | STR_CONST
      { SET_NODELOC(@1); $$ = string_const($1); }
    | BOOL_CONST
      { SET_NODELOC(@1); $$ = bool_const($1); }
    ;
%%

/* This function is called automatically when Bison detects a parse error. */
void yyerror(char *s)
{
  extern int curr_lineno;

  cerr << "\"" << curr_filename << "\", line " << curr_lineno << ": " \
    << s << " at or near ";
  print_cool_token(yychar);
  cerr << endl;
  omerrs++;

  if(omerrs>50) {fprintf(stdout, "More than 50 errors\n"); exit(1);}
}

static int located_yylex()
{
  int token = cool_yylex();
  cool_yylloc.first_line = cool_yylloc.last_line = curr_lineno;
  cool_yylloc.first_column = cool_yylloc.last_column = 0;
  return token;
}

