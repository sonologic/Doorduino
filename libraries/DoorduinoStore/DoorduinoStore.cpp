/*
**
*/

#include <EEPROM.h>
#include <sha256.h> // https://github.com/Cathedrow/Cryptosuite
#include "DoorduinoStore.h"

#define KEYSTORESIZE  (E2END+1)

#define KEY_EMPTY   0
#define KEY_INUSE   1
#define KEY_ADMIN   2

#ifdef DEBUG
#define DBG(...) Serial.print(__VA_ARGS__)
#else
#define DBG(...) {}
#endif

DoorduinoStore::DoorduinoStore() {
  int i;

  i=1;
  // noop
}

void DoorduinoStore::erase(void) {
  DBG("Erasing eeprom, ");
  DBG(E2END+1);
  DBG(" bytes\n");
  for(int i=0;i<=E2END;i++) {
    EEPROM.write(i,0);
  }
}

bool DoorduinoStore::get_key_by_hash(uint8_t *revoke_hash,char *secret1,byte *addr) {
      int idx;
      int base;
      uint8_t *hash;
      //byte addr[8];
      bool revoked=false;
      
      DBG("hash to revoke: ");
      for (int i=0; i<32; i++) {
        DBG("0123456789abcdef"[revoke_hash[i]>>4]);
        DBG("0123456789abcdef"[revoke_hash[i]&0xf]);
      }
      DBG("\n");

      base=0; idx=0;
      while( ((idx+1)*9) <= KEYSTORESIZE ) {
        base=idx*9;
  
        if(EEPROM.read(base)&KEY_INUSE) {
          Sha256.init();
          for( int i = 0; i < strlen(secret1); i++) {
            Sha256.print(secret1[i]);
          }
          for(int i=0;i<8;i++) {
            addr[i]=EEPROM.read(base+1+i);
            Sha256.print(addr[i]);
          }        
          hash=Sha256.result(); 
          bool match=true;
          for(int i=0;i<32;i++) {
            if(hash[i]!=revoke_hash[i]) match=false;
          }
          if(match) {
            DBG("found matching key at idx ");
            DBG(idx);
            DBG("\n");
            return true;
          }
        }
        idx++;
      }
      return false;
}

int DoorduinoStore::find_key(byte *addr) {
  int idx=0;
  int base;
  
  while( ((idx+1)*9) <= KEYSTORESIZE ) {
    base=idx*9;
    if( EEPROM.read(base)&KEY_INUSE ) {
      int i;
      for(i=0;i<8;i++) {
        if(EEPROM.read(base+1+i)!=addr[i]) break;
      }
      if(i==8) {
        return base;
      }
    }
    idx++;
  }
  return -1;
}

bool DoorduinoStore::check(byte *addr) {
  if(find_key(addr)==-1) return false;
  return true;
}

bool DoorduinoStore::is_admin(byte *addr) {
  int base=find_key(addr);
  
  if( (base!=-1) && (EEPROM.read(base)&KEY_ADMIN) ) {
    return true;
  }
  return false;
}

bool DoorduinoStore::add_key(byte *addr) {
  int base=find_key(addr);
  
  if( base==-1 ) {
    DBG("Add key\n");
    int idx=0;
    int base;
    while( ((idx+1)*9) <= KEYSTORESIZE ) {
      base=idx*9;
      if(EEPROM.read(base)==KEY_EMPTY) {
        DBG("Found slot on ");
        DBG(base);
        DBG("\n");
        EEPROM.write(base,KEY_INUSE);
        for(int i=0;i<8;i++) {
          EEPROM.write(base+1+i,addr[i]);
        }
        return true;
      }
      idx++;
    }
    return false;
  } else {
    reset_admin(addr);
  }
}

bool DoorduinoStore::del_key(byte *addr) {
  int base=find_key(addr);
  
  if(base==-1) return false;
  
  EEPROM.write(base,KEY_EMPTY);
  for(byte i=0;i<8;i++) {
    EEPROM.write(base+1+i,0);
  }
}

bool DoorduinoStore::set_admin(byte *addr) {
  int base=find_key(addr);

  DBG("set_admin: Found key on ");
  DBG(base);
  DBG("\n");
  
  if(base!=-1) {
    EEPROM.write(base,EEPROM.read(base)|KEY_ADMIN);
    return true;
  }
  return false;
}

bool DoorduinoStore::reset_admin(byte addr[8]) {
  int base=find_key(addr);
  
  if(base!=-1) {
    EEPROM.write(base,EEPROM.read(base)&(~KEY_ADMIN));
    return true;
  }
  return false;
}

void DoorduinoStore::dump(void) {
  for(int i=0;i<KEYSTORESIZE;i+=9) {
      DBG(i);
      DBG(":");
      for( int j = 0; j < 9; j++) {
        DBG(EEPROM.read(i+j), HEX);
        DBG(" ");
      }
      DBG("\n");
    
  }
}
