/*
**
*/

#include <OneWire.h>
#include <DoorduinoGpio.h>
#include <DoorduinoStore.h>
#include "DoorduinoAuth.h"

#ifdef DEBUG
#define DBG(...) Serial.print(__VA_ARGS__)
#else
#define DBG(...) {}
#endif

#define CONFIRM { setTimeout(CONFIRM_TIME); _state=14; }
#define FAIL { setTimeout(FAIL_TIME); _state=15; }

DoorduinoAuth::DoorduinoAuth(DoorduinoEnvironment *e,DoorduinoStore _store, DoorduinoGpio _gpio, int pin) : 
  DoorduinoComponent(e), 
  _store(_store), 
  _gpio(_gpio), 
  _ds(pin) 
{
  setTimeout(18);
  _s1=_s2=_s3=false;
}

bool DoorduinoAuth::_scan_bus(byte *addr) {
  if( _ds.search(addr) ) {
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


void DoorduinoAuth::iteration(void) {
  
  switch(_state) {
    case 1:
      _gpio.set_led(LED_BLACK);
      setTimeout(18);
      _state=22;
      break;

    case 2:
    case 3:
    case 4:
    case 22:
      _gpio.set_led( (( _state==2 ) || ( _state==4 ))?LED_BLACK:LED_BLUE);

      if(_env->s1) {			// button 1 - add key
        _s1=true;
        _state=5;
      } else if(_env->s2) {		// button 2 - revoke key
        _s2=true;
        _state=6;
      } else if(_env->s3) {		// button 3 - add admin key
        _s3=true;
        _state=7;
      } else if(_scan_bus(_env->addr)) {	// scan onewire bus
	_state=17;
      } else if(timeout()) {		// idle led blink pattern (substates)
        switch(_state) {
          case 2: _state=3; setTimeout(2); break;
          case 3: _state=4; setTimeout(2); break;
          case 4: _state=22; setTimeout(18); break;
          case 22: _state=2; setTimeout(2); break;
        }
      }

      break;

    case 5:
      _s1=true; _state=8; setTimeout(SCAN_ADMIN_TIME); break;
    case 6:
      _s2=true; _state=8; setTimeout(SCAN_ADMIN_TIME); break;
    case 7:
      _s3=true; _state=8; setTimeout(SCAN_ADMIN_TIME); break;

    case 8:
      _gpio.blink_led(LED_BLACK,LED_BLUE,600,_timeout);
      if(_scan_bus(_env->addr)) {
        _state=9;
      } else if(timeout()) {
        _state=16;
      }
      break;

    case 9:
      if(_store.is_admin(_env->addr)) {
	setTimeout(SCAN_SUBJECT_TIME);
	_state=10;
      } else {
	setTimeout(FAIL_TIME);
        _state=15;
      }
      break;

    case 10:
      _gpio.blink_led(LED_BLACK,LED_YELLOW,600,_timeout);
      if(_scan_bus(_env->addr)) {
	_state=_s2?11:12;
      } else if(timeout()) {
	_state=16;
      }
      break;

    case 11:
      if(_store.del_key(_env->addr)) CONFIRM else FAIL;
      break;

    case 12:
      if(_store.add_key(_env->addr)) {
        if(_s3) { // set admin
          _state=13;
        } else {
	  CONFIRM
        }
      } else {
        FAIL
      }
      break;

    case 13:
      if(_store.set_admin(_env->addr)) CONFIRM else FAIL;
      break;

    case 14:
      _gpio.blink_led(LED_BLACK,LED_GREEN,600,_timeout);
      if(timeout()) _state=16;
      break;

    case 15:
      _gpio.blink_led(LED_RED,LED_BLUE,200,_timeout);
      if(timeout()) _state=16;
      break;

    case 16:
      _s1=_s2=_s3=false;
      _state=1;
      break;

    case 17:
      if(_store.find_key(_env->addr)!=-1) {
        _state=18;
      } else {
        setTimeout(FAIL_TIME);
        _state=21;
      }
      break;

    case 18:
      _gpio.set_led(LED_GREEN);
      _gpio.open_door();
      _env->log_addr=true;
      setTimeout(OPEN_TIME);
      _state=19;
      break;

    case 19:
      if(timeout()) _state=20;
      break;

    case 20:
      _gpio.close_door();
      _gpio.set_led(LED_BLACK);
      _state=1;
      break;

    case 21:
      _gpio.blink_led(LED_BLACK,LED_RED,200,_timeout);
      if(timeout()) _state=1;
      break;

    default:
      // this should not happen, reset
      _state=16;
      break;
  }

}
