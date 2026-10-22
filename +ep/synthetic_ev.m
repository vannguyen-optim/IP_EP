function days = synthetic_ev(cfg)
%SYNTHETIC_EV Deterministic software fixture, never a scientific ACN dataset.
rng(cfg.base_seed+901,'twister');
n=12; mask=false(n,cfg.ev.n_slots);
for i=1:n
    first=randi([22,45]); last=min(88,first+randi([16,40]));
    mask(i,first:last)=true;
end
energy=cfg.ev.dt_hours*cfg.ev.power_cap_kw*sum(mask,2).*(.2+.5*rand(n,1));
ids=arrayfun(@(i)sprintf('synthetic_%03d',i),(1:n)','UniformOutput',false);
days={struct('date','2019-05-01','mask',mask,'energy',energy,...
    'session_ids',{ids},'source_kind','synthetic software check')};
end
