/*
** File  : revspace_key.pde
** Author: "Koen Martens" <gmc@revspace.nl>
** Date  : 2010-01-11
** Desc. : Operates a 1-wire bus, waiting for a 1-wire device to
**         appear. Reads its address, and compares that to a list
**         of stored addresses in the arduino's EEPROM. Further
**         features include the ability to add and revoke keys, and
**         logging/revoking over http to a remote server.
**
**         https://foswiki.sonologic.nl/RevelationSpace/ProjectSpaceAccessControl
**
**    This program is free software: you can redistribute it and/or modify
**    it under the terms of the GNU General Public License as published by
**    the Free Software Foundation, either version 3 of the License.
**
**    This program is distributed in the hope that it will be useful,
**    but WITHOUT ANY WARRANTY; without even the implied warranty of
**    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**    GNU General Public License for more details.
**
**    You should have received a copy of the GNU General Public License
**    along with this program.  If not, see <http://www.gnu.org/licenses/>.
**
*/

#include <OneWire.h>
#include <EEPROM.h>
#include <SPI.h>
#include <Ethernet.h>
#include <sha256.h>  // https://github.com/Cathedrow/Cryptosuite

#undef DEBUG

#define VERSION "3"

#ifdef DEBUG
#define DBG(...) Serial.print(__VA_ARGS__)
#else
#define DBG(...) {}
#endif

#define KEYSTORESIZE  (E2END+1)

#define KEY_EMPTY  0
#define KEY_INUSE  1
#define KEY_ADMIN  2

#define OPEN_DELAY  4000
#ifdef DEBUG
#define FAIL_DELAY 3000
#else
#define FAIL_DELAY 30000
#endif

#define CHECK_REVOCATION  60  // seconds between checking revocation server

#define LED_BLACK  0
#define LED_BLUE   1
#define LED_GREEN  2
#define LED_RED    4
#define LED_PURPLE (LED_BLUE|LED_RED)
#define LED_YELLOW (LED_GREEN|LED_RED)
#define LED_WHITE  7

// define to wipe eeprom and program 1st admin key
//#define SETUP

// network setup
byte mac[] = { 0xDE, 0xD0, 0x07, 0xEE, 0x77, 0xED };
byte ip[] = { 42, 42, 0, 31 };
byte server[] = { 42, 42, 0, 25 }; // LCD

Client client(server, 80);

// these are on analog pins
int add_pin = 14;        // button to add key
int add_admin_pin = 15;  // button to add admin key
int revoke_pin = 16;      // button to revoke key
int extern_pin = 17;      // external open command

// these are on digital pins
OneWire  ds(2);

int r_pin = 3;
int g_pin = 5;
int b_pin = 6;

int strike_pin = 7;

int ethrst_pin = 8;

// used for timing remote revocation checks
int loop_count=0;
// used for giving the impression of a really fancy alarm system
byte slow_blink=0;
#define SLOWBLINK 10

// revocation constants
char secret1[]="secret3";
char secret2[]="secret2";

/*
** set led color by provided RGB value,
** color, bit 0 - enable BLUE
** color, bit 1 - enable GREEN
** color, bit 2 - enable RED
*/
void set_led(byte color) {
  digitalWrite(r_pin,(color&4)?LOW:HIGH);
  digitalWrite(g_pin,(color&2)?LOW:HIGH);
  digitalWrite(b_pin,(color&1)?LOW:HIGH);
}

/*
** blink led with a frequency of 1hz
** col1 - color for 1st half of period
** col2 - color for 2nd half of period
** duration - duration in seconds
** leaves led in col2
*/
void blink_led(byte col1,byte col2,int duration) {
  for(int i=0;i<duration;i++) {
    set_led(col1);
    delay(500);
    set_led(col2);
    delay(500);
  }
}

void setup_ethernet(void) {
   // workaround for buggy ethernet shield reset
  pinMode(ethrst_pin,OUTPUT);
  digitalWrite(ethrst_pin,LOW);
  delay(50);
  digitalWrite(ethrst_pin,HIGH);
  pinMode(ethrst_pin,INPUT);
  delay(200);
  Ethernet.begin(mac, ip);
  delay(200);
}
/*
** initialise ethernet shield, set pin modes and
** start serial output, dump contents of eeprom
*/
void setup(void) {
  setup_ethernet();
  pinMode(add_pin,INPUT);
  pinMode(add_admin_pin,INPUT);
  pinMode(revoke_pin,INPUT);
  pinMode(extern_pin,INPUT);
  digitalWrite(add_pin,HIGH);
  digitalWrite(add_admin_pin,HIGH);
  digitalWrite(revoke_pin,HIGH);
  digitalWrite(extern_pin,HIGH);
  pinMode(r_pin,OUTPUT);
  pinMode(g_pin,OUTPUT);
  pinMode(b_pin,OUTPUT);
  pinMode(strike_pin,OUTPUT);
  Serial.begin(9600);
  Serial.write("Initialized version ");
  Serial.write(VERSION);
  Serial.write("..\n");
  dump_eeprom();

}

/*
** send hash of key address to log server
** returns true on success, false otherwise
*/
bool log_key(byte *addr) {
  uint8_t* hash;
  
  Sha256.init();
  for( int i = 0; i < strlen(secret1); i++) {
    Sha256.print(secret1[i]);
  }
  for( int i = 0; i < 8; i++) {
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

bool log_revocation(byte *addr) {
  uint8_t* hash;
  
  Sha256.init();
  for( int i = 0; i < strlen(secret2); i++) {
    Sha256.print(secret2[i]);
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
*/
void check_revocations(void) {
  uint8_t revoke_hash[32];
  uint8_t *hash;
  byte addr[8];
  byte recv_count;
  byte state;
  int idx=0;
  int base;
  int retry=3;
  
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
                return;
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
        return;
      }
      
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
            DBG("revoke key at idx ");
            DBG(idx);
            DBG("\n");
            if(log_revocation(addr)) {
              DBG("revocation logged\n");
              del_key(addr);
            } else {
              DBG("revocation log attempt failed\n");
            }
          }
        }
        idx++;
      }
      retry=0;
    } else {
      DBG("network connection failed\n");
      retry--;
      setup_ethernet();
    }
  }
}

int find_key(byte *addr) {
  int idx=0;
  int base;
  
  while( ((idx+1)*9) <= KEYSTORESIZE ) {
    base=idx*9;
    if(EEPROM.read(base)&KEY_INUSE) {
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

bool check(byte *addr) {
  if(find_key(addr)==-1) return false;
  return true;
}

bool is_admin(byte *addr) {
  int base=find_key(addr);
  
  if( (base!=-1) && (EEPROM.read(base)&KEY_ADMIN) ) {
    return true;
  }
  return false;
}

bool add_key(byte *addr) {
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

bool del_key(byte *addr) {
  int base=find_key(addr);
  
  if(base==-1) return false;
  
  EEPROM.write(base,KEY_EMPTY);
  for(byte i=0;i<8;i++) {
    EEPROM.write(base+1+i,0);
  }
}

bool set_admin(byte *addr) {
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

bool reset_admin(byte addr[8]) {
  int base=find_key(addr);
  
  if(base!=-1) {
    EEPROM.write(base,EEPROM.read(base)&(~KEY_ADMIN));
    return true;
  }
  return false;
}

void dump_eeprom(void) {
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

void door_open(byte *addr) {
  set_led(LED_GREEN);
  digitalWrite(strike_pin,HIGH);
  log_key(addr);
  delay(OPEN_DELAY);
  set_led(LED_BLACK);
  digitalWrite(strike_pin,LOW);
}

void loop(void) {
  byte i;
  byte present = 0;
  byte data[12];
  byte addr[8];

#ifdef SETUP
  set_led(LED_WHITE);
  DBG("Erasing eeprom, ");
  DBG(E2END+1);
  DBG(" bytes\n");
  for(int i=0;i<=E2END;i++) {
    EEPROM.write(i,0);
  }

  dump_eeprom();
  
  DBG("Waiting for admin key..\n");
  
  byte blink=0;
  for(;;) {
    set_led( (blink==0)?LED_BLUE:LED_WHITE );
    blink=1-blink;
    if( ds.search(addr) ) {
      DBG("R=");
      for( i = 0; i < 8; i++) {
        DBG(addr[i], HEX);
        DBG(" ");
      }
      DBG("\n");
      if ( OneWire::crc8( addr, 7) != addr[7]) {
        DBG("CRC is not valid!\n");
      } else {
        DBG("Registering admin key\n");
        if(add_key(addr)) {
          if(set_admin(addr)) {
            set_led(LED_GREEN);
          } else {
            set_led(LED_RED);
          }
          set_led(LED_RED);
        }
        dump_eeprom();
        for(;;);
      }
      
    } else {
      ds.reset_search();
      delay(250);
    } 
  }
  
#else

  loop_count++;

  if(digitalRead(extern_pin)==LOW) {
    for(i=0;i<8;i++) addr[i]=0;
    door_open(addr);
  }
  
  if(loop_count>=(CHECK_REVOCATION*4)) {
    set_led(LED_PURPLE);
    DBG("checking revocations\n");
    check_revocations();
    loop_count=0;
    set_led(LED_BLUE);
  }
  
  if( ds.search(addr) ) {
    DBG("R=");
    for( i = 0; i < 8; i++) {
      DBG(addr[i], HEX);
      DBG(" ");
    }
    DBG("\n");
    if ( OneWire::crc8( addr, 7) != addr[7]) {
      DBG("CRC is not valid!\n");
      return;
    }
    if(find_key(addr)!=-1) {
      DBG("Valid key, open door\n");
      door_open(addr);
    } else {
      DBG("Invalid key\n");
      set_led(LED_RED);
      delay(FAIL_DELAY);
      set_led(LED_BLACK);
      DBG("Ready..\n");
    }
  } else {
    ds.reset_search();
    
    byte state=0;
    if(digitalRead(add_pin)==LOW) {
      DBG("Add key\n");
      state=1;
    }
    if(digitalRead(add_admin_pin)==LOW) {
      DBG("Add admin key\n");
      state=2;
    }
    if(digitalRead(revoke_pin)==LOW) {
      DBG("Revoke key\n");
      state=3;
    }
 
    if(state>0) {
      byte blink=0;
      byte got_admin=0;
      
          // blink led blue and wait for admin key
      DBG("Wait for admin key\n");
      for(i=0;i<20;i++) {
        set_led((blink==0?LED_BLUE:LED_BLACK));
        if(ds.search(addr)) {
          DBG("R=");
          for( i = 0; i < 8; i++) {
            DBG(addr[i], HEX);
            DBG(" ");
          }
          DBG("\n");
          if ( OneWire::crc8( addr, 7) != addr[7]) {
            DBG("CRC is not valid!\n");
            return;
          }
      
          if(is_admin(addr)) {
            got_admin=1;
            break;
          } else {
            blink_led(LED_RED,LED_BLACK,10);
            return;
          }
        }
        ds.reset_search();
        delay(500);
        blink=1-blink;
      }
      
          // if not admin key, blink and exit
      if( !got_admin ) {
        DBG("no admin key\n");
        DBG(i,DEC);
        DBG("\n");
        if(i==20) {
          blink_led(LED_RED,LED_BLACK,10);
        }
        return;        
      }     
          
      blink=0;
      byte got_key=0;
      
          // blink led yellow and wait for new key
      DBG("Wait for new key\n");
      for(i=0;i<20;i++) {
        set_led((blink==0?LED_YELLOW:LED_BLACK));
        if(ds.search(addr)) {
          DBG("R=");
          for( i = 0; i < 8; i++) {
            DBG(addr[i], HEX);
            DBG(" ");
          }
          DBG("\n");
          if ( OneWire::crc8( addr, 7) != addr[7]) {
            DBG("CRC is not valid!\n");
            return;
          }
          got_key=1;
          break;
        }
        ds.reset_search();
        delay(500);
        blink=1-blink; 
      }          
    
      if(got_key) {  
          switch(state) {
            case 1:  // add
              if(add_key(addr)) {
                blink_led(LED_GREEN,LED_BLACK,10);
              } else {
                blink_led(LED_RED,LED_BLACK,10);
              }
              break;
            case 2:  // add admin
              if(add_key(addr)) {
                if(set_admin(addr)) {
                  blink_led(LED_GREEN,LED_BLACK,10);
                } else {
                  blink_led(LED_RED,LED_BLUE,10);
                }
              } else {
                blink_led(LED_RED,LED_BLACK,10);
              }
              break;
            case 3:  // revoke
              if(del_key(addr)) {
                blink_led(LED_GREEN,LED_BLACK,10);
              } else {
                blink_led(LED_RED,LED_BLACK,10);
              }
              break;    
          }
      }
    }
  }    
  
  set_led( (slow_blink==(SLOWBLINK-1) || slow_blink==(SLOWBLINK-3)) ?LED_BLACK:LED_BLUE );
  slow_blink=(slow_blink+1)%SLOWBLINK;
  
  delay(250);
#endif  
  
}
