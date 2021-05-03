%Cconv Dynamic DiSP
%Irwin Xavier
%06-02-2021

clear all, close all;

outputNo = 2;   %No. of Outputs
inputNo = 1;    %No. of Inputs (1 = mono, 2 = stereo, ...)
IxO = inputNo * outputNo; %No. of Inputs x No. of Outputs

TDI_index = 1;
updateRate = 5;   %TDI update rate in ms
overlaps = 3;

h = importdata('TDIMat.mat');          %Impulse Response
h = h(:, :, 1:IxO);     %Making library match no. of outputs

h = TDIinterpolate(h, 25);  %Interpolating the TDI matrix with arguments: (TDIs, Interpolation factor)

% MinPhaseEQ
for i = 1 : IxO
    for j = 1 : size(h,1)
        h(j, :, i) = TDIminPhaseEQ(8192, h(j, :, i));
    end
end

h = permute(h, [2 1 3]);    %Rearranging the TDI matrix to h(TDI Length, TDI No, Output No)
h = h./max(abs(h),[],1);    %Normalising TDIs

in_data = dsp.AudioFileReader('Filename','Neon.wav');    %Input File
frameSize = ceil((updateRate/1000)*in_data.SampleRate);      %Calculating the buffer size
in_data = dsp.AudioFileReader('Filename','Neon.wav', 'SamplesPerFrame', frameSize);

deviceWriter = dsp.AudioFileWriter('cconv.wav', 'SampleRate', in_data.SampleRate);      %Output Writer
% deviceWriter = audioDeviceWriter("SampleRate", in_data.SampleRate);      %Output Writer

k = frameSize;    %Input Partition Length
n = k;      %IR Partition Length
L = k + n - 1;      %Transform Size

overlap = ceil(frameSize/overlaps);

conv_length = size(h, 1) + k - 1;    %Length of the convolved output

inblock = zeros(round((3*frameSize)), 1);  %Array to store input frame
outblock = zeros(3*conv_length, IxO);   %Array to store the output frame

y = zeros(conv_length, 1);  %Init array to store the convolved output
xfft = zeros(L, 1);

% output = [];

latency = [];

inblock(1 : frameSize, :) = in_data()*0.6;
inblock(frameSize+1 : 2*frameSize, :) = in_data()*0.6;

%Processing Loop
while ~isDone(in_data)
    inblock(2*frameSize+1 : end, :) = in_data()*0.6;        %Read input frame
    
    tic
    
    OL_ind = 1;
        
    while OL_ind + overlap <= frameSize + 1
        
        if TDI_index == size(h,2)
            TDI_index = 1;
        end
        
        TDI_conv = h(:, TDI_index, 1:IxO);
        
        for i = 1 : IxO
            outblock(OL_ind : OL_ind + conv_length - 1, i) = ...
            outblock(OL_ind : OL_ind + conv_length - 1, i) + ...
            cconv(inblock(OL_ind : OL_ind + frameSize-1, 1),TDI_conv(:,i));
        end
        OL_ind = OL_ind + overlap;
        TDI_index = TDI_index + 1;
    end
    
    processed_audio = outblock(1:frameSize, :);
    
    latency = [latency toc];
    
    deviceWriter(processed_audio);
    
    inblock(1 : 2*frameSize, 1) = inblock(frameSize + 1 : end, 1);

    outblock(1 : end - frameSize, :) = outblock(frameSize + 1 : end, :);
end


figure('Name', 'cconv()');
plot(latency);
title({'Latency' ['Min:' num2str(min(latency)*1000) 'ms  Max:' num2str(max(latency)*1000) 'ms  Avg:' num2str(mean(latency)*1000) 'ms']});
xlim([1 length(latency)]);
grid('on');
set(gcf,'Color','w');

release(in_data);
release(deviceWriter);