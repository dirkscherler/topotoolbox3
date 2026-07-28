function h = plotdz(SW,options)
%PLOTDZ Creates distance-elevation plot of a SWATHobj
%
% Syntax
%
%     plotdz(SW)
%     plotdz(SW,'pn','pv',...)
%     h = ...;
%
% Description
%
%     PLOTDZ creates a profile-view plot of a SWATHobj, showing the
%     statictics (min, max, mean +/- standard dev.) of the z-values as a
%     function of distance along the profile of the SWATHobj.
%
% Input arguments
%
%     SW     instance of SWATHobj
%
%     Parameter name/value pairs
%
%     'left'   {true}, false
%     determines if the left half (as seen from the direction of the 
%     central line) of the SWATHobj is included in the statistics
%
%     'right'   {true}, false
%     determines if the right half (as seen from the direction of the 
%     central line) of the SWATHobj is included in the statistics
%
%     'distadjust'   {0}, scalar
%     allows shifting the x-axis by a scalar value. This is useful when
%     alligning a SWATHobj that was obtained along, e.g., a reach of
%     a drainage network, with the STREAMobj that it was derived from
%
%     'plotminmax'    {true}, false
%     determines whether min/max ranges are plotted
%  
%     'boundedline'   {true}, false
%     both standard deviation from the mean and min/max are plotted using 
%     patch.
%
%     if boundedline is true, then following parameters apply
%     'facecolor'          color (three element vector) for the face color
%                          of the std range. Default is 
%                          [0.5059 0.8471 0.8157]
%     'minmaxfacecolor'    color of the min/max range. Default is [.8 .8 .8]
%     'edgecolor           edge color for the std range {'none'}
%     'minmaxedgecolor'    edge color for the min/max range {'none'}
%     'facealpha'          alpha of the std range {1}
%     'minmaxfacealpha'    alpha of the min/max range {1}
%
% Output arguments (optional)
%
%     h    handle object of the plotted features. h contains several
%          handles to the different parts of the plot
%
% Example
%
%     DEM = GRIDobj('srtm_bigtujunga30m_utm11.tif');
%     SW = SWATHobj(DEM,'dx',200,'dy',200);
%     G = gradient8(DEM,'degree');
%     SWG = mapswath(SW,G);
%     figure, plotdz(SWG)
%     title('Slope angle along swath')
%
%
% Author: Dirk Scherler (scherler[at]gfz-potsdam.de)
%         Wolfgang Schwanghart (schwangh[at]uni-potsdam.de)
% Date: 12. November, 2024

arguments
    SW  SWATHobj
    options.left (1,1) = true
    options.right (1,1) = true
    options.distadjust (1,1) = 0
    options.boundedline (1,1) = true
    options.facecolor = [0.5059 0.8471 0.8157]
    options.facealpha = .5
    options.minmaxfacecolor = []
    options.edgecolor = 'none'
    options.meancolor = 'k'
    options.meanlinewidth = 1
    options.plotminmax (1,1) = true
    options.minmaxcolor = []
    options.minmaxedgecolor = 'none'
    options.minmaxfacealpha = .3
end

% parameters
distadjust = options.distadjust;
left       = options.left;
right      = options.right;
boundedl   = options.boundedline;

% by default, minmax color should be equal to the boundedline, but be more
% transparent
if isempty(options.minmaxcolor)
    if isstring(options.facecolor) || ischar(options.facecolor)
        options.minmaxcolor = letter2rgb(options.facecolor);
    else
        options.minmaxcolor = options.facecolor;
    end
end
if isempty(options.minmaxfacecolor)
    if isstring(options.facecolor) || ischar(options.facecolor)
        options.minmaxfacecolor = letter2rgb(options.facecolor);
    else
        options.minmaxfacecolor = options.facecolor;
    end
end


if ~left && ~right
    warning('Empty SWATHobj: nothing to plot')
    return;
end


if ~left
    ny = ceil(length(SW.disty)/2)+1;
    SW.Z = SW.Z(ny:end,:);
elseif ~right
    ny = floor(length(SW.disty)/2);
    SW.Z = SW.Z(1:ny,:);
end

[z_min,dist]  = stat(SW,@min);
dist   = dist + distadjust;

z_max  = stat(SW,@max);
z_mean = stat(SW,@(x) mean(x,'omitmissing'));
z_std = stat(SW,@(x) std(x,'omitmissing'));

% draw SWATHobj
ax = gca;
if ishold(ax)
    ISHOLD = true;
else
    ISHOLD = false;
    hold(ax,'on')
    box(ax,'on')
end


if (boundedl) %exist('boundedline','file') && 
    if options.plotminmax
    hp(3) = patch([dist(:); flipud(dist(:))],...
                  [z_min(:); flipud(z_max(:))],...
                  options.minmaxfacecolor,...
                  'EdgeColor',options.minmaxedgecolor,...
                  'FaceAlpha',options.minmaxfacealpha);
    end
    hp(2) = patch([dist(:); flipud(dist(:))],...
                  [z_mean(:)-z_std(:); flipud(z_mean(:)+z_std(:))],...
                  options.facecolor,...
                  'EdgeColor',options.edgecolor,...
                  'FaceAlpha',options.facealpha);
    

    hp(1) = plot(dist,z_mean,'color',options.meancolor,'LineWidth',options.meanlinewidth);

else
    hp(1) = plot(dist,z_mean,'-','Color',options.meancolor,'LineWidth',1.5); 
    hp(2) = plot([dist;nan;dist],[z_mean-z_std;nan;z_mean+z_std],'-',...
        'color',options.meancolor);
    if options.plotminmax
        hp(3) = plot([dist;nan;dist],[z_min(:);nan;z_max(:)],':',...
            'color',options.meancolor);
    end
end

drawnow
xlabel(sprintf('Distance along profile (%s)',SW.xyunit))
ylabel(sprintf('Z (%s)',SW.zunit))
if options.plotminmax
    legend(hp,{'Mean','+/- St.Dev.','Min/Max'})
else
    legend(hp,{'Mean','+/- St.Dev.'})
end

if ~ISHOLD
    hold(ax,'off')
end

if nargout == 1
    h = hp;
end

