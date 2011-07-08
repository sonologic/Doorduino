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
#include <HTTPClient.h> // https://github.com/interactive-matter/HTTPClient/downloads
#include <sha256.h>  // https://github.com/Cathedrow/Cryptosuite
#include "config.h"  // configuration options

#define VERSION "4"

#ifdef DEBUG
#define DBG(...) Serial.print(__VA_ARGS__)
#else
#define DBG(...) {}
#endif

#include <DoorduinoNet.h>
#include <DoorduinoStore.h>
#include <DoorduinoGpio.h>


DoorduinoNet net(ethrst_pin,mac,ip);
DoorduinoStore store;
DoorduinoGpio gpio(r_pin,g_pin,b_pin,strike_pin);

OneWire  ds(onewire_pin);

// used for timing remote revocation checks
int loop_count=0;

// used for giving the impression of a really fancy alarm system
byte slow_blink=0;
#define SLOWBLINK 10

/*
** set pin modes and start serial output
*/
void setup(void) {
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
}

void door_open(byte *addr) {
  gpio.open_door();
  net.log_key(server,addr,secret1);
  delay(OPEN_DELAY);
  gpio.close_door();
}

void processExternal(void) {
  byte addr[8];
  if(digitalRead(extern_pin)==LOW) {
    for(int i=0;i<8;i++) addr[i]=0;
    door_open(addr);
  }
}

void processRevocations(void) {
    uint8_t revoke_hash[32];
    byte addr[8];
    
    gpio.set_led(LED_PURPLE);
    DBG("checking revocations\n");
    if(net.get_revocation(server,revoke_hash)) {
      if(store.get_key_by_hash(revoke_hash,secret1,addr)) {
        if(net.log_revocation(server,addr,secret2)) {
          DBG("revocation logged\n");
          store.del_key(addr);
        } else {
          DBG("revocation log attempt failed, refusing to revoke\n");
        }
      }
    }
    gpio.set_led(LED_BLUE);
}

bool scan_bus(byte *addr) {
  if( ds.search(addr) ) {
    DBG("R=");
    for( int i = 0; i < 8; i++) {
      DBG(addr[i], HEX);
      DBG(" ");
    }
    DBG("\n");
    if ( OneWire::crc8( addr, 7) != addr[7]) {
      DBG("CRC is not valid!\n");
      return false;
    }
    return true;
  }
  return false;
}

void loop(void) {
  byte i;
  byte present = 0;
  byte data[12];
  byte addr[8];

  store.dump();
  
#ifdef SETUP
  gpio.set_led(LED_WHITE);
  store.erase();

  store.dump();
  
  DBG("Waiting for admin key..\n");
  
  byte blink=0;
  for(;;) {
    gpio.set_led( (blink==0)?LED_BLUE:LED_WHITE );
    blink=1-blink;
    
    if(scan_bus(addr)) {
        DBG("Registering admin key\n");
        if(store.add_key(addr)) {
          if(store.set_admin(addr)) {
            gpio.set_led(LED_GREEN);
          } else {
            gpio.set_led(LED_RED);
          }
          gpio.set_led(LED_RED);
        }
        store.dump();
        for(;;);
    } else {
      ds.reset_search();
      delay(250);
    } 
  }
  
#else

  loop_count++;

  // external door open request??
  processExternal();

  
  // periodic key revocation
  if(loop_count>=(CHECK_REVOCATION*4)) {
    processRevocations();
    loop_count=0;
  }
  
  // read one-wire bus
  if( scan_bus(addr) ) {
    
    if(store.find_key(addr)!=-1) {
      DBG("Valid key, open door\n");
      door_open(addr);
    } else {
      DBG("Invalid key\n");
      gpio.set_led(LED_RED);
      delay(FAIL_DELAY);
      gpio.set_led(LED_BLACK);
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
        gpio.set_led((blink==0?LED_BLUE:LED_BLACK));
        if(scan_bus(addr)) {      
          if(store.is_admin(addr)) {
            got_admin=1;
            break;
          } else {
            gpio.blink_led(LED_RED,LED_BLACK,10);
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
          gpio.blink_led(LED_RED,LED_BLACK,10);
        }
        return;        
      }     
          
      blink=0;
      byte got_key=0;
      
          // blink led yellow and wait for new key
      DBG("Wait for new key\n");
      for(i=0;i<20;i++) {
        gpio.set_led((blink==0?LED_YELLOW:LED_BLACK));
        if(scan_bus(addr)) {
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
              if(store.add_key(addr)) {
                gpio.blink_led(LED_GREEN,LED_BLACK,10);
              } else {
                gpio.blink_led(LED_RED,LED_BLACK,10);
              }
              break;
            case 2:  // add admin
              if(store.add_key(addr)) {
                if(store.set_admin(addr)) {
                  gpio.blink_led(LED_GREEN,LED_BLACK,10);
                } else {
                  gpio.blink_led(LED_RED,LED_BLUE,10);
                }
              } else {
                gpio.blink_led(LED_RED,LED_BLACK,10);
              }
              break;
            case 3:  // revoke
              if(store.del_key(addr)) {
                gpio.blink_led(LED_GREEN,LED_BLACK,10);
              } else {
                gpio.blink_led(LED_RED,LED_BLACK,10);
              }
              break;    
          }
      }
    }
  }    
  
  gpio.set_led( (slow_blink==(SLOWBLINK-1) || slow_blink==(SLOWBLINK-3)) ?LED_BLACK:LED_BLUE );
  slow_blink=(slow_blink+1)%SLOWBLINK;
  
  delay(250);
#endif  
  
}
