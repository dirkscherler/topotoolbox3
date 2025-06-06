function SH = castshadow(DEM,azid,altd)

%CASTSHADOW Cast shadow calculated from digital terrain
%
% Syntax
%
%     SH = castshadow(DEM,azid,altd)
%
% Description
%     
%     castshadow calculates the shadow created on a form next to a surface 
%     that is turned away from the source of light. 
%
% Input arguments
%
%     DEM    digital elevation model (class: GRIDobj)
%     azid   azimuth angle in degrees of light source (clockwise from top)
%     altd   elevation angle in degrees of light source above horizon
%
% Output arguments
%
%     SH     values between 0 and 1 with values of 1 indicating shadowed 
%            and 0 indicating non-shadowed areas. Values between 0 and 1
%            can be interpreted to indicate a degree of shadowing. 
%
% Example
%     
%     DEM = GRIDobj('srtm_bigtujunga30m_utm11.tif');
%     C   = castshadow(DEM,135,20);
%     imageschs(DEM,C,'colormap',flipud(gray))
%
% 
% See also: GRIDobj/imageschs, GRIDobj/hillshade  
%
% Author: Wolfgang Schwanghart (schwangh[at]uni-potsdam.de)
% Date: 3. June, 2024

arguments
    DEM  GRIDobj
    azid {mustBeNumeric} = 180
    altd {mustBeNumeric} = 45
end


azid = mod(-azid,360);
% force values in the DEM to be larger than zero
% because imrotate fills loose image ends with zeros
DEM.Z =  - min(DEM.Z(:)) + DEM.Z + 1;

%
% affine transformation matrix
A = [cosd(azid) sind(azid); ...
    -sind(azid) cosd(azid)];
A(3,3) = 1; 

% tform = affine2d(A);
tform = maketform('affine',A);
% image transformation
[demr,xdata,ydata]  = imtransform(DEM.Z,tform,'bilinear',...
    'Udata',[1 DEM.size(2)],'Vdata',[1 DEM.size(1)]);

% calculate height of sunbeams
lowering = DEM.cellsize*tand(altd);
demrcopy = demr;
for r = 2:size(demr,1)
    demr(r,:) = max(demr(r-1,:) - lowering,demr(r,:)).*(demr(r,:)>0);
end
demr = single(demr>demrcopy);

% backtransform image 
azid = -azid;
A = [cosd(azid) sind(azid); ...
    -sind(azid) cosd(azid)];
A(3,3) = 1;
demr = imtransform(demr,maketform('affine',A),'bilinear',...
    'Udata',xdata,'Vdata',ydata,...
    'xdata',[1 DEM.size(2)],'ydata',[1 DEM.size(1)],...
    'Size',DEM.size);

% write to GRIDobj
SH = DEM;
SH.Z = demr;




    