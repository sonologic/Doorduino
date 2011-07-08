/*
** Doorduino key store
** (c) 2011, "Koen Martens" <gmc@revspace.nl>
** Released under LGPL3
*/

#ifndef DoorduineStore_h
#define DoorduineStore_h

#include "WProgram.h"

class DoorduinoStore {
  public:
    DoorduinoStore();
    void erase(void);
    bool get_key_by_hash(uint8_t *revoke_hash,char *secret1,byte *addr);
    int find_key(byte *addr);
    bool check(byte *addr);
    bool is_admin(byte *addr);
    bool add_key(byte *addr);
    bool del_key(byte *addr);
    bool set_admin(byte *addr);
    bool reset_admin(byte *addr);
    void dump(void);
  private:
};

#endif
