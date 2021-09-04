# Memory mapped hardware
## 0x0 Input port
Read button/switch serial input from onboard 74HC
## 0x1-0x2 UART
### 0x1 UART Data
Read - read incoming byte. Write - transmit byte. Upper 8 bits are ignored
### 0x2 UART Status
Bit 0 - New data. Set if there is new data received. Reset when address 0x1 is read

Bit 1 - Ready for transmit. Check before sending data 

## 0x1000 - 0x4bff VGA 
VGA framebuffer. Every pixel is 8bit value BBGGGRRR, each address contains two subsequent pixels. Resolution 160x120 px

## 0x4c00 - 0x(ff)ffff RAM
SDRAM controller. General purpose ram for data