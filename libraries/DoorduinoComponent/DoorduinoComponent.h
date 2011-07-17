/*
** Doorduino auth state machine
** (c) 2011, "Koen Martens" <gmc@revspace.nl>
** Released under LGPL3
*/

#ifndef DoorduineComponent_h
#define DoorduineComponent_h

#include "WProgram.h"

typedef struct {
  bool s1;
  bool s2;
  bool s3;
  byte addr[8];
  bool log_addr;
  uint8_t revoke_hash[32];
  bool log_revocation;
  bool log_revocation_failed;
  bool loop_closed;
  bool space_closed;
} DoorduinoEnvironment;

class DoorduinoComponent {
  public:
    DoorduinoComponent(DoorduinoEnvironment *e);
    bool timeout(void);
    void setTimeout(int t);
    void iteration(void);
  protected:
    int _state;
    int _timeout;
    DoorduinoEnvironment *_env;
};

#endif
