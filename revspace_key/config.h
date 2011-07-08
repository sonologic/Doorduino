// debug output
#undef DEBUG

// define to wipe eeprom and program 1st admin key
#undef SETUP

// network setup
byte mac[] = { 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF };	// our mac address
byte ip[] = { 10, 0, 6, 66 };				// our ip
byte server[] = { 10, 0, 23, 42 }; 			// server ip

// shared secrets for server communication
char secret1[]="some very long sentence";
char secret2[]="some other very long sentence";

// seconds between checking revocation server
#define CHECK_REVOCATION  60

// delays
#define OPEN_DELAY  4000

#ifdef DEBUG
#define FAIL_DELAY 3000
#else
#define FAIL_DELAY 30000
#endif

/*
** Pins:
**  0 - serial RX
**  1 - serial TX
**  2 - onewire bus
**  3 - red led
**  4 - ethernet shield SD enable
**  5 - green led
**  6 - blue led
**  7 - strike activation relay
**  8 - ethernet shield reset
**  9 - NEW: sense space open switch
** 10 - ethernet shield W5100 enable
** 11 - ethernet shield SPI
** 12 - ethernet shield SPI
** 13 - ethernet shield SPI
** 14 - button 'add key'
** 15 - button 'add admin key'
** 16 - button 'revoke key'
** 17 - external door open trigger (low active)
** 18 - NEW: sense door reed switch
** 19 - NEW: activate bell
**
** 14-19 are analog pins 0-5
**
*/

#define onewire_pin 2      // onewire bus
#define r_pin 3            // red led
#define g_pin 5            // green led
#define b_pin 6            // blue led
#define strike_pin 7       // door strike actuator
#define ethrst_pin 8       // ethernet shield reset
#define space_status_pin 9 // space status sensor
#define add_pin 14         // button to add key
#define add_admin_pin 15   // button to add admin key
#define revoke_pin 16      // button to revoke key
#define extern_pin 17      // external open command
#define door_sensor_pin 18 // door reed switch sensor
#define bell_pin 19        // bell actuator
