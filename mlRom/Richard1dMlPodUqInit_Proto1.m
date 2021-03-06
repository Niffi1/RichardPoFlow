function [] = Richard1dMlPodUqInit_Proto1()
% Initilize UQ for Richars equation with random input using mchaine learning & POD
% generate training testing dataset
%
% Richars equation 1D pod solver testing file.
% The function focus on fix Dirichlet BC.
% This function serves as a Demo for all Richard solver developed in this
% project.
% 
% Proto1: Created form Richard1dMlPodUQ_Proto1() in idPod
%
% Input parameters:
%
% Output parameters:
%
% See also: 
%
% Author:   Wei Xing
% History:  15/06/2017  file created
%
clear
close all
%% Solver Setup
% Spatial setup
lengthZ=100;
deltaZ=0.1;
nZ=lengthZ/deltaZ+1;

% Temporal setup
lengthT=200;
deltaT=1;
nTime=lengthT/deltaT;
% tStep=1:deltaT:lengthTime;


%Solver iteration setup
nMaxIteration=50;
maxIteError=1;

% update mesh structure
Mesh.lengthZ=lengthZ;
Mesh.deltaZ=deltaZ;
Mesh.nZ=nZ;

%% initial conditions and boundary value (DBC)
h_init=ones(nZ,1)*-61.5; %value for all initial points
h_init(1,1)=-20.7;       %value for top DBC
h_init(end,1)=-61.5;     %value for bottom DBC
Mesh.H=h_init;

Mesh.dbcFlag=zeros(nZ,1);     %specify DBC location
Mesh.dbcFlag(1)=1;
Mesh.dbcFlag(end)=1;

%% Define for C and K non-linear function
theata_s=0.287;
theata_r=0.075;
alpha=1.611e6;
beta=3.96;

rho=1.175e6;
r=4.74;
% kFromhKs @(h) Ks.*rho./(rho+abs(h).^r);
% K = @(h) Ks.*rho./(rho+abs(h).^r);
K = @(h,Ks) Ks.*rho./(rho+abs(h).^r);

theata    = @(h)  alpha.*(theata_s-theata_r)/(alpha+abs(h).^beta)+theata_r;
theataDif = @(h) -alpha.*(theata_s-theata_r).*-1.*(alpha+abs(h).^beta).^(-2).*abs(h).^(beta-1);
        
%% Define and Decompose the permeability input field II
lengthScale=lengthZ*0.2; %larger number means less stochastic (more correlation as one zooms in the 
nKl=20;
nSample=200;

% KsMean=0.0094;
% KsVar= (KsMean*0.3)^2;

GaussianMean= log(0.0014);
GaussianVar = (GaussianMean*0.5)^2;       


[Z] = ndgrid(0:deltaZ:lengthZ);
%calculate distance matrix
distance = pdist(Z);
distanceMatrix = squareform(distance);

covMatrix=exp(-distanceMatrix./lengthScale);    %calculate correlation matrix 
covMatrix=GaussianVar*covMatrix;                %calculate covariance  matrix 

[klBasis,klEigenValue,~] = svds(covMatrix,nKl);  % KL decomposition on covariance matrix via SVD/eigen decomposition

% Make permeability field
% sample= randn( size(klBasis,2),1);               %Sampling from a normal distribution
% sample= randn(nKl,nSample);                              %Sampling from a normal distribution
sample= lhsdesign(nSample,nKl)';                         %Sampling using latin hypercube

% sample(1:1,:)=0.5*ones(nSample,1);

Ks = (klBasis*sqrt(klEigenValue)*sample)+GaussianMean;  %Multivariate Gaussian
Ks = exp(Ks);                                          


%% FOM on K
% define non-linear term
h=waitbar(0,'FOM on Ks on progress');
for i=1:nSample
%     K = @(h) Ks(:,i).*rho./(rho+abs(h).^r);  %!CALL this function every time uisng new permeability field Ks
    Mesh.Ks=Ks(:,i);
    tic
    [H,iteration1] = Richard1dPicardSolver(Mesh,nTime,deltaT,nMaxIteration,maxIteError,theataDif,K);
    
    tCost1(i,1)=toc;  
    iTera1(i,1)=sum(iteration1);
    H_uq1(:,:,i)=H;
    
    waitbar(i/nSample)
end
close(h)


%% UQ process
mu_H_uq1 =mean(H_uq1,3);
var_H_uq1=std(H_uq1,0,3);
mid_H_uq1=median(H_uq1,3);

figure(3)
nZShow=100;
zShow=1:round(nZ/nZShow):nZ;
figure(2)
for t=1:1:nTime
    figure(4)
    errorbar(zShow,mu_H_uq1(zShow,t),var_H_uq1(zShow,t),'-')
    hold on
    plot(zShow,mid_H_uq1(zShow,t),'-')
    
    hold off
    title(sprintf('Mean Variance and Median @t=%i',t))
%     legend('All KL basis','Truncation KL basis')
    drawnow
%     frame(t)=getframe;    %comment to save cpu time and memory
end


%% Storage
    filename='/Users/weix/Desktop/Data/data7';
    % [status,msg] = mkdir('/uesrs/desktop/Data/data1.mat')
    save(filename);



end
