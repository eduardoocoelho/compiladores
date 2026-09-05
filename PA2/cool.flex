/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Variaveis auxiliares para comentarios e strings
 */
static int comment_depth = 0;
static bool string_too_long = false;

static bool append_string_char(char character) {
    if (string_buf_ptr < string_buf + MAX_STR_CONST - 1) {
        *string_buf_ptr++ = character;
        return true;
    }

    if (!string_too_long) {
        string_too_long = true;
        return true;
    }

    return false;
}

#define APPEND_STRING_CHAR(character)                                      \
    do {                                                                   \
        if (!append_string_char(character)) {                              \
            cool_yylval.error_msg = (char *)"String constant too long";   \
            BEGIN(STRING_RECOVERY);                                        \
            return ERROR;                                                  \
        }                                                                  \
    } while (0)

%}

/*
 * Start conditions for comments and string constants
 */
%x COMMENT
%x STRING
%x STRING_RECOVERY

/*
 * Define names for regular expressions here.
 */

/* Operadores de múltiplos caracteres */
DARROW          =>
ASSIGN          <-
LE              <=

/* Palavras-chave (case-insensitive) */
CLASS           [cC][lL][aA][sS][sS]
ELSE            [eE][lL][sS][eE]
FI              [fF][iI]
IF              [iI][fF]
IN              [iI][nN]
INHERITS        [iI][nN][hH][eE][rR][iI][tT][sS]
ISVOID          [iI][sS][vV][oO][iI][dD]
LET             [lL][eE][tT]
LOOP            [lL][oO][oO][pP]
POOL            [pP][oO][oO][lL]
THEN            [tT][hH][eE][nN]
WHILE           [wW][hH][iI][lL][eE]
CASE            [cC][aA][sS][eE]
ESAC            [eE][sS][aA][cC]
NEW             [nN][eE][wW]
OF              [oO][fF]
NOT             [nN][oO][tT]

/* Booleanos: o primeiro caractere DEVE ser minúsculo */
TRUE            t[rR][uU][eE]
FALSE           f[aA][lL][sS][eE]

/* Identificadores e Literais */
INT_CONST       [0-9]+
TYPEID          [A-Z][a-zA-Z0-9_]*
OBJECTID        [a-z][a-zA-Z0-9_]*

%%

 /*
  *  Comentários de linha única (-- ...)
  */
"--"[^\n]*          { /* Ignora até o final da linha sem consumir o \n */ }

 /*
  *  Comentários em bloco aninhados (* ... *)
  */
"(*" {
    comment_depth = 1;
    BEGIN(COMMENT);
}

<COMMENT>"(*" {
    comment_depth++;
}

<COMMENT>"*)" {
    comment_depth--;
    if (comment_depth == 0) {
        BEGIN(INITIAL);
    }
}

<COMMENT>\n {
    curr_lineno++;
}

<COMMENT><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = (char *)"EOF in comment";
    return ERROR;
}

<COMMENT>[^(*\n]+   { /* Consome qualquer texto comum dentro do comentário */ }
<COMMENT>"*"        { /* Consome asteriscos que não fecham comentário */ }
<COMMENT>"("        { /* Consome parênteses que não abrem comentário */ }

 /*
  *  Erro para fechamento de comentário sem abertura
  */
"*)" {
    cool_yylval.error_msg = (char *)"Unmatched *)";
    return ERROR;
}

 /*
  *  Constantes de String ("...")
  */
\" {
    string_buf_ptr = string_buf;
    string_too_long = false;
    BEGIN(STRING);
}

<STRING>\" {
    BEGIN(INITIAL);

    if (string_too_long) {
        cool_yylval.error_msg = (char *)"String constant too long";
        return ERROR;
    }

    *string_buf_ptr = '\0';
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return STR_CONST;
}

<STRING>\n {
    curr_lineno++;
    BEGIN(INITIAL);
    cool_yylval.error_msg = (char *)"Unterminated string constant";
    return ERROR;
}

<STRING><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = (char *)"EOF in string constant";
    return ERROR;
}

<STRING>"\\"\0 {
    cool_yylval.error_msg = (char *)"String contains escaped null character.";
    BEGIN(STRING_RECOVERY);
    return ERROR;
}

<STRING>\0 {
    cool_yylval.error_msg = (char *)"String contains null character.";
    BEGIN(STRING_RECOVERY);
    return ERROR;
}

<STRING>"\\0" {
    APPEND_STRING_CHAR('0');
}

<STRING>"\\b" {
    APPEND_STRING_CHAR('\b');
}

<STRING>"\\t" {
    APPEND_STRING_CHAR('\t');
}

<STRING>"\\n" {
    APPEND_STRING_CHAR('\n');
}

<STRING>"\\f" {
    APPEND_STRING_CHAR('\f');
}

<STRING>\\\n {
    curr_lineno++;
    APPEND_STRING_CHAR('\n');
}

<STRING>\\. {
    APPEND_STRING_CHAR(yytext[1]);
}

<STRING>\\ {
    BEGIN(INITIAL);
    cool_yylval.error_msg = (char *)"backslash at end of file";
    return ERROR;
}

<STRING>[^\\\n\"\0]+ {
    char *yptr = yytext;
    while (*yptr) {
        APPEND_STRING_CHAR(*yptr++);
    }
}

 /*
  * Recuperação após um erro que já foi retornado.
  * Nenhum segundo token ERROR deve ser produzido para a mesma string.
  */
<STRING_RECOVERY>\"     { BEGIN(INITIAL); }
<STRING_RECOVERY>\n {
    curr_lineno++;
    BEGIN(INITIAL);
}
<STRING_RECOVERY>\\\n   { curr_lineno++; }
<STRING_RECOVERY><<EOF>> {
    BEGIN(INITIAL);
    yyterminate();
}
<STRING_RECOVERY>"\\"\0 { /* Ignora outro nulo escapado */ }
<STRING_RECOVERY>\0     { /* Ignora outro caractere nulo */ }
<STRING_RECOVERY>\\.    { /* Ignora qualquer caractere escapado */ }
<STRING_RECOVERY>\\     { /* Ignora barra final; erro da string já foi reportado */ }
<STRING_RECOVERY>[^\\\n\"\0]+ { /* Ignora o restante da string inválida */ }

 /*
  *  Operadores de múltiplos caracteres
  */
{DARROW}            { return DARROW; }
{ASSIGN}            { return ASSIGN; }
{LE}                { return LE; }

 /*
  *  Palavras-chave
  */
{CLASS}             { return CLASS; }
{ELSE}              { return ELSE; }
{FI}                { return FI; }
{IF}                { return IF; }
{IN}                { return IN; }
{INHERITS}          { return INHERITS; }
{ISVOID}            { return ISVOID; }
{LET}               { return LET; }
{LOOP}              { return LOOP; }
{POOL}              { return POOL; }
{THEN}              { return THEN; }
{WHILE}             { return WHILE; }
{CASE}              { return CASE; }
{ESAC}              { return ESAC; }
{NEW}               { return NEW; }
{OF}                { return OF; }
{NOT}               { return NOT; }

 /*
  *  Booleanos
  */
{TRUE} {
    cool_yylval.boolean = 1;
    return BOOL_CONST;
}

{FALSE} {
    cool_yylval.boolean = 0;
    return BOOL_CONST;
}

 /*
  *  Identificadores e inteiros
  */
{INT_CONST} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

{TYPEID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

{OBJECTID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

 /*
  *  Espaços em branco e quebras de linha
  */
[ \t\r\f\v]+        { /* Ignora espaços em branco */ }
\n                  { curr_lineno++; }

 /*
  *  Operadores de caractere único e pontuação
  */
"+"|"-"|"*"|"/"|"~"|"<"|"="|"."|"@"|";"|":"|"("|")"|"{"|"}"|"," {
    return (int)yytext[0];
}

 /*
  *  Qualquer outro caractere não reconhecido é erro léxico
  */
. {
    cool_yylval.error_msg = yytext;
    return ERROR;
}

%%

/*
 * Compatibilidade com o linker do libfl no Ubuntu moderno:
 * extern "C" é necessário para que o compilador g++ exporte
 * o símbolo 'yylex' sem "name mangling" de C++.
 */
#undef yylex
extern "C" int yylex() {
    return cool_yylex();
}
