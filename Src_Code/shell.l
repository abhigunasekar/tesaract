
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include <string>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include "y.tab.hh"
#include "shell.hh"
#include <iostream>
#include <fstream>
#include <pwd.h>

extern "C" char * read_line();
static  void yyunput (int c,char *buf_ptr  );

int mygetc(FILE *f) {
  static char *p;
  char ch;

  if (!isatty(0)) {
    return getc(f);
  }

  if (p == NULL || *p == 0) {
    char *s = read_line();
    p = s;
  }
  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)



void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

"2>" {
  return TWOGREAT;
}

\n {
  return NEWLINE;
}

"|" {
  return PIPE;
}

"exit" {
  return EXIT;
}

"&" {
  return AMPERSAND;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

"<" {
  return LESS;
}

">>" {
  return GREATGREAT;
}

"2>" {
  //return TWOGREAT;
}


">&" {
  return GREATAMP;
}

">>&" {
  return GREATGREATAMP;
}


  

"${$}" {
  int pid = getpid();
  std::string pid_str = std::to_string(pid);
  for (int i = pid_str.size() - 1; i >= 0; i--) {
    myunputc(pid_str[i]);
  }
}

"${?}" {
  pid_t ret_code = Shell::last_return_code;
  std::string ret_code_str = std::to_string(ret_code);
  for (int i = ret_code_str.size() - 1; i >= 0; i--) {
    myunputc(ret_code_str[i]);
  }
}

"${!}" {
 int last_pid = Shell::last_pid;
 std::string last_pid_str = std::to_string(last_pid);
 for (int i = last_pid_str.size() - 1; i >= 0; i--) {
   myunputc(last_pid_str[i]);
 }
}

"${_}" {
 std::string last_arg_str = Shell::last_arg;
 for (int i = last_arg_str.size() - 1; i >= 0; i--) {
   myunputc(last_arg_str[i]);
 }
}

"${SHELL}" {
  char *buffer = (char *) malloc(1025);
  std::string path = realpath(Shell::arguments[0], buffer);
  for (int i = path.size() - 1; i >= 0; i--) {
      myunputc(path[i]);
  }
  free(buffer);
}


[~][^ \t\n]* {
  std::string temp = std::string(yytext);
  std::string home = getenv("HOME");
  if (temp.size() > 1) {
    std::string name;
    int i = 1;
    while ((i < temp.size()) && (temp[i] != '/')) {
      name += temp[i];
      i++;
    }
    struct passwd *dir = getpwnam(name.c_str());
    home = dir->pw_dir;
    home += temp.substr(i, temp.size() - i);
  }
  for (int i = home.size() - 1; i >= 0; i--) {
    myunputc(home[i]);
  }
}


source[ ]*[^ \t\n][^ \t\n]* {
  std::string temp = std::string(yytext);
  std::string filename = temp.substr(7, temp.size());
  FILE *file_ptr = fopen(filename.c_str(), "r");
  if (file_ptr != NULL) {
    std::string contents;
    char c;
    while ((c = getc(file_ptr)) != EOF) {
      contents += c;
    }
    for (int i = contents.size() - 1; i >= 0; i--) {
      myunputc(contents[i]);    
    }
  }
  fclose(file_ptr);
}

\$\([^\n].*\) {
  yylval.cpp_string = new std::string(yytext);
  yylval.cpp_string->erase(0, 1);
  yylval.cpp_string->erase(0, 1);
  yylval.cpp_string->erase(yylval.cpp_string->end() - 1, yylval.cpp_string->end());
  
  // Save Defaults
  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperror = dup(2);

  // Create pipes
  int to_subprocess[2];
  int from_subprocess[2];

  pipe(to_subprocess);
  pipe(from_subprocess);

  dup2(to_subprocess[0], 0);
  close(to_subprocess[0]);
  dup2(from_subprocess[1], 1);
  close(from_subprocess[1]);

  yylval.cpp_string->append("\nexit\n");
  write(to_subprocess[1], yylval.cpp_string->c_str(), strlen(yylval.cpp_string->c_str()));
  //write(to_subprocess[1], "\nexit\n", 6);
  close(to_subprocess[1]);

  int pid=fork();

  if (pid == 0) {
    // Child process
    execvp("/proc/self/exe", NULL);
    perror("exec error");
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    dup2(tmperror, 2);
    close(tmpin);
    close(tmpout);
    close(tmperror);
    close(from_subprocess[0]);
    _exit(1);
  }
  else if (pid < 0) {
    perror("error");
    _exit(0);
  }

  while(waitpid(pid, NULL, WNOHANG) == 0) {
    // Do Nothing. Just Wait.
  }

  // restore defaults.
  dup2(tmpin, 0);
  dup2(tmpout, 1);
  dup2(tmperror, 2);
  close(tmpin);
  close(tmpout);
  close(tmperror);

  char character;
  char *buffer = (char *) malloc(1025);
  int num_read = 0;
  int n;
  while ((read(from_subprocess[0], &character, 1)) !=  0) {
    if (character == '\n') {
      buffer[num_read] = ' ';
      num_read++;
    }
    else {
      buffer[num_read] = character;
      num_read++;
    }
  }
  buffer[num_read] = '\n';
  close(from_subprocess[0]);

  for (int i = num_read - 1; i >= 0; i--) {
    myunputc(buffer[i]);
  }

}

\$\{[^ \t\n]* {
  std::string temp = std::string(yytext);
  int index = temp.size() - 1;
  int flag = 0;
  int endVar = temp.size() - 1;
  while (index >= 0) {
    if (temp[index] == '}') {
      flag = 1;
      endVar = index;
    }
    else if (temp[index] == '{') {
      std::string varName = temp.substr(index + 1, endVar - index - 1);
      std::string value = getenv(varName.c_str());
      for (int z = value.size() - 1; z >= 0; z--) {
        myunputc(value[z]);
      }
      flag = 0;
      index = index - 2;
      continue;
    }
    if (flag == 0) {
      myunputc(temp[index]);
    }
    index--;
  }
  /*for (int i = 0; i < temp.size(); i++) {
    if (temp[i] == '}') {
      std::string varName = temp.substr(2, i - 2);
      std::string value = getenv(varName.c_str());
      for (int j = temp.size() - 1; j >= i; j--) {
          myunputc(temp[j]);
      }
      for (int z = value.size() - 1; z >= 0; z--) {
        myunputc(value[z]);
      }
      break;
    }
  }*/
}

\\\"[^\t\n][^\t\n]*\\\" {
  std::string temp = std::string(yytext);
  yylval.cpp_string = new std::string("\"" + temp.substr(2, temp.size() - 4) + "\"");
  return WORD;
}

\"[^\t\n][^\t\n]*\" {
  std::string temp = std::string(yytext);
  yylval.cpp_string = new std::string(temp.substr(1, temp.size() - 2));
  return WORD;
}

[^ \t\n][^ \t\n]*  {
  std::string temp = std::string(yytext);
  int index = 0;
  // Iterate through string
  while (index < temp.size()) {
    /* get each char of the string.
       if the char is one of the four special chars, remove it from the string
       */
    char current = temp[index];
    if ((current == '\\') && (index + 1 != temp.size())) {
      current = temp[index + 1];
      switch(current) {
        case '\\':
          temp.erase(index, 1);
          break;
        case '&':
        case '<':
        case '>':
        case '\"':
        case '|':
          temp.erase(index, 1);
        default:
          index++;
      }
      continue;
    }
    // Right now, you are attempting to handle iomodifiers as part of a word
    // Instead, redo regex for a word such that it allows an iomodifier only if its precedeed by a backslash
    // Don't erase escaped characters.
    // Don't need any of 276 because you don't need to unput anything
    if ((temp[index] == '<') || (temp[index] == '>') || (temp[index] == '&') || (temp[index] == '|')) {
      for (int i = temp.size() - 1; i > index; i--) {
        myunputc(temp[i]);
      }
      myunputc(' ');
      //std::cout << temp << std::endl;
      myunputc(temp[index]);
      temp = temp.substr(0, index);
    }
    index++;
  }
  
  yylval.cpp_string = new std::string(temp);
  //std::cout << yylval.cpp_string << std::endl;
  if (temp.size() == 0) {
    yyparse();
  }
  else {
  return WORD;
  }
}



