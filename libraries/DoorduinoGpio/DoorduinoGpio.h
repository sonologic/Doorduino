/*
** Doorduino GPIO
** (c) 2011, "Koen Martens" <gmc@revspace.nl>
** Released under LGPL3
*/

#ifndef DoorduineGpio_h
#define DoorduineGpio_h

#include "WProgram.h"

#define LED_BLACK	0
#define LED_BLUE	1
#define LED_GREEN	2
#define LED_RED		4
#define LED_PURPLE	(LED_BLUE|LED_RED)
#define LED_YELLOW	(LED_GREEN|LED_RED)
#define LED_WHITE	(LED_RED|LED_GREEN|LED_BLUE)

class DoorduinoGpio {
  public:
    DoorduinoGpio(int rpin,int gpin,int bpin,int strikepin);
    void set_led(byte color);
    void blink_led(byte col1,byte col2,int duration);
    void open_door(void);
    void close_door(void);
  private:
    int _r;
    int _g;
    int _b;
    int _strike;
};

#endif
