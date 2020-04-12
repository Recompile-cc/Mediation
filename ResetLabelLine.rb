require 'serialport'

sp = SerialPort.new('/dev/ttyUSB0', 4800)
sp.write("\ez(\r\eA10")