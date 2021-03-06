function varargout = plotclassification(obj, varargin)
   [classes, ncomp, varargin] = classres.getClassPlotParams(obj.nClasses, obj.nComp, obj.classNames, varargin{:});

   cref = copy(obj.cref);
   cpred = copy(obj.cpred_);

   excludedRows = cpred.excludedRows;   
   classNames = obj.classNames(classes);
   
   cref.includerows(excludedRows);
   cpred.includerows(excludedRows);
   
   if isempty(cpred.wayFullNames{1})
      objNames = textgen('', 1:size(cpred, 1))';
   else   
      objNames = cpred.wayFullNames{1};
   end
   
   values = squeeze(obj.cpred_.values_(:, :, ncomp));   
   
   x = (1:size(values, 1))';
   ind_none = true(size(x, 1), 1);
   
   plotData = [];
   refData = [];
   plotObjNames = {};
   plotExcludedRows = [];
   refData = [];
   
   for i = classes
      ind = values(:, i) == 1;
      if any(ind)
         plotData = [plotData; [x(ind), i * ones(sum(ind), 1)]];
         
         if isempty(plotObjNames)
            plotObjNames = objNames(ind);
         else
            plotObjNames = [plotObjNames; objNames(ind)];
         end
         
         if isempty(refData)
            refData = cref(ind, :);
         else   
            refData = [refData; cref(ind, :)];
         end
         
         per = excludedRows & ind;
         plotExcludedRows = [plotExcludedRows; per(ind)];
      end
      
      ind_none = ind_none & ~ind;      
   end
      
   if any(ind_none)
      plotData = [plotData; [x(ind_none), zeros(sum(ind_none), 1)]];
      plotObjNames = [plotObjNames; objNames(ind_none)];
      refData = [refData; cref(ind_none, :)];
      per = excludedRows & ind_none;
      plotExcludedRows = [plotExcludedRows; per(ind_none)];
   end
   
   plotData = mdadata(plotData);
   plotData.dimNames = {'Objects', 'Classes'};
   plotData.rowFullNamesAll = plotObjNames;
   
   plotExcludedRows = logical(plotExcludedRows);
   if any(plotExcludedRows)
      plotData.excluderows(plotExcludedRows);
      refData.excluderows(plotExcludedRows);
   end
   
   h = gscatter(plotData, refData, varargin{:});
   
   set(gca, 'YTick', [0 classes], 'YTickLabel', ['None', classNames]);
   ylabel('Classes')
   xlabel('Objects')
   
   if ~ishold
      box on
      title('Classification');
      correctaxislim(15, [], [0 max(classes)]);
   end
   
   if nargout > 0
      varargout{1} = h.plot;
   end   
end
