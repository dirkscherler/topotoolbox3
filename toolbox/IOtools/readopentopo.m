function DEM = readopentopo(options)

%READOPENTOPO Read global DEMs using the opentopography.org API
%
% Syntax
%
%     DEM = readopentopo(pn,pv,...)
%
% Description
%
%     readopentopo reads DEMs from opentopography.org using the API
%     described here: http://www.opentopography.org/developers
%     Most of the DEMs come in geographic coordinates (WGS84) and should be
%     projected to a projected coordinate system (use reproject2utm or 
%     project) before further analysis in TopoToolbox.     
%
%     Note that an API authorization key will be required for this API.
%     Users can request an API key via myOpenTopo in the OpenTopography
%     portal (https://opentopography.org/).
%     
%     To use this key in MATLAB, you can create a text file named
%     opentopography.apikey in MATLAB's preference folder (prefdir)
%     containing the API key. If this file exists, you do not need to
%     provide the key explicitly when calling this function.
%     
%     If you supply an empty string as the API key and no API key-file
%     exists, a dialog box will appear allowing you to enter and
%     permanently save the key directly to the preference folder.
%     
%     To delete a saved API key, navigate to the folder returned by the
%     prefdir command and manually remove the opentopography.apikey file.
%
%     If you use any of these DEMs in your work, please acknowledge
%     OpenTopgraphy. Most DEMs also have specific dataset citations that
%     you should mention in your work. 
%
% Input arguments
%
%     Parameter name values
%
%     'interactive'    {true} or false. If true, readopentopo will open a
%                      GUI that enables interactive selection. If true,
%                      then any given extent options will be ignored.
%     'filename'       provide filename. By default, the function will save
%                      the DEM to a temporary file in the system's temporary 
%                      folder. The option 'deletefile' controls whether the
%                      file is kept on the hard drive.
%     'extent'         GRIDobj, geopolyshape or four element vector with
%                      geographical coordinates in the order [west east
%                      south north]. If a GRIDobj is supplied, readopentopo
%                      uses the function GRIDobj/getextent to obtain the
%                      bounding box in geographical coordinates. If extent
%                      is set, then the following parameter names 'north',
%                      'south', ... are ignored.
%     'addmargin'      Expand the extent derived from 'extent',GRIDobj by a
%                      scalar value in °. Default is 0.01. The option is
%                      only applicable if extent is provided by a GRIDobj, 
%                      or a geopolyshape
%     'north'          northern boundary in geographic coordinates (WGS84).
%                      The option is ignored if the option 'extent' is
%                      provided or if 'interactive', true.
%     'south'          southern boundary
%     'west'           western boundary
%     'east'           eastern boundary
%     'demtype'        The global raster dataset 
%                      {'SRTMGL3'}:       SRTM GL3 (90m) (default)
%                      'SRTMGL1':         SRTM GL1 (30m)  
%                      'SRTMGL1_E':       SRTM GL1 (Ellipsoidal)  
%                      'AW3D30':          ALOS World 3D 30m  
%                      'AW3D30_E':        ALOS World 3D (Ellipsoidal)
%                      'SRTM15Plus':      Global Bathymetry SRTM15+ V2.1  
%                                         (only mediterranean area so far)
%                      'NASADEM':         NASADEM Global DEM 
%                      'COP30':           Copernicus Global DSM 30m 
%                      'COP90':           Copernicus Global DSM 90m 
%                      'EU_DTM:           Continental Europe Digital 
%                                         Terrain Model 
%                      'GEDI_L3':         Global Ecosystem Dynamics 
%                                         Investigation 1x1 km DTM
%                      'GEBCOIceTopo':    Global Bathymetry (500 m)
%                      'GEBCOSubIceTopo': Global Bathymetry (500 m)
%                      'CA_MRDEM_DSM':    Medium Resolution (30 m) Digital 
%                                         Surface Model (MRDEM) of Canada
%                      'CA_MRDEM_DTM':    Medium Resolution (30 m) Digital 
%                                         Terrain Model (MRDEM) of Canada
%                      'ANADEM':          A Digital Terrain Model for South 
%                                         America
%                      'GEDTM30':         Global Ensemble Digital Terrain 
%                                         Model
%     'apikey'         char or string. See above on how to get and apply
%                      the api key.
%     'verbose'        {true} or false. If true, then some information on
%                      the process is shown in the command window.
%     'checkrequestlimit' {true} or false. Opentopography implements
%                      request limits. If the chose extent exceeds the 
%                      request limit, readopentopo will issue an error. If
%                      this option is set to false, readopentopo will try
%                      to download.
%     'deletefile'     {true} or false. True, if file should be deleted
%                      after it was downloaded and added to the workspace.
% 
% Output arguments
%
%     DEM            Digital elevation model in geographic coordinates
%                    (GRIDobj)
%
% Example
%
%     DEM = GRIDobj('srtm_bigtujunga30m_utm11.tif');
%     DEM2 = readopentopo('extent',DEM);
%     DEM2 = reproject2utm(DEM2,90);
%     imagesc(DEM2)
%     hold on
%     getoutline(DEM)
%     hold off
%
% See also: GRIDobj, websave, roipicker
%
% Reference: http://www.opentopography.org/developers
%
% Author: Wolfgang Schwanghart (schwangh[at]uni-potsdam.de)
% Date: 22. August, 2025

arguments
    options.demtype {mustBeTextScalar,mustBeMember(options.demtype,...
        {'SRTMGL3','SRTMGL1','SRTMGL1_E',...
     'AW3D30','AW3D30_E','SRTM15Plus',...
     'NASADEM','COP30','COP90',...
     'EU_DTM','GEDI_L3','GEBCOSubIceTopo','GEBCOIceTopo',...
     'CA_MRDEM_DSM','CA_MRDEM_DTM','GEDTM30','ANADEM'})} = 'SRTMGL3'
    options.filename = ''
    options.interactive (1,1) = false
    options.extent = []
    options.addmargin (1,1) = 0.01
    options.north (1,1) = 37.091337
    options.south (1,1) = 36.738884
    options.west  (1,1) = -120.168457
    options.east  (1,1) = -119.465576
    options.deletefile (1,1) = false
    options.verbose (1,1) = true
    options.apikey  = ''
    options.checkrequestlimit (1,1) = true
end

validdems = {'SRTMGL3','SRTMGL1','SRTMGL1_E',...
     'AW3D30','AW3D30_E','SRTM15Plus',...
     'NASADEM','COP30','COP90',...
     'EU_DTM','GEDI_L3','GEBCOSubIceTopo','GEBCOIceTopo',...
     'CA_MRDEM_DSM','CA_MRDEM_DTM','GEDTM30','ANADEM'};

demtype = validatestring(options.demtype,...
    validdems,'readopentopo');

% Access global topographic datasets including SRTM GL3 (Global 90m), 
% GL1 (Global 30m), ALOS World 3D and SRTM15+ V2.1 (Global Bathymetry 500m). 
% Note: Requests are limited to 
% 125,000,000 km2 for SRTM15+ V2.1,'GEBCOSubIceTopo','GEBCOIceTopo', and 
% 4,050,000 km2 for SRTM GL3, COP90 and 
% 450,000 km2 for all other data.
requestlimits = [4.05e6, 0.45e6, 0.45e6, ...
                 0.45e6, 0.45e6, 125e6,...
                 0.45e6, 0.45e6, 4.05e6, ...
                 0.45e6, 50e7, 125e6, ...
                 125e6, 0.45e6, 0.45e6, ...
                 0.45e6, 0.45e6]; % km^2
requestlimit  = requestlimits(strcmp(demtype,validdems));

% API URL
url = 'https://portal.opentopography.org/API/globaldem?';

% Remove leading and trailing characters from api string
options.apikey = strip(options.apikey);

if strlength(options.apikey) == 0
    % check whether file opentopography.apikey is available
    apikeyfile = fullfile(prefdir,'opentopography.apikey');
    if exist(apikeyfile,'file')
        fid = fopen(apikeyfile);
        apikey = textscan(fid,'%c');
        apikey = apikey{1}';
        % Remove leading and trailing blanks, if there are any
        apikey = strip(apikey);
        fclose(fid);
    else
        apikey = strip(getApiKeyDialog(apikeyfile));
        % error('Readopentopo requires an API Key. Please read the help.')
    end

else
    apikey = options.apikey;
end

% save to drive
woptions = weboptions('Timeout',100000);

% get extent
if ~isempty(options.extent)
    if isa(options.extent,'GRIDobj')
        ext = getextent(options.extent,true);
        west  = ext(1) - options.addmargin;
        east  = ext(2) + options.addmargin;
        south = ext(3) - options.addmargin;
        north = ext(4) + options.addmargin;

    elseif isa(options.extent,"geopolyshape") || isa(options.extent,"mappolyshape")
        if isa(options.extent,"mappolyshape")
            [xlimits,ylimits] = bounds(options.extent);
            [latlim,lonlim] = projinv(options.extent.ProjectedCRS,xlimits,ylimits);
        else
            [latlim,lonlim] = bounds(options.extent);
        end
        west  = lonlim(1) - options.addmargin;
        east  = lonlim(2) + options.addmargin;
        south = latlim(1) - options.addmargin;
        north = latlim(2) + options.addmargin; 
        
    elseif isnumeric(options.extent) & (numel(options.extent) == 4)
        west = options.extent(1);
        east = options.extent(2);
        south = options.extent(3);
        north = options.extent(4);
    else
        error('Unknown format of extent')
    end
else
    west = options.west;
    east = options.east;
    south = options.south;
    north = options.north;
end


% now we have an extent. Or did the user request interactively choosing
% the extent?
if any([isempty(west) isempty(east) isempty(south) isempty(north)]) || options.interactive
    if options.interactive 
        ext = roipicker('requestlimit',requestlimit);
        if isempty(ext)
            DEM = [];
            return
        end
        west = ext(2);
        east = ext(4);
        south = ext(1);
        north = ext(3);
    end
end

% make sure that coordinates are within bounds
west = min(max(west,-180),180);
east = max(min(east,180),-180);
south = min(max(south,-90),90);
north = max(min(north,90),-90);

if west == east || south == north
    error('The provided extent is a line or point.')
end

% Construct a filename unless the filename is defined as option
if options.filename == "" % Note that '' == ""
    options.filename = fullfile(ttcachedir, strcat("OpenTopo_", ...
        string(south), "_", ...
        string(north), "_", ...
        string(west), "_", ...
        string(east), "_", options.demtype, ".tif"));
end

% create output file
f = fullfile(options.filename);

% If the file already exists, open and return it
if isfile(f)
    DEM = GRIDobj(f);
    
    if ~isProjected(DEM)
        disp(' ')
        disp('The downloaded DEM is not in a projected coordinate system.')
        disp('Make sure to project the DEM using GRIDobj/project or')
        disp('GRIDobj/reproject2utm.')
        disp('  ')
    end
    
    DEM.name = demtype;
    return;
end

% Check request limit
a = areaint([south south north north],...
            [west east east west],...
            almanac('earth','radius','kilometers'));

if options.checkrequestlimit && (a > requestlimit)
    error('TopoToolbox:readopentopo',...
            ['Request limit (' num2str(requestlimit) ' km^2) exceeded.\n'...
             'Your extent is ' num2str(a,1) ' km^2. Choose a smaller area.' ])
end

if options.verbose

    disp('-------------------------------------')
    disp('readopentopo process:')
    disp(['DEM type: ' demtype])
    disp(['API url: ' url])
    disp(['Local file name: ' f])
    disp(['Area: ' num2str(a,2) ' sqkm'])
    disp('-------------------------------------')
    disp(['Starting download: ' char(datetime("now"))])
end

% Download with websave
if isempty(apikey)
    outfile = websave(f,url,'west',west,...
        'east',east,...
        'north',north,...
        'south',south,...
        'outputFormat', 'GTiff', ...
        'demtype', demtype, ...
        woptions);
else
    outfile = websave(f,url,'west',west,...
        'east',east,...
        'north',north,...
        'south',south,...
        'outputFormat', 'GTiff', ...
        'demtype', demtype, ...
        'API_Key',apikey,...
        woptions);
end

if options.verbose
    disp(['Download finished: ' char(datetime("now"))])
    disp(['Reading DEM: ' char(datetime("now"))])
end

try

    DEM      = GRIDobj(f);
    
    if ~isProjected(DEM)
        disp(' ')
        disp('The downloaded DEM is not in a projected coordinate system.')
        disp('Make sure to project the DEM using GRIDobj/project or')
        disp('GRIDobj/reproject2utm.')
        disp('  ')
    end
    
    DEM.name = demtype;
    if options.verbose
        disp(['DEM read: ' char(datetime("now"))])
    end
    
catch
    % Something went wrong. See whether we can derive some information.
    fid = fopen(outfile);
    in = textscan(fid,'%c');
    disp('Could not retrieve DEM. This is the message returned by opentopography API:')
    disp([in{1}]')
    disp('readopentopo returns empty array')
    fclose(fid);
    DEM = [];
end
    

if options.deletefile
    delete(f);
    if options.verbose
        disp('Temporary file deleted')
    end
end

if options.verbose
    disp(['Done: ' char(datetime("now"))])
    disp('-------------------------------------')
end
end



function apiKey = getApiKeyDialog(apikeyfile)
    % getApiKeyDialog opens a dialog for user to enter an API key.
    % Returns the API key string or empty if cancelled.
    %
    % If the user presses "Submit and Save", the key will also be written
    % to a text file "api_key.txt" in the current folder.
    
    apiKey = '';

    % Create dialog
    d = dialog('Position',[300 300 400 150], ...
               'Name','Enter API Key', ...
               'WindowStyle','modal');
    
    % Instruction text
    uicontrol('Parent',d,...
              'Style','text',...
              'Position',[20 100 360 30],...
              'String','Please enter your API key:',...
              'HorizontalAlignment','left');
    
    % Edit field
    editBox = uicontrol('Parent',d,...
                        'Style','edit',...
                        'Position',[20 70 360 25],...
                        'HorizontalAlignment','left');
    
    % Buttons
    uicontrol('Parent',d,...
              'Position',[20 20 100 30],...
              'String','Cancel',...
              'Callback',@(src,evt) delete(d));
    
    uicontrol('Parent',d,...
              'Position',[140 20 100 30],...
              'String','Submit',...
              'Callback',@(src,evt) submitCallback(false));
    
    uicontrol('Parent',d,...
              'Position',[260 20 120 30],...
              'String','Submit and Save',...
              'Callback',@(src,evt) submitCallback(true));

    % Wait for user
    uiwait(d);
    
    % Nested callback
    function submitCallback(saveToFile)
        apiKey = get(editBox,'String');
        if saveToFile && ~isempty(apiKey)
            
            fid = fopen(apikeyfile,'w');
            if fid ~= -1
                fprintf(fid,'%s',strip(apiKey));
                fclose(fid);
            else
                warning('Could not save API key to file.');
            end
        end
        delete(d);
    end
end

