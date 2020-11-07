
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <regex.h>
#include <dirent.h>
#include <assert.h>
#include <algorithm>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE PIPE AMPERSAND LESS GREATGREAT TWOGREAT 
%token AMPGREAT GREATAMP GREATGREATAMP
%token EXIT

%{
//#define yylex yylex
#include <cstdio>
#include "shell.hh"
#include <cstring>
#include <string.h>

void yyerror(const char * s);
int yylex();
void expandWildcardsIfNecessary(char *);
void expandWildcard(char *, char *);
int cmpfunc(const void *, const void *);

std::vector<std::string> arrayOfEntries;
#define MAXFILES 1024
int nEntries = 0;

int cmpfunc (const void * a, const void * b) {
   return strcmp(*(const char **) a, *(const char **) b);
}

void expandWildcard(char * prefix, char *suffix) {
  // If suffix is empty, simply insert prefix
  if (suffix[0] == 0) {
    std::string toAdd(prefix);
    arrayOfEntries.push_back(toAdd);
    nEntries++;
    return;
  }
  // Modify suffix location and copy respectively to component
  char *b = strchr(suffix, '/') ;
  char component[MAXFILES] = "";
  if (b != NULL) {
    strncpy(component, suffix, b - suffix);
    suffix = b + 1;
  }
  else {
    strcpy(component, suffix);
    suffix = suffix + strlen(suffix);
  }

  char newPrefix[MAXFILES];
  if ((strchr(component, '*') == NULL) && (strchr(component, '?') == NULL)) {
    if (strcmp(prefix, "/") == 0) {
      sprintf(newPrefix, "%s%s", prefix, component);
    }
    else {
      sprintf(newPrefix, "%s/%s", prefix, component);
    }
    expandWildcard(newPrefix, suffix);
    return;
  }


  char *reg = (char *) malloc(2 * strlen(component) + 10);
  char *a = (char *) component;
  char *r = (char *) reg;
  *r = '^';
  r++;
  
  while (*a) {
    // Translates * to .* (RegEx)
    if (*a == '*') {
      *r = '.';
      r++;
      *r = '*';
      r++;
    }
    // Translates ? to .
    else if (*a == '?') {
      *r = '.';
      r++;
    }
    // Translates . to \.
    else if (*a == '.') {
      *r = '\\';
      r++;
      *r='.';
      r++;
    }
    // Translate directly to anything
    else {
      *r = *a;
      r++;
    }
    a++;
  }
  *r = '$';
  r++;
  *r = 0;

  regex_t re;
  int expbuf = regcomp( &re, reg, REG_EXTENDED|REG_NOSUB);
  if (expbuf != 0) {
    perror("Complete");
    return;
  }

  char *directory;
  if (*prefix == '\0') {
    directory=".";
  }
  else {
    directory = prefix;
  }
  DIR *d = opendir(directory);
  if (d == NULL) {
    return;
  }
  
  struct dirent *ent;
  int maxEntries = 20;
 
  while ((ent = readdir(d)) != NULL) {
    // Check if name matches
    regmatch_t match;
    if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
      if (ent->d_name[0] == '.') {
        if (component[0] == '.') {
          if ((strcmp(prefix, "/") == 0) || (*prefix == '\0')) {
            sprintf(newPrefix, "%s%s", prefix, ent->d_name);
          }
          else {
            sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
          }
          expandWildcard(newPrefix, suffix);
        }
      }
      else {
        if ((strcmp(prefix, "/") == 0) || (*prefix == '\0')) {
            sprintf(newPrefix, "%s%s", prefix, ent->d_name);
          }
          else {
            sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
          }
          expandWildcard(newPrefix, suffix);
      }
    }
  }
  closedir(d); 
  regfree(&re);
  free(reg);

} // expandWildcard

void expandWildcardsIfNecessary(std::string *arg) {
  if ((strchr(arg->c_str(), '*') == NULL) && (strchr(arg->c_str(), '?') == NULL)) {
    Command::_currentSimpleCommand->insertArgument(arg);
    return;
  }
  char *reg = (char *) malloc(2 * arg->size() + 10);
  char *a = strdup(arg->c_str());
  //printf("%s = \n", strdup(arg->c_str()));
  char *r = reg;
  *r = '^';
  r++;

  // Line 74 - 99: Convert Wildcard syntax to RegEx syntax

  while (*a) {
    // Translates * to .* (RegEx)
    if (*a == '*') {
      *r = '.';
      r++;
      *r = '*';
      r++;
    }
    // Translates ? to .
    else if (*a == '?') {
      *r = '.';
      r++;
    }
    // Translates . to \.
    else if (*a == '.') {
      *r = '\\';
      r++;
      *r='.';
      r++;
    }
    // Translate directoryectly to anything
    else {
      *r = *a;
      r++;
    }
    a++;
  }
  *r = '$';
  r++;
  *r = 0;
  /* reg = RegEx string that corresponds to wildcard string passed in */

  // Compile regex expression
  regex_t re;
  int expbuf = regcomp( &re, reg, REG_EXTENDED|REG_NOSUB);
  if (expbuf != 0) {
    perror("Complete");
    return;
  }

  DIR *directory = opendir(".");
  if (directory == NULL) {
    perror("opendir");
    return;
  }
  
  regmatch_t match;


  struct dirent *ent;
  int maxEntries = 1024;
  int nEntries = 0;
  char **array = (char **) malloc(maxEntries * sizeof(char *));
  while ( (ent = readdir(directory)) != NULL) {
    // Check if name matches
    if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
      // Add argument
      if (nEntries == maxEntries) {
        maxEntries *= 2;
        array = (char **) realloc(array, maxEntries * sizeof(char *));
        assert(array != NULL);
      }
      // Only add to argument if the file is hidden and the original entry contained a dot.
      if (ent->d_name[0] == '.') {
        if (arg->c_str()[0] == '.') {
          array[nEntries] = strdup(ent->d_name);
          nEntries++;
        }
      }
      else {
        array[nEntries] = strdup(ent->d_name);
        nEntries++;
      }
    }
  }
  closedir(directory);
  qsort(array, nEntries, sizeof(char *), cmpfunc);
  for (int i = 0; i < nEntries; i++) {
    Command::_currentSimpleCommand->insertArgument(new std::string(strdup(array[i])));
    free(array[i]);
  }
  free(array);
}

%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

command_list:
  command_list PIPE command_and_args
  | command_and_args
  ;

simple_command:
  command_list iomodifier_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE 
  | error NEWLINE { yyerrok; }
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    char *prefix = "";
    if ((strcmp($1->c_str(), "${?}") == 0) ||
        (strchr(($1)->c_str(), '*') == NULL) && (strchr(($1)->c_str(), '?') == NULL)) {
      Command::_currentSimpleCommand->insertArgument($1);
    }
    else {
      arrayOfEntries.clear();
      expandWildcard(prefix, (char *) $1->c_str());
      if (arrayOfEntries.size() == 0) {
        Command::_currentSimpleCommand->insertArgument($1);
      }
      // maybe else if
      else if (!arrayOfEntries.empty()) {
        std::sort(arrayOfEntries.begin(), arrayOfEntries.end());
        for (int i = 0; i < arrayOfEntries.size(); i++) {
          std::string *entry = new std::string(arrayOfEntries[i]);
          Command::_currentSimpleCommand->insertArgument(entry);
        }
      }
    }
    
  }
  ;

command_word:
  EXIT {
    if (isatty(0)) {
      printf("\nGood bye!!\n\n");
    }
    for (int i = 0; i < 3; i++) {
      close(i);
    }
    exit(1);
  }
  |
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_list:
  iomodifier_list iomodifier_opt
  | /* NOTHING REQUIRED */ 
  ;
iomodifier_opt:
  GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile == NULL) {
      Shell::_currentCommand._outFile = $2;
    }
    else {
      Shell::_currentCommand.multi_output = true;
    }
    Shell::_currentCommand._outFlag = O_WRONLY | O_CREAT | O_TRUNC;
  }

  | GREATGREAT WORD {
      //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._outFlag = O_WRONLY | O_CREAT | O_APPEND;
      // IMPLEMENT APPEND
  }

  | TWOGREAT WORD {
      //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._errFile = $2;
      Shell::_currentCommand._errFlag = O_WRONLY | O_CREAT | O_TRUNC;
      // IMPLEMENT TWOGREAT
  }

  | GREATAMP WORD {
      //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = $2;
      Shell::_currentCommand._outFlag = O_WRONLY | O_CREAT | O_TRUNC;
      Shell::_currentCommand._errFlag = O_WRONLY | O_CREAT | O_TRUNC;
      // IMPLEMENT GREATAMP
  }

  | GREATGREATAMP WORD {
      //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = $2;
      Shell::_currentCommand._outFlag = O_WRONLY | O_CREAT | O_APPEND;
      Shell::_currentCommand._errFlag = O_WRONLY | O_CREAT | O_APPEND;
      // IMPLEMENT GREATGREATAMP
  }

  | LESS WORD {
     // printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._inFile = $2;
      // IMPLEMENT LESS
  }
 
  ;

background_opt:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  | /* NOTHING REQUIRED here */
  ;
%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
