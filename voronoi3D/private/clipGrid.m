function [V, C, symV] = clipGrid(dt,bound)

s = dsearchn(dt.Points,sum(bound.Points(bound.ConnectivityList(1,:),:)/3,1));

Q = [1, s];
V = [];
symV = cell(0);
C = cell(size(dt.Points,1),1);
CT = cell(numel(C),1);
CT{s} = 1;
E = dt.edges;
while ~isempty(Q)
    t =  Q(end,1); s = Q(end,2);
    Q = Q(1:end-1,:);
    NC = [E(:,2)==s, E(:,1)==s];
    bisect = find(any(NC,2));

    NT = findNeighbours(bound.ConnectivityList, t);    %sum(ismember(face2vert,face2vert(t,:)),2)==2;


    n = bsxfun(@minus, dt.Points(E(NC),:), dt.Points(s,:));
    n = bsxfun(@rdivide, n,sqrt(sum(n.^2,2)));
    x0 = bsxfun(@plus, dt.Points(E(NC),:), dt.Points(s,:))/2;


    symT = {-find(any(bound.ConnectivityList==bound.ConnectivityList(t,1),2)); ...
            -find(any(bound.ConnectivityList==bound.ConnectivityList(t,2),2)); ...
            -find(any(bound.ConnectivityList==bound.ConnectivityList(t,3),2))};

    
    [newVertex, symT] = clipPolygon(bound.Points(bound.ConnectivityList(t,:),:),...
                                    n,x0,symT,symV,bisect);
    symV = [symV; symT];
    C{s} = [C{s}, size(V,1)+1:size(V,1)+size(newVertex,1)];
    V = [V;newVertex];
    [Q,CT] = updateQue(Q, symT, CT, E, NC, s, t);    

end



end


function NT = findNeighbours(V, t)
    VT = V(t,:);
    V  = [V(1:t-1,:);nan,nan,nan;V(t+1:end,:)];
    NT = [t;...
          find(sum(ismember(V,VT([1,2])),2)==2);...
          find(sum(ismember(V,VT([2,3])),2)==2);...
          find(sum(ismember(V,VT([3,1])),2)==2)];
end


function [symV] = updateSym(localSym, NC, NT)
    if localSym<0
        symV = -NT(-localSym);
    else
        symV = NC(localSym);
    end
end


function [Q, CT] = updateQue(Q, symV, CT, E, NC, s, t)
    % Find possible new cells
    symV = cell2mat(symV);
    bNew = unique(symV(symV>0));
    tNew = -unique(symV(symV<0));
    for i = 1:numel(bNew)
       if isempty(CT{E(bNew(i),NC(bNew(i),:))}) || ~any(CT{E(bNew(i),NC(bNew(i),:))}==t) %New cell facet pair
           Q = [Q; t, E(bNew(i),NC(bNew(i),:))];
           CT{E(bNew(i),NC(bNew(i),:))} = [CT{E(bNew(i),NC(bNew(i),:))}, t];
       end
    end
    for i = 1:numel(tNew)
        if ~any(CT{s}==tNew(i))
           Q = [Q; tNew(i), s];
           CT{s} = [CT{s}, tNew(i)];
        end
    end
end