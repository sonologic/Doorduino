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
    bool log_key(unsigned char* server, unsigned char* addr, char* secret);
    bool log_revocation(byte *server, byte *addr, char *secret);
    bool get_revocation(byte *server, uint8_t *hash);
    bool spaceLoopClosed(char *host,byte *ip);
  private:
    int  _rst_pin;
    uint8_t *_mac;
    uint8_t *_ip;   
};

#endif
