/*
** Doorduino networking
** (c) 2011, "Koen Martens" <gmc@revspace.nl>
** Release under LGPL3
*/

#ifndef DoorduineNetClient_h
#define DoorduineNetClient_h

#include <Ethernet.h>
#include <DoorduinoComponent.h>
#include <DoorduinoNet.h>
#include "WProgram.h"

class DoorduinoNetClient : public DoorduinoComponent {
  public:
    DoorduinoNetClient(DoorduinoEnvironment *e, DoorduinoNet net);
    void reset(void);
    bool log_key(unsigned char* server, unsigned char* addr, char* secret);
    bool log_revocation(byte *server, byte *addr, char *secret);
    bool get_revocation(byte *server, uint8_t *hash);
    bool spaceLoopClosed(char *host,byte *ip);
  private:
    DoorduinoNet _net;
};

#endif
