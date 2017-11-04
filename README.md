# telemetry script
LUA telemetry script for opentx 2.1.x/2.2.x written and tested with:
* OpenTX/Companion 2.1.8/2.2.0
* FrSky Taranis plus (X9D+)
* SP3 Racing EVO
* cleanflight v2.1.0

## Installation
* copy script into the TELEMETRY folder on the SD card

## Info
* display named switch positions
* low and critical battery status is announced via voice
* starting with 90m the hight is announced
* non available telemetry values are not displayed and will be ignored
* lap statistics are displayed. A lap is counted when switch SH is triggered.

## Pictures
* Page 1/3:
display of VFAS and RSSI. In addition named switch positions and arm status
![Page 1/3](tlmy1_2.png)

* Page 2/3:
display of  altitude (1 sec interval calibration). alt and vspd incl. the min and max values. The diagram shows the as well the min and max value of the displayed graph
![Page 2/3](tlmy2_2.png)

* Page 3/3:
display of lap count and lap timers with best, worst, average, last lap time.
![Page 3/3](tlmy3_3.png)
