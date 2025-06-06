function val = getvalue(S,nal,options)

%GETVALUE Retrieve value from node-attribute list
%
% Syntax
%
%     val = getvalue(S,nal,pn,pv)
%
% Description
%
%     getvalue extracts values from node-attribute lists nal of a stream
%     network S.
%
% Input arguments
%
%     S        STREAMobj
%     nal      node-attribute list(s). nal must be a valid node-attribute
%              list (isnal). If S has n nodes, then nal is a nx1 vector or 
%              nxm matrix. 
%     
%     Parameter name/value arguments
%              
%              getvalue takes one of the following pn/pv arguments
%
%     'distance'    scalar or vector of the distance measured from the outlet.
%                   This only works if S represents a single stream (i.e. S
%                   has only one channelhead).
%     'coordinates' pairs of x and y coordinates. Coordinates are snapped
%                   to the nearest stream network pixels (see snap2stream).
%                   A snapping distance > sqrt(2*cellsize) issues a
%                   warning.
%     'IXgrid'      linear index into the GRIDobj, from which S was derived.
%                   Locations that are not on the stream network will have
%                   nan-values in the output vector or matrix.
%
% Example 1: Get the distance of all confluences to the stream network
%            outlet
%
%     DEM = GRIDobj('srtm_bigtujunga30m_utm11.tif');
%     FD = FLOWobj(DEM,'preprocess','carve');
%     S  = STREAMobj(FD,'minarea',1000);
%     IX = streampoi(S,'confluence','ix');
%     d = S.distance;
%     dlocs = getvalue(S,d,'IXgrid',IX);
%     histogram(dlocs)
%
% Example 2: Get elevations of a stream along a set of distance values
%
%     DEM = GRIDobj('srtm_bigtujunga30m_utm11.tif');
%     FD = FLOWobj(DEM,'preprocess','carve');
%     S  = STREAMobj(FD,'minarea',1000);
%     S = trunk(klargestconncomps(S));
%     nal = [getnal(S,DEM) gradient(S,DEM)];
%     z = getvalue(S,nal,'distance',[20000 40000 30000]);
%     plotdz(S,DEM);
%     hold on
%     plot([20000 40000 30000],z(:,1),'s');
%     hold off
% 
%            
% See also: STREAMobj, STREAMobj/distance, STREAMobj/getnal
%
% Author: Wolfgang Schwanghart (schwangh[at]uni-potsdam.de)
% Date: 7. March, 2025

arguments
    S    STREAMobj
    nal  
    options.distance = []
    options.coordinates = []
    options.IXgrid   = []
end

narginchk(4,4)



if isa(nal,'GRIDobj')
    nal = ezgetnal(S,nal);

elseif iscell(nal)
    % nal is a cell array of GRIDobjs or nals
    nal = cellfun(@(x) ezgetnal(S,x),nal,'UniformOutput',false);
    nal = horzcat(nal{:});
end
    
if ~isnal(S,nal(:,1))
    error('TopoToolbox:getvalue','nal is not a valid node-attribute list')
end

if ~isempty(options.distance)
    if info(S,'nrchannelheads') > 1
        error('TopoToolbox:getvalue',...
            ['The STREAMobj S must be a single stream. It must not have \n' ...
            'more than one channel head. See STREAMobj/trunk and \n' ...
            'STREAMobj/klargestconncomps for extracting single rivers.'])
    end
    

    nal = num2cell(nal,1);
    
    [~,~,d,nal{:}] = STREAMobj2XY(S,S.distance,nal{:});
    nal = cell2mat(nal);
    d(end) = [];
    nal(end,:) = [];
    
    val = interp1(d,nal,options.distance(:));
    
    % d = S.distance;
    % [~,ix] = min(abs(d - options.distance));
    % val    = nal(ix,:);
    
elseif ~isempty(options.coordinates)
    [~,~,IX,res] = snap2stream(S,options.coordinates(:,1),options.coordinates(:,2));
    [~,locb] = ismember(IX,S.IXgrid);
    val = nal(locb,:);
    
    if any(res> (sqrt(2*S.cellsize)+eps))
        warning('TopoToolbox:getvalue', ...
           ['Some of the coordinates are not located on nodes of the stream \n' ...
            'network. The maximum snap distance is ' num2str(max(res)) '.']);
    end
    
    
elseif ~isempty(options.IXgrid)
    [I,locb] = ismember(options.IXgrid,S.IXgrid);
    val = nan(numel(options.IXgrid),size(nal,2));
    val(I,:) = nal(locb(I),:);
    
end

    



