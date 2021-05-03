% TDIminPhaseEQ.m
% Adam Hill
% March 1, 2017
%
% Function to apply minuimum phase EQ to a TDI.
%
% Inputs:   m       =   TDI length (samples)
%           sMode   =   type of TDI (don't apply EQ to allpass)
%           TDI     =   single TDI for equalization
% Output:   TDI     =   single, equalized TDI

function TDI = TDIminPhaseEQ(m, TDI)

% apply minimum phase equalization to the TDIs
frTDI = fft(TDI(1 : m));
frTDI = frTDI./exp(conj(hilbert(log(abs(frTDI)))));
TDI = real(ifft(frTDI));
