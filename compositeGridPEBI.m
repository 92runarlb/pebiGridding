function varargout = compositeGridPEBI(dims, pdims, varargin)
    nx = dims(1);
    ny = dims(2);
    
    dx = pdims(1)/(nx - 1);
    dy = pdims(2)/(ny - 1);

    
    opt = struct('padding', 1, ...
                 'lines', {{}}, ...
                 'circleFactor', 0.6);
         
    opt = merge_options(opt, varargin{:});

    circleFactor = opt.circleFactor;
    assert(0.5<circleFactor && circleFactor < 1)
    
    Pts = [];
    priIndex = [];
    gridSpacing = [];
    faultType = zeros(size(Pts, 1), 1);
    for i = 1:numel(opt.lines)
        l = opt.lines{i};
        
        assert(all(size(l) == [2 2]));
        p1 = l(1, :);
        p2 = l(2, :);
        
        v = p2 - p1;
        
        dists = norm(v, 2)/norm([dx, dy], 2);
        dists = max(ceil(dists), 2);
        
        % Expand into a vector
        l = p1;
        for j = 1:dists
            l = [l; p1 + v*j/dists]; % Should move this into the nex foor loop
        end
        
        % Create left vector and right vector(to contain fracture points).
        left = zeros(dists, 2);
        right = zeros(dists, 2);

        for j=1:dists
            line_length = norm(l(j+1,:)-l(j,:), 2);   %||p_(j+1) - p_j||
            n1 = (l(j+1,:)-l(j,:))/line_length;       %Unit vector
            n2 = [-n1(2), n1(1)];                     %Unit normal
            fracture_radius = line_length/2*sqrt(4*circleFactor^2 -1);  %% OBS! Should make sure fracture points are equaly spaced.
            left(j,:) = l(j,:) + line_length/2*n1 + fracture_radius*n2;
            right(j,:) = l(j,:) + line_length/2*n1 - fracture_radius*n2;
        end

        nl = 2*size(left, 1);
        Pts = [Pts;left;right];
        priIndex = [priIndex; (2+i)*ones(nl,1)];
        gridSpacing = [gridSpacing; (2-100*eps)*fracture_radius*ones(nl,1)];
        plot(left(:,1),left(:,2), 'b.');
        plot(right(:,1), right(:,2), 'r.');
    end
    
    vx = 0:dx:pdims(1);
    vy = 0:dy:pdims(2);
    [X, Y] = meshgrid(vx, vy);


    [ii, jj] = meshgrid(1:nx, 1:ny);

    nedge = opt.padding;
    exterior = (ii <= nedge | ii > nx - nedge) | ...
               (jj <= nedge | jj > ny - nedge);

    interior = ~exterior;

    X(interior) = X(interior);
    Y(interior) = Y(interior);

    resPts = [X(:), Y(:)];
    Pts = [Pts;resPts];
    priIndex = [priIndex; ones(size(Pts, 1), 1)];
    gridSpacing = [gridSpacing; (min(dx,dy)-100*eps)*ones(size(Pts,1),1)];
    
    
    [Pts, removed] = removeConflictPoints(Pts, gridSpacing, priIndex);
 
    Tri = delaunayTriangulation(Pts);
    
    G = triangleGrid(Pts, Tri.ConnectivityList);

    G = pebi(G);
    plot(Pts(:,1),Pts(:,2), 'o')

    varargout{1} = G;
    if nargout > 1
        varargout{2} = indicator;
    end
end


function [Pts, removed] = removeConflictPoints(Pts, gridSpacing, priIndex)
    Ic = 1:size(Pts, 1);
    ptsToClose = Pts;
    removed = zeros(size(Pts, 1), 1);
    
    distance = pdist(ptsToClose)';
    dlt = distLessThan(distance, gridSpacing(Ic));
    Ic = findToClose(dlt);
    
    while length(Ic)>1
        sumToClose = sumToClosePts(dlt);
        sumToClose = sumToClose(find(sumToClose));
        [~, Is] = sort(sumToClose,'descend');
        [~, Ii ] = sort(priIndex(Ic(Is)), 'ascend');

        removePoint = Ic(Is(Ii(1)));
        removed(removePoint) = 1;        
        Ic = Ic(Ic~=removePoint);
        ptsToClose = Pts(Ic,:);
        
        if size(ptsToClose,1) ==1
            continue
        end
        distance = pdist(ptsToClose)';
        dlt = distLessThan(distance, gridSpacing(Ic));
        Ic = Ic(findToClose(dlt));
    end
    Pts = Pts(~removed,:);
end


function [arr] = distLessThan(distance, b)
    n = length(distance);
    [i,j] = arrToMat(1:n, n);
    arr = distance < max(b(i), b(j));
end

function [pts] = sumToClosePts(arr)
    n = length(arr);
    m = ceil(sqrt(2*n)); % = 0.5 + 0.5sqrt(1+8n) for n > 0
    pts = zeros(m,1);
    for i = 1:m
        k1 = matToArr(i+1:m, i, m);
        k2 = matToArr(i,1:i-1, m);
        pts(i) = sum(arr(k1)) + sum(arr(k2)); 
    end
end

function indexes = findToClose(arr)
    n = length(arr);
    k = find(arr);
    [i, j] = arrToMat(k, n);
    indexes = unique([i ; j]);
end

function [k] = matToArr(i,j, m)
    assert(all(abs(j)) && all(abs(i-j)) && all(abs(1+m-i)));
    k = 1 + (j-1)*m - (j-1).*j/2 + i-j - 1;
end

function [i, j] = arrToMat(k, n)
    m = ceil(sqrt(2*n));
    j = ceil((2*m-1)/2 - 0.5*sqrt((2*m-1)^2 - 8*k));
    i = k + j - (j-1).*(m-j/2);
end


function [Pts, isNew, removed] = replacePointsByHull(Pts, P_target)
    Tri = delaunayTriangulation(P_target);
    keep = isnan(Tri.pointLocation(Pts));
    
    Pts = [Pts(keep, :); P_target];
    isNew = true(size(Pts, 1), 1);
    isNew(1:sum(keep)) = false;
    
    removed = ~keep;
end
