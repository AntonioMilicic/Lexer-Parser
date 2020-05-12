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

 /* Add Your own definitions here */

int comment_counter = 0;

%}


 /* Define names for regular expressions here. */

blank_space		[ \f\r\t\v]
number_type_integer	[0-9]+
data_type		[A-Z][a-zA-Z0-9_]*
data_object		[a-z][a-zA-Z0-9_]*

true_statement		t(?i:rue)
false_statement		f(?i:alse)

left_arrow 		<=
right_arrow 		=>
assign_value 		<-

single_line_comments	"--".*

single_sign		"@"|"~"|"+"|"-"|"*"|"/"|"<"|"="|"{"|"}"|"("|")"|":"|";"|"."|","
error_sign		"`"|"!"|"#"|"^"|"$"|"%"|"&"|[\\]|"["|"]"|"|"|"_"|">"|"?"


 /* State definitions */

%x comment_state_buffer
%x string_state_buffer
%x error_state_buffer

%%

 /* Multi char operators */

{right_arrow}		return DARROW;
{left_arrow}		return LE;
{assign_value}		return ASSIGN;


 /* Single line comments */

"single_line_comments" 	;
"single_line_comments"\n	++curr_lineno;


 /* Skip blank space */

\n			++curr_lineno;
{blank_space}+		;


 /* Case insensitive */

(?i:not)	return NOT;
(?i:class)	return CLASS;
(?i:else)	return ELSE;
(?i:if)		return IF;
(?i:fi)		return FI;
(?i:in)		return IN;
(?i:new)	return NEW;
(?i:of)		return OF;
(?i:let)	return LET;
(?i:then)	return THEN;
(?i:while)	return WHILE;
(?i:loop)	return LOOP;
(?i:pool)	return POOL;
(?i:case)	return CASE;
(?i:esac)	return ESAC;
(?i:inherits)	return INHERITS;
(?i:isvoid)	return ISVOID;


 /* Case sensitive */

{true_statement} {
	cool_yylval.boolean = true;
	return BOOL_CONST;
}

{false_statement} {
	cool_yylval.boolean = false;
	return BOOL_CONST;
}


 /* Identifiers */

{number_type_integer} {
	cool_yylval.symbol = inttable.add_string(yytext);
	return INT_CONST;
}

{data_type} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return TYPEID;
}

{data_object} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return OBJECTID;
}


 /* Single sign syntax */

{single_sign}		return int(yytext[0]);


 /* Error, with error sign in use */

{error_sign} {
	cool_yylval.error_msg = yytext;
	return ERROR;
}


 /* Comment handler */


{single_line_comments}

"*)" {
	cool_yylval.error_msg = "Unmatched *)";
	return ERROR;
}

"(*" {
	++comment_counter;
	BEGIN(comment_state_buffer);
}



<comment_state_buffer>"(*"	++comment_counter;

<comment_state_buffer>"*)" {
	--comment_counter;
	if(comment_counter == 0)
		BEGIN(INITIAL);
}

<comment_state_buffer>.	

<comment_state_buffer>\n	++curr_lineno;

<comment_state_buffer><<EOF>> {
	BEGIN(INITIAL);
	if(comment_counter > 0){
		cool_yylval.error_msg = "EOF in comment";
		comment_counter = 0;
		return ERROR;
	}
}


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  *  String handler
  */

"\"" {
	BEGIN(string_state_buffer);
	string_buf_ptr = string_buf;
}

<string_state_buffer>"\"" {
	if(string_buf_ptr - string_buf >= MAX_STR_CONST) {
		*string_buf = '\0';
		cool_yylval.error_msg = "String you entered is too long";
		BEGIN(error_state_buffer);
		return ERROR;
	}
	*string_buf_ptr = '\0';
	cool_yylval.symbol = stringtable.add_string(string_buf);
	BEGIN(INITIAL);
	return STR_CONST;
}

<string_state_buffer>\0	{
	*string_buf = '\0';
	cool_yylval.error_msg = "NULL cant be part of string";
	BEGIN(error_state_buffer);
	return ERROR;
}

<string_state_buffer>\n	{
	*string_buf = '\0';
	BEGIN(INITIAL);
	cool_yylval.error_msg = "Unterminated string constant";
	return ERROR;
}

<string_state_buffer><<EOF>> {
	cool_yylval.error_msg = "EOF in string";
	BEGIN(INITIAL);
	return ERROR;
}

<string_state_buffer>.		{ *string_buf_ptr++ = *yytext; }

<string_state_buffer>"\\b"	{ *string_buf_ptr++ = '\b'; }

<string_state_buffer>"\\f"	{ *string_buf_ptr++ = '\f'; }

<string_state_buffer>"\\n"	{ *string_buf_ptr++ = '\n'; }

<string_state_buffer>"\\t"	{ *string_buf_ptr++ = '\t'; }

<string_state_buffer>"\\"[^\0]	{ *string_buf_ptr++ = yytext[1]; }


 /*
  * Error, with error state
  */

<error_state_buffer>\" { BEGIN(INITIAL); }

<error_state_buffer>\0 { BEGIN(INITIAL); }

<error_state_buffer>.  {}

 /*
  * Error, no match
  */

. {
	cool_yylval.error_msg = yytext;
	return ERROR;
}


%%
