/*
** Doorduino networking
** (c) 2011, "Koen Martens" <gmc@revspace.nl>
** Released under LGPL3
*/

#include <inttypes.h>
#include <Ethernet.h>
#include <HTTPClient.h> // https://github.com/interactive-matter/HTTPClient/downloads
#include <sha256.h> // https://github.com/Cathedrow/Cryptosuite
#include "WProgram.h"
#include "DoorduinoNet.h"

#ifdef DEBUG
#define DBG(...) Serial.print(__VA_ARGS__)
#else
#define DBG(...) {}
#endif

DoorduinoNet::DoorduinoNet(int ethrst_pin,uint8_t *mac, uint8_t *ip) : _server(23) {
  _mac=mac;
  _ip=ip;
  _rst_pin=ethrst_pin;
  reset();
}

void DoorduinoNet::reset(void) {
  pinMode(_rst_pin,OUTPUT);
  digitalWrite(_rst_pin,LOW);
  delay(50);
  digitalWrite(_rst_pin,HIGH);
  pinMode(_rst_pin,INPUT);
  delay(200);
  Ethernet.begin(_mac,_ip);
  delay(200);
  _server.begin();
}
/*
bool DoorduinoNet::processClient(bool *loopStatus) {
  Client client = _server.available();
  if(client == true) {
    if(client.available()==1) {
    }
  }
  return true;
}
*/
/*
** send hash of key address to log server
** returns true on success, false otherwise
*/
bool DoorduinoNet::log_key(unsigned char* server, unsigned char* addr, char* secret) {
  uint8_t* hash;

  Client client(server, 80);
  
  Sha256.init();
  for( int i = 0; i < strlen(secret); i++) {
    Sha256.print(secret[i]);
  }
  for(int i = 0; i < 8; i++) {
    Sha256.print(addr[i]);
  }
  hash=Sha256.result(); 
  
  if (client.connect()) {
    DBG("network connected\n");
    client.print("GET /logkey.php?key=");
    for (int i=0; i<32; i++) {
      client.print("0123456789abcdef"[hash[i]>>4]);
      client.print("0123456789abcdef"[hash[i]&0xf]);
    }
    client.println(" HTTP/1.0");
    client.println();
    
    while (client.available()) {
      char c = client.read();
      DBG(c);
    }
    client.stop();
    DBG("network connection closed\n");
  } else {
    DBG("network connection failed\n");
  }
}

bool DoorduinoNet::log_revocation(byte *server, byte *addr, char *secret) {
  uint8_t* hash;
  
  Client client(server, 80);

  Sha256.init();
  for( int i = 0; i < strlen(secret); i++) {
    Sha256.print(secret[i]);
  }
  for( int i = 0; i < 8; i++) {
    Sha256.print(addr[i]);
  }
  hash=Sha256.result();

  if(client.connect()) {
    DBG("network connected\n");
    client.print("GET /revoked.php?action=log&hash=");
    for (int i=0; i<32; i++) {
      client.print("0123456789abcdef"[hash[i]>>4]);
      client.print("0123456789abcdef"[hash[i]&0xf]);
    }
    client.println(" HTTP/1.0");
    client.println();

    client.stop();
    DBG("network connection closed\n");    
  } else {
    DBG("network connection failed\n");
    return false;
  }
  return true;
}


/*
** check remote server for revocations and delete revoked
** keys from eeprom
**
** returns:
** true - hash (32 character array) contains the hash
** of the key to be revoked and secret2
** false - nothing to revoke, hash is undefined
*/
bool DoorduinoNet::get_revocation(byte *server, uint8_t *revoke_hash) {
  byte recv_count;
  byte state;
  int retry=3;
  
  Client client(server, 80);

  while(retry>0) {

    if (client.connect()) {
      DBG("network connected\n");
      client.println("GET /revoked.php?action=gethash HTTP/1.0");
      client.println();

      recv_count=0;
      state=0;
      while (client.connected() && recv_count<32) {
        // TODO: timeout to prevent DoS attack
        if(client.available()) {
          char c = client.read();
          switch(state) {
            case 0:
              if(c=='R') state++;
              break;
            case 1:
              if(c=='E') state++; else state=0;
              break;
            case 2:
              if(c=='V') state++; else state=0;
              break;
            case 3:
              if(c=='0') {
                client.stop();
                DBG("nothing to revoke");
                return false;
              }
              state=4;
              break;
            case 4:
              revoke_hash[recv_count++]=c;
              break;
          }
        }
      }
      client.stop();
    
      if(recv_count<32) {
        DBG("nothing to revoke..\n");
        return false;
      }
  
      return true;    
    } else {
      DBG("network connection failed\n");
      retry--;
      reset();
    }
  }
}

bool DoorduinoNet::spaceLoopClosed(char *host,byte *ip) {
  HTTPClient client(host,ip);

  FILE *result = client.getURI("/loop.php");

  int returnCode = client.getLastReturnCode();
  if(result!=NULL) {
    client.closeStream(result);
  } else {
    DBG("failed to connect to check space loop state\n");
  }

  if(returnCode==200) return false;
  if(returnCode==204) return true;
}

