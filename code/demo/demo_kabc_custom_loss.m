% function demo_kabc_custom_loss( )
%DEMO_KABC_CUSTOM_LOSS Demonstrate how to use kabc_custom_loss
%@author Wittawat
%
seed = 3;
oldRng = rng();
rng(seed);

% The following functions are not needed by kabc_custom_loss
% Just for data construction.
%
% Likelihood function handle.
%  Gaussian likelihood as an example
%likelihood_func = @(theta, n)randn(1, n) + theta;
% 
% Exponential likelihood
likelihood_func = @(theta, n)exprnd(theta, 1, n);

% A proposal distribution for drawing the latent variables of interest.
%proposal_dist = @(n)randn(1, n)*sqrt(8);
%
% uniform 
proposal_dist = @(n)unifrnd(0.1, 10, 1, n);
% a function for computing a vector of summary statistics from a set of samples
% func : (d x n) -> p x 1 vector for some p
stat_gen_func = @(data) 1./(1+ exp(-mean(data, 2)));
%stat_gen_func = @(data) geomean(data, 2);

% kabc needs a training set containing (summary stat, parameter) pairs.
% construct a training set
num_latent_draws = 500; % this is also the training size
num_pseudo_data = 200;
train_params = proposal_dist(num_latent_draws);
train_stats = zeros(1, num_latent_draws);
% for each single parameter, we need to construct a summary statistic of 
% observations generated by the parameter.
for i=1:size(train_params, 2)
    theta = train_params(:, i);
    observations = likelihood_func(theta, num_pseudo_data);
    stat = stat_gen_func(observations);
    train_stats(:, i) = stat;
end


% ------- options for kabc ------------
% All options are described in kabc_cond_embed
op = struct();
op.seed = seed;

% a list of regularization parameter candidates in kabc. 
% Chosen by cross validation.
ntr = num_latent_draws;
op.kabc_reg_list = 10.^(-4:2:4)/sqrt(ntr);

% a list of Gaussian widths squared to be used as candidates for Gaussian kernel
op.kabc_gwidth2_list = [1/8, 1/4, 1, 2].* (meddistance(train_stats)^2);

%
% generate some actual observations.
true_theta = 3;
num_obs = 300;
num_obs_validate = ceil(0.75*num_obs);
obs = likelihood_func(true_theta, num_obs );
observed_stat = stat_gen_func(obs(1:num_obs_validate));
held_out_obs = obs( (num_obs_validate+1):end);

% Loss function to be used to measure the goodness of parameters (Gaussian width ,
% regularization parameter). A loss function takes the form 
% f: (weights_func, train_stats ) -> real number.  
% Lower is better.
op.kabc_loss_func = @(weights_func, train_stats)norm(hist(likelihood_func(train_stats*weights_func(observed_stat), 500))-hist(held_out_obs));
% ---- training ------
[R, op] = kabc_custom_loss(train_stats, train_params, op);
% R contains a regression function mapping from a stat to its param
%

display(R);

weights_func = R.regress_weights_func ;
W = weights_func(stat_gen_func(obs));
%% plot weights given by the regression function corresponding to the best 
% chosen parameters.
%figure 
hold on
stem(train_params, W);
set(gca, 'fontsize', 16);
title(sprintf('true theta: %.2g, Observed stat: %.2g, likelihood = %s', ...
   true_theta, observed_stat, ...
   func2str(likelihood_func) ));
grid on
hold off 


% change seed back 
rng(oldRng);
% end

