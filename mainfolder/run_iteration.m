function results = run_iteration(whichmethod, opts, iter)
% mijung wrote on jan 21,2015

% inputs: 
% (1) whichmethod: ssf_kernel_abc (ours), rejection_abc, ssb_abc, and ssf_abc.
% (2) opts:
%            opts.likelihood_func: determine likelihood function
%            opts.true_theta: a vector of true parameters
%            opts.num_obs: # of observations (actual observation)
%            opts.num_theta_samps: # of samples for theta
%            opts.num_pseudodata_samps: # of samples for pseudo-data
%            opts.epsilon_list : list of epsilon to test 
%            opts.prior_var: prior variance to draw theta
% (3) seed number

%% (1) generate observations

if strcmp(num2str(opts.likelihood_func),'like_sigmoid_pw_const')
    op = struct();
    op.likelihood_func = @like_sigmoid_pw_const;
    dat = gen_sigmoid_pw_const(opts.true_theta, opts.num_obs, iter);
end
% figure(2);
% hist(dat.samps)

%% (2) test the chosen algorithm

% op. All options are described in each subfunction below.
op.seed = iter;
op.proposal_dist = @(n)randn(length(opts.true_theta), n)*sqrt(opts.prior_var);
op.epsilon_list = opts.epsilon_list;
op.num_latent_draws = opts.num_theta_samps;
op.num_pseudo_data = opts.num_pseudodata_samps;

if strcmp(num2str(whichmethod),'ssf_kernel_abc')
    
    %% (1) ssf_kernel_abc
    
    % width squared.
    % width2 = meddistance(dat.samps)^2/2;
    width2 = meddistance(dat.samps)/2;
    op.mmd_kernel = KGaussian(width2);
    op.mmd_exponent = 2;
    
    [R, op] = ssf_kernel_abc(dat.samps, op);
    
    cols = length(opts.true_theta);
    num_eps = length(op.epsilon_list);
    post_mean = zeros(num_eps, cols);
    prob_post_mean = zeros(num_eps, cols);
    
    for ei = 1:num_eps    
        post_mean(ei,:) = R.latent_samples*R.norm_weights(:, ei) ;
        [~, prob_post_mean(ei,:)] = like_sigmoid_pw_const(post_mean(ei,:), 1); 
    end
    
elseif strcmp(num2str(whichmethod),'rejection_abc')
    
    %% (2) rejection_abc
     % additional op for rejection abc
    op.stat_gen_func = @(data) [mean(data, 2) var(data,0,2)];
    op.stat_dist_func = @(stat1, stat2) norm(stat1 - stat2);
    op.threshold_func = @(dists, epsilons) bsxfun(@lt, dists(:), epsilons(:)');
    stat_scale = mean(abs(op.stat_gen_func(dat.samps)));
    op.epsilon_list = logspace(-1.5, 0, 9)*stat_scale;
    
    [R, op] = ssb_abc(dat.samps, op);
    
    cols = length(opts.true_theta);
    num_eps = length(op.epsilon_list);
    post_mean = zeros(num_eps, cols);
    prob_post_mean = zeros(num_eps, cols);
    accpt_rate = zeros(num_eps, 1); 
    
    for ei = 1:num_eps
        idx_accpt_samps = R.unnorm_weights(:, ei);
        accpt_rate(ei) = sum(idx_accpt_samps);
        post_mean(ei, :) = mean(R.latent_samples(:, idx_accpt_samps), 2) ;
        [~, prob_post_mean(ei,:)] = like_sigmoid_pw_const(post_mean(ei,:), 1);
    end
    
    results.accpt_rate = accpt_rate;

elseif strcmp(num2str(whichmethod),'ssb_abc')
    
  %% (3) soft abc  
    op.stat_gen_func = @(data) [mean(data, 2) var(data,0,2)];
    op.stat_dist_func = @(stat1, stat2) norm(stat1 - stat2);
    op.threshold_func = @(dists, epsilons) exp(-bsxfun(@times, dists(:), 1./epsilons(:)'));
    stat_scale = mean(abs(op.stat_gen_func(dat.samps)));
    op.epsilon_list = logspace(-1.5, 0, 9)*stat_scale;
    
    [R, op] = ssb_abc(dat.samps, op);
    
    cols = length(opts.true_theta);
    num_eps = length(op.epsilon_list);
    post_mean = zeros(num_eps, cols);
    prob_post_mean = zeros(num_eps, cols);
    
    for ei = 1:num_eps
        post_mean(ei,:) = R.latent_samples*R.unnorm_weights(:, ei)/sum(R.unnorm_weights(:, ei)) ;
        [~, prob_post_mean(ei,:)] = like_sigmoid_pw_const(post_mean(ei,:), 1);
    end
        
elseif strcmp(num2str(whichmethod),'ssf_abc')
    
else 
    
     disp('shit, sorry! we do not know which method you are talking about');

end

%% (3) outputing results of interest

results.post_mean = post_mean;
results.prob_post_mean = prob_post_mean;
results.dat = dat; 