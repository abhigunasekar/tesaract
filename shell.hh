#ifndef shell_hh
#define shell_hh

#include "command.hh"

struct Shell {

  static void prompt();

  static Command _currentCommand;

  static char ** arguments;

  static int last_return_code;

  static int last_pid;

  static std::string last_arg;

  static int start;

  static int pid;
};

#endif
