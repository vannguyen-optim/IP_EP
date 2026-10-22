function manifest = EP_RUN_PUBLICATION(cfg)
%EP_RUN_PUBLICATION Run or resume the full protocol. Default timing is serial.
if nargin<1, cfg=EP_CONFIG('publication'); end
assert(~cfg.synthetic_ev_for_smoke,'EP:Data','Publication runs cannot use synthetic EV data.');
manifest=ep.run(cfg);
end
