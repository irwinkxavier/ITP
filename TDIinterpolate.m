%TDIinterpolate.m
%Jonathan Moore
%Function made by Irwin Xavier
%10-02-2021

%Inputs:    TDIs    =   TDI matrix to be interpolated
%           int     =   Interpolation factor
%
%Example:
%TDIMat = TDIinterpolate(TDIs, 25)

function TDIMat = TDIinterpolate(TDIs, int)
    TDIMat = TDIs;
    NoSources = size(TDIMat,3);
    TDILVal = size(TDIMat,2);
    TDINoVal = size(TDIMat,1);
    
    Int = int + 1;
    
    % Generate parameters for interpolation
    x =  [1,Int]';
    xi = linspace(1,Int,Int)';
    
    TempMat = [];

    for i = 1:NoSources 
        Index = 1;
        for t = 1:TDINoVal
            IntMat = zeros(2, TDILVal);

            if t~= TDINoVal
                IntMat(1,:) = TDIMat(t,:,i);
                IntMat(2,:) = TDIMat(t+1,:,i);
            else
                IntMat(1,:) = TDIMat(t,:,i);
                IntMat(2,:) = TDIMat(1,:,i);
            end

            IntMat = interp1(x,IntMat,xi);
            TempMat(Index : Index+Int-1 ,:,i) = IntMat;
            Index = Index + Int-1;
        end  
    end


    TDIMat = TempMat((1:size(TempMat,1)-1),:,:);
end