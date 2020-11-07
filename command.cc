/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>

// Includes for fork(), ....
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>



#include <iostream>

#include "command.hh"
#include "shell.hh"


Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    multi_output = false;
    
}

// Define a handler for zombie process
extern "C" void zombie_handler(int signal, siginfo_t *info,
                                void *ucontext) {
  while (int pid = waitpid(-1, NULL, WNOHANG) > 0) { // Kills the current process.
    printf("%d exited\n", pid);
    Shell::prompt();
  }
}


void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
    multi_output = false;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

void Command::execute() {
    if (Shell::start == 0) {
        Shell::start = 1;
        Shell::pid = getpid();
    }
    if (multi_output == true) {
      printf("Ambiguous output redirect.\n");
      clear();
      return;
    }
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::prompt();
        return;
    }

    // Print contents of Command data structure only if fd is not terminal
    if ( isatty(0) ) {
        print();
    }

    // Add execution here
    int tmpin = dup(0);
    int tmpout = dup(1);
    int tmperror = dup(2);

    // set the initial input
    int fdin;
    if (_inFile) {
        fdin = open(_inFile->c_str(), O_RDONLY);
        /*if (fdin == -1) {
          fprintf(stderr, "Input File Doesn't Exist!\n");
        }*/
    }
    else {
        //Use Default input
        fdin = dup(tmpin);
    }

    int ret;
    int fdout;
    int fderror;
    for (unsigned int i = 0; i < _simpleCommands.size(); i++) {
        //redirect input
        dup2(fdin, 0);
        close(fdin);
        //setup output
        if (i == _simpleCommands.size() - 1) {
            // Last simple command
            Shell::last_arg = std::string(*_simpleCommands[i]->getLastArgument());
            //printf("%s\n", Shell::last_arg);
            if (_outFile) {
                fdout = open(_outFile->c_str(), _outFlag, 0666);
            }
            else {
                fdout = dup(tmpout);
            }
            if (_errFile) {
                fderror = open(_errFile->c_str(), _errFlag, 0666);
            }
            else {
                fderror = dup(tmperror);
            }
        }
        else {
            // Not last simple command, we have to pipe
            int fdpipe[3];
            pipe(fdpipe);
            fdout = fdpipe[1];
            fderror = fdpipe[2];
            fdin = fdpipe[0];
        }
        // Redirect Output
        dup2(fdout, 1);
        dup2(fderror, 2);
        close(fdout);
        close(fderror);
        // Create child process
        if (strcmp("printenv", _simpleCommands[i]->_arguments[0]->c_str()) == 0) {
            int j = 0;
            while (environ[j] != NULL) {
                std::string env_value = environ[j];
                std::cout << env_value << std::endl;
                j++;
            }
            continue;
        }
        if (strcmp("setenv", _simpleCommands[i]->_arguments[0]->c_str()) == 0) {
            std::string A = _simpleCommands[i]->_arguments[1]->c_str();
            std::string B = _simpleCommands[i]->_arguments[2]->c_str();
            setenv(A.c_str(), B.c_str(), 1);
            continue;
        }
        if (strcmp("unsetenv", _simpleCommands[i]->_arguments[0]->c_str()) == 0) {
            std::string A = _simpleCommands[i]->_arguments[1]->c_str();
            unsetenv(A.c_str());
            continue;
        }
        if (strcmp("cd", _simpleCommands[i]->_arguments[0]->c_str()) == 0) {
            if (_simpleCommands[i]->_arguments[1] != NULL) {
                std::string dir = _simpleCommands[i]->_arguments[1]->c_str();
                DIR *open_return_val = opendir(dir.c_str());
                if (open_return_val != NULL) {
                    closedir(open_return_val);
                    chdir(dir.c_str());
                }
                else {
                    std::string err_string = std::string("cd: can't cd to " + dir);
                    perror(err_string.c_str());
                }
            }
            else {
                chdir(getenv("HOME"));
            }
            continue;
        }
        else if (strcmp("printenv", _simpleCommands[i]->_arguments[0]->c_str()) == 0) {

        }
        
        ret=fork();
        if (ret == 0) {
           // fprintf(stderr, "Command = %s", _simpleCommands[i])
            execvp(_simpleCommands[i]->_arguments[0]->c_str(), 
            _simpleCommands[i]->getArguments());
            perror("execvp");
            exit(1);
        }
    }
    //restore in/out defaults
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    dup2(tmperror, 2);
    close(tmpin);
    close(tmpout);
    close(tmperror);
    if (!_background) {
        // Wait for last command
        int ret_code;
        waitpid(ret, &ret_code, 0);
        if (WIFEXITED(ret_code)) {
          Shell::last_return_code = WEXITSTATUS(ret_code);
          if (Shell::last_return_code != 0) {
            // exit error
            char *error = getenv("ON_ERROR");
            if (error != NULL) {
              printf("%s\n", error);
            }
          }
        }
    }
    else {
        Shell::last_pid = ret;
        // Use handler for Zombie Process
        struct sigaction sig;
        sig.sa_sigaction = zombie_handler;
        sigemptyset(&sig.sa_mask);
        sig.sa_flags = SA_RESTART | SA_SIGINFO;
        sigaction(SIGCHLD, &sig, NULL);
    }
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec

    // Clear to prepare for next command
    clear();

    // Print new prompt
    Shell::prompt();
}



SimpleCommand * Command::_currentSimpleCommand;
