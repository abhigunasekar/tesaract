#include <cstdio>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "shell.hh"

char ** Shell::arguments;
int Shell::last_return_code;
int Shell::last_pid;
int Shell::pid;
std::string Shell::last_arg;
int Shell::start;

extern "C" void handler(int);
int yyparse(void);
int yyrestart(FILE *);
void myunputc(int);

void Shell::prompt() {
  if ( isatty(0) ) {
    char *prompt = getenv("PROMPT");
    if (prompt == NULL) {
      printf("myshell>");
      fflush(stdout);
    }
    else {
      printf("%s ", prompt);
      fflush(stdout);
    }
  }
}

int main(int argc, char **argv) {
  //Shell::pid = getpid();
  Shell::arguments = argv;
  // Setup handler for Ctrl-C
  struct sigaction sig;
  sig.sa_handler = handler;
  sigemptyset(&sig.sa_mask);
  sig.sa_flags = SA_RESTART;
  sigaction(SIGINT, &sig, NULL);

 // Implement .shellrc
 /* FILE *file_ptr = fopen("/homes/agunase/.shellrc", "r");
  yyrestart(file_ptr);
  yyparse();
  if (file_ptr != NULL) {
    std::string contents;
    char c;
    while ((c = getc(file_ptr)) != EOF) {
      contents += c;
    }
    for (int i = contents.size() - 1; i >= 0; i--) {
      myunputc(contents[i]);    
    }
    fclose(file_ptr);
  }
  
  yyrestart(stdin);*/

  Shell::prompt();
  yyparse();
  
}

// Define a handler for Ctrl C
extern "C" void handler(int signal) {
  waitpid(0, NULL, 0); // Kills the current process.
  Shell::_currentCommand.clear();
  printf("\n");
  Shell::prompt();
}

Command Shell::_currentCommand;

