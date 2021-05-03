%Overlap Save Non Uniform Partition Streaming Profiled
%Irwin Xavier
%31-01-2021

clear all, close all;

in_data = dsp.AudioFileReader('Filename','Fragments of Time.wav', 'SamplesPerFrame', 2048); %Input File
[h, Fsh] = audioread('click.wav');          %Impulse Response

deviceWriter = dsp.AudioFileWriter('output.wav', "SampleRate",in_data.SampleRate);  %Output Writer

k = in_data.SamplesPerFrame;    %Input Partition Length
n = k;      %IR Partition Length
L = k + n - 1;      %Transform Size

%IR Processing
hCount = 0;
%Splitting IR to partitions of increasing length
i = 1;
while(i < length(h))
    hCount = hCount + 1;
    j = i + n - 1;
    if(length(h(i : end)) <= n)
        eval(['h' num2str(hCount) ' = [h(i : end); zeros(n - length(h(i : end)), 1)];']);   %Creating the last partition
    else
        eval(['h' num2str(hCount) ' = h(i : j);']);     %Splitting IR to partitions of increasing length
    end
    
    if(hCount == 1)
        eval(['hfft' num2str(hCount) ' = fft(h' num2str(hCount) ', 4 * n);']);    %Calculating FFT of the first IR partition with transform size '4n'
    end
    
    i = j + 1;  %Setting the first sample of the next partition
    n = 2 * n;  %Setting the next partition length to twice the current length
end

conv_length = n + 1;    %Length of the convolved output

inblock = zeros(L, 1);  %Array to store input frame
sub_h = zeros(k, 1);    %Array to store IR sub-partition
outblock = zeros(conv_length, 1);   %Array to store output frame
inblock_h1 = zeros(4*k,1);

latency = [];

%profile on
%Processing Loop
while ~isDone(in_data)
    inblock(k : end) = in_data();   %Read input frame
    
    tic;
    
    %Convolving input partition with IR partitions
    for c = 1 : hCount
        if(c == 1)
            inblock_h1 = ifft(hfft1 .* fft(inblock, 4 * k));    %Convolving signal partition with first IR partition
        
        %Using Uniform Partition Overlap-Save Convolution to convolve with all IR partitions except the first partition
        else
            sub_inblock = zeros(L, 1);  %Init array to store overlapped frames of inblock
            eval(['sub_outblock = zeros(length(h' num2str(c) '), 1);']);    %Init array to store convolved output of sub_inblock
            eval(['inblock_h' num2str(c) ' = zeros(length(sub_outblock) + 2 * k, 1);']);    %Init array to store convolved output of inblock
            
            for a = 1 : k : length(inblock)     %Looping through inblock
                %Creating overlapped frames of inblock
                if length(inblock(a : end)) > k
                    sub_inblock(k : end) = inblock(a : a + k - 1);
                else
                    sub_inblock(k : end) = [inblock(a : end); zeros(k - length(inblock(a : end)), 1)];  %Creating the last frame
                end
                sub_inblockFFT = fft(sub_inblock, L);   %Taking FFT of sub_inblock
                
                %Convolving sub_outblock with IR partition
                for b = 1 : k : eval(['length(h' num2str(c) ')'])   %Looping through the IR Partition
                    eval(['sub_h = h' num2str(c) '(b : b + k - 1);']);  %Creating a IR sub-partition
                    %Convolving and Overlap-Save the output to sub_outblock
                    sub_x = ifft(sub_inblockFFT .* fft(sub_h, L));
                    sub_outblock(b : b + k - 1) = sub_x(L - k + 1 : end);
                end
                
                %Overlap-Add to get inblock's convolved output
                if a ~= 1
                    eval(['inblock_h' num2str(c) '(k + 1 : end - k) = inblock_h' num2str(c) '(k + 1 : end - k) +  sub_outblock(1 : end);']);
                else
                    eval(['inblock_h' num2str(c) '(1 : length(sub_outblock)) = sub_outblock;']);
                end
                
                sub_inblock = [sub_inblock(end - k + 2 : end); zeros(k, 1)];    %Shift last 'k - 1' samples to the start of the array
            end
            
            %Convolving the last sub_inblock frame
            sub_inblockFFT = fft(sub_inblock, L);
                for b = 1 : k : eval(['length(h' num2str(c) ')'])
                    eval(['sub_h = h' num2str(c) '(b : b + k - 1);']);
                    sub_x = ifft(sub_inblockFFT .* fft(sub_h, L));
                    sub_outblock(b : b + k - 1) = sub_x(L - k + 1 : end);
                end
            eval(['inblock_h' num2str(c) '(2*k + 1 : end) = inblock_h' num2str(c) '(2*k + 1 : end) +  sub_outblock(1 : end);']);
        end
    end
    
    %Overlap-Add to get final output
    y = inblock_h1(k : end);
    y(2 : end) = y(2 : end) + inblock_h2(1 : length(y(2 : end)));
    y = [y; inblock_h2(end - k + 1 : end)];
    for c = 3 : hCount
        eval(['y(end - 2*k + 1 : end) = y(end - 2*k + 1 : end) + inblock_h' num2str(c) '(1 : 2*k);']);
        eval(['y = [y; inblock_h' num2str(c) '(2*k + 1 : end)];']);
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

figure('Name', 'Overlap Save Non Uniform Partition');
plot(latency());
title({'Latency' ['Min:' num2str(min(latency)*1000) 'ms  Max:' num2str(max(latency)*1000) 'ms  Avg:' num2str(mean(latency)*1000) 'ms']});
xlim([1 length(latency)]);
grid('on');
set(gcf,'Color','w');

release(in_data);
release(deviceWriter);