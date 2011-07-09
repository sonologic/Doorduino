/*
**
*/

#include "DoorduinoComponent.h"

#ifdef DEBUG
#define DBG(...) Serial.print(__VA_ARGS__)
#else
#define DBG(...) {}
#endif

DoorduinoComponent::DoorduinoComponent(DoorduinoEnvironment *e) {
  _timeout=0;
  _state=1;
  _env=e;
}

bool DoorduinoComponent::timeout(void) {
  if(_timeout>0) {
    _timeout--;
    return false;
  }
  return true;
}

void DoorduinoComponent::setTimeout(int t) {
  _timeout=t;
}

void iteration(void) {
  // noop
}
