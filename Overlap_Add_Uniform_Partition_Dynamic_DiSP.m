%Overlap Add Uniform Partition Dynamiic DiSP
%Irwin Xavier
%06-02-2021

clear all, close all;

outputNo = 1;   %No. of Outputs
inputNo = 1;    %No. of Inputs (1 = mono, 2 = stereo, ...)
IxO = inputNo * outputNo; %No. of Inputs x No. of Outputs

TDI_index = 1;
updateRate = 100;   %TDI update rate in ms

in_data = dsp.AudioFileReader('Filename','Fragments of Time.wav');    %Input File
frameSize = ceil((updateRate/1000)*in_data.SampleRate);      %Calculating the buffer size
in_data = dsp.AudioFileReader('Filename','Fragments of Time.wav', 'SamplesPerFrame', frameSize);
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

% deviceWriter = dsp.AudioFileWriter('overlap-add dynamic.wav', 'SampleRate', in_data.SampleRate);      %Output Writer
deviceWriter = audioDeviceWriter("SampleRate", in_data.SampleRate);      %Output Writer

k = in_data.SamplesPerFrame;    %Input Partition Length
n = k;      %IR Partition Length
L = k + n - 1;      %Transform Size

h = [h; zeros(mod(-mod(length(h), k), k), size(h, 2), size(h, 3))];   %Zero-padding the IR so that it's divisible by k

conv_length = (ceil(size(h,1)/n) + 1)*k - 1;    %Length of the convolved output

inblock = zeros(k, IxO);  %Array to store input frame
outblock = zeros(conv_length, IxO);   %Array to store the output frame

y = zeros(conv_length, 1);  %Init array to store the convolved output
xfft = zeros(L, 1);

% output = [];

latency = [];


%Processing Loop
while ~isDone(in_data)
    inblock = repmat(in_data(), 1, outputNo);        %Read input frame
    
    tic
    
    if TDI_index == size(h,2)
        TDI_index = 1;
    end
    
    xfft = fft(inblock, L, 1);     %Taking FFT of the input frame
    y = zeros(conv_length, IxO);  %Init array to store the convolved output

    for a = 1 : k : size(h, 1)   %Looping through IR and convolving with inblock

        sub_h = squeeze(h(a : a + k - 1, TDI_index , :));    %Creating the IR partition
        sub_y = ifft(fft(sub_h, L, 1) .* xfft, L, 1);    %Convolving inblock with the IR partition
        %Overlap-Add to get the convolved output
         if(a == 1)
            y(1 : L, :) = sub_y;
        else
            y(a : a + L - 1, :) = y(a : a + L - 1, :) + sub_y(1 : end, :);
        end
    end

    outblock = outblock + y;    %Adding the convolved output to the output frame

    latency = [latency toc];

    deviceWriter(outblock(1 : k, :));  %Output first 'k' samples of outblock
%     output = [output; outblock(1 : k, :)];  %Output first 'k' samples of outblock
    outblock = [outblock(k+1:end, :); zeros(k, IxO)];    %Shift remaining samples to the start of the array
    TDI_index = TDI_index + 1;
end

%Output the tail of the last convolved partition
for i = 1: k : size(outblock, 1) - k
    deviceWriter(outblock(i : i + k - 1, :));
%     output = [output; outblock(i : i + k - 1, :)];
end

figure('Name', 'Overlap Add Uniform Partition');
plot(latency);
title({'Latency' ['Min:' num2str(min(latency)*1000) 'ms  Max:' num2str(max(latency)*1000) 'ms  Avg:' num2str(mean(latency)*1000) 'ms']});
xlim([1 length(latency)]);
grid('on');
set(gcf,'Color','w');

release(in_data);
release(deviceWriter);