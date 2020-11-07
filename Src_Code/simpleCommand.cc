#include <cstdio>
#include <cstdlib>
#include <string.h>

#include <iostream>

#include "simpleCommand.hh"

SimpleCommand::SimpleCommand() {
  _arguments = std::vector<std::string *>();
}

SimpleCommand::~SimpleCommand() {
  // iterate over all the arguments and delete them
  for (auto & arg : _arguments) {
    delete arg;
  }
}

void SimpleCommand::insertArgument( std::string * argument ) {
  // simply add the argument to the vector
  _arguments.push_back(argument);
}

// Print out the simple command
void SimpleCommand::print() {
  for (auto & arg : _arguments) {
    std::cout << "\"" << arg->c_str() << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}

char ** SimpleCommand::getArguments() {
    char ** args = new char * [_arguments.size() + 1];
    for (unsigned int i = 0; i < _arguments.size(); i++) {
        args[i] = strdup(_arguments[i]->c_str());
    }
    args[_arguments.size()] = NULL;
    return args;
}

std::string *SimpleCommand::getLastArgument() {
  return _arguments.back();
}
