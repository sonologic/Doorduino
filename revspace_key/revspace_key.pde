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

#include <DoorduinoComponent.h>
#include <DoorduinoNet.h>
#include <DoorduinoStore.h>
#include <DoorduinoGpio.h>
#include <DoorduinoAuth.h>

DoorduinoEnvironment env = {
  false, false, false,
  { 0,0,0,0,0,0,0,0 },
  false,
  { 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 },
  false, false, false, false
};
  

DoorduinoNet net(ethrst_pin,mac,ip);
DoorduinoStore store;
DoorduinoGpio gpio(r_pin,g_pin,b_pin,strike_pin);
DoorduinoAuth auth(&env, store, gpio, onewire_pin);

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
  store.dump();
}
  
#ifdef SETUP

void loop(void) {
  byte addr[8];

  store.dump();

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
  
#else // undef SETUP

/*
** Events:
** - space open
** - space closed
** - loop open
** - loop closed
** - 
*/

void loop(void) {
  if(digitalRead(add_pin)==LOW) {
    env.s1=true;
  }
  if(digitalRead(revoke_pin)==LOW) {
    env.s3=true;
  }
  if(digitalRead(add_admin_pin)==LOW) {
    env.s2=true;
  }
  
  auth.iteration();
  
  // netclient.iteration();
  
  // netserver.iteration();

  delay(100);
}

#endif
