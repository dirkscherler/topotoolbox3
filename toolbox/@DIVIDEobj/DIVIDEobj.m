classdef DIVIDEobj
    %DIVIDEobj Create divide object (DIVIDEobj)
    %
    % Syntax
    %
    %     D = DIVIDEobj(FD,ST)
    %     D = DIVIDEobj(FD,ST,pn,pv)
    %
    % Description
    %
    %     An instance of divide object encapsulates information on the geometry
    %     and connectivity of a divide network, based on the flow direction of
    %     a digital elevation model and a STREAMobj or a logical raster that
    %     indicates the position of streams. Divides are defined as the lines
    %     surrounding drainage basins and thus they are positioned in between
    %     pixels of the digital elevation model. The drainage basins used to
    %     define divide objects are based on tributrary junctions that are
    %     derived from changes in stream orders.
    %     DIVIDEobj provides access to various methods that investigate
    %     properties of a divide network and associated data.
    %
    % Input arguments
    %
    %     FD     instance of flow direction object (FLOWobj)
    %     ST     instance of stream object (STREAMobj) or logical grid
    %            (GRIDobj) that indicates stream locations (e.g. obtained
    %            from thresholding the flow accumulation raster)
    %
    % Parameter name/value pairs
    %
    %     network      toggle (default=true) to indicate whether after the
    %                  identification of the divides, they shall arranged
    %                  into a divide network (divnet), sorted (sort), and
    %                  assigned divide distances (divdist). Turn off to
    %                  obtain only divide segments. Usually this is used
    %                  only for code development.
    %     verbose      toggle (default=false) for displaying function 
    %                  execution progress in the command window.
    %     useparallel  toggle to compute in parallel (default=false)
    %
    % Output arguments
    %
    %     D      instance of DIVIDEobj
    %
    % Examples
    %
    %     DEM = GRIDobj('srtm_bigtujunga30m_utm11.tif');
    %     FD  = FLOWobj(DEM);
    %     ST = STREAMobj(FD,flowacc(FD)>1000);
    %     D = DIVIDEobj(FD,ST);
    %     hillshade(DEM)
    %     hold on
    %     plot(D)
    %
    % See also: FLOWobj/drainagebasins, FLOWobj/streamorder
    %
    % Author: Dirk Scherler (scherler[at]gfz-potsdam.de)
    % Date: August 2020
    %       April 2025
    %       July 2026


    properties
        size      % size of hypothetical GRIDobj that would place the
                  % divide nodes into cells
        cellsize  % cellsize
        wf        % 2-by-3 affine transformation matrix
        IX        % nan-separated linear indices of divide nodes into
                  % instance of divide GRIDobj
        order     % divide order
        distance  % maximum directed distance from divide endpoint
        ep        % linear indices of divide network endpoints
        jct       % linear indices of divide network junctions
        jctedg    % number of edges per junction (divides)
        endo      % linear indices of endorheic nodes
        issorted  % flag to indicate if divide network is sorted
        ordertype % name of ordering scheme
    end


    methods


        function [D,varargout] = DIVIDEobj(FD,ST,options)
            %DIVIDEobj Construct an instance of this class

            arguments
                FD {mustBeA(FD,'FLOWobj')}
                ST {mustBeA(ST,{'STREAMobj','GRIDobj'})}
                options.network (1,1) = true
                options.verbose (1,1) = false
                options.useparallel (1,1) = false
            end
            
            verbose = options.verbose;

            % Prepare
            % The divide object is shifted by half a cell size in x & y
            cellarea = FD.cellsize^2;
            hcs = FD.cellsize/2;
            D.cellsize = FD.cellsize;
            D.wf = FD.wf+[0,0,-hcs;0,0,hcs];
            D.size = FD.size+[1 1];

            % To maintain backward compatibility, also allow for stream
            % grids
            if isa(ST,'GRIDobj')
                ST = STREAMobj(FD,ST);
            end
            
            % Outlets / sinks
            outlets = streampoi(ST,'outlets','ix');
            
            % Label stream segments (reaches) and get contributing areas
            L = labelreach(ST);
            STG = STREAMobj2GRIDobj(ST,L);
            L = mapfromnal(FD,ST,L);
            outlet_gridval = STG.Z(outlets);

            % Note that GRIDobj2polygon has an issue with catchments that
            % contain pixels only diagonally connected to another
            % catchment along the edge. These are not recognized and
            % filled. However, the counter part catchment, which has
            % the diagonally connected pixel apendix is recognized well.
            % GRIDobj2geotable can identify such features only as holes,
            % where each diagonally connected pixel is one hole. We use
            % GRIDobj2polygon and subsequently compare grid and polygon
            % areas to determine whether we need to split the outline. We
            % identify the point where to split using GRIDobj2geotable and
            % comparing the nodes of hole polygons with the outer poylgon.
            
            MS = GRIDobj2polygon(L,'holes',false);
            [MS.outlet_id] = deal(nan);
            [MS.endo] = deal(false);
            for i = 1 : numel(MS)
                % check for issue in derived outline
                area_grid = MS(i).Area.*cellarea;
                area_poly = polyarea(MS(i).X(1:end-1),MS(i).Y(1:end-1));
                if abs(area_poly-area_grid)>hcs
                    % problematic polygon
                    tMS = GRIDobj2geotable(L==i);
                    tMS = geotable2mapstruct(tMS);
                    ix = find(isnan(tMS.X),1,'first'); % start of hole nodes
                    tx = MS(i).X;
                    ty = MS(i).Y;
                    idoutside = coord2ind(D,tx,ty);
                    idinside = coord2ind(D,tMS.X(ix:end),tMS.Y(ix:end));
                    % find outside nodes that require a break
                    iy = find(ismember(idoutside,idinside));
                    % insert NaN
                    [~,isort] = sort([(1:numel(tx))';iy]);
                    tx = [tx;nan(numel(iy),1)];
                    ty = [ty;nan(numel(iy),1)];
                    tx = tx(isort);
                    ty = ty(isort);
                    MS(i).X = tx;
                    MS(i).Y = ty;
                end
                % append nan to coordinate vectors if needed
                if not(isnan(MS(i).X(end)))
                    MS(i).X = [MS(i).X(:);NaN];
                    MS(i).Y = [MS(i).Y(:);NaN];
                end
                % identify outlets
                outix = ismember(outlet_gridval,MS(i).gridval);
                if sum(outix)>0
                    MS(i).outlet_id = outlets(outix);
                end
            end
            [outx,outy] = ind2coord(STG,vertcat(MS.outlet_id));
            out = [outx(:),outy(:)];
            
            % Coordinates of all flow edges in stream object
            % (to find those that change basin ID)
            st_giver = ST.IXgrid(ST.ix);
            st_receiver = ST.IXgrid(ST.ixc);
            [x1,y1] = ind2coord(FD,st_giver);
            [x2,y2] = ind2coord(FD,st_receiver);
            
            % The following three lines can speed up the code but currently
            % don't work because of the GRIDObj2polygon issue mentioned
            % above: incorrect basin outlines preclude focusing on stream
            % nodes that change basin ID.
            %IX = abs(st_giver_label-st_receiver_label)>0;
            %[x1,y1] = ind2coord(FD,st_giver(IX));
            %[x2,y2] = ind2coord(FD,st_receiver(IX));
            
            % Flow edge midpoints
            mx = (x1+x2)./2;
            my = (y1+y2)./2;
            
            % Loop over basin outlines to get divides
            if (verbose)
                f = waitbar(0,'Processing divides');
            end
            
            n = numel(MS);

            if (options.useparallel)

                PPDQ = parallel.pool.DataQueue;
                p = 0;
                afterEach(PPDQ,@(~) updateWaitbar);
    
                parfor i = 1 : n
                    
                    tx = MS(i).X;
                    ty = MS(i).Y;
                    tout = out(i,:);

                    [ntx,nty] = getdivide(D,tx,ty,tout,mx,my,hcs);

                    MS(i).X = ntx;
                    MS(i).Y = nty;
                    
                    if (verbose)
                        send(PPDQ,i);
                    end

                end

            else % in serial

                for i = 1 : n
                    
                    if (verbose)
                        waitbar(i/n,f,sprintf('Processing divides: %d / %d',i,n))
                    end
                    
                    tx = MS(i).X;
                    ty = MS(i).Y;
                    tout = out(i,:);

                    [ntx,nty] = getdivide(D,tx,ty,tout,mx,my,hcs);
                    
                    MS(i).X = ntx;
                    MS(i).Y = nty;
                    
                end

            end
            
            if (verbose)
                close(f)
            end
            
            % Endorheic divide nodes
            isendo = [MS.endo];
            Ien = unique(coord2ind(D,vertcat(MS(isendo).X),vertcat(MS(isendo).Y)));
            
            % All divide nodes
            I = coord2ind(D,vertcat(MS.X),vertcat(MS.Y));
            
            % Remove redundant edges (these arise from overlapping drainage 
            % basins and are abundant)
            T = [I(1:end-1),I(2:end)]; % edges (connections between nodes)
            % Rows with one NaN in either column become NaN
            T(sum(isnan(T),2)==1,:) = NaN;
            % Set redundant edges to NaN
            sT = sort(T,2); % lower index left (rows unchanged)
            [~,IX,~] = unique(sT,'stable','rows');
            %[~,IX,~] = unique(sT,'rows','legacy');
            T0 = nan(size(T));
            T0(IX,:) = T(IX,:);
            
            % Remove self-connections
            IX = (T0(:,1)-T0(:,2))==0;
            T0(IX,:) = NaN;
            
            % Remove redundant edges
            TT = T0';
            TT = TT(:);
            dTT = TT(1:end-1)-TT(2:end);
            IX = not([dTT;NaN]==0);
            TT = TT(IX);
        
            % Remove redundant NaN between segments
            IX = isnan(TT(:,1));
            JX = [IX(2:end);true];
            IJ = logical(min([IX JX],[],2));
            TT = [TT(not(IJ));NaN];
        
            % Assemble structure
            M = struct;
            ix = [0;find(isnan(TT))];
            ct = 0;
            for i = 1 : length(ix)-1
                if (ix(i+1)-ix(i))>2 % avoid single nodes
                    ct = ct+1;
                    M(ct).IX = TT(ix(i)+1:ix(i+1));
                    M(ct).nix = numel(M(ct).IX);
                    % identify endorheic nodes
                    M(ct).isendo = ismember(M(ct).IX,Ien);
                end
            end

            D.IX = vertcat(M.IX);
            D.endo = vertcat(M.isendo);
            
            D.issorted = false;
            
            % Get junctions and endpoints
            if options.network
                if (verbose)
                    f = waitbar(0.25,'Creating divide network');
                end
                D = divnet(D,FD);
                if (verbose)
                    waitbar(0.5,f,'Sorting divide network');
                end
                D = sort(D);
                if (verbose)
                    waitbar(0.75,f,'Calculating distances');
                end
                D = divdist(D);
                if (verbose)
                    waitbar(1,f,'Calculating distances');
                    close(f)
                end
            end

            if nargout>1
                varargout{1} = M;
            end
            
            function updateWaitbar
                p = p + 1;
                waitbar(p/n,f,sprintf('Processing %d/%d',p,n));
            end

        end


        function DOUT = divnet(DIN,FD)
            %DIVNET   Compute divide network
            %
            % Syntax
            %
            %     D2 = divnet(D,FD)
            %
            % Description
            %
            %     DIVNET finds the endpoints and junctions that define the
            %     divide network in a divide object. Endpoints are the
            %     outer limits of a divide network, equivalent to channel
            %     heads in a drainage network. Junctions are points where
            %     two (or more) divides meet. They are equivalent to
            %     confluences in a drainage network. Both endpoints and
            %     junctions will be stored in the form of linear indices in
            %     the divide object.
            %
            % Input
            %
            %     D         instance of class DIVIDEobj
            %     FD        instance of class FLOWobj
            %
            % Output
            %
            %     D2         instance of class DIVIDEobj
            %
            % Example
            %
            %     D = divnet(D,FD);
            %
            % See also: DIVIDEobj, DIVIDEobj/sort
            %
            % Author: Dirk Scherler (scherler[at]gfz.de)
            % Date: Nov 2018
            %       Apr 2018
            %       Jul 2026

            %  input properties: D.IX
            % output properties: D.ep, D.jct, D.jctedg

            DOUT = DIN;
            
            % Create divide grids as helpers (FX, NEDGE, NST)
            [x,y] = wf2XY(FD.wf,FD.size);
            cs = FD.cellsize;
            hcs = cs/2;
            xn = [x-hcs;x(end)+hcs];
            yn = [y+hcs;y(end)-hcs];
            A = zeros(FD.size+1);
            FX = GRIDobj(xn,yn,A); % grid that indicates diagonal flow
            NEDGE = FX; % grid that counts the number of divide edges
            NST = FX; % grid that counts the numnber of segment termini
            [x,y] = getcoordinates(FX);
            [XD,YD] = meshgrid(x,y);
            
            % Indices of flow edge midpoints
            [x1,y1] = ind2coord(FD,FD.ix);
            [x2,y2] = ind2coord(FD,FD.ixc);
            dx = x2-x1;
            dy = y2-y1;
            mx = (x1+x2)./2;
            my = (y1+y2)./2;
            [mix,res] = coord2ind(DIN,mx,my);
            % Identify diagonal flow connections
            FX.Z(mix(res<0.5*hcs & abs(dx+dy)<cs)) = 1; % NW-SE / SE-NW
            FX.Z(mix(res<0.5*hcs & abs(dx+dy)>cs)) = 2; % NE-SW / SW-NE
            % Horizontal/vertical connections == 0
            
            % Unique nodes (e) and number of edges (NEDGE)
            T0 = [DIN.IX(1:end-1),DIN.IX(2:end)];
            T0(sum(isnan(T0),2)==1,:) = NaN; % rows with one NaN become NaN
            ix = not(isnan(T0(:,1)));
            T1 = T0(ix,:); % without NaNs
            [e,~,f] = unique([T0(ix,1);T0(ix,2)],'rows','stable');
            CTS = [e accumarray(f,1)];
            NEDGE.Z(CTS(:,1)) = CTS(:,2);
            
            % Unique segment termini and number of appearances
            M = onl2struct(DIN.IX);
            st = [M.st];
            [e,~,f] = unique(st(:),'stable');
            STIX = [e accumarray(f,1)];
            NST.Z(STIX(:,1)) = STIX(:,2);
            
            % Identify junctions 
            % (more than two divide edges and no crossing river)
            DOUT.jct = find(NEDGE.Z>2 & FX.Z==0);
            DOUT.jctedg = NEDGE.Z(DOUT.jct);
        
            % Identify broken segments
            % (the following cases are clearly identified)
            ixdseg = find((NEDGE.Z==2 & NST.Z==2 & FX.Z==0) | ... 
                (NEDGE.Z==4 & NST.Z==2 & FX.Z>0) | ...
                (NEDGE.Z==4 & NST.Z==4 & FX.Z>0) | ...
                (NEDGE.Z==3 & NST.Z==3 & FX.Z>0));
            % Distinguish between endpoints and broken segments 
            % (at NEDGE==2,NST==2,FX>0 both are possible)
            ix = find(NEDGE.Z==2 & NST.Z==2 & FX.Z>0);
            L = nan(numel(ix),1);
            smallres = 0.1*cs;
            for i = 1 : length(ix)
                [r,c] = find(T1==ix(i));
                x1 = XD(T1(r(1),3-c(1))); % 3-c=2 if c=1 and 3-c=1 if c=2
                y1 = YD(T1(r(1),3-c(1)));
                x2 = XD(T1(r(2),3-c(2)));
                y2 = YD(T1(r(2),3-c(2)));
                dx = x2-x1;
                dy = y2-y1;
                if min(abs([dx,dy]))>smallres % else, points are 2*cs apart
                    L(i) = (abs(dx+dy)>cs)+1;
                end
            end
            isep = abs(L-FX.Z(ix));
            isep(isnan(isep)) = 1;
            newix = not(logical(isep));
            ixdseg = [ixdseg; ix(newix)];
            
            if (0) % JUST FOR TESTING 
               
                [tx,ty] = ind2coord(D,vertcat(M.IX));

                [dsx,dsy] = ind2coord(D,ixdseg);
                nix = find(NEDGE.Z==2 & NST.Z==2 & FX.Z>0);
                [nx,ny] = ind2coord(D,nix);

                close all
                clear ax
                figure('Position',[30 101 1335 654])
                for sp = 1 : 4
                    subplot(2,2,sp)
                    switch sp
                        case 1; imagesc(FX), title('diagonal flow')
                        case 2; imagesc(NEDGE), title('number of edges')
                        case 3; imagesc(NST), title('number of segment termini')
                        case 4; imagesc(STG), title('stream grid')
                    end
                    colorbar
                    hold on
                    plot(ST,'color','r','LineWidth',1.5)
                    ax(sp) = gca;
                    plot(tx,ty,'ko-','LineWidth',1.5)
                    scatter(dsx,dsy,100,'yo','filled')
                    %scatter(nx,ny,100,'co','filled')
                    %scatter(izx,izy,100,'go','filled')
                    xlim(xlims)
                    ylim(ylims)
                end
                linkaxes(ax)

            end
            
            % Merge broken segments
            M = onl2struct(DIN.IX);
            for i = 1 : length(M)
                ix = ismember(M(i).st,ixdseg);
                M(i).dead_st = ix;
            end
            allst = vertcat(M.st);
            dst = allst(vertcat(M.dead_st));
            udst = unique(dst(:));
            [M.tag] = deal(true);
            for i = 1:length(udst) 
                this_dst = udst(i);
                [r,c] = find(allst==this_dst);
                if length(r)==2 % 2 segment termini
                    ix1 = M(r(1)).IX(1:end-1);
                    ix2 = M(r(2)).IX(1:end-1);
                    if c(1) == 1
                        ix1 = flip(ix1);
                    end
                    if c(2) == 2
                        ix2 = flip(ix2);
                    end
                    % Merge segments
                    M(r(1)).IX = [ix1;ix2(2:end);NaN];
                    M(r(1)).st = M(r(1)).IX([1,end-1])';
                    M(r(2)).tag = false;

                elseif length(r)>2 % 3 or 4 segment termini
                    % Get adjacent nodes
                    [tr,tc] = ind2sub(DIN.size,this_dst);
                    % as a function of the orientation of the flow
                    k = FX.Z(this_dst);
                    switch k
                        case 1 % 1 = NW-SE
                            p1 = [tr-1,tc;tr,tc+1];
                            p2 = [tr,tc-1;tr+1,tc];
                        case 2 % 2 = NE-SW
                            p1 = [tr-1,tc;tr,tc-1];
                            p2 = [tr,tc+1;tr+1,tc];
                    end
                    p{1} = sub2ind(DIN.size,p1(:,1),p1(:,2));
                    p{2} = sub2ind(DIN.size,p2(:,1),p2(:,2));
                    % Find and merge segments (once or twice)
                    for g = 1 : 2
                        m = nan(1,2); ct = 0;
                        for j = 1 : length(r)
                            tix = M(r(j)).IX(1:end-1);
                            if c(j)==2 % flip to have this_dst on top
                                tix = flip(tix);
                            end
                            % check if next node after this_dst is on this
                            % side of the flow path
                            ax = ismember(p{g},tix(2));
                            if any(ax)
                                ax = find(ax,1);
                                ct = ct+1;
                                m(ct) = j;
                                p{g}(ax) = [];
                            end
                        end
                        if isempty(p{g})
                            ix1 = M(r(m(1))).IX(1:end-1);
                            ix2 = M(r(m(2))).IX(1:end-1);
                            if c(m(1)) == 1
                                ix1 = flip(ix1);
                            end
                            if c(m(2)) == 2
                                ix2 = flip(ix2);
                            end

                            % Merge segments
                            M(r(m(1))).IX = [ix1;ix2(2:end);NaN];
                            M(r(m(1))).st = M(r(m(1))).IX([1,end-1])';
                            M(r(m(2))).tag = false;
                            % remove segments from searchable list
                            [r,rix] = setdiff(r,r(m(:)));
                            c = c(rix);
                            if isscalar(r)
                                break;
                            end
                        end
                    end

                end
                % Remove redundant segments
                tags = [M.tag];
                M = M(tags);
                allst = vertcat(M.st);
            end
            M = onl2struct(vertcat(M.IX)); % Update structure
            
            % Insert breaks at junctions
            for i = 1:length(M)
                ix = M(i).IX(1:end-1);
                tix = ix;
                tix([1 end]) = NaN; % omit segment termini
                iy = find(ismember(tix,DOUT.jct));
                if nnz(iy)>0
                    iy = [1;iy(:);length(ix)];
                    NM = struct;
                    for k = 1 : length(iy)-1
                        NM(k).IX = [ix(iy(k):iy(k+1));NaN];
                    end
                    M(i).IX = vertcat(NM.IX);
                end
            end
            M = onl2struct(vertcat(M.IX)); % Update structure
            

            DOUT.IX = vertcat(M.IX);
            st = [M.st];
            DOUT.ep = setdiff(st(:),DOUT.jct);

        end
        

        function [tx,ty] = getdivide(D,tx,ty,tout,mx,my,hcs)
            % This function inserts NaNs into basin outlines where these
            % cross rivers, and makes sure the lines start at such a break.

            % split divide edges crossing rivers (insert nans where
            % divide edge midpoints == flow edge midpoints)
            tmx = (tx(1:end-1)+tx(2:end))./2;
            tmy = (ty(1:end-1)+ty(2:end))./2;
            %ix = ismember([tmx,tmy],[mx,my],'rows');
            ix = ismembertol([tmx,tmy],[mx,my],1e-12,'ByRows',true);
            iy = find(ix);
            [~,isort] = sort([(1:numel(tx))';iy]);
            tx = [tx;nan(numel(iy),1)];
            ty = [ty;nan(numel(iy),1)];
            tx = tx(isort);
            ty = ty(isort);

            % identify divide nodes on river edges
            %ix = ismember([tx,ty],[mx,my],'rows');
            ix = ismembertol([tx,ty],[mx,my],1e-12,'ByRows',true);
            iy = find(ix);

            % insert nans and duplicate point
            [~,isort] = sort([(1:numel(tx))';repmat(iy,2,1)]);
            tx = [tx;nan(numel(iy),1);tx(iy)];
            ty = [ty;nan(numel(iy),1);ty(iy)];
            tx = tx(isort);
            ty = ty(isort);

            % Check for endorheic drainage
            isendo = false;
            if not(isnan(tout))

                % Check for internal drainage
                % (by comparing the corner coordinates of the outlet pixels with basin outlines)
                %[outx,outy] = ind2coord(STG,MS(i).outlet_id);
                fx = [tout(1)-hcs,tout(1)-hcs,tout(1)+hcs,tout(1)+hcs];
                fy = [tout(2)-hcs,tout(2)+hcs,tout(2)-hcs,tout(2)+hcs];
                fi = nan(size(fx));
                fi(:) = coord2ind(D,fx,fy);
                tix = coord2ind(D,tx,ty);
                ix = ismember(fi,tix);
                % endorheic drainages have outlets that don't intersect the catchment outlines
                isendo = not(any(ix,2));

                if (isendo)
                    warning('Warning: found endorheic drainage. Results may be erroneous.')
                else
                    iy = ismember(tix,fi(ix)','rows');
                    %iy = ismember([tx,ty],[fx(ix)',fy(ix)'],'rows');
                    tx(iy) = nan;
                    ty(iy) = nan;
                end

            end

            % remove redundant nan
            IX = isnan(tx);
            JX = [IX(2:end);true];
            IJ = logical(min([IX JX],[],2));
            tx = tx(not(IJ));
            ty = ty(not(IJ));

            % reorder
            if not(isendo)
                ix = find(isnan(tx),1,'first');
                if not(isempty(ix))
                    tx = [tx(ix+1:end);tx(1:ix)];
                    ty = [ty(ix+1:end);ty(1:ix)];
                end
            end

            % remove duplicate nodes
            dtx = tx(1:end-1)-tx(2:end);
            dty = ty(1:end-1)-ty(2:end);
            ix = not(dtx==0 & dty==0);
            tx = [tx(ix);NaN];
            ty = [ty(ix);NaN];

            if (0) % JUST FOR TESTING
                close all
                plot(ST)
                hold on
                % plot segments in alternating colors
                ii = [1;find(isnan(tx))];
                cols = {'m-','g-'};
                for j = 1 : numel(ii)-1
                    plot(tx(ii(j):ii(j+1)),ty(ii(j):ii(j+1)),...
                        cols{mod(j,2)+1},'LineWidth',1);
                end
                % plot points that occur more than once
                ii = coord2ind(D,tx,ty);
                for j = 1 : numel(ii)
                    ix = find(ii==ii(j));
                    if numel(ix)==2
                        scatter(tx(j),ty(j),50,'red','filled')
                    elseif numel(ix)==3
                        scatter(tx(j),ty(j),50,'cyan','filled')
                    end
                    hold on
                end

            end

        end


    end
end

