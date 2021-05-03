%Conv Streaming Latency Test
%Irwin Xavier
%23-01-2021

clear all, close all;

in_data = dsp.AudioFileReader('Filename','Fragments of Time.wav', 'SamplesPerFrame', 2048);    %Input File
h = audioread('click.wav');          %Impulse Response

deviceWriter = dsp.AudioFileWriter('output.wav', 'SampleRate', in_data.SampleRate);      %Output Writer

k = in_data.SamplesPerFrame;    %Input Partition Length
n = k;      %IR Partition Length
l = k + n - 1;      %Transform Size

conv_length = size(h, 1) + k - 1;    %Length of the convolved output

inblock = zeros(k, 1);  %Array to store input frame
outblock = zeros(conv_length, 1);   %Array to store the output frame

latency = [];   %Array storing all measured latency values

%Processing Loop
while ~isDone(in_data)
    inblock = in_data();        %Read input frame
    
    tic;    %Latency measuring starts

    y = cconv(inblock, h);

    outblock = outblock + y;    %Adding the convolved output to the output frame
    
    latency = [latency toc];    %Latency measuring stops and is stored in 'latency'

    deviceWriter(outblock(1 : k));  %Output first 'k' samples of outblock
    outblock = [outblock(k+1:end); zeros(k, 1)];    %Shift remaining samples to the start of the array
    
end

% Output the tail of the last convolved partition
for i = 1: k : length(outblock) - k
    deviceWriter(outblock(i : i + k - 1));
end

figure('Name', 'cconv()');
plot(latency);
title({'Latency' ['Min:' num2str(min(latency)*1000) 'ms  Max:' ...
    num2str(max(latency)*1000) 'ms  Avg:' num2str(mean(latency)*1000) 'ms']});

xlim([1 length(latency)]);
grid('on');
set(gcf,'Color','w');

release(in_data);
release(deviceWriter);