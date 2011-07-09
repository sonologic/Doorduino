/*
** Doorduino auth state machine
** (c) 2011, "Koen Martens" <gmc@revspace.nl>
** Released under LGPL3
*/

#ifndef DoorduineAuth_h
#define DoorduineAuth_h

#include <OneWire.h>
#include <DoorduinoComponent.h>
#include <DoorduinoStore.h>
#include <DoorduinoGpio.h>
#include "WProgram.h"

#define SCAN_ADMIN_TIME		100
#define SCAN_SUBJECT_TIME	100
#define FAIL_TIME		300
#define CONFIRM_TIME		 50
#define OPEN_TIME		  5

class DoorduinoAuth : public DoorduinoComponent {
  public:
    DoorduinoAuth(DoorduinoEnvironment *e, DoorduinoStore store, DoorduinoGpio gpio, int pin);
    void iteration(void);
  private:
    bool _scan_bus(byte *addr);
    DoorduinoStore _store;
    DoorduinoGpio _gpio;
    int _state;
    OneWire _ds;
    bool _s1;
    bool _s2;
    bool _s3;
};

#endif
