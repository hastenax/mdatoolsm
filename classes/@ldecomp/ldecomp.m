classdef ldecomp < handle

   properties 
      info
   end
   
   properties (SetAccess = 'protected')
      scores
      variance
      modpower
      T2
      Q2
   end
   
   properties (SetAccess = 'protected', Hidden = true)
      tnorm
      totvar
   end
   
   methods
      function obj = ldecomp(scores, loadings, data, tnorm, totvar, Q2, T2, modpower)                           
%          if ~isa(scores, 'mdadata') || ~isa(loadings, 'mdadata') || ~isa(data, 'mdadata')
%             error('The arguments should be objects of class MDADATA!');
%          end
         
         obj.scores = scores;
         
         if nargin < 8
            modpower = [];
         end
         
         if nargin < 4
            tnorm = [];
         end
         
         if nargin < 5 || isempty(totvar)
            obj.totvar = sum(data.values(:).^2);
         else
            obj.totvar = totvar;
         end   
         
         if nargin < 6
            [T2, Q2, modpower, tnorm] = ldecomp.getDistances(scores, loadings, data, tnorm);            
         end
         
         obj.T2 = T2;
         obj.Q2 = Q2;
         obj.tnorm = tnorm;
         obj.modpower = modpower;         
         obj.variance = ldecomp.getVariance(Q2, obj.totvar);
      end   

      function set.info(obj, value)
         if ~ischar(value)
            error('Parameter "info" should have a text value!');
         end
         obj.info = value;
      end
      
      function summary(obj)
         if ~isempty(obj.info)
            fprintf('\n%s', obj.info);
         end         
         show(obj.variance);
      end   
   end
   
   methods (Static = true)
      
      function [T2, Q2, modpower, tnorm] = getDistances(scores, loadings, data, tnorm)
      % calculate residual distances, modelling power and singular values
      % for scores
      
         excludedRows = scores.excludedRows;
         
         svalues = scores.valuesAll;
         data = data.valuesAll(:, ~(data.excludedCols | data.factorCols));
         loadings = loadings.values;
         
         if nargin < 4
            tnorm = [];
         elseif ~isempty(tnorm)
            tnorm = tnorm.valuesAll;
         end
         
         [nObj, nComp] = size(svalues);
   
         T2 = zeros(nObj, nComp);
         Q2 = zeros(nObj, nComp);
         modpower = zeros(nObj, nComp);
      
         % calculate singular values for scores
         % without taking into account excluded data
         if isempty(tnorm)
            tnorm = sqrt(sum(svalues(~excludedRows, :).^2)/(sum(~excludedRows) - 1));
         end
         
         % calculate normalized scores         
         scoresn = bsxfun(@rdivide, svalues, tnorm);  
   
         if nObj > 1
            datasd = sqrt(sum(data .^2)/(nObj - 1));
         end
         
         % calculate distances for each set of components
         for i = 1:nComp
            exp = svalues(:, 1:i) * loadings(:, 1:i)';
            res = data - exp;
         
            Q2(:, i) = sum(res.^2, 2);
            T2(:, i) = sum(scoresn(:, 1:i).^2, 2);
      
            if nObj > i
               modpower(:, i) = 1 - sqrt(sum(res.^2)/(nObj - i - 1))/datasd;
            end
         end

         % set up datasets for output
         if isa(scores, 'mdaimage')            
            T2 = reshape(T2, scores.height, scores.width, scores.nCols);
            T2 = mdaimage(T2, scores.colNames);
            Q2 = reshape(Q2, scores.height, scores.width, scores.nCols);
            Q2 = mdaimage(Q2, scores.colNames);
         else   
            T2 = mdadata(T2, scores.rowNamesAll, scores.colNames);
            T2.rowFullNames = scores.rowFullNamesAll;
            Q2 = mdadata(Q2, scores.rowNamesAll, scores.colNames);
            Q2.rowFullNames = scores.rowFullNamesAll;
         end
         
         T2.name = 'T2 residuals';
         T2.dimNames = scores.dimNames;
         T2.colFullNames = scores.colFullNames;
         T2.excluderows(excludedRows);

         Q2.name = 'Q2 residuals';
         Q2.dimNames = scores.dimNames;
         Q2.colFullNames = scores.colFullNames;
         Q2.excluderows(excludedRows);

         tnorm = mdadata(tnorm, {'tnorm'}, scores.colNames, {'tnorm', scores.dimNames{2}});
         tnorm.name = 'Singular values for scores';
         tnorm.colFullNamesAll = scores.colFullNamesAll;

         modpower = mdadata(modpower, scores.rowNamesAll, scores.colNames, scores.dimNames);
         modpower.name = 'Modelling power';
         modpower.rowFullNamesAll = scores.rowFullNamesAll;
         modpower.colFullNamesAll = scores.colFullNamesAll;
         modpower.excluderows(excludedRows);         
      end
      
      function variance = getVariance(Q2, totvar)
         cumresvar = sum(Q2.values, 1) / totvar * 100;
         cumexpvar = 100 - cumresvar;
         expvar = [cumexpvar(1), diff(cumexpvar)];   
         
         variance = mdadata([expvar; cumexpvar], {'Expvar', 'Cumexpvar'});
         variance.dimNames = {'Variance', Q2.dimNames{2}};
         variance.name = 'Variance';
         variance.colNames = Q2.colNames;
         variance.colFullNamesAll = Q2.colFullNamesAll;
         variance = variance';
      end
   
      function limits = getResLimits(data, model)
         colNames = model.loadings.colNames;
         colFullNames = model.loadings.colFullNames;
         
         nObj = data.nRows;
         nVar = data.nNumCols;
         nComp = model.nComp;
         alpha = model.alpha;
         
         if nargin < 4
            alpha = 0.05;
         end
         
         % calculate T2 limits using Hotelling T2 statistics
         T2lim = zeros(1, nComp);
         for i = 1:nComp
            if nObj == i
               T2lim(i) = 0;
            else
               T2lim(i) = (i * (nObj - 1) / (nObj - i)) * mdafinv(1 - alpha, i, nObj - i);  
            end
         end
         
         % calculate Q2 limits using F statistics
         Q2lim = zeros(1, nComp);
         
         conflim = 100 - alpha * 100;   
         cl = 2 * conflim - 100;
   
         nValues = min(nObj, nVar);
         eigenvalues = model.eigenvalues.values;
         if numel(eigenvalues) < nValues
            % calculate eigenvalues for other possible components
            residuals = data.numValues - model.calres.scores.values * model.loadings.values';
            [~, s, ~] = svd(residuals, 0);
            e = (diag(s).^2)/(size(residuals, 1) - 1);
            eigenvalues = [eigenvalues; e(1:nValues - numel(eigenvalues))];
         end
         
         for i = 1:nComp
            if i < nValues
               evals = eigenvalues((i + 1):nValues);         
         
               t1 = sum(evals);
               t2 = sum(evals.^2);
               t3 = sum(evals.^3);
               h0 = 1 - 2 * t1 * t3/3/(t2^2);
         
               if (h0 < 0.001)
                  h0 = 0.001;
               end
               
               ca = sqrt(2) * erfinv(cl/100);
               h1 = ca * sqrt(2 * t2 * h0^2)/t1;
               h2 = t2 * h0 * (h0 - 1)/(t1^2);
               
               Q2lim(i) = t1 * (1 + h1 + h2)^(1/h0);
            else
               Q2lim(i) = 0;
            end   
         end
         
         limits = mdadata([T2lim; Q2lim], {'T2', 'Q2'}, colNames, {'Limits', 'Components'});
         limits.name = 'Statistical limits for residuals';
         limits.colFullNamesAll = colFullNames;         
      end   
   end   
end
