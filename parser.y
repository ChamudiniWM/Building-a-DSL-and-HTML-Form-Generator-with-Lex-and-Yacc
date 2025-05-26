%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylineno;
extern char *yytext;


FILE *html;
char **current_options = NULL;
int current_option_count = 0;

// Structure to hold the attributes for each field
typedef struct {
    char *required;
    int min;
    int max;
    char *min_str;
    char *max_str;
    char *pattern;
    char *default_value;
    char *accept;
    int rows;
    int cols;
} FieldAttributes;


FieldAttributes current_attributes;

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s at line %d, near token '%s'\n", s, yylineno, yytext);
}


int yylex(void);

%}

%union {
    char *str;        // For strings like ID, type names
}

%token <str> ID STRING TYPE BOOLEAN OPERATOR
%token FORM SECTION FIELD META VALIDATE IF ERROR
%token LBRACK RBRACK LBRACE RBRACE COLON SEMICOLON EQUALS COMMA
%token <str> NUMBER  
%type <str> value

%%

form : FORM ID LBRACE meta_section sections validation_block_opt RBRACE {
    fprintf(html, "</form>\n");
}
;

meta_section : META meta_entries
;

meta_entries : meta_entry meta_entries
             | meta_entry
;

meta_entry : ID EQUALS STRING SEMICOLON
;

sections : section sections
         | section
;

section : SECTION ID LBRACE fields RBRACE
;

fields : field fields
       | field
;

field : FIELD ID COLON TYPE attr_list_opt SEMICOLON {
    fprintf(html, "<label>%s: ", $2);

    if (strcmp($4, "text") == 0) {
        fprintf(html, "<input type=\"text\" name=\"%s\"", $2);
        if (current_attributes.default_value)
            fprintf(html, " value=\"%s\"", current_attributes.default_value);
        if (current_attributes.pattern)
            fprintf(html, " pattern=\"%s\"", current_attributes.pattern);
        //commented to show the use of event listener...uncomment if event listener is not necessary...
        //if (current_attributes.required)
           // fprintf(html, " required");

    } else if (strcmp($4, "email") == 0) {
        fprintf(html, "<input type=\"email\" name=\"%s\"", $2);
        if (current_attributes.pattern)
            fprintf(html, " pattern=\"%s\"", current_attributes.pattern);
        if (current_attributes.required)
            fprintf(html, " required");

    } else if (strcmp($4, "password") == 0) {
       fprintf(html, "<input type=\"password\" name=\"%s\"", $2);
       if (current_attributes.required)
           fprintf(html, " required");
       if (current_attributes.pattern)
           fprintf(html, " pattern=\"%s\"", current_attributes.pattern);

    } else if (strcmp($4, "date") == 0) {
       fprintf(html, "<input type=\"date\" name=\"%s\"", $2);
       if (current_attributes.min_str)
          fprintf(html, " min=%s", current_attributes.min_str);
       if (current_attributes.max_str)
          fprintf(html, " max=%s", current_attributes.max_str);
       if (current_attributes.required)
           fprintf(html, " required");

    } else if (strcmp($4, "number") == 0) {
        fprintf(html, "<input type=\"number\" name=\"%s\"", $2);
        if (current_attributes.required)
            fprintf(html, " required");

    } else if (strcmp($4, "checkbox") == 0) {
        fprintf(html, "<input type=\"checkbox\" name=\"%s\" value=\"on\"", $2);
        if (current_attributes.default_value && strcmp(current_attributes.default_value, "true") == 0)
            fprintf(html, " checked");
        if (current_attributes.required)
            fprintf(html, " required");
        fprintf(html, ">");

    } else if (strcmp($4, "radio") == 0) {
        fprintf(html, "<br>");
        for (int i = 0; i < current_option_count; i++) {
            fprintf(html, "<input type=\"radio\" name=\"%s\" value=\"%s\"", $2, current_options[i]);
            if (current_attributes.required && i == 0)
               fprintf(html, " required");  // only on first
            // Remove quotes from string
            char *label = current_options[i];
            size_t len = strlen(label);
            if (len >= 2 && label[0] == '"' && label[len - 1] == '"') {
               label[len - 1] = '\0';      
               label++;                     
            }
            fprintf(html, "> %s<br>", label);

        }

    } else if (strcmp($4, "dropdown") == 0) {
        fprintf(html, "<select name=\"%s\">", $2);
        for (int i = 0; i < current_option_count; i++) {
            if (current_attributes.default_value && strcmp(current_options[i], current_attributes.default_value) == 0)
                fprintf(html, "<option value=\"%s\" selected>%s</option>", current_options[i], current_options[i]);
            else
                fprintf(html, "<option value=\"%s\">%s</option>", current_options[i], current_options[i]);
        }
        fprintf(html, "</select>");


    } else if (strcmp($4, "textarea") == 0) {
        fprintf(html, "<textarea name=\"%s\"", $2);
        if (current_attributes.rows)
            fprintf(html, " rows=\"%d\"", current_attributes.rows);
        if (current_attributes.cols)
            fprintf(html, " cols=\"%d\"", current_attributes.cols);
        fprintf(html, ">");
        if (current_attributes.default_value)
            fprintf(html, "%s", current_attributes.default_value);
        fprintf(html, "</textarea>");

    } else if (strcmp($4, "file") == 0) {
        fprintf(html, "<input type=\"file\" name=\"%s\" accept=\"image/*\"", $2);
        if (current_attributes.accept)
            fprintf(html, " accept=\"%s\"", current_attributes.accept);
        if (current_attributes.required)
            fprintf(html, " required");

    } else {
        fprintf(html, "<input type=\"%s\" name=\"%s\"", $4, $2);
    }



    if (current_attributes.required) {
        fprintf(html, " required");
    }

    //If you need to use event listener without set the min value here, comment the below 3 rows...
    if (current_attributes.min) { 
        fprintf(html, " min=\"%d\"", current_attributes.min);
    }


    if (current_attributes.max) {
        fprintf(html, " max=\"%d\"", current_attributes.max);
    } 

    fprintf(html, "</label><br>\n");

    if (current_options != NULL) {
        for (int i = 0; i < current_option_count; i++) {
            free(current_options[i]);
        }
        free(current_options);
        current_options = NULL;
        current_option_count = 0;
    }

    memset(&current_attributes, 0, sizeof(FieldAttributes));
}
;

attr_list_opt : attr_list
              |
;

attr_list : attr_list attr
          | attr
;

attr
  : ID EQUALS value {
      if (strcmp($1, "required") == 0 && strcmp($3, "true") == 0) {
          current_attributes.required = strdup("required");
      } else if (strcmp($1, "min") == 0) {
          if (strchr($3, '"')) {
             current_attributes.min_str = strdup($3);
          } else {
             current_attributes.min = atoi($3);
          }
      } else if (strcmp($1, "max") == 0) {
          if (strchr($3, '"')) {
             current_attributes.max_str = strdup($3);
          } else {
             current_attributes.max = atoi($3);
          }
      }else if (strcmp($1, "pattern") == 0) {
          // Remove surrounding quotes from the pattern string
          size_t len = strlen($3);
          if (len >= 2 && $3[0] == '"' && $3[len - 1] == '"') {
             $3[len - 1] = '\0';               
            current_attributes.pattern = strdup($3 + 1); 
          }else{
            current_attributes.pattern = strdup($3); 
          }
      } else if (strcmp($1, "default") == 0) {
          current_attributes.default_value = strdup($3);
      } else if (strcmp($1, "accept") == 0) {
          current_attributes.accept = strdup($3);
      } else if (strcmp($1, "rows") == 0) {
          current_attributes.rows = atoi($3);
      } else if (strcmp($1, "cols") == 0) {
          current_attributes.cols = atoi($3);
      }
  }

  | ID EQUALS LBRACK options_init string_list RBRACK {
      // options already captured
  }
;


options_init :
    {
        current_options = malloc(sizeof(char*) * 100);
        current_option_count = 0;
    }
;

string_list
  : STRING {
      current_options[current_option_count++] = $1;
  }
  | string_list COMMA STRING {
      current_options[current_option_count++] = $3;
  }
;

value : STRING   { $$ = $1; }
      | NUMBER   { $$ = $1; }     // treat NUMBER as string for simplicity
      | BOOLEAN  { $$ = $1; }
;

validation_block_opt : validation_block
                     |
;

validation_block : VALIDATE LBRACE validations RBRACE
;

validations : validation validations
            | validation
;

validation : IF ID OPERATOR value LBRACE ERROR STRING SEMICOLON RBRACE {
    const char *operator = $3;
          char *val = $4;

    // Special case: fix '== ""' to use JS empty string comparison
    if (val[0] == '"' && val[strlen(val)-1] == '"') {
        val[strlen(val)-1] = '\0'; 
        val++;                     
    }

    if (strcmp(operator, "==") == 0 && strcmp(val, "") == 0) {
        operator = "===";
    }

    fprintf(html,
        "<script>\n"
        "document.MyForm.addEventListener('submit', function(e) {\n"
        "  if (!document.MyForm.checkValidity()) return;\n"
        "  if (document.MyForm['%s'].value %s '%s') {\n"
        "    e.preventDefault();\n"
        "    alert('%s');\n"
        "  }\n"
        "});\n"
        "</script>\n",
        $2, operator, val, $7
    );
}

;

%%

int main(int argc, char **argv) {
    html = fopen("output.html", "w");
    if (!html) {
        perror("Failed to open output.html");
        exit(1);
    }
    fprintf(html, "<!DOCTYPE html>\n");
fprintf(html, "<html>\n<head>\n<meta charset=\"UTF-8\">\n<title>Registration Form</title>\n");
fprintf(html, "<style>\n");

fprintf(html,
    "  body {\n"
    "    font-family: Arial, sans-serif;\n"
    "    background-color: #f4f4f4;\n"
    "    padding: 40px;\n"
    "  }\n"
    "  form {\n"
    "    background-color: white;\n"
    "    max-width: 600px;\n"
    "    margin: auto;\n"
    "    padding: 30px;\n"
    "    border-radius: 10px;\n"
    "    box-shadow: 0 0 15px rgba(0,0,0,0.2);\n"
    "  }\n"
    "  label {\n"
    "    display: block;\n"
    "    margin-top: 20px;\n"
    "    font-weight: bold;\n"
    "  }\n"
    "  input, select, textarea {\n"
    "    width: 100%%;\n"
    "    padding: 10px;\n"
    "    margin-top: 5px;\n"
    "    border: 1px solid #ccc;\n"
    "    border-radius: 5px;\n"
    "    box-sizing: border-box;\n"
    "  }\n"
    "  input[type=\"checkbox\"], input[type=\"radio\"] {\n"
    "    width: auto;\n"
    "    margin-right: 10px;\n"
    "  }\n"
    "  input[type=\"submit\"] {\n"
    "    background-color: #28a745;\n"
    "    color: white;\n"
    "    border: none;\n"
    "    padding: 12px 20px;\n"
    "    font-size: 16px;\n"
    "    border-radius: 5px;\n"
    "    cursor: pointer;\n"
    "    margin-top: 20px;\n"
    "  }\n"
    "  input[type=\"submit\"]:hover {\n"
    "    background-color: #218838;\n"
    "  }\n"
);

fprintf(html, "</style>\n</head>\n<body>\n");
fprintf(html, "<form name=\"MyForm\">\n");


    yyparse();
    fprintf(html, "<br><input type=\"submit\" value=\"Submit\">\n</form>\n");
    fclose(html);
    return 0;
}

