%Overlap Save Uniform Partition Static DiSP
%Irwin Xavier
%02-02-2021

clear all, close all;

outputNo = 1;   %No. of Outputs
inputNo = 1;    %No. of Inputs (1 = mono, 2 = stereo, ...)
IxO = inputNo * outputNo; %No. of Inputs x No. of Outputs

in_data = dsp.AudioFileReader('Filename','Fragments of Time.wav', 'SamplesPerFrame', 4410);    %Input File
h = importdata('TDIMat.mat');          %Impulse Response

h = permute(h, [2 1 3]);    %Rearranging the TDI matrix to h(TDI Length, TDI No, Output No)
h = h(:, :, 1:IxO);     %Making library match no. of outputs
h = h./max(abs(h),[],1);    %Normalising TDIs

deviceWriter = dsp.AudioFileWriter('overlap-save static.wav', 'SampleRate', in_data.SampleRate);      %Output Writer
% deviceWriter = audioDeviceWriter("SampleRate", in_data.SampleRate);      %Output Writer

k = in_data.SamplesPerFrame;    %Input Partition Length
n = k;      %IR Partition Length
L = k + n - 1;      %Transform Size

h = [h; zeros(mod(-mod(length(h), k), k), size(h, 2), size(h, 3))];   %Zero-padding the IR so that it's divisible by k

conv_length = (ceil(size(h,1)/n))*k;    %Length of the convolved output

inblock = zeros(L, IxO);  %Array to store input frame
outblock = zeros(conv_length, IxO);   %Array to store the output frame

y = zeros(conv_length, 1);  %Init array to store the convolved output
xfft = zeros(L, 1);

% output = [];

latency = [];

%Processing Loop
while ~isDone(in_data)
    inblock(k : end, :) = repmat(in_data(), 1, outputNo);   %Read input frame
    
    tic
    
    xfft = fft(inblock, L, 1);     %Taking FFT of the input frame
    y = zeros(conv_length, IxO);  %Init array to store the convolved output

    for a = 1 : k : size(h, 1)   %Looping through IR and convolving with inblock

        sub_h = squeeze(h(a : a + k - 1, 1 , :));    %Creating the IR partition
        sub_y = ifft(fft(sub_h, L, 1) .* xfft, L, 1);    %Convolving inblock with the IR partition
        
        %Overlap-Save to get the convolved output
        y(a : a + k - 1, :) = sub_y(n : end, :);
    end

    outblock = outblock + y;    %Adding the convolved output to the output frame

    latency = [latency toc];

    deviceWriter(outblock(1 : k, :));  %Output first 'k' samples of outblock
%     output = [output; outblock(1 : k, :)];  %Output first 'k' samples of outblock
    outblock = [outblock(k+1:end, :); zeros(k, IxO)];    %Shift remaining samples to the start of the array
    inblock = [inblock(k + 1 : end, :); zeros(k, IxO)];  %Shift last 'n - 1' samples to the start of the array
end
   
%Output the tail of the last convolved partition
for i = 1: k : size(outblock, 1) - k
    deviceWriter(outblock(i : i + k - 1, :));
%     output = [output; outblock(i : i + k - 1, :)];
end

figure('Name', 'Overlap Save Uniform Partition');
plot(latency);
title({'Latency' ['Min:' num2str(min(latency)*1000) 'ms  Max:' num2str(max(latency)*1000) 'ms  Avg:' num2str(mean(latency)*1000) 'ms']});
xlim([1 length(latency)]);
grid('on');
set(gcf,'Color','w');

release(in_data);
release(deviceWriter);