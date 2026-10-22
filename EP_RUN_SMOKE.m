function manifest = EP_RUN_SMOKE()
%EP_RUN_SMOKE Exercise all solvers, including explicitly synthetic EV fixtures.
EP_RUN_CHECKS();
cfg=EP_CONFIG('smoke');
manifest=ep.run(cfg);
end
