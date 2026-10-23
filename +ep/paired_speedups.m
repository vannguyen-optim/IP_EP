function [details,summary] = paired_speedups(runs,manifest)
%PAIRED_SPEEDUPS Matched successful runs, with separate eligible I/T counts.
rows=struct([]); summaries=struct([]);
if isempty(runs), details=table(); summary=table(); return; end
for k=1:height(runs)
    alt=runs(k,:); mi=find(strcmp({manifest.methods.key},char(alt.method_key)),1);
    if isempty(mi) || alt.status~="converged", continue; end
    method=manifest.methods(mi);
    if method.matched_step && ~strcmp(method.key,'nm')
        baseline="nm";
    elseif isfield(method,'main') && ~method.main
        baseline="nm_fast";
    else
        continue
    end
    base=runs(runs.model_id==alt.model_id & runs.trial==alt.trial & runs.method_key==baseline,:);
    if height(base)~=1 || base.status~="converged", continue; end
    ir=NaN; tr=NaN;
    if isfinite(alt.iterations) && isfinite(base.iterations) && alt.iterations>0 && base.iterations>0
        ir=base.iterations/alt.iterations;
    end
    if isfinite(alt.time_seconds) && isfinite(base.time_seconds) && alt.time_seconds>0 && base.time_seconds>0
        tr=base.time_seconds/alt.time_seconds;
    end
    id=alt.model_id; name=alt.model_name;
    if alt.model_type=="ev", id="ev_all"; name="EV (all days)"; end
    row=struct('model_id',id,'model_name',name,'instance_id',alt.model_id,...
        'trial',alt.trial,'seed',alt.seed,'baseline_key',baseline,...
        'baseline_name',base.method_name,'method_key',alt.method_key,...
        'method_name',alt.method_name,'alpha',alt.alpha,...
        'iteration_ratio_baseline_over_method',ir,'time_ratio_baseline_over_method',tr);
    if isempty(rows)
        rows=row;
    else
        rows(end+1)=row; %#ok<AGROW>
    end
end
if isempty(rows), details=table(); summary=table(); return; end
details=struct2table(rows); ids=unique(details.model_id,'stable');
for p=1:numel(ids)
    for m=1:numel(manifest.methods)
        method=manifest.methods(m);
        t=details(details.model_id==ids(p) & details.method_key==string(method.key),:);
        if isempty(t), continue; end
        ri=t.iteration_ratio_baseline_over_method; rt=t.time_ratio_baseline_over_method;
        % Ratios are defined only for the explicitly counted eligible pairs.
        ri=ri(isfinite(ri)); rt=rt(isfinite(rt));
        qi=ep.percentile(ri,[.25,.5,.75]); qt=ep.percentile(rt,[.25,.5,.75]);
        summary_row=struct('model_id',ids(p),'model_name',t.model_name(1),...
            'baseline_key',t.baseline_key(1),'baseline_name',t.baseline_name(1),...
            'method_key',string(method.key),'method_name',string(method.name),...
            'alpha',method.alpha,'n_success_pairs',height(t),...
            'n_positive_iteration_pairs',numel(ri),'n_positive_time_pairs',numel(rt),...
            'iteration_ratio_q25',qi(1),'iteration_ratio_median',qi(2),'iteration_ratio_q75',qi(3),...
            'time_ratio_q25',qt(1),'time_ratio_median',qt(2),'time_ratio_q75',qt(3));
        if isempty(summaries)
            summaries=summary_row;
        else
            summaries(end+1)=summary_row; %#ok<AGROW>
        end
    end
end
summary=struct2table(summaries);
end
