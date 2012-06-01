/*
 * Copyright (c) 2012 Agilo Software GmbH
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/**
 * objeq (Object Querying)
 * This module defines both a Lexer and Grammar that use the
 * Jison Parser Generator (http://zaach.github.com/jison/)
 *
 * @author Thom Bradford (github/bradford653)
 * @author Stefano Rago (github/sterago)
 */

%lex

%options case-insensitive

digit [0-9]
esc   "\\"
int   "-"?(?:[0-9]|[1-9][0-9]+)
exp   (?:[eE][-+]?[0-9]+)
frac  (?:\.[0-9]+)
ws    [\s]

%%

{int}{frac}?{exp}?\b return 'NUMBER';

'"'("\\x"[a-fA-F0-9]{2}|"\\u"[a-fA-F0-9]{4}|"\\"[^xu]|[^"{esc}\n])*'"' {
  yytext = yytext.substr(1,yyleng-2); return 'STRING';
}
"'"("\\"['bfvnrt/{esc}]|"\\u"[a-fA-F0-9]{4}|[^'{esc}])*"'" {
  yytext = yytext.substr(1,yyleng-2); return 'STRING';
}

"%"[1-9][0-9]* {
  yytext = yytext.substr(1); return 'ARGREF';
};

{ws}+                         /* skip whitespace */
"undefined"                   return 'UNDEFINED';
"null"                        return 'NULL';
"true"                        return 'TRUE';
"false"                       return 'FALSE';
"select"|"->"                 return 'SELECT';
("order"{ws}+)?"by"             return 'ORDER_BY';
"asc"                         return 'ASC';
"desc"                        return 'DESC';
"and"|"&&"                    return 'AND';
"or"|"||"                     return 'OR';
"not"|"!"                     return 'NOT';
"in"                          return "IN";
"=="                          return 'EQ';
"!="                          return 'NEQ';
"<="                          return 'LTE';
">="                          return 'GTE';
"<"                           return 'LT';
">"                           return 'GT';
"("                           return '(';
")"                           return ')';
"["                           return '[';
"]"                           return ']';
"."                           return '.';
","                           return ',';
"+"                           return '+';
"-"                           return '-';
"*"                           return '*';
"/"                           return '/';
"%"                           return '%';
[A-Za-z_$][A-Za-z_$0-9-]*     return 'IDENT';
<<EOF>>                       return 'EOF';
.                             return 'INVALID';

/lex

/* Operator Associativity and Precedence */

%left '+' '-'
%left '*' '/'
%left '%'
%left AND OR
%left EQ NEQ IN
%left GT GTE LT LTE
%left NOT NEG
%left '.'

%start program

%% /* Parser Grammar */

/*
 * There are optimizations we can perform here, like combining literals,
 * but for now, we just want to get this thing to work
 */

program
  : query EOF        { return $1; }
  ;

query
  : expr             { $$ = { expr: $1 }; }
  | filter           { $$ = $1; $1.expr = true; }
  | expr filter      { $$ = $2; $2.expr = $1; }
  ;

filter
  : order_by         { $$ = { order: $1, sortFirst: true }; }
  | order_by select  { $$ = { order: $1, select: $2, sortFirst: true }; }
  | select           { $$ = { select: $1 }; }
  | select order_by  { $$ = { select: $1, order: $2 }; }
  ;

expr
  : expr '+' expr    { $$ = ['add', $1, $3]; }
  | expr '-' expr    { $$ = ['sub', $1, $3]; }
  | expr '*' expr    { $$ = ['mul', $1, $3]; }
  | expr '/' expr    { $$ = ['div', $1, $3]; }
  | expr '%' expr    { $$ = ['mod', $1, $3]; }
  | expr 'AND' expr  { $$ = ['and', $1, $3]; }
  | expr 'OR' expr   { $$ = ['or', $1, $3]; }
  | expr EQ expr     { $$ = ['eq', $1, $3]; }
  | expr NEQ expr    { $$ = ['neq', $1, $3]; }
  | expr GT expr     { $$ = ['gt', $1, $3]; }
  | expr GTE expr    { $$ = ['gte', $1, $3]; }
  | expr LT expr     { $$ = ['lt', $1, $3]; }
  | expr LTE expr    { $$ = ['lte', $1, $3]; }
  | expr IN expr     { $$ = ['in', $1, $3]; }
  | NOT expr         { $$ = ['not', $2]; }
  | '-' expr         %prec NEG { $$ = ['neg', $2]; }
  | '(' expr ')'     { $$ = $2; }
  | array            { $$ = $1; }
  | NUMBER           { $$ = Number(yytext); }
  | STRING           { $$ = yytext; }
  | TRUE             { $$ = true; }
  | FALSE            { $$ = false; }
  | NULL             { $$ = null; }
  | UNDEFINED        { $$ = undefined; }
  | path             { $$ = $1; }
  ;

array
  : '[' array_list ']'         { $$ = ['arr', $2]; }
  | '[' ']'                    { $$ = ['arr', []]; }
  ;

array_list
  : expr                       { $$ = [$1]; }
  | array_list ',' expr        { $$ = $1; $1.push($3); }
  ;

select
  : SELECT path                { $$ = $2; }
  ;

order_by
  : ORDER_BY order_list        { $$ = $2; }
  ;

order_list
  : order_spec                 { $$ = [$1]; }
  | order_list ',' order_spec  { $$ = $1; $1.push($3); }
  ;

order_spec
  : path                       { $$ = { path: $1, ascending: true }; }
  | path ASC                   { $$ = { path: $1, ascending: true }; }
  | path DESC                  { $$ = { path: $1 }; }
  ;

path
  : ARGREF                     { $$ = ['path', Number($1)-1]; }
  | IDENT                      { $$ = ['path', $1]; }
  | path '.' IDENT             { $$ = $1; $1.push($3); }
  ;
