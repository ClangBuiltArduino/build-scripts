#include <Arduino.h>

void setup() {
	Serial.begin(9600);
	Serial.print("started\n");
	pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
	Serial.print("loop iter\n");
	digitalWrite(LED_BUILTIN, HIGH);// turn the LED on (HIGH is the voltage level)
	Serial.print("1\n");
	delay(500);
	digitalWrite(LED_BUILTIN, LOW);
	Serial.print("0\n");
	delay(500);
}
