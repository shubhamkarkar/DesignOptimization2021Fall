%% INTRODUCTION 
% NAME: SHUBHAM ASHOK KARKAR
% ASU ID: 1223319344 
% DESIGN OPTIMIZATION 
% PROJECT - 3

%%%% AN 88 LINE TOPOLOGY OPTIMIZATION CODE Nov, 2010 %%%% 
function top88(nelx,nely,volfrac,penal,rmin,ft)
nelx = 110;
nely = 90;
volfrac = 0.5;
penal = 6;
rmin = 3;
ft = 2;

%% MATERIAL PROPERTIES ARE AS:
E0 = 210; 
Emin = 1e-9; 
nu = 0.3; 


%% PREPARATION OF FINITE ELEMENT ANALYSIS: 

A11 = [12 3 -6 -3; 
    3 12 3 0; 
    -6 3 12 -3; 
    -3 0 -3 12]; 

A12 = [-6 -3 0 3; 
    -3 -6 -3 -6; 
    0 -3 -6 3; 
    3 -6 3 -6]; 

B11 = [-4 3 -2 9; 
    3 -4 -9 4; 
    -2 -9 -4 -3; 
    9 4 -3 -4]; 

B12 = [ 2 -3 4 -9; 
    -3 2 9 -2; 
    4 9 2 3; 
    -9 -2 3 2];

KE = 1/(1-nu^2)/24*([A11 A12; A12' A11] + nu*[B11 B12; B12' B11]);
fprintf("nelx = %d \n",nelx);
nodenrs = reshape(1:(1+nelx)*(1+nely),1+nely,1+nelx); 
edofVec = reshape(2*nodenrs(1:end-1,1:end-1)+1,nelx*nely,1); 
edofMat = repmat(edofVec,1,8) + repmat([0 1 2*nely+[2 3 0 1] -2 -1],nelx*nely,1); 

iK = reshape(kron(edofMat,ones(8,1))',64*nelx*nely,1); 
jK = reshape(kron(edofMat,ones(1,8))',64*nelx*nely,1); 

% DEFINING LOADS AND SUPPORTS (HALF MBB-BEAM): 
F = sparse(2,1,-1,2*(nely+1)*(nelx+1),1); 
U = zeros(2*(nely+1)*(nelx+1),1); 
fixeddofs = union([1:2:2*(nely+1)],[2*(nelx+1)*(nely+1)]); 
alldofs = [1:2*(nely+1)*(nelx+1)]; 
freedofs = setdiff(alldofs,fixeddofs);

%% PREPARING THE GAUSSIAN FILTER 
iH = ones(nelx*nely*(2*(ceil(rmin)-1)+1)^2,1); 
jH = ones(size(iH)); 
sH = zeros(size(iH)); 
k = 0; 
for i1 = 1:nelx 
    for j1 = 1:nely 
        e1 = (i1-1)*nely + j1; 
        for i2 = max(i1-(ceil(rmin)-1),1):min(i1+(ceil(rmin)-1),nelx) 
            for j2 = max(j1-(ceil(rmin)-1),1):min(j1+(ceil(rmin)-1),nely) 
                e2 = (i2-1)*nely+j2; 
                k = k+1; 
                iH(k) = e1; 
                jH(k) = e2;
                sH(k) = max(0,rmin-sqrt((i1-i2)^2+(j1-j2)^2)); 
            end 
        end 
    end 
end 

H = sparse(iH,jH,sH); 
Hs = sum(H,2);

%% INITIALIZING THE ITERATIONS: 
x = repmat(volfrac,nely,nelx); 
xPhys = x; 
loop = 0; 
change = 1;

%% START ITERATION: 
while change > 0.01 
    loop = loop + 1;

%% FINITE ELEMENT-ANALYSIS: 
    sK = reshape(KE(:)(Emin + xPhys(:)'.^penal(E0-Emin)),64*nelx*nely,1);
    K = sparse(iK,jK,sK);
    K = (K+K')/2
    U(freedofs) = K(freedofs,freedofs)\F(freedofs);

%% OBJECTIVE FUNCTION AND SENSITIVITY ANALYSIS: 
    ce = reshape(sum((U(edofMat)*KE).*U(edofMat),2),nely,nelx); 
    % element-wise strain energy 
    c = sum(sum((Emin + xPhys.^penal*(E0-Emin)).*ce)); 
    % total strain energy 
    dc = -penal*(E0-Emin)*xPhys.^(penal-1).*ce; 
    % design sensitivity 
    dv = ones(nely,nelx);

%% FILTERING/MODIFICATION OF SENSITIVITIES: 
    if ft == 1 
        dc(:) = H*(x(:).dc(:))./Hs./max(1e-3,x(:)); 
    elseif ft == 2 
        dc(:) = H*(dc(:)./Hs); 
        dv(:) = H*(dv(:)./Hs); 
    end

%% OPTIMALITY CRITERIA UPDATE OF DESIGN VARIABLES AND PHYSICAL DENSITIES: 
    r_1 = 0; 
    r_2 = 1e9; 
    m = 0.2; 
    while (r_2 - r_1)/(r_1 + r_2) > 1e-3 
        r_m = 0.5*(r_2 + r_1);
        xnew = max(0, max(0, max(x-m, min(1, min(x + m, x.*sqrt(-dc./dv/r_m))))));
        if ft==1
            xPhys = xnew;
        elseif ft == 2
            xPhys(:) = (H*xnew(:))./Hs;
        end
        if sum(xPhys(:)) > volfrac*nelx*nely
            r_1 = r_m;
        else 
            r_2 = r_m;
        end
    end 
    change = max(abs(xnew(:)-x(:))); 
    x = xnew;

%% PRINT RESULTS: 
    fprintf(' It.:%5i Obj.:%11.4f Vol.:%7.3f ch.:%7.3f\n',loop,c, ...
        mean(xPhys(:)),change);

%% PLOT DENSITIES: 
    colormap(gray); 
    imagesc(1-xPhys); 
    caxis([0 1]); 
    axis equal; 
    axis off; 
    drawnow; 
end