%Overlap Add Uniform Partition Streaming Profiled
%Used to profile the program
%Irwin Xavier
%31-01-2021

clear all, close all;

in_data = dsp.AudioFileReader('Filename','Fragments of Time.wav', 'SamplesPerFrame', 2048);    %Input File
h = audioread('click.wav');          %Impulse Response

deviceWriter = dsp.AudioFileWriter('output.wav', 'SampleRate', in_data.SampleRate);      %Output Writer

k = in_data.SamplesPerFrame;    %Input Partition Length
n = k;      %IR Partition Length
l = k + n - 1;      %Transform Size

h = [h; zeros(mod(-mod(length(h), k), k),1)];   %Zero-padding the IR so that it's divisible by k

conv_length = (ceil(length(h)/n) + 1)*k - 1;    %Length of the convolved output

inblock = zeros(k, 1);  %Array to store input frame
outblock = zeros(conv_length, 1);   %Array to store the output frame
y = zeros(conv_length, 1);  %Init array to store the convolved output
xfft = zeros(l, 1);

latency = [];

% % profile on
%Processing Loop
while ~isDone(in_data)
    inblock = in_data();        %Read input frame
    
    tic
    
    xfft = fft(inblock, l);     %Taking FFT of the input frame
    
    
    for a = 1 : k : size(h, 1)   %Looping through IR and convolving with inblock
        
        sub_h = h(a : a + k - 1);   %Creating the IR partition
        sub_y = ifft(fft(sub_h, l) .* xfft);    %Convolving inblock with the IR partition
        %Overlap-Add to get the convolved output
        if(a == 1)
            y(1 : l) = sub_y;
        else
            y(a : a + l - 1) = y(a : a + l - 1) + sub_y(1 : end);
        end
    end
    
    outblock = outblock + y;    %Adding the convolved output to the output frame
    
    latency = [latency toc];
    
    deviceWriter(outblock(1 : k));  %Output first 'k' samples of outblock
    outblock = [outblock(k+1:end); zeros(k, 1)];    %Shift remaining samples to the start of the array
end

%Output the tail of the last convolved partition
for i = 1: k : length(outblock) - k
    deviceWriter(outblock(i : i + k - 1));
end

figure('Name', 'Overlap Add Uniform Partition');
plot(latency);
title({'Latency' ['Min:' num2str(min(latency)*1000) 'ms  Max:' num2str(max(latency)*1000) 'ms  Avg:' num2str(mean(latency)*1000) 'ms']});
xlim([1 length(latency)]);
grid('on');
set(gcf,'Color','w');

release(in_data);
release(deviceWriter);