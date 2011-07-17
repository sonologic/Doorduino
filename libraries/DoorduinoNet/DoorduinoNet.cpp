/*
** Doorduino networking, ethernet
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

