function files = current_exports(summary,pairs,records,manifest) %#ok<INUSD>
%CURRENT_EXPORTS Whitelist only artifacts represented by the current results.
files={}; if isempty(summary), return; end
ids=unique(string(summary.model_id),'stable');
isEV=any(ids=="ev_all"); det=ids(ids~="ev_all");
nonlinear=det(startsWith(det,'nonlinear_')); other=det(~startsWith(det,'nonlinear_'));
if manifest.cfg.export_tables
    files{end+1}=fullfile('tables','environment.tex');
    if ~isempty(nonlinear), files{end+1}=fullfile('tables','nonlinear_results.tex'); end
    if ~isempty(other)
        files{end+1}=fullfile('tables','deterministic_results.tex');
        files{end+1}=fullfile('tables','reference_solutions.tex');
    end
    if ~isempty(det)
        files{end+1}=fullfile('tables','paired_speedups.tex');
        files{end+1}=fullfile('tables','parameter_sensitivity.tex');
        files{end+1}=fullfile('tables','deterministic_discussion.tex');
    end
    if isEV
        files{end+1}=fullfile('tables','ev_results.tex');
        files{end+1}=fullfile('tables','ev_quality.tex');
        files{end+1}=fullfile('tables','ev_discussion.tex');
        if ~manifest.cfg.synthetic_ev_for_smoke && isfield(manifest,'data_snapshot') && ...
                isfield(manifest.data_snapshot,'audit')
            files{end+1}=fullfile('tables','ev_data_summary.tex');
        end
    end
end
if manifest.cfg.export_figures
    dimensions=[];
    for j=1:numel(nonlinear)
        token=regexp(char(nonlinear(j)),'^nonlinear_(\d+)_k\d+$','tokens','once');
        if ~isempty(token), dimensions(end+1)=str2double(token{1}); end %#ok<AGROW>
    end
    stems={};
    for n=unique(dimensions,'stable'), stems{end+1}=sprintf('nonlinear_%d_convergence',n); end %#ok<AGROW>
    for j=1:numel(other), stems{end+1}=[char(other(j)) '_convergence']; end %#ok<AGROW>
    if isEV, stems=[stems,{'ev_convergence','ev_daily_comparison','ev_load_profile'}]; end
    for j=1:numel(stems)
        files{end+1}=fullfile('figures',[stems{j},'.png']); %#ok<AGROW>
        files{end+1}=fullfile('figures',[stems{j},'.pdf']); %#ok<AGROW>
    end
end
end
