function MS = geotable2mapstruct(GT,options)

%GEOTABLE2MAPSTRUCT Convert a geotable to a mapping structure
%
% Syntax
%
%     MS = geotable2mapstruct(GT)
%
% Description
%
%     geotable2mapstruct converts a geotable to a mapping structure. 
%
% Input arguments
%
%     GT    geotable
%
%     Parameter name/value pairs
%
%     'xycolvec'   {false} or true. If true, x- and y-coordinates are 
%                  stored as column vectors. By default, they are row
%                  vectors.
%     'appendnan'  {false} or true. If true, a nan is appended at the end 
%                  of the x and y coordinate vectors.
%
% Output arguments
%
%     MS    structure array
%
% See also: mapstruct2geotable, polygon2GRIDobj,
%           STREAMobj/STREAMobj2geotable, STREAMobj/STREAMobj2mapstruct
%
% Author: Wolfgang Schwanghart (schwangh@uni-potsdam.de)
% Date: 9. July, 2024

arguments
    GT {mustBeGeotable}
    options.xycolvec (1,1) = false
    options.appendnan   (1,1) = false
end

[~,isproj] = parseCRS(GT);
if ~isproj
    MS = geotable2table(GT,["Latitude" "Longitude"]);

else
    MS = geotable2table(GT,["X" "Y"]);

end

if options.appendnan
    MS.X = cellfun(@(x) [x nan],MS.X,'UniformOutput',false);
    MS.Y = cellfun(@(x) [x nan],MS.Y,'UniformOutput',false);
end

if options.xycolvec
    MS.X = cellfun(@(x) x(:),MS.X,'UniformOutput',false);
    MS.Y = cellfun(@(x) x(:),MS.Y,'UniformOutput',false);
end

geomType = GT.Shape.Geometry;

MS = table2struct(MS);

switch geomType
    case 'point'
        [MS.Geometry] = deal('Point');
    case 'line'
        [MS.Geometry] = deal('Line');
    case 'polygon'
        [MS.Geometry] = deal('Polygon');
    otherwise
        error('Unknown geometry type.')
end



end

function mustBeGeotable(inp)
if ~isgeotable(inp)
    error("Input must be a geotable.")
end
end