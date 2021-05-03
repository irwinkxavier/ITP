%Overlap Add Non Uniform Partition Streaming Profiled
%Irwin Xavier
%31-01-2021

clear all, close all;

in_data = dsp.AudioFileReader('Filename','Fragments of Time.wav', 'SamplesPerFrame', 2048);     %Input File
[h, Fsh] = audioread('click.wav');          %Impulse Response

deviceWriter = dsp.AudioFileWriter('output.wav', "SampleRate",in_data.SampleRate);      %Output Writer

k = in_data.SamplesPerFrame;    %Input Partition Length
n = k;      %IR Partition Length
l = k + n - 1;      %Transform Size

%IR Processing
hCount = 0;     %Init varaible storing no. of IR partitions
%Splitting IR to partitions of increasing length
i = 1;
while(i < length(h))
    i = i + hCount * k;
    hCount = hCount + 1;
    j = i + n - 1;
    if(length(h(i : end)) <= n)
        eval(['h' num2str(hCount) ' = h(i : end);']);   %Zero-padding the last partition if needed
        eval(['hfft' num2str(hCount) ' = fft(h' num2str(hCount) ', l);']);    %Calculating FFT of the IR partition
        break
    else
        eval(['h' num2str(hCount) ' = h(i : j);']);     %Splitting IR to partitions of length k
        eval(['hfft' num2str(hCount) ' = fft(h' num2str(hCount) ', l);']);    %Calculating FFT of the IR partition
    end
    
    n = 2 * n;      %Doubling partition size
    l = k + n - 1;  %Updating transform size
end


conv_length = l + n - k;    %Length of the convolved output

inblock = zeros(k, 1);  %Array to store input frame
outblock = zeros(conv_length, 1);   %Array to store output frame

latency = [];

%profile on
%Processing Loop
while ~isDone(in_data)
    inblock = in_data();    %Read input frame
    
    tic
    
    for a = 1 : hCount
        eval(['y' num2str(a) '= ifft(hfft' num2str(a) ' .* fft(inblock, length(hfft' num2str(a) ')));']);    %Convolving signal partiton with all IR partitions
        %Overlap-Add to get the convolved output of each signal partition
        if(a == 1)
            y = y1;
        else
            eval(['y(end - k + 2 : end) = y(end - k + 2 : end) + y' num2str(a) '(1 : k - 1);']);
            eval(['y = [y; y' num2str(a) '(k : end)];']);
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

figure('Name', 'Overlap Add Non Uniform Partition');
plot(latency);
title({'Latency' ['Min:' num2str(min(latency)*1000) 'ms  Max:' num2str(max(latency)*1000) 'ms  Avg:' num2str(mean(latency)*1000) 'ms']});
xlim([1 length(latency)]);
grid('on');
set(gcf,'Color','w');

release(in_data);
release(deviceWriter);