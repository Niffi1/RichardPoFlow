function [  ] = Richard2Dv28_ScriptDemo()
% 2D Richards equation with Dirichlet/Neumann boundary condition 
% H based Richards equation
%
% This is a self-contained Script DEMO function that requires no other
% functions and data.
% This Code is meant to be tutorial purpose and thus may suffer from
% computational inefficiency and other issues.
%
% Discretize method:  1st order Finite difference solution on space and time.
% Nonlinear solution: Picards iteration.
% Mesh: a CUSTOM defined (z,x) rectangle based mesh.
% 
% BC type    N: normal (N is natural number)
%  		  	 0: Dirichlet BC
%		  	-N: Neuman BC 
%
% First edition: Weix 20/04/2017 
% Version IV: missing
% Version 1.40: Weix 12/04/2017 improve the flexibilities (for different BC and domain) by
%                               introducing the indexMatrix and use 0 to indicate D-BC.
% Version 1.50: Weix 13/04/2017 Vectorization
% Version 2.70: Weix 24/04/2017 add Updata Neumann boundary condition. 
%               Update the way  points are accessed. (see Richard1Dv27 for more history)
% Version 2.72: Weix 25/04/2017 improve organization
% Version 2.8:  Weix 02/05/2017 Use class definition to seperate code.
%               Weix 26/07/2017 update documentation.
%% 
tic
%% Setup
% Spatial setup
lengthZ=40;
deltaZ=4;
nZ=lengthZ/deltaZ+1;

lengthX=40;
deltaX=4;
nX=lengthX/deltaX+1;

% Temporal setup
lengthTime=300;
deltaTime=1;
nTime=lengthTime/deltaTime;

% Iteration solver setup
nMaxIteration=100;
miniIteError=1;


%% Initialize mesh
% [X,Z] = meshgrid(0:deltaX:lengthX,0:deltaZ:lengthZ);
[Z,X] = ndgrid(0:deltaZ:lengthZ,0:deltaX:lengthX);

mesh.lengthZ=lengthZ;
mesh.deltaZ=deltaZ;
mesh.nZ=nZ;

mesh.lengthX=lengthX;
mesh.deltaX=deltaX;
mesh.nX=nX;

mesh.nodeIndex=zeros(nZ,nX);

mesh.X=X;
mesh.Z=Z;

%%  Permeability field
lengthcale=100;     
%larger number means less stochastic (more correlation as one zooms in the 
%field) field. Thus gives smoother result.
scale=0.005;
% overall magnitude of the permeability field. decide the changing speed.

Ks=permeabilityField([Z(:),X(:)],lengthcale)*scale;
Ks=reshape(Ks,nZ,nX);
mesh.Ks=Ks;

%% DBC for top&bottom and NBC for left&right
mesh.nodeIndex(2:end-1,1:end)=reshape(uint32(1:(nZ-2)*(nX)), (nZ-2), (nX));     
nodeInFieldIndex=find(mesh.nodeIndex);

mesh.nodeIndex(:,1)=-mesh.nodeIndex(:,1);         %munus value for NBC
mesh.nodeIndex(:,end)=-mesh.nodeIndex(:,end);     %munus value for NBC
    

%% initial conditions and boundary value
H_init=ones(nZ,nX)*-61.5;               %value for all initial points

H_init(1,1:end)=ones(nX,1)*-20.7;       %value for top DBC
H_init(end,1:end)=ones(nX,1)*-61.5;     %value for bottom DBC

%% update mesh up to date to BC and initial condition
mesh.nNode=length(mesh.nodeIndex(mesh.nodeIndex~=0));


%% MAIN 
% using picard iteration to solve Richards equation
mesh.H=H_init;
tic                         %set timer 
for t=1:nTime

    previousH= mesh.H;      %preserved for time discretize
    for k=1:nMaxIteration   %Picards iteration
        
        H0=mesh.H;          %preserved for iteration error measure
        
        [A,B] = PicardFdm(mesh,deltaTime,previousH);
        hFree=A\(-B);
        
        mesh.H(nodeInFieldIndex)=hFree;   %update h(pressure head) 
             %REMEMBER To pay extra attention to ordering when using other indexing order
             % H(find(nodeIndex))=hFree;   
        
        sseIte=sum((mesh.H(:)-H0(:)).^2);
        if sqrt(sseIte)<miniIteError 
            break 
        end
        
    end    
    hRecord(:,:,t)=mesh.H;      %record h field time series
    
end

computerTime=toc

%% Plot 
figure(1)
    subplot(2,2,1)
    pcolor(mesh.X,mesh.Z,mesh.Ks)
    shading interp;
    colormap jet;
    title(sprintf('Permeability field'))

    subplot(2,2,2)
    pcolor(mesh.X,mesh.Z,hRecord(:,:,end))
    shading interp;
    colormap jet;
    title(sprintf('End time pressure'))

    for t=1:1:nTime
        subplot(2,2,3)
        contourf(mesh.X,mesh.Z,hRecord(:,:,t))
%         colormap(hot)
        shading interp;
        colorbar
    %     shading interp;
        title(sprintf('pressure time=%i',t))

        subplot(2,2,4)
        contourf(mesh.X,mesh.Z,theataFunc(hRecord(:,:,t)))
%         colormap(hot)
        shading interp;
        colorbar
    %     shading interp;

        title(sprintf('saturation time=%i',t))
        drawnow
        frame(t)=getframe;

    end

figure(2)
    surf(H_init);
    for t=1:nTime
        surf(X,Z,hRecord(:,:,t))
    %     shading interp;
        title(sprintf('time=%i',t))
        drawnow
        frame(t)=getframe;

    end


end

%% sub functions
 function [A,B] = PicardFdm(mesh,deltaTime,previousH)
 % Function used to discretize Richards equation FDM on time and space.
 % It accept Dirichlet BC (0) and homogeneous Neuman BC (miuns R).
 
        A=speye(length(mesh.nNode));
        B=zeros(length(mesh.nNode),1);
        
        tic
        C=theataDifFunc(mesh.H);
%         K=kFunc(H);
        K=kFieldFunc(mesh.H,mesh.Ks);
        nonlieanrTime=toc
        
        tic
        for iZ=1:mesh.nZ
            for iX=1:mesh.nX
            
                indexCenter=mesh.nodeIndex(iZ,iX);
                
                switch sign(indexCenter)                    
                    case 0      %is NOT a free node with index number
                        continue
                    case -1     %TODO this is wrong As NBC location (0 flux direction) need to be found.

                        if iZ==1        % a top NBC point               
                           indexUp=0;                             
                           %Forge a up ghost point 
                           nbcValue=0;  
                           hUp=  mesh.H(iZ+1,iX)- 2* mesh.deltaZ* nbcValue; %TODO NBCvalue free control

                           kHalfDown =(K(iZ,iX)+K(iZ+1,iX))/2;                         
                           kHalfUp=kHalfDown;  %Vitual K 

                        else
                           indexUp=mesh.nodeIndex(iZ-1,iX);
                           kHalfUp  =(K(iZ,iX)+K(iZ-1,iX))/2; 
                           hUp=mesh.H(iZ-1,iX);
                        end

                        if iZ==mesh.nZ       %if a bottom NBC point             
                           indexDown=0;                             
                           %Forge a up ghost point 
                           nbcValue=0;  
                           hDown=  mesh.H(iZ-1,iX)- 2* mesh.deltaZ* nbcValue; %TODO NBCvalue free control

                           kHalfUp   =(K(iZ,iX)+K(iZ-1,iX))/2;
                           kHalfDown =kHalfUp;       %Vitual K    
                        else 
                           indexDown=mesh.nodeIndex(iZ+1,iX);
                           kHalfDown  =(K(iZ,iX)+K(iZ+1,iX))/2; 
                           hDown=mesh.H(iZ+1,iX);  
                        end

                        if iX==1        % a left NBC point               
                           indexLeft=0;                             
                           %Forge a up ghost point 
                           nbcValue=0;  
                           hLeft=  mesh.H(iZ,iX+1)- 2* mesh.deltaX* nbcValue; %TODO NBCvalue free control

                           kHalfRight =(K(iZ,iX)+K(iZ,iX+1))/2;                         
                           kHalfLeft=kHalfRight; %Vitual K  

                        else
                           indexLeft=mesh.nodeIndex(iZ,iX-1);
                           kHalfLeft  =(K(iZ,iX)+K(iZ,iX-1))/2; 
                           hLeft=mesh.H(iZ,iX-1);
                        end

                        if iX==mesh.nX        % a right NBC point               
                           indexRight=0;                             
                           %Forge a up ghost point 
                           nbcValue=0;  
                           hRight=  mesh.H(iZ,iX-1)- 2* mesh.deltaX* nbcValue; %TODO NBCvalue free control

                           kHalfLeft =(K(iZ,iX)+K(iZ,iX-1))/2;                         
                           kHalfRight=kHalfLeft; %Vitual K  

                        else
                           indexRight=mesh.nodeIndex(iZ,iX+1);
                           kHalfRight  =(K(iZ,iX)+K(iZ,iX+1))/2; 
                           hRight=mesh.H(iZ,iX+1);
                        end
                    case 1      % if Normal inner point
                    
                        indexUp=mesh.nodeIndex(iZ-1,iX);
                        indexDown=mesh.nodeIndex(iZ+1,iX);
                        indexLeft=mesh.nodeIndex(iZ,iX-1);
                        indexRight=mesh.nodeIndex(iZ,iX+1);

                        hUp=mesh.H(iZ-1,iX);
                        hDown=mesh.H(iZ+1,iX);
                        hLeft=mesh.H(iZ,iX-1);
                        hRight=mesh.H(iZ,iX+1);

                        kHalfUp   =(K(iZ,iX)+K(iZ-1,iX))/2;
                        kHalfDown =(K(iZ,iX)+K(iZ+1,iX))/2;
                        kHalfLeft =(K(iZ,iX)+K(iZ,iX-1))/2;
                        kHalfRight=(K(iZ,iX)+K(iZ,iX+1))/2;
                    otherwise 
                        error('unknown node type');
    
                end   
                
                cCenter=C(iZ,1);   

                wUp   = -kHalfUp  ./mesh.deltaZ^2;
                wDown = -kHalfDown./mesh.deltaZ^2;
                wLeft = -kHalfLeft./mesh.deltaX^2;
                wRight= -kHalfRight./mesh.deltaX^2;

                wCenter=cCenter/deltaTime-wUp-wDown-wLeft-wRight;

                b=(kHalfDown-kHalfUp)/mesh.deltaZ-previousH(iZ,iX)*cCenter/deltaTime;

                %modify if neighbours are DBC points           
                b=b + wUp   * hUp   * ~indexUp...
                    + wDown * hDown * ~indexDown...
                    + wLeft * hLeft * ~indexLeft...
                    + wRight * hRight * ~indexRight;


                indexUp=abs(indexUp);
                indexDown=abs(indexDown);
                indexLeft=abs(indexLeft);
                indexRight=abs(indexRight);
                indexCenter=abs(indexCenter);

                if indexUp>0 A(indexCenter,indexUp)=wUp; end
                if indexDown>0 A(indexCenter,indexDown)=wDown; end
                if indexLeft>0 A(indexCenter,indexLeft)=wLeft; end
                if indexRight>0 A(indexCenter,indexRight)=wRight; end

                A(indexCenter,indexCenter)=wCenter;
                B(indexCenter,1)=b;
                   
            end
        end
        assembleTime=toc
end







function [A,b]=RichardsPicard(mesh)
%This is supposed to be a linear operator on the mesh (provided values) to assemble Ax+b=0 
% it would call [weight]=weightGen(h,hL,hR,hT,hB) function onece assign all
% neighbours.
    A=speye(length(mesh.nNode));
    B=zeros(length(mesh.nNode),1);

    C=theataDifFunc(mesh.H);
    K=kFieldFunc(mesh.H,mesh.Ks);

    for iZ=1:nZ
        for iX=1:nX
            indexCenter=nodeIndex(iZ,iX);
            
            switch sign(indexCenter)        
                case 0      %is NOT a free node with index number
                    continue
                case -1     %TODO this is wrong As NBC location (0 flux direction) need to be found.
                    
                case 1      % if Normal inner point
                    
                    indexUp=nodeIndex(iZ-1,iX);
                    indexDown=nodeIndex(iZ+1,iX);
                    indexLeft=nodeIndex(iZ,iX-1);
                    indexRight=nodeIndex(iZ,iX+1);

                    hUp=H(iZ-1,iX);
                    hDown=H(iZ+1,iX);
                    hLeft=H(iZ,iX-1);
                    hRight=H(iZ,iX+1);

                    kHalfUp   =(K(iZ,iX)+K(iZ-1,iX))/2;
                    kHalfDown =(K(iZ,iX)+K(iZ+1,iX))/2;
                    kHalfLeft =(K(iZ,iX)+K(iZ,iX-1))/2;
                    kHalfRight=(K(iZ,iX)+K(iZ,iX+1))/2;
                otherwise 
                    error('unknown node type');
            end
                   
        
        end
    end
    
end


function  [weight]=weightGen(h,hL,hR,hT,hB)
%function the generate weight connecting hi and its neighbour
%not finished
    wUp   = -(K(iZ,iX)+K(iZ-1,iX))/2 ./deltaZ^2;
    
end



function theata=theataFunc(H)
theataS=0.287;
theataR=0.075;
alpha=1.611e6;
beta=3.96;

theata=alpha.*(theataS-theataR)./(alpha+abs(H).^beta)+theataR;
end

function theataDif=theataDifFunc(H)
theata_s=0.287;
theata_r=0.075;
alpha=1.611e6;
beta=3.96;

theataDif=-alpha.*(theata_s-theata_r).*-1.*(alpha+abs(H).^beta).^(-2).*abs(H).^(beta-1);

end

function result=kFunc(H)
rho=1.175e6;
r=4.74;
k_s=0.00944;

result=k_s.*rho./(rho+abs(H).^r);
end

function result=kFieldFunc(H,ks)
% H and k must be the same sizes
rho=1.175e6;
r=4.74;

result=ks.*rho./(rho+abs(H).^r);
end



function Ks=permeabilityField(X,lengthcale)
% permeability generator (log-normal) given X coordinates and measure lengthscale.
%
% log(ks)=z~N(0,cov(x1,x2))
% cov[z_{12}]=cov(x1,x2)=exp(-|x1-x2|/c) and E[z]=0
%
% pointCoordinate=[X(:),Z(:)];

%larger number means less stochastic field. Thus less smooth.
% lengthcale=10; 

[nX,dimX]=size(X);

%calculate distance matrix
distance = pdist(X);
distanceMatrix = squareform(distance);

%calculate covariance matrix
covMatrix=exp(-distanceMatrix./lengthcale);    

% KL decomposition on covariance matrix via SVD/eigen decomposition
% [klBasis,klEigenValue] = eigs(covMatrix,nY*nX); 
[klBasis,klEigenValue,~] = svds(covMatrix,nX); 


% [nKlBasis,~]=sizes(klBasis);


%Generate independent normal samples 
seed=101;
rng(seed);
sample= randn(nX,1);

%make multivariate Gaussian distributions with samples. zero mean.
%Covariance specified though KL basis.
Ks=klBasis*sqrt(klEigenValue)*sample;
% Ks=reshape(Ks,nY,nX);

% a log (multi) normal permeability field
Ks=exp(Ks);

end

