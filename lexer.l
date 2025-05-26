%{
#include "y.tab.h"
#include <string.h>
%}

%option yylineno
extern int yylineno;


ID      [a-zA-Z_][a-zA-Z0-9_]*
NUMBER  [0-9]+
STRING  \"[^\"]*\"
BOOLEAN (true|false)

%%

"form"           { return FORM; }
"section"        { return SECTION; }
"field"          { return FIELD; }
"meta"           { return META; }
"validate"       { return VALIDATE; }
"if"             { return IF; }
"error"          { return ERROR; }

"text"|"textarea"|"number"|"email"|"date"|"checkbox"|"dropdown"|"radio"|"password"|"file" {
                    yylval.str = strdup(yytext); return TYPE; }

"<="|"=="|">="|"!="|"<"|">" { yylval.str = strdup(yytext); return OPERATOR; }

{STRING}         { yylval.str = strdup(yytext); return STRING; }
{BOOLEAN}        { yylval.str = strdup(yytext); return BOOLEAN; }
{NUMBER}         { yylval.str = strdup(yytext); return NUMBER; }
{ID}             { yylval.str = strdup(yytext); return ID; }

"["              { return LBRACK; }
"]"              { return RBRACK; }
"{"              { return LBRACE; }
"}"              { return RBRACE; }
":"              { return COLON; }
";"              { return SEMICOLON; }
"="              { return EQUALS; }
","              { return COMMA; }

[ \t\r\n]        ;  // skip whitespace

.                { printf("Unknown character: %s\n", yytext); }

%%
