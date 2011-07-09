#include <DoorduinoGpio.h>

DoorduinoGpio::DoorduinoGpio(int r_pin,int g_pin,int b_pin,int strike_pin) {
  _r=r_pin;
  _g=g_pin;
  _b=b_pin;
  _strike=strike_pin;
}

/*
** set led color by provided RGB value,
** color, bit 0 - enable BLUE
** color, bit 1 - enable GREEN
** color, bit 2 - enable RED
*/
void DoorduinoGpio::set_led(byte color) {
  digitalWrite(_r,(color&4)?LOW:HIGH);
  digitalWrite(_g,(color&2)?LOW:HIGH);
  digitalWrite(_b,(color&1)?LOW:HIGH);
}

/*
** blink led with a frequency of 'period' iterations
** needs to be called on each iteration with parameter t
** indicating the progress of iterations
** col1 - color for 1st half of period
** col2 - color for 2nd half of period
** period - period in iterations
** t - time counter (iterations, either increasing or decreasing)
*/
void DoorduinoGpio::blink_led(byte col1,byte col2,int period,int t) {
  int tt = t%period;

  set_led( (tt<(period/2))?col1:col2 );  
}

void DoorduinoGpio::open_door() {
  set_led(LED_GREEN);
  digitalWrite(_strike,HIGH);
}

void DoorduinoGpio::close_door() {
  set_led(LED_BLACK);
  digitalWrite(_strike,LOW);
}

