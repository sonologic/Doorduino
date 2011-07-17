/*
** Doorduino networking
** (c) 2011, "Koen Martens" <gmc@revspace.nl>
** Release under LGPL3
*/

#ifndef DoorduineNet_h
#define DoorduineNet_h

#include <Ethernet.h>
#include "WProgram.h"

class DoorduinoNet {
  public:
    DoorduinoNet(int ethr_rst_pin, uint8_t *mac, uint8_t *ip);
    void reset(void);
  private:
    int  _rst_pin;
    uint8_t *_mac;
    uint8_t *_ip;
    Server _server;
};

#endif
