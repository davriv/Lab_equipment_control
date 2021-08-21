%%% MATLAB deck to deploy time-domain response of the CLB
%%% controlling voltage DC sources, waveform generator and
%%% oscilloscope, with GPIB-USB and LAN.
%%% Voltage source for VDD           ---> Keithley 2635A
%%% Voltage source for +K and -K     ---> Agilent E3645A
%%% Waveform generator for U1 and U2 ---> Keysight 33600A
%%% Oscilloscope                     ---> Tektronix MDO3104
%%% Voltages sources are controlled with GPIB-USB.
%%% Waveform generator and Oscilloscope are controlled with LAN
%%% Ing. David Gerardo Rivera Orozco
%%% March, 2021
%%% CINVESTAV IPN Master in Electrical Engineering Program
%%% Control platform: Keysight Connection Expert

% Clear variables, close figures and clean command window
clc;
clear all;
close all;

%----------------------Inicialization of Keithley 2635A---------------------
Dir=24;  %% Address of Keithley 2635A
s=instrfind('PrimaryAddress',24);
if ~isempty(s)
    fclose(s)
    clear s
end
pol=gpib('keysight',7,24); %We name the object "pol" as in polarization
fopen(pol);
pause(5);
fprintf(pol,'smua.reset()'); %%SMU Reset
fprintf(pol,'*IDN?');   %Status
fprintf(pol,'smua.source.func = smua.OUTPUT_DCVOLTS'); %DCVOLTS = Voltage Source Mode
fprintf(pol,'smua.source.levelv = 20');  % Voltage initial value
fprintf(pol,'smua.source.limiti = 1.5');   % Current limit
%--------------------------------------------------------------------------

%-----------------Inicialization of 2 DC sources Agilent 3645A ----------------
s=instrfind('PrimaryAddress',8);
if ~isempty(s)
    fclose(s)
    clear s
end
VmasK=gpib('agilent',7,8); %We name the object VmasK, that is, +K.
fopen(VmasK);
s=instrfind('PrimaryAddress',9);
if ~isempty(s)
    fclose(s)
    clear s
end
VmenosK=gpib('agilent',7,9); %We name the object VmenosK, that is, -K.
fopen(VmenosK);
%--------------------------------------------------------------------------

%------------------Setting voltages to have OR functionality-----------------
fprintf(VmasK,'VOLT %d',6.25);
fprintf(VmasK,'OUTP ON');
fprintf(pol,'smua.source.levelv = %d',5);
fprintf(pol, 'smua.source.output = smua.OUTPUT_ON');
fprintf(VmenosK,'VOLT %d',1.3);
fprintf(VmenosK,'OUTP ON'); 
%--------------------------------------------------------------------------

%----------------Inicialization LAN of Waveform gen. and O-scope---------------
vAddress = ['TCPIP0::10.0.7.161::inst0::INSTR'] %Waveform generator Keysight 33600A
vAddress1 = ['TCPIP0::10.0.7.249::inst0::INSTR'] %Oscilloscope Tektronix MDO3104
fgen = visa('ni',vAddress1)
fgen1 = visa('keysight',vAddress)
fgen.InputBufferSize = 10000;
fopen(fgen);
fopen(fgen1);
%--------------------------------------------------------------------------

%-------------------Setting input signals through waveform gen.------------------
fprintf (fgen1, '*RST');
% SOUR1=1kHz square signal
fprintf(fgen1,'SOUR1:FUNC SQU');
fprintf(fgen1,'SOURCE1:VOLT 2.5');
fprintf(fgen1,'SOURCE1:VOLT:OFFSET 1.25'); 
fprintf(fgen1,'SOUR1:FUNC:SQU:PER 1ms');
fprintf(fgen1,'SOUR1:FUNC:SQU:DCYC 50');
fprintf(fgen1,'OUTPUT1 ON');
% SOUR1=2kHz square signal
fprintf(fgen1,'SOUR2:FUNC SQU');
fprintf(fgen1,'SOURCE2:VOLT 2.5');
fprintf(fgen1,'SOURCE2:VOLT:OFFSET 1.25'); 
fprintf(fgen1,'SOUR2:FUNC:SQU:PER 0.5ms');
fprintf(fgen1,'SOUR2:FUNC:SQU:DCYC 50');
fprintf(fgen1,'OUTPUT2 ON');
%--------------------------------------------------------------------------

%-----------------------Capturing signal data from O-scope----------------------
pause(4);
fprintf(fgen, 'AUTOS EXECute');
pause(4);

% Set the |ByteOrder| to match the requirement of the instrument
myFgen.ByteOrder = 'littleEndian';

% Turn headers off, this makes parsing easier
fprintf(fgen, 'HEADER OFF');

% Get record length value
recordLength = query(fgen, 'HOR:RECO?');
fprintf(fgen,'DAT:SOU CH1');

% Ensure that the start and stop values for CURVE query match the full
% record length
fprintf(fgen, ['DATA:START 1;DATA:STOP ' recordLength]);

% Read YOFFSET to calculate the vertical values
yOffset = query(fgen, 'WFMO:YOFF?');

% Read YMULT to calculate the vertical values
verticalScale  = query(fgen,'WFMOUTPRE:YMULT?');
horizontalAxis = str2double(query(fgen,'WFMO:XZE?'));
horizontalInc = str2double(query(fgen,'WFMO:XIN?'));
long=str2double(recordLength);
x=horizontalAxis:horizontalInc:((long*horizontalInc)/2);

% Request 8 bit binary data on the CURVE query
fprintf(fgen, 'DATA:ENCDG RIBINARY;WIDTH 1');
fprintf(fgen,'DAT:SOU CH1');

% Request the CURVE
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 1 (U1)
y1 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);

%Repeat procces for other channels
fprintf(fgen,'DAT:SOU CH2');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 2 (U2)
y2 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH3');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 3 (OR Function)
y3 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH4');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 4 (nodo M)
y4 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);

%--------------------------------------------------------------------------

%------------------Setting voltages to have AND functionality-----------------
fprintf(VmasK,'VOLT %d',6.25);
fprintf(VmasK,'OUTP ON');
fprintf(VmenosK,'VOLT %d',3.75);
fprintf(VmenosK,'OUTP ON'); 
%--------------------------------------------------------------------------

%-----------------------Capturing signal data from O-scope----------------------
fprintf(fgen,'DAT:SOU CH1');

% Request the CURVE
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 1 (U1)
y1_1 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH2');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 2 (U2)
y2_1 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH3');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 3 (OR Function)
y3_1 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH4');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 4 (nodo M)
y4_1 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
%--------------------------------------------------------------------------

%------------------Setting voltages to have XOR functionality-----------------
fprintf(VmasK,'VOLT %d',3.75);
fprintf(VmasK,'OUTP ON');
fprintf(VmenosK,'VOLT %d',1.3);
fprintf(VmenosK,'OUTP ON'); 

fprintf(fgen,'DAT:SOU CH1');

% Request the CURVE
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 1 (U1)
y1_2 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH2');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 2 (U2)
y2_2 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH3');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type channel 3 (OR Function)
y3_2 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
fprintf(fgen,'DAT:SOU CH4');
fprintf(fgen, 'CURVE?');

% Read the captured data as 8-bit integer data type  channel 4 (nodo M)
y4_2 = (str2double(verticalScale) * (binblockread(fgen,'int8')))' + str2double(yOffset);
%--------------------------------------------------------------------------

%-------------------Off, clean and close------------------
% Turning off equipment
fprintf(fgen1,'OUTPUT1 OFF');
fprintf(fgen1,'OUTPUT2 OFF');
fprintf(VmasK,'OUTP OFF');
fprintf(VmenosK,'OUTP OFF');
fprintf(pol,'smua.source.output = smua.OUTPUT_OFF');

% Clean up Close the connection
fclose(fgen);
fclose(fgen1);
fclose(pol);
fclose(VmasK);
fclose(VmenosK);

% Clear the variables
clear fgen;
clear fgen1;
clear VmasK;
clear VmenosK;
clear pol;
%--------------------------------------------------------------------------

%-------------------Plot the acquired data and add axis labels------------------
% Logic Function OR
figure
plot(x(1:length(y1)),y1); 
xlabel('s'); 
ylabel('Volts');
title('Respuestas Celda Logica Bidimensional OR');
grid on;
hold on;
plot(x(1:length(y2)),y2); 
hold on;
plot(x(1:length(y3)),y3); 
hold on;
plot(x(1:length(y4)),y4); 

% Logic Function AND
figure
plot(x(1:length(y1_1)),y1_1); 
xlabel('s'); 
ylabel('Volts');
title('Respuestas Celda Logica Bidimensional AND');
grid on;
hold on;
plot(x(1:length(y2_1)),y2_1); 
hold on;
plot(x(1:length(y3_1)),y3_1); 
hold on;
plot(x(1:length(y4_1)),y4_1); 

% Logic Function XOR
figure
plot(x(1:length(y1_2)),y1_2); 
xlabel('s'); 
ylabel('Volts');
title('Respuestas Celda Logica Bidimensional XOR');
grid on;
hold on;
plot(x(1:length(y2_2)),y2_2); 
hold on;
plot(x(1:length(y3_2)),y3_2); 
hold on;
plot(x(1:length(y4_2)),y4_2); 
%--------------------------------------------------------------------------
