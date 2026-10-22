function export_tables(summary,pairs,records,manifest,folder)
%EXPORT_TABLES Current manuscript tables, frozen provenance, and brief findings.
% Brackets contain IQR widths; the CSV summaries retain Q1 and Q3 separately.
if isempty(summary), return; end
if ~isfolder(folder), mkdir(folder); end
methods=manifest.methods;
main=methods([methods.main]);
ids=string(manifest.model_ids); ids=ids(~startsWith(ids,'ev_'));
nonlinear=ids(startsWith(ids,'nonlinear_'));
other=ids(~startsWith(ids,'nonlinear_'));
if ~isempty(nonlinear)
    results_table(fullfile(folder,'nonlinear_results.tex'),nonlinear,summary,main);
end
if ~isempty(other)
    results_table(fullfile(folder,'deterministic_results.tex'),other,summary,main);
    reference_table(fullfile(folder,'reference_solutions.tex'),other,records);
end
if ~isempty(ids)
    paired_table(fullfile(folder,'paired_speedups.tex'),ids,pairs,methods);
    sensitivity_table(fullfile(folder,'parameter_sensitivity.tex'),ids,summary,pairs,methods);
    deterministic_discussion(fullfile(folder,'deterministic_discussion.tex'),summary,pairs);
end
ev=summary(summary.model_id=="ev_all",:);
if ~isempty(ev)
    ev_results(fullfile(folder,'ev_results.tex'),ev,methods);
    ev_quality(fullfile(folder,'ev_quality.tex'),ev,methods);
    ev_discussion(fullfile(folder,'ev_discussion.tex'),ev);
    if ~manifest.cfg.synthetic_ev_for_smoke
        assert(isfield(manifest,'data_snapshot') && isfield(manifest.data_snapshot,'audit'),...
            'EP:DataSnapshot','The run manifest does not contain frozen ACN selection counts. Re-run with the current package.');
        data_table(fullfile(folder,'ev_data_summary.tex'),manifest.data_snapshot.audit);
    end
end
write_environment(fullfile(folder,'environment.tex'),manifest);
end

function results_table(path,ids,summary,methods)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,'\begin{tabular}{lcccccc}'); put(fid,'\toprule');
row(fid,{'Method','Success','Iterations','Time (s)','Calls','$R_\eta$','Err'});
put(fid,'\midrule');
for k=1:numel(ids)
    put(fid,['\multicolumn{7}{l}{' model_label(ids(k)) '} \\']);
    for j=1:numel(methods)
        t=select(summary,ids(k),methods(j).key);
        if isempty(t), continue; end
        row(fid,{escape(methods(j).name),success(t),...
            triplet(t.iterations_median,t.iterations_q25,t.iterations_q75,'count'),...
            triplet(t.time_median,t.time_q25,t.time_q75,'general'),...
            mathnum(t.total_subproblems_median,'count'),...
            mathnum(t.residual_median,'scientific'),mathnum(t.reference_error_median,'scientific')});
    end
    if k<numel(ids), put(fid,'\midrule'); end
end
put(fid,'\bottomrule'); put(fid,'\end{tabular}');
end

function reference_table(path,ids,records)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,'\begin{tabular}{lcc}'); put(fid,'\toprule');
row(fid,{'Model','Reference solution','KKT residual'}); put(fid,'\midrule');
for k=1:numel(ids)
    found=find(cellfun(@(r)strcmp(r.meta.model_id,char(ids(k))),records),1);
    if isempty(found), continue; end
    m=records{found}.meta;
    if isempty(m.reference), continue; end
    parts=arrayfun(@(x)sprintf('%.7f',x),m.reference(:)','UniformOutput',false);
    row(fid,{model_label(ids(k)),['$(' strjoin(parts,',\,') ')$'],mathnum(m.reference_kkt,'scientific')});
end
put(fid,'\bottomrule'); put(fid,'\end{tabular}');
end

function paired_table(path,ids,pairs,methods)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,'\begin{tabular}{lcccc}'); put(fid,'\toprule');
row(fid,{'Model','$\alpha$','Pairs (I/T)','Iteration ratio','Time ratio'}); put(fid,'\midrule');
methods=methods([methods.matched_step] & ~strcmp({methods.key},'nm'));
for k=1:numel(ids)
    for j=1:numel(methods)
        t=select_pairs(pairs,ids(k),methods(j).key,'nm');
        [eligible,ri,rt]=ratio_cells(t);
        label=''; if j==1, label=model_label(ids(k)); end
        row(fid,{label,sprintf('%.2f',methods(j).alpha),eligible,ri,rt});
    end
    if k<numel(ids), put(fid,'\midrule'); end
end
put(fid,'\bottomrule'); put(fid,'\end{tabular}');
end

function sensitivity_table(path,ids,summary,pairs,methods)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,'\begin{tabular}{lcccccc}'); put(fid,'\toprule');
row(fid,{'Method','Success','Iterations','Time (s)','Pairs (I/T)','Iteration ratio','Time ratio'});
put(fid,'\midrule'); methods=methods(~[methods.main]);
for k=1:numel(ids)
    put(fid,['\multicolumn{7}{l}{' model_label(ids(k)) '} \\']);
    for j=1:numel(methods)
        t=select(summary,ids(k),methods(j).key);
        if isempty(t), continue; end
        p=select_pairs(pairs,ids(k),methods(j).key,'nm_fast');
        [eligible,ri,rt]=ratio_cells(p);
        row(fid,{escape(methods(j).name),success(t),...
            triplet(t.iterations_median,t.iterations_q25,t.iterations_q75,'count'),...
            triplet(t.time_median,t.time_q25,t.time_q75,'general'),eligible,ri,rt});
    end
    if k<numel(ids), put(fid,'\midrule'); end
end
put(fid,'\bottomrule'); put(fid,'\end{tabular}');
end

function ev_results(path,summary,methods)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,'\begin{tabular}{lccccc}'); put(fid,'\toprule');
row(fid,{'Method','Success','Iterations','Time (s)','$R_\eta$','Projections'}); put(fid,'\midrule');
for j=1:numel(methods)
    t=select(summary,'ev_all',methods(j).key); if isempty(t), continue; end
    if j>1 && ~methods(j).main && methods(j-1).main, put(fid,'\midrule'); end
    row(fid,{escape(methods(j).name),success(t),...
        triplet(t.iterations_median,t.iterations_q25,t.iterations_q75,'count'),...
        triplet(t.time_median,t.time_q25,t.time_q75,'general'),...
        mathnum(t.residual_median,'scientific'),mathnum(t.projection_count_median,'count')});
end
put(fid,'\bottomrule'); put(fid,'\end{tabular}');
end

function ev_quality(path,summary,methods)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,'\begin{tabular}{lccccc}'); put(fid,'\toprule');
row(fid,{'Method','$J$','$g_{\rm FW}$','Relative gap','Energy error (kWh)','Bound error (kW)'});
put(fid,'\midrule');
for j=1:numel(methods)
    t=select(summary,'ev_all',methods(j).key); if isempty(t), continue; end
    if j>1 && ~methods(j).main && methods(j-1).main, put(fid,'\midrule'); end
    row(fid,{escape(methods(j).name),mathnum(t.objective_median,'scientific'),...
        mathnum(t.gap_median,'scientific'),mathnum(t.relative_gap_max,'scientific'),...
        mathnum(t.energy_error_kwh_max,'scientific'),mathnum(t.bound_error_kw_max,'scientific')});
end
put(fid,'\bottomrule'); put(fid,'\end{tabular}');
end

function data_table(path,audit)
% Counts belong to the saved run, never to a mutable input path.
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,'\begin{tabular}{lc}'); put(fid,'\toprule'); row(fid,{'Quantity','Count'}); put(fid,'\midrule');
n=field(audit,'raw_sessions',NaN); duplicates=field(audit,'duplicates',NaN);
distinct=field(audit,'distinct_session_ids',field(audit,'distinct_ids',n-duplicates));
labels={'Input records','Distinct session identifiers','Valid same-day sessions',...
    'Excluded: no complete charging interval','Excluded: energy exceeds interval capacity',...
    'Retained sessions','Daily instances'};
counts=[n,distinct,field(audit,'valid_same_day',NaN),field(audit,'empty_window',NaN),...
    field(audit,'energy_infeasible',NaN),field(audit,'retained_sessions',NaN),field(audit,'retained_days',NaN)];
for j=1:numel(labels), row(fid,{labels{j},number(counts(j),'count')}); end
put(fid,'\bottomrule'); put(fid,'\end{tabular}');
end

function deterministic_discussion(path,summary,pairs)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
d=summary(summary.model_id~="ev_all",:);
put(fid,sprintf('The deterministic tests reach the residual tolerance in %d of %d scheduled runs.',...
    sum(d.n_success),sum(d.n_expected)));
if isempty(pairs), return; end
p=pairs(pairs.model_id~="ev_all" & pairs.baseline_key=="nm" & pairs.method_key=="i025",:);
ri=p.iteration_ratio_median; ri=ri(isfinite(ri));
if ~isempty(ri)
    put(fid,sprintf(['At the common step size, the median paired iteration ratios of NM to I-0.25 '...
        'range from %.2f to %.2f across %d instances with eligible pairs.'],min(ri),max(ri),numel(ri)));
end
p=pairs(pairs.model_id~="ev_all" & pairs.baseline_key=="nm_fast",:);
i=p.iteration_ratio_median; t=p.time_ratio_median;
i=i(isfinite(i)); t=t(isfinite(t));
if ~isempty(i) || ~isempty(t)
    put(fid,sprintf(['The scaled-step inertial configurations have median paired ratios above one in '...
        '%d of %d iteration comparisons and %d of %d time comparisons with NM-fast.'],...
        nnz(i>1),numel(i),nnz(t>1),numel(t)));
end
end

function ev_discussion(path,summary)
fid=open_text(path); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
put(fid,sprintf('The charging tests reach the residual tolerance in %d of %d scheduled runs.',...
    sum(summary.n_success),sum(summary.n_expected)));
if all(isfinite(summary.relative_gap_max)) && all(isfinite(summary.energy_error_kwh_max))
    put(fid,['The maximum normalized Frank--Wolfe gap is '...
        mathnum(max(summary.relative_gap_max),'scientific')...
        ', and the maximum energy equality error is '...
        mathnum(max(summary.energy_error_kwh_max),'scientific') ' kWh.']);
end
comparisons={{'nm','i025','At the common step size'},...
    {'nm_fast','is010','In the scaled-step comparison'}};
for j=1:numel(comparisons)
    c=comparisons{j}; a=select(summary,'ev_all',c{1}); b=select(summary,'ev_all',c{2});
    if isempty(a) || isempty(b) || ~isfinite(a.iterations_median) || ~isfinite(b.iterations_median), continue; end
    put(fid,[c{3} ', the median iteration counts are ' mathnum(a.iterations_median,'count')...
        ' for ' escape(a.method_name) ' and ' mathnum(b.iterations_median,'count')...
        ' for ' escape(b.method_name) '.']);
end
end

function write_environment(path,manifest)
env=field(manifest,'environment',struct());
release=char(string(field(env,'matlab_release','')));
if ~isempty(release) && release(1)~='R', release=['R' release]; end
if isempty(release)
    software=['MATLAB (' escape(field(manifest,'matlab_version','version recorded in protocol.json')) ')'];
else
    software=['MATLAB ' escape(release)];
end
sentence=['The experiments were run in ' software ' in double precision'];
cpu=char(string(field(env,'cpu','')));
computer=char(string(field(env,'computer',field(manifest,'computer',''))));
if ~isempty(cpu)
    sentence=[sentence ' on a system equipped with the ' escape(cpu) ' processor'];
elseif ~isempty(computer)
    sentence=[sentence ' on a \texttt{' escape(computer) '} system'];
end
parts={}; cores=field(env,'physical_cores',NaN); ram=field(env,'ram_gib',NaN);
if isnumeric(cores) && isscalar(cores) && isfinite(cores), parts{end+1}=sprintf('%d physical cores',round(cores)); end
if isnumeric(ram) && isscalar(ram) && isfinite(ram), parts{end+1}=sprintf('%.1f GiB RAM',ram); end
if ~isempty(parts), sentence=[sentence ', with ' strjoin(parts,' and ')]; end
os=char(string(field(env,'os','')));
if ~isempty(os), sentence=[sentence ', running ' escape(os)]; end
sentence=[sentence '.'];
if manifest.cfg.parallel
    sentence=[sentence sprintf(' Independent runs used a process pool with %d workers.',manifest.cfg.n_workers)];
else
    sentence=[sentence ' Runs were executed serially.'];
end
ep.write_text(path,[sentence newline]);
end

function t=select(summary,id,key)
t=summary(summary.model_id==string(id) & summary.method_key==string(key),:);
end
function t=select_pairs(pairs,id,key,baseline)
if isempty(pairs), t=table(); return; end
t=pairs(pairs.model_id==string(id) & pairs.method_key==string(key) & pairs.baseline_key==string(baseline),:);
end
function [eligible,ri,rt]=ratio_cells(t)
if isempty(t), eligible='0/0'; ri='--'; rt='--'; return; end
eligible=sprintf('%d/%d',t.n_positive_iteration_pairs,t.n_positive_time_pairs);
ri=triplet(t.iteration_ratio_median,t.iteration_ratio_q25,t.iteration_ratio_q75,'ratio');
rt=triplet(t.time_ratio_median,t.time_ratio_q25,t.time_ratio_q75,'ratio');
end
function s=success(t)
s=sprintf('%d/%d',t.n_success,t.n_expected);
end
function s=triplet(m,q1,q3,style)
if any(isnan([m,q1,q3])), s='--'; return; end
s=['$' number(m,style) '\, [' number(q3-q1,style) ']$'];
end
function s=mathnum(v,style)
if isnan(v), s='--'; else, s=['$' number(v,style) '$']; end
end
function s=number(v,style)
if isnan(v), s='--'; return; end
if isinf(v)
    if v>0, s='\infty'; else, s='-\infty'; end
    return
end
switch style
    case 'count'
        if abs(v-round(v))<1e-10, s=sprintf('%.0f',v); else, s=sprintf('%.1f',v); end
    case 'ratio', s=sprintf('%.2f',v);
    case 'scientific'
        if v==0, s='0'; return; end
        token=regexp(sprintf('%.2e',v),'^(.+)e([+-]?\d+)$','tokens','once');
        s=sprintf('%s\\times10^{%d}',token{1},str2double(token{2}));
    otherwise
        raw=sprintf('%.4g',v); token=regexp(raw,'^(.+)e([+-]?\d+)$','tokens','once');
        if isempty(token), s=raw; else, s=sprintf('%s\\times10^{%d}',token{1},str2double(token{2})); end
end
end
function label=model_label(id)
id=char(id); tok=regexp(id,'^nonlinear_(\d+)_k(\d+)$','tokens','once');
if ~isempty(tok), label=sprintf('$n=%s$, $\\kappa=%s$',tok{1},tok{2}); return; end
switch id
    case 'electricity', label='Electricity';
    case 'quadratic', label='Quadratic';
    case 'river', label='River';
    otherwise, label=escape(id);
end
end
function s=escape(s)
s=char(string(s)); s=strrep(s,'\',char(1));
a={'{','}','_','%','&','#','$'};
for j=1:numel(a), s=strrep(s,a{j},['\' a{j}]); end
s=strrep(s,'~','\textasciitilde{}'); s=strrep(s,'^','\textasciicircum{}');
s=strrep(s,char(1),'\textbackslash{}');
end
function v=field(s,name,default)
if isstruct(s) && isfield(s,name), v=s.(name); else, v=default; end
end
function fid=open_text(path)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'EP:ExportOpen','Cannot create %s.',path);
end
function put(fid,text)
fprintf(fid,'%s\n',text);
end
function row(fid,cells)
put(fid,[strjoin(cells,' & ') ' \\']);
end
