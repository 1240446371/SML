function [estimate, varargout] = gmm_em(data, varargin) 
  
 % default parameters 
 conf = struct(... 
     'maxloops', 500, ... 
     'thr', 1e-10, ... 
     'verbose', 0, ... 
     'components', 8, ... 
     'logging', 0, ... 
     'init', 'fcm1' ... 
     ); 
  
 if nargout>1 
     conf.logging = 1; 
     varargout{1} = []; 
 end 
  
 conf = getargs(conf, varargin); 
  
 if nargout<2 
     conf.logging=0; 
 end 
 log_covfixer2 = {}; 
 log_loglikes = {}; 
 log_initialmix = {}; 
 log_mixtures = {}; 
  
  
 % --- initialization --- 
 
 N = size(data,1);    % number of points 
 D = size(data,2);    % dimensions 
 C = conf.components; 
  
 % ��������
 if isreal(data) 
     Nparc = D+D*(D+1)/2; 
 else 
     Nparc = 2*D + D*D; 
 end 
 N_limit = (Nparc+1)*3*C; 
 if N < N_limit 
     %warning_wrap('gmmb_em:data_amount', ... 
     % ['Training data may be insufficient for selected ' ... 
     % 'number of components. ' ... 
     %   'Have: ' num2str(N) ', recommended: >' num2str(N_limit) ... 
     %   ' points.']); 

 end 
  
 switch lower(conf.init) 
     case 'fcm1' 
         initS = gmmb_em_init_fcm1(data, C, conf.verbose); 
     case 'cmeans1' 
         initS = gmmb_em_init_cmeans1(data, C); 
     case 'cmeans2' 
         initS = gmmb_em_init_cmeans2(data, C); 
     otherwise 
         error(['Unknown initializer method: ' conf.init]); 
 end 
  
  
 if any(initS.weight == 0) 
     error('Initialization produced a zero weight.'); 
 end 
  
 mu = initS.mu; 
 sigma = initS.sigma; 
 weight = initS.weight; 
 
 log_initialmix = initS; 
 fixerloops = zeros(1, C); 

 old_loglike = -realmax; 
  
 loops=1; 
 fixing_cycles = 0; 
  
 tulo = gmmcpdf(data, mu, sigma, weight); 
  
 while 1 
     % EM�㷨 
     pcompx = tulo ./ (sum(tulo,2)*ones(1,C)); 
      
     if ~all( isfinite(pcompx(:))  ) 
         error('Probabilities are no longer finite.'); 
     end 
      
     for c = 1:C 
         psum = sum(pcompx(:,c));  
         weight(c) = 1/N*psum;  % weight
         % mean 
         nmu = sum(data.*(pcompx(:,c)*ones(1,D)), 1).' ./ psum; 
         mu(:,c) = nmu; 
       
         % covariance 
         moddata = (data - ones(N,1)*(nmu.')) .* (sqrt(pcompx(:,c))*ones(1,D)); 
         % sqrt(pcompx) is because it will be squared back 
         nsigma = (moddata' * moddata) ./ psum; 
          
         % covariance matrix goodness assurance 
         [sigma(:,:,c), fixerloops(1,c)] = covfixer2(nsigma);  
     end 
      
     % test���̽���
     tulo = gmmcpdf(data, mu, sigma, weight); 
     loglike = sum(log(sum(tulo, 2)+realmin)); 
      
     if conf.verbose ~= 0 
         disp([ 'log-likelihood diff ' num2str(loglike-old_loglike)  ' on round ' num2str(loops) ]); 
     end 
      
     if conf.logging>0 
         log_covfixer2{loops} = fixerloops; 
         log_loglikes{loops} = loglike; 
     end 
     if conf.logging>1 
         log_mixtures{loops} = struct(... 
             'weight', weight, ... 
             'mu', mu, ... 
             'sigma', sigma); 
     end 
  
     if any(fixerloops ~= 0) 
         fixing_cycles = fixing_cycles +1; 
         if conf.verbose ~= 0 
             disp(['fix cycle ' num2str(fixing_cycles) ... 
                   ', fix loops ' num2str(fixerloops)]); 
         end 
     else 
         % no cov's were fixed this round, reset the counter 
         % and evaluate threshold. 
         fixing_cycles = 0; 
         if (abs(loglike/old_loglike -1) < conf.thr) 
             break; 
         end 
     end 
      
     if fixing_cycles > 100 %%wy �޸���20----100
      %warning_wrap('gmmb_em:fixing_loop', ... 
      %          ['A covariance matrix has been fixed repeatedly' ... 
      %          ' too many times, quitting EM estimation.']); 
         break; 
     end 
      
     if loops >= conf.maxloops 
         break; 
     end 
  
     loops = loops +1; 
     old_loglike = loglike; 
 end 
  
  
  
 estimate = struct('mu', mu,... 
         'sigma', sigma,... 
         'weight', weight); 
  
 if conf.logging>1 
     varargout{1} = struct(... 
         'iterations', {loops}, ... 
         'covfixer2', {cat(1,log_covfixer2{:})}, ... 
        'loglikes', {cat(1,log_loglikes{:})}, ... 
         'initialmix', {log_initialmix}, ... 
         'mixtures', {log_mixtures}); 
 end 
 if conf.logging == 1 
     varargout{1} = struct(... 
         'iterations', {loops}, ... 
         'covfixer2', {cat(1,log_covfixer2{:})}, ... 
         'loglikes', {cat(1,log_loglikes{:})} ); 
 end 
  
  
 % ------------------------------------------ 
  
 function tulo = gmmcpdf(data, mu, sigma, weight) 
 N = size(data, 1); 
 C = size(weight,1); 
  
 pxcomp = zeros(N,C); 
 for c = 1:C 
     pxcomp(:,c) = cmvnpdf(data, mu(:,c).', sigma(:,:,c)); 
 end 
 tulo = pxcomp.*repmat(weight.', N,1); 
 
 
 function [pclass, clust]=gmmb_cmeans(pdata,nclust,count);

rp = randperm(size(pdata,1));
clust = pdata(rp(1:nclust),:);

for kierros=1:count,
	% compute squared distance from every point to every cluster center.
	for i=1:nclust,
		vd = pdata - repmat(clust(i,:),size(pdata,1),1);
		cet(:,i) = sum(abs(vd).^2, 2);
	end;

	% compute new cluster centers
	[a, pclass]=min(cet');

	for i=1:nclust,
		clust(i,:) = mean( pdata(find(pclass==i), :) );
	end;
end;

 function initS = gmmb_em_init_cmeans1(data, C)
 
 D = size(data,2);    % dimensions
 if C>1
     [lbl, mu] = gmmb_cmeans(data, C, 15);
     % initialization has random nature, results will vary
 else
     %lbl = ones(size(data, 1), 1);
     mu = mean(data, 1);
 end

 % covariances initialization
 nsigma = covfixer2(diag(diag(cov(data))));
 sigma = zeros(D,D,C);
 for c = 1:C
     sigma(:,:,c) = nsigma;
 end
 
 % weights initialization
 weight = ones(C,1) * (1/C);
 
 initS = struct(...
     'mu', mu.', ...
     'sigma', sigma, ...
     'weight', weight ...
     );

 
  function initS = gmmb_em_init_fcm1(data, C, verbose);
 
 D = size(data,2);    % dimensions

 % mu = zeros(D,C);
 
 % mus initialization (thanks V. Kyrki)
 if C>1
     mu = fcm(data, C, [2.0 100 1e-3 verbose]).';
     % fcm initialization has random nature, results will vary
 else
     mu = mean(data, 1).';
 end
 % covariances initialization
 nsigma = covfixer2(diag(diag(cov(data))));
 sigma = zeros(D,D,C);
 for c = 1:C
     sigma(:,:,c) = nsigma;
 end
 % weights initialization
 weight = ones(C,1) * (1/C);

 initS = struct(...
     'mu', mu, ...
     'sigma', sigma, ...
     'weight', weight ...
     );

 
 function mix = gmminitial(x,options,label,ncentres,covar_type,ppca_dim)
 if nargin < 3 
    ncentres = 32; 
    cov_type = 'diag'; 
elseif nargin < 4 
    cov_type = 'diag'; 
end     
 
[nx,xdim] = size(x); 
mix.type = 'gmm'; 
mix.nin = xdim; 
mix.ncentres = ncentres; 
mix.label = label; 
vartypes = {'spherical', 'diag', 'full', 'ppca'}; 
if sum(strcmp(covar_type, vartypes)) == 0  % ��ĳһ�ַ����Ͷ���ַ������бȽϵļ��� 
    error('Undefined covariance type'); 
else 
    mix.covar_type = covar_type; 
end 
 
% Use kmeans algorithm to set centres 
options(5) = 1; 
% Initialize centres 
centres = randn(ncentres, mix.nin); 
[mix.centres,post,options] = mykmeans(centres,x,options); 
cluster_size = sum(post,1); 
mix.priors = cluster_size / sum(cluster_size);  
 
% Arbitrary width used if variance collapses to zero: make it 'large' so 
% that centre is responsible for a reasonable number of points. 
GMM_WIDTH = eps; 
 
switch mix.covar_type 
    case 'spherical' 
        if mix.ncentres > 1 
      % Determine widths as distance to nearest centre  
      % (or a constant if this is zero) 
            cdist = dist2(mix.centres,mix.centres); 
            cdist = cdist + diag(realmax * ones(mix.ncentres,1)); %��cdist�ĶԽ�Ԫ����� 
            mix.covars = min(cdist); %ÿһ�����ӿռ��Э�������Ϊ��λ��˱������ʽ���Ҫ������Э������������һ����СΪ������������������ 
            mix.covars = mix.covars + GMM_WIDTH*(mix.covars < eps); % 
        else 
      % Just use variance of all data points averaged over all 
      % dimensions 
            mix.covars = mean(diag(cov(x))); 
        end 
            mix.nwts = mix.ncentres + mix.ncentres*mix.nin + mix.ncentres; %��˳������Ϊ��� mix.priors��mix.centres�� mix.covars������ڴ�ռ���Ŀ 
    case 'diag' 
        mix.covars =  []; 
        %ncentres = mix.ncentres; 
        %centres = mix.centres; 
        for j = 1:mix.ncentres 
      % Pick out data points belonging to this centre 
            c = x(find(post(:,j)),:);  
            if size(c,1) == 0 %(nx/mix.ncentres)*1E-1 
                warning(['the ',num2str(j),'th is zero cluster']); 
                %mix.priors(j) = []; 
                %centres(j,:) = []; 
                %ncentres = ncentres - 1; 
                mix.covars = [mix.covars;eps*ones(1,mix.nin)]; 
            else     
                diffs = c - (ones(size(c,1), 1) * mix.centres(j,:)); 
                covj = sum((diffs.*diffs),1)/size(c,1); 
            end%XX
        end %XXX
                %if ~any(covj>eps) 
                    %warning('some identical input train data'); 
                    %centres(j,:) = []; 
                    %mix.priors(j) = []; 
                    %ncentres = ncentres - 1; 
                %elseif any(covj>eps) 
                    %mix.covars = [mix.covars;covj]; 
                %else 
                if any(covj < eps^2) 
                    warning('some bad input train data'); 
                    covj = covj + GMM_WIDTH*(covj +mix.nin )
            error('Dimension of PPCA subspaces must be less than data.') 
        end 
        mix.ppca_dim = ppca_dim; 
        mix.covars = 0.1*ones(1, mix.ncentres);%?????? 
        init_space = eye(mix.nin); 
        init_space = init_space(:, 1:mix.ppca_dim); 
        init_space(mix.ppca_dim+1:mix.nin, :) = ... 
            ones(mix.nin - mix.ppca_dim, mix.ppca_dim); 
        mix.U = repmat(init_space , [1 1 mix.ncentres]); 
        mix.lambda = ones(mix.ncentres, mix.ppca_dim); 
        mix.nwts = mix.ncentres + mix.ncentres*mix.nin + ...%������ֱ�Ϊ 
        mix.ncentres + mix.ncentres*mix.ppca_dim + ...      %mix.covars�� 
        mix.ncentres*mix.nin*mix.ppca_dim;                  %mix.lambda��  
        for j = 1:mix.ncentres                              %mix.U�ڴ濪�� 
      % Pick out data points belonging to this centre 
            c = x(find(post(:,j)),:); 
            diffs = c - (ones(size(c, 1), 1) * mix.centres(j, :)); 
            [tempcovars, tempU, templambda] = ... 
                ppca((diffs'*diffs)/size(c, 1), mix.ppca_dim);  
            if length(templambda) ~= mix.ppca_dim 
	            error('Unable to extract enough components'); 
            else  
                mix.covars(j) = tempcovars; 
                mix.U(:, :, j) = tempU; 
                mix.lambda(j, :) = templambda; 
            end 
        end 
    otherwise 
        error(['Unknown covariance type ', mix.covar_type]); 
end 




